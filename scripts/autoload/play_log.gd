extends Node
## Sends each play to Supabase, as this player (Auth): one row in `plays`,
## kept up to date, and the records Telemetry makes in `play_events`. See
## supabase/migrations for the tables and who may write what.
##
## Nothing here may slow the game or stop it. Records wait in memory and go
## in batches, every FLUSH_S seconds and at the end of a wave or a death.
## What can't be sent (no network, the game closing) is kept in
## user://play_log_queue.json and sent the next time the game starts. Event
## rows carry a sequence number per play, so a batch sent twice is stored
## once.

const FLUSH_S := 20.0
const BATCH := 200
## At most this many unsent events are kept; the oldest go first. About 25
## full games.
const MAX_QUEUED := 5000
## The database takes at most this many events per play (play_events_ranges).
const MAX_PER_PLAY := 10000
const QUEUE := "user://play_log_queue.json"
const ENDPOINT_PLAYS := "/rest/v1/plays"
const ENDPOINT_EVENTS := "/rest/v1/play_events"

## The play in progress, or "" between games.
var play_id := ""
## Returns the play's summary fields (see Game.log_summary). Set by Game.
var summary_fn := Callable()
var _seq := 0
var _finished := false
## Waiting to be sent: new plays, event rows, and the latest fields per play.
var _creates: Array = []
var _events: Array = []
var _patches := {}
var _sending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Auth.enabled():
		return
	_load_queue()
	var timer := Timer.new()
	timer.wait_time = FLUSH_S
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()
	Auth.changed.connect(func() -> void:
		if Auth.signed_in():
			_flush())


## A new play. `info` has mode, seed, party, cls and name.
func begin(info: Dictionary) -> void:
	if not Auth.enabled():
		return
	play_id = _uuid()
	_seq = 0
	_finished = false
	_creates.append({
		"id": play_id,
		"started_at": _now(),
		"mode": info.get("mode", "solo"),
		"match_seed": int(info.get("seed", 0)),
		"party_size": int(info.get("party", 1)),
		"hero_class": str(info.get("cls", "")),
		"hero_name": str(info.get("name", "")),
		"platform": OS.get_name().to_lower() + ("/touch" if Touch.on else ""),
		"build": str(ProjectSettings.get_setting("application/config/version", "dev")),
	})
	_flush()


## A record from Telemetry: ["log", slot, kind, t, chapter, wave, data].
func add(e: Array) -> void:
	if play_id == "" or _finished or _seq >= MAX_PER_PLAY:
		return
	_events.append({"play_id": play_id, "seq": _seq, "slot": e[1], "kind": e[2], "t": e[3],
		"chapter": e[4], "wave": e[5], "data": e[6]})
	_seq += 1
	if e[2] in ["death", "wave_end", "hero_wave", "game_over"]:
		_flush()


## Ends the play. Only the first call counts, so every way out of a game can
## call it.
func finish(outcome: String) -> void:
	if play_id == "" or _finished:
		return
	_update_summary()
	var p: Dictionary = _patches.get(play_id, {})
	p["outcome"] = outcome
	p["ended_at"] = _now()
	_patches[play_id] = p
	_finished = true
	summary_fn = Callable()
	play_id = ""
	_save_queue()
	_flush()


func _tick() -> void:
	_update_summary()
	_flush()


func _update_summary() -> void:
	if play_id == "" or _finished or not summary_fn.is_valid():
		return
	var p: Dictionary = _patches.get(play_id, {})
	p.merge(summary_fn.call(), true)
	_patches[play_id] = p


func _flush() -> void:
	if _sending or not Auth.signed_in():
		return
	if _creates.is_empty() and _events.is_empty() and _patches.is_empty():
		return
	_sending = true
	var ok := await _send_all()
	_sending = false
	if not ok:
		_save_queue()
	elif play_id == "":
		_save_queue()


## Sends in order: plays first, since events need their play. Stops at the
## first failure and keeps the rest.
func _send_all() -> bool:
	while not _creates.is_empty():
		var row: Dictionary = _creates[0]
		var res := await Auth.api(HTTPClient.METHOD_POST, ENDPOINT_PLAYS + "?on_conflict=id", row,
			"resolution=ignore-duplicates,return=minimal")
		if not _handled(res, "play"):
			return false
		_creates.pop_front()
	while not _events.is_empty():
		var batch := _events.slice(0, BATCH)
		var res := await Auth.api(HTTPClient.METHOD_POST, ENDPOINT_EVENTS + "?on_conflict=play_id,seq", batch,
			"resolution=ignore-duplicates,return=minimal")
		if not _handled(res, "events"):
			return false
		# add() may have appended while this batch was out; only drop what was sent.
		_events = _events.slice(batch.size())
	for id: String in _patches.keys():
		var fields: Dictionary = _patches[id]
		var res := await Auth.api(HTTPClient.METHOD_PATCH, ENDPOINT_PLAYS + "?id=eq." + id, fields, "return=minimal")
		if not _handled(res, "update"):
			return false
		# Newer fields may have arrived while this was out: keep those for next time.
		if _patches.get(id) == fields:
			_patches.erase(id)
	return true


## True when the request went through, or failed in a way a retry won't fix
## (the row is dropped then, so one bad row can't block the rest).
func _handled(res: Dictionary, what: String) -> bool:
	if res["error"] == "":
		return true
	var code := int(res["code"])
	# 404: the tables aren't there yet (migration not applied). Keep it all for later.
	if code == 0 or code == 401 or code == 404 or code == 408 or code == 429 or code >= 500:
		return false
	push_warning("PlayLog: %s dropped (%d): %s" % [what, code, res["error"]])
	return true


func _save_queue() -> void:
	if _events.size() > MAX_QUEUED:
		_events = _events.slice(_events.size() - MAX_QUEUED)
	var f := FileAccess.open(QUEUE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"creates": _creates, "events": _events, "patches": _patches}))


func _load_queue() -> void:
	if not FileAccess.file_exists(QUEUE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUEUE))
	if not parsed is Dictionary:
		return
	# JSON reads every number back as a float, and Postgres won't take 3.0 for an integer.
	_creates = _whole(parsed.get("creates", []))
	_events = _whole(parsed.get("events", []))
	_patches = _whole(parsed.get("patches", {}))


static func _whole(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _whole(x))
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _whole(v[k])
		return out
	return v


static func _now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


static func _uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
