extends Node
## Email and password accounts through Supabase Auth's REST API. There's no
## SDK for Godot, so this calls the endpoints with HTTPRequest, which the web
## build turns into fetch().
##
## The project URL and publishable key live in project.godot under
## [supabase]. The publishable key is meant to ship in the client; row level
## security protects the data. With either one empty, accounts are off and
## the menu hides the account button.
##
## The session is kept in user://session.cfg (IndexedDB in a browser). An
## access token lasts an hour, so a timer swaps it for a fresh one through
## the refresh token a couple of minutes before it runs out.

signal changed

const SESSION := "user://session.cfg"
const REFRESH_MARGIN := 120.0
const MIN_PASSWORD := 6

var url := ""
var key := ""
var email := ""
var user_id := ""
var access_token := ""
var refresh_token := ""
var expires_at := 0.0
## True while a sign in, sign up or refresh is waiting on the server.
var busy := false
## The last thing worth telling the player, good or bad.
var message := ""
var message_is_error := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	url = str(ProjectSettings.get_setting("supabase/url", "")).strip_edges().trim_suffix("/")
	key = str(ProjectSettings.get_setting("supabase/publishable_key", "")).strip_edges()
	if not enabled():
		return
	_load()
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()
	if _from_link():
		return
	if refresh_token != "":
		_refresh()


## The confirmation email's link opens the game with the new session after
## the #. Supabase sends it to the Site URL set in the dashboard
## (Authentication > URL Configuration), which has to be this page.
func _from_link() -> bool:
	if not OS.has_feature("web"):
		return false
	var hash := str(JavaScriptBridge.eval("window.location.hash", true)).trim_prefix("#")
	if hash == "":
		return false
	var q := {}
	for pair in hash.split("&"):
		var kv := pair.split("=", true, 1)
		if kv.size() == 2:
			q[kv[0]] = kv[1].uri_decode()
	if not q.has("access_token") and not q.has("error"):
		return false
	# Takes the tokens out of the address bar and the history.
	JavaScriptBridge.eval("history.replaceState(null, '', location.pathname + location.search)", true)
	if q.has("error"):
		var expired := str(q.get("error_code", "")) == "otp_expired"
		_say("That link has expired. Sign in to get a new one." if expired else str(q.get("error_description", "That link didn't work.")).replace("+", " "), true)
		return true
	var claims := _jwt_claims(str(q["access_token"]))
	_take({
		"access_token": q["access_token"],
		"refresh_token": q.get("refresh_token", ""),
		"expires_at": float(q.get("expires_at", Time.get_unix_time_from_system() + 3600)),
		"user": {"email": claims.get("email", ""), "id": claims.get("sub", "")},
	})
	_say("Email confirmed. Signed in as %s." % email)
	return true


