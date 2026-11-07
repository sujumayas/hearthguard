extends Control
## The title screen and lobby: a name, one of the four heroes, then solo,
## host or join. In the lobby each player gets a corridor (west, north,
## east); a corridor with no one in it stays shut for the whole game.

const BONE := Color("f4efe6")
const DIM := Color("8a8494")
const DUSK := Color("1d1828")
const EDGE := Color("3a3248")

var heading: Font
var body: Font
var name_edit: LineEdit
var addr_edit: LineEdit
var status := ""
var in_lobby := false
var t := 0.0
var hits: Array = []
var mouse := Vector2.ZERO
var picked := "fighter"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	heading = load("res://assets/fonts/kanit.tres")
	body = load("res://assets/fonts/outfit.tres")
	picked = Net.my_cls
	name_edit = LineEdit.new()
	name_edit.text = Net.my_name
	name_edit.placeholder_text = "Your name"
	name_edit.max_length = 16
	name_edit.add_theme_font_override("font", body)
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.text_changed.connect(func(s: String) -> void: Net.set_identity(s, picked))
	add_child(name_edit)
	addr_edit = LineEdit.new()
	addr_edit.placeholder_text = "Host address (e.g. 192.168.1.20)"
	addr_edit.add_theme_font_override("font", body)
	addr_edit.add_theme_font_size_override("font_size", 16)
	add_child(addr_edit)
	Net.lobby_changed.connect(func() -> void:
		in_lobby = not Net.players.is_empty() and Net.online)
	Net.failed.connect(func(msg: String) -> void:
		status = msg
		in_lobby = false)
	Net.closed.connect(func() -> void:
		status = "The host closed the game."
		in_lobby = false)
	Sfx.music("music_menu")
	gui_input.connect(_on_input)


## The web build is solo for now: a browser can't host, and joining a desktop
## host from an https page needs a wss:// address (see README).
var SOLO_ONLY := OS.has_feature("web")


func _process(delta: float) -> void:
	t += delta
	mouse = get_local_mouse_position()
	var cx := size.x * 0.5
	name_edit.position = Vector2(cx - 150, 150)
	name_edit.size = Vector2(300, 38)
	addr_edit.position = Vector2(cx + 30, size.y - 108)
	addr_edit.size = Vector2(260, 40)
	addr_edit.visible = not in_lobby
	addr_edit.editable = not SOLO_ONLY
	queue_redraw()


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in range(hits.size() - 1, -1, -1):
			if (hits[i][0] as Rect2).has_point(e.position):
				(hits[i][1] as Callable).call()
				Sfx.play("click", 0.6)
				return


func _btn(r: Rect2, text: String, fn: Callable, col := DUSK) -> void:
	var over := r.has_point(mouse)
	Kept.rect(self, r, col.lightened(0.12) if over else col)
	Kept.rect(self, r, EDGE, false, 2.0)
	_center(r.get_center().x, r.position.y + r.size.y * 0.5 + 7, text, 19, BONE, body)
	hits.append([r, fn])


## A button that's there but can't be pressed yet.
func _btn_off(r: Rect2, text: String) -> void:
	Kept.rect(self, r, DUSK.darkened(0.35))
	Kept.rect(self, r, Color(EDGE, 0.4), false, 2.0)
	_center(r.get_center().x, r.position.y + r.size.y * 0.5 + 1, text, 17, Color(BONE, 0.35), body)
	_center(r.get_center().x, r.position.y + r.size.y - 5, "Coming soon", 11, Color("ffbf5e", 0.8), body)