## The middle part of a JWT, which holds the email and user id. Trusted only
## for display: Supabase checks the signature on every request.
func _jwt_claims(token: String) -> Dictionary:
	var parts := token.split(".")
	if parts.size() != 3:
		return {}
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var parsed: Variant = JSON.parse_string(Marshalls.base64_to_raw(b64).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


func enabled() -> bool:
	return url != "" and key != ""


func signed_in() -> bool:
	return access_token != ""


func sign_in(mail: String, password: String) -> void:
	mail = mail.strip_edges()
	if not _check(mail, password):
		return
	_start("Signing in...")
	var res := await _post("/auth/v1/token?grant_type=password", {"email": mail, "password": password})
	busy = false
	if res["error"] != "":
		_say(res["error"], true)
		return
	_take(res["data"])
	_say("Signed in as %s." % email)


func sign_up(mail: String, password: String) -> void:
	mail = mail.strip_edges()
	if not _check(mail, password):
		return
	_start("Creating your account...")
	var res := await _post("/auth/v1/signup", {"email": mail, "password": password})
	busy = false
	if res["error"] != "":
		_say(res["error"], true)
		return
	var data: Dictionary = res["data"]
	# With email confirmation on, Supabase sends a link and no session.
	if data.has("access_token"):
		_take(data)
		_say("Account created. Signed in as %s." % email)
	else:
		_say("Check %s for a link to confirm your account, then sign in." % mail)


func sign_out() -> void:
	var token := access_token
	_clear()
	_say("Signed out.")
	if token != "":
		# Ends the session on the server too. Already signed out here if it fails.
		_post("/auth/v1/logout", {}, token)


func _tick() -> void:
	if refresh_token != "" and not busy and expires_at - Time.get_unix_time_from_system() < REFRESH_MARGIN:
		_refresh()


func _refresh() -> void:
	var sent := refresh_token
	busy = true
	var res := await _post("/auth/v1/token?grant_type=refresh_token", {"refresh_token": sent})
	busy = false
	# Signed out or signed in again while this was waiting: the answer is stale.
	if refresh_token != sent:
		return
	if res["error"] == "":
		_take(res["data"])
	elif int(res["code"]) in [400, 401, 403]:
		# The refresh token was revoked or already used.
		_clear()
		_say("Your session ended. Sign in again.", true)
	# Any other failure is most likely no network. Keep the session and retry on the next tick.


func _check(mail: String, password: String) -> bool:
	if busy:
		return false
	if not enabled():
		_say("Accounts aren't set up in this build.", true)
		return false
	var at := mail.find("@")
	if at < 1 or mail.find(".", at) == -1:
		_say("Enter a valid email address.", true)
		return false
	if password.length() < MIN_PASSWORD:
		_say("The password needs at least %d characters." % MIN_PASSWORD, true)
		return false
	return true


func _start(text: String) -> void:
	busy = true
	_say(text)


func _say(text: String, is_error := false) -> void:
	message = text
	message_is_error = is_error
	changed.emit()


func _take(data: Dictionary) -> void:
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", refresh_token))
	var now := Time.get_unix_time_from_system()
	expires_at = float(data.get("expires_at", now + float(data.get("expires_in", 3600))))
	var user: Dictionary = data.get("user", {}) if data.get("user") is Dictionary else {}
	email = str(user.get("email", email))
	user_id = str(user.get("id", user_id))
	_save()
	changed.emit()


func _clear() -> void:
	access_token = ""
	refresh_token = ""
	expires_at = 0.0
	email = ""
	user_id = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION))
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "access_token", access_token)
	cfg.set_value("session", "refresh_token", refresh_token)
	cfg.set_value("session", "expires_at", expires_at)
	cfg.set_value("session", "email", email)
	cfg.set_value("session", "user_id", user_id)
	cfg.save(SESSION)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION) != OK:
		return
	access_token = str(cfg.get_value("session", "access_token", ""))
	refresh_token = str(cfg.get_value("session", "refresh_token", ""))
	expires_at = float(cfg.get_value("session", "expires_at", 0.0))
	email = str(cfg.get_value("session", "email", ""))
	user_id = str(cfg.get_value("session", "user_id", ""))


## POSTs JSON to Supabase. Returns {code, data, error}, where error is a line
## for the player and empty on success.
func _post(path: String, body: Dictionary, token := "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray(["apikey: " + key, "Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var offline := {"code": 0, "data": {}, "error": "Couldn't reach the server. Check your connection."}
	if http.request(url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		http.queue_free()
		return offline
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return offline
	var code := int(res[1])
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var error := "" if code >= 200 and code < 300 else _error_text(data, code)
	return {"code": code, "data": data, "error": error}


func _error_text(data: Dictionary, code: int) -> String:
	match str(data.get("error_code", data.get("error", ""))):
		"invalid_credentials", "invalid_grant":
			return "Wrong email or password."
		"email_not_confirmed":
			return "Confirm your email first. The link is in your inbox."
		"user_already_exists", "email_exists":
			return "That email already has an account. Sign in instead."
		"over_request_rate_limit", "over_email_send_rate_limit":
			return "Too many tries. Wait a minute and try again."
	for field in ["msg", "error_description", "message"]:
		if str(data.get(field, "")) != "":
			return str(data[field])
	return "Something went wrong (%d)." % code