func _center(x: float, y: float, text: String, s: int, col: Color, f: Font = null) -> void:
	var font := f if f != null else heading
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string(font, Vector2(x - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)


func _draw() -> void:
	hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color("0f0c16"))
	# Embers rising from a fire below, the Town's Hearth.
	for i in 60:
		var x := fmod(i * 97.3, size.x)
		var y := size.y - fmod(t * (30.0 + i % 7 * 9.0) + i * 53.0, size.y + 40.0)
		Kept.disc(self, Vector2(x + sin(t + i) * 12.0, y), 2.0 + i % 3, Color(1.0, 0.6, 0.2, 0.35))
	var cx := size.x * 0.5
	_center(cx, 74, "Hearthguard", 58, Color("ffd27a"))
	_center(cx, 106, "A MatchRPG hero defense  ·  Kingsfoil Studios", 17, DIM, body)
	_center(cx, 140, "Everything the heroes went down to fight is climbing up to the Town.", 15, Color(1, 1, 1, 0.6), body)
	# The four heroes.
	var w := 230.0
	var x0 := cx - w * 2.0 - 15.0
	for i in HeroClasses.ORDER.size():
		var id: String = HeroClasses.ORDER[i]
		var c: Dictionary = HeroClasses.get_def(id)
		var r := Rect2(x0 + i * (w + 10), 205, w, 300)
		var sel := id == picked
		Kept.rect(self, r, (c["color"] as Color).darkened(0.7) if sel else DUSK)
		Kept.rect(self, r, (c["color"] as Color) if sel else EDGE, false, 3.0 if sel else 2.0)
		var rank := 5 if sel else 1
		var pose := {"frame": HeroLook.frame_at(t)}
		if sel and fmod(t, 2.0) < 0.5:
			var k := fmod(t, 2.0) / 0.5
			match id:
				"archer":
					pose["aim"] = k
				"mage":
					pose["cast"] = k
				_:
					pose["swing"] = k
		HeroLook.draw(self, r.position + Vector2(w * 0.5 - 44, 26), 2.0, c["color"], [c["branch"], "r:%d" % rank], pose)
		draw_set_transform(Vector2.ZERO)
		_center(r.get_center().x, r.position.y + 190, c["name"], 26, (c["color"] as Color).lightened(0.3))
		var lines := _wrap(c["desc"], w - 24, 14)
		for k2 in mini(lines.size(), 4):
			_center(r.get_center().x, r.position.y + 214 + k2 * 18, lines[k2], 14, Color(1, 1, 1, 0.75), body)
		var cid := id
		hits.append([r, func() -> void:
			picked = cid
			Net.set_identity(name_edit.text, cid)])
	if in_lobby:
		_draw_lobby(cx)
	elif SOLO_ONLY:
		_btn(Rect2(cx - 290, size.y - 160, 180, 44), "Play solo", func() -> void:
			Net.set_identity(name_edit.text, picked)
			Net.solo()
			Net.start_game())
		_btn_off(Rect2(cx - 90, size.y - 160, 180, 44), "Host a game")
		_btn_off(Rect2(cx + 110, size.y - 160, 180, 44), "Join")
		draw_string(body, Vector2(cx - 290, size.y - 82), "Online co-op for up to 3 players is coming soon.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	else:
		_btn(Rect2(cx - 290, size.y - 160, 180, 44), "Play solo", func() -> void:
			Net.set_identity(name_edit.text, picked)
			Net.solo()
			Net.start_game())
		_btn(Rect2(cx - 90, size.y - 160, 180, 44), "Host a game", func() -> void:
			Net.set_identity(name_edit.text, picked)
			status = Net.host()
			if status == "":
				in_lobby = true)
		_btn(Rect2(cx + 110, size.y - 160, 180, 44), "Join", func() -> void:
			Net.set_identity(name_edit.text, picked)
			status = Net.join(addr_edit.text)
			if status == "":
				status = "Connecting...")
		draw_string(body, Vector2(cx - 290, size.y - 82), "Up to 3 players. Each one opens a corridor.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	if status != "":
		_center(cx, size.y - 30, status, 16, Color("ffbf5e"), body)


func _draw_lobby(cx: float) -> void:
	var r := Rect2(cx - 300, 520, 600, 140)
	Kept.rect(self, r, Color(0.08, 0.07, 0.11, 0.95))
	Kept.rect(self, r, EDGE, false, 2.0)
	var host_note := "You are hosting on port %d. Friends join with your address." % Net.PORT if Net.is_host() else "Connected. Waiting for the host to start."
	draw_string(body, r.position + Vector2(16, 26), host_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	if Net.is_host():
		var ips: Array = Array(IP.get_local_addresses()).filter(func(a: String) -> bool: return a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"))
		draw_string(body, r.position + Vector2(16, 46), "Your address: " + ", ".join(ips.slice(0, 3)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd98a"))
	var y := r.position.y + 72
	var ids: Array = Net.players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.players[a]["slot"]) < int(Net.players[b]["slot"]))
	for id: int in ids:
		var p: Dictionary = Net.players[id]
		var c: Dictionary = HeroClasses.get_def(p["cls"])
		var lane: String = MapData.CORRIDORS[int(p["slot"])]["name"]
		draw_string(heading, Vector2(r.position.x + 16, y), "%s  ·  %s  ·  %s" % [p["name"], c["name"], lane], HORIZONTAL_ALIGNMENT_LEFT, -1,
			18, (c["color"] as Color).lightened(0.3))
		y += 24
	if Net.is_host():
		_btn(Rect2(r.end.x - 170, r.end.y - 54, 154, 42), "Start", func() -> void: Net.start_game(), Color("2f5a2a"))
	_btn(Rect2(r.end.x - 330, r.end.y - 54, 150, 42), "Leave", func() -> void:
		Net.leave()
		in_lobby = false)


func _wrap(text: String, width: float, s: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if body.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
