extends Node2D
## The match. On the host it runs the Sim at the preset's tick rate and
## sends the clients what happened (events, reliable), where the mobs are
## (a packed snapshot, 15 a second) and the heroes' numbers (10 a second).
## Every screen, the host's too, draws from those. Each player moves their
## own hero here and tells the host where it is and what it hits.

const SNAP_EVERY := 2
const STATE_EVERY := 3
const SYNC_EVERY := 2

var map: MapData
var sim: Sim
var view: View
var map_view: MapView
var overlay: Node2D
var cam: Camera2D
var hud: Hud
var ctrl: HeroControl
var slots := {}
var my_slot := 0
var is_host := true
var started := false
var loaded := {}
var state := {}
var remote := {}
var tick := 0
var trauma := 0.0
var cam_locked := false
var cam_pos := Vector2.ZERO
var zoom := 1.0
var over_shown := false
## The play logs: Telemetry reads the Sim on the host, PlayLog stores.
var telemetry: Telemetry


func _ready() -> void:
	name = "Game"
	slots = Net.slots()
	if slots.is_empty():
		Net.solo()
		slots = Net.slots()
	my_slot = Net.my_slot()
	is_host = multiplayer.is_server()
	map = MapData.new()
	map_view = MapView.new()
	add_child(map_view)
	map_view.setup(map, active_lanes())
	view = View.new()
	view.map = map
	view.game = self
	view.local_slot = my_slot
	add_child(view)
	overlay = Node2D.new()
	overlay.z_index = 5
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()
	var info: Dictionary = slots.get(my_slot, {"cls": "fighter", "name": "Hero"})
	ctrl = HeroControl.new()
	add_child(ctrl)
	ctrl.setup(self, map, view, my_slot, info["cls"])
	cam_pos = ctrl.pos
	# Follows by default: the preset says "free", but losing your hero in a
	# horde is never fun. Y frees it, edge pan and arrows then move it.
	cam_locked = true
	if Touch.on:
		zoom = 1.1
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	view.shake.connect(func(a: float) -> void: trauma = minf(1.0, trauma + a))
	view.callout.connect(func(text: String, col: Color, size: float) -> void: hud.callout(text, col, size))
	for s: int in slots:
		view.heroes[s] = {"slot": s, "cls": slots[s]["cls"], "name": slots[s]["name"], "pos": MapData.hero_start(s),
			"flip": false, "alive": true, "hp": 1.0, "max_hp": 1.0}
	Net.closed.connect(_on_host_gone)
	PlayLog.begin({"mode": ("host" if is_host else "join") if Net.online else "solo", "seed": Net.seed_value,
		"party": slots.size(), "cls": info["cls"], "name": info["name"]})
	PlayLog.summary_fn = log_summary
	if is_host:
		sim = Sim.new(Net.seed_value, slots, map)
		telemetry = Telemetry.new(sim)
		loaded[1] = true
		_try_start()
	else:
		_rpc_loaded.rpc_id(1)
	Engine.physics_ticks_per_second = Tuning.tick_rate()


func active_lanes() -> Array:
	var out: Array = slots.keys()
	out.sort()
	return out


## The share of the Town's HP still standing (every building at full is 1).
func town_frac() -> float:
	return clampf(float(state.get("town_hp", 1.0)) / maxf(1.0, float(state.get("town_max", 1.0))), 0.0, 1.0)


# --- Network -----------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _rpc_loaded() -> void:
	loaded[multiplayer.get_remote_sender_id()] = true
	_try_start()


func _try_start() -> void:
	for s: int in slots:
		if not loaded.has(int(slots[s]["peer"])):
			return
	started = true


func peer_left(peer: int) -> void:
	if sim == null:
		return
	for s: int in slots:
		if int(slots[s]["peer"]) == peer:
			toast("%s left. Their corridor goes quiet." % slots[s]["name"])
			var h: HeroState = sim.heroes.get(s)
			if h != null:
				sim.heroes.erase(s)
				sim.players = maxi(1, sim.heroes.size())
	_try_start()


func _exit_tree() -> void:
	# Leave, Back to the Town, or the window closing. A play that ended
	# already keeps its outcome.
	PlayLog.finish("quit")


## What the play's row in `plays` holds, from what this screen knows.
func log_summary() -> Dictionary:
	var me: Dictionary = state.get("heroes", {}).get(my_slot, {})
	var d: Dictionary = state.get("dir", {})
	var out := {"chapter": int(d.get("chapter", 0)), "wave": int(d.get("wave", 0)),
		"duration_s": snappedf(float(state.get("t", 0.0)), 0.1), "hearth_frac": snappedf(town_frac(), 0.001)}
	if not me.is_empty():
		out.merge({"level": int(me.get("level", 1)), "kills": int(me.get("kills", 0)), "deaths": int(me.get("deaths", 0)),
			"damage_done": roundf(float(me.get("dmg", 0.0))), "damage_taken": roundf(float(me.get("taken", 0.0))),
			"gold": int(me.get("gold", 0)),
			"final": {"ranks": me.get("ranks", []), "talents": me.get("talents", []), "belt": me.get("belt", [])}}, true)
	return out


func _on_host_gone() -> void:
	PlayLog.finish("disconnected")
	hud.show_end("The host left", "The connection to the host was lost.")


@rpc("authority", "reliable")
func _rpc_events(ev: Array) -> void:
	_handle(ev)


@rpc("authority", "unreliable_ordered")
func _rpc_snap(buf: PackedByteArray) -> void:
	view.read_snapshot(buf, float(SNAP_EVERY) / Tuning.tick_rate())


@rpc("authority", "unreliable_ordered")
func _rpc_state(st: Dictionary) -> void:
	_apply_state(st)


@rpc("any_peer", "unreliable_ordered")
func _rpc_sync(p: Vector2, look: Dictionary) -> void:
	_on_sync(_sender_slot(), p, look)


@rpc("any_peer", "reliable")
func _rpc_cmd(cmd: String, args: Array) -> void:
	_on_cmd(_sender_slot(), cmd, args)


func _sender_slot() -> int:
	var id := multiplayer.get_remote_sender_id()
	for s: int in slots:
		if int(slots[s]["peer"]) == id:
			return s
	return -1


func _on_sync(slot: int, p: Vector2, look: Dictionary) -> void:
	if sim == null or not sim.heroes.has(slot):
		return
	var h: HeroState = sim.heroes[slot]
	if map.is_open(p):
		h.pos = p
	h.flip = look.get("flip", false)
	h.moving = look.get("moving", false)
	remote[slot] = look


func _on_cmd(slot: int, cmd: String, args: Array) -> void:
	if sim == null or not sim.heroes.has(slot):
		return
	var h: HeroState = sim.heroes[slot]
	match cmd:
		"attack":
			Skills.attack(sim, h, int(args[0]))
		"cast":
			if not Skills.cast(sim, h, int(args[0]), args[1], int(args[2])):
				sim.emit(["denied", slot])
		"learn":
			Skills.learn(sim, h, int(args[0]))
		"talent":
			Skills.pick_talent(sim, h, int(args[0]), int(args[1]))
		"drink":
			Skills.drink(sim, h, int(args[0]), args[1])
		"buy":
			Skills.buy(sim, h, str(args[0]))
		"build":
			sim.build(h, str(args[0]))
		"ready":
			sim.director.call_wave(slot)


func _send(cmd: String, args: Array) -> void:
	if is_host:
		_on_cmd(my_slot, cmd, args)
	else:
		_rpc_cmd.rpc_id(1, cmd, args)


func send_attack(id: int) -> void:
	_send("attack", [id])


func send_cast(i: int, at: Vector2, tid: int) -> void:
	_send("cast", [i, at, tid])
	view.heroes.get(my_slot, {})["cast_t"] = 0.0


func send_learn(i: int) -> void:
	_send("learn", [i])


func send_talent(row: int, choice: int) -> void:
	_send("talent", [row, choice])


func send_drink(i: int, at: Vector2) -> void:
	_send("drink", [i, at])


func send_buy(id: String) -> void:
	_send("buy", [id])


func send_build(id: String) -> void:
	_send("build", [id])


func send_ready() -> void:
	_send("ready", [])


# --- The tick ------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	tick += 1
	if is_host and started and sim != null:
		var me: HeroState = sim.heroes.get(my_slot)
		if me != null:
			if map.is_open(ctrl.pos):
				me.pos = ctrl.pos
			me.flip = ctrl.flip()
			me.moving = ctrl.moving
			remote[my_slot] = ctrl.look()
		sim.step()
		var ev := sim.take_events()
		ev.append_array(telemetry.observe(ev))
		if not ev.is_empty():
			_handle(ev)
			if Net.online:
				_rpc_events.rpc(ev)
		var buf := sim.pack_mobs()
		view.read_snapshot(buf, 1.0 / Tuning.tick_rate())
		if Net.online and tick % SNAP_EVERY == 0:
			_rpc_snap.rpc(buf)
		if tick % STATE_EVERY == 0:
			var st := sim.pack_state()
			st["looks"] = remote
			_apply_state(st)
			if Net.online:
				_rpc_state.rpc(st)
	elif not is_host and tick % SYNC_EVERY == 0:
		_rpc_sync.rpc_id(1, ctrl.pos, ctrl.look())


func _apply_state(st: Dictionary) -> void:
	state = st
	view.dark = st.get("dark", view.dark)
	var hs: Dictionary = st.get("heroes", {})
	var looks: Dictionary = st.get("looks", {})
	for s: int in hs:
		var d: Dictionary = hs[s]
		if s == my_slot:
			ctrl.apply_info(d)
		var hp: Dictionary = view.heroes.get(s, {})
		if hp.is_empty():
			continue
		hp["alive"] = d["alive"]
		hp["hp"] = d["hp"]
		hp["max_hp"] = d["max_hp"]
		hp["gear"] = HeroStats.gear(d["cls"], d["talents"])
		for k: String in ["stun", "root", "aegis", "ward", "bloodlust", "surge", "untouchable"]:
			hp[k] = d.get(k, 0.0)
		if s != my_slot:
			hp["to"] = d["pos"]
			var lk: Dictionary = looks.get(s, {})
			hp["flip"] = lk.get("flip", d.get("flip", false))
			hp["moving"] = lk.get("moving", false)
			hp["swing"] = lk.get("swing", -1.0)
	hud.on_state(st)
	if str(st.get("over", "")) != "" and not over_shown:
		over_shown = true
		var won: bool = st["over"] == "victory"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			# Late, so this game's last records have come in first.
			PlayLog.finish("victory" if won else "defeat")
			hud.show_end("Victory" if won else "Defeat",
				"The Town stands. Astaroth is gone." if won else "Every building in the Town is a ruin."))


func _handle(ev: Array) -> void:
	view.handle(ev)
	for e: Array in ev:
		match e[0]:
			"log":
				if e[1] == my_slot or (e[1] == -1 and is_host):
					PlayLog.add(e)
			"banner":
				hud.banner(e[1], e[2], e[3])
			"chapter":
				map_view.set_chapter(e[1])
				view.chapter = e[1]
			"music":
				Sfx.music(e[1])
			"boss":
				hud.boss_card(e[2])
			"elite":
				hud.elite_card(e[2])
			"push":
				if e[1] == my_slot:
					ctrl.push(Vector2(e[2], e[3]))
			"respawn":
				if e[1] == my_slot:
					ctrl.teleport(Vector2(e[2], e[3]))
					cam_pos = ctrl.pos
			"denied":
				if e[1] == my_slot:
					Sfx.ui("denied", 0.5)
			"cast":
				var hp: Dictionary = view.heroes.get(e[1], {})
				if not hp.is_empty() and e[1] != my_slot:
					hp["cast_t"] = 0.0
			"learn", "talent":
				if e[1] == my_slot:
					Sfx.ui("click", 0.6)
			"camp":
				hud.open_shop(true)
			"rush":
				hud.callout("Called early  +%d gold" % int(e[1]), Color("ffd98a"), 34.0)
			"say":
				hud.callout(e[1], e[2], 30.0)
			"build":
				var who: String = "You" if e[1] == my_slot else str(view.heroes.get(e[1], {}).get("name", "A player"))
				var bname: String = TownDefs.get_def(e[2])["name"]
				if e.size() > 5 and e[5]:
					toast("%s rebuilt the %s." % [who, bname])
				else:
					toast("%s %s the %s%s." % [who, "built" if int(e[3]) == 1 else "raised", bname,
						"" if int(e[3]) == 1 else " to level %d" % int(e[3])])
			"fire":
				if not e[2] and not e[4]:
					toast("A road fire in the %s went out." % MapData.CORRIDORS[int(e[3])]["name"])
			"call":
				if e[1] != my_slot:
					toast("%s wants the next wave now (Space)." % str(view.heroes.get(e[1], {}).get("name", "A player")))
			"wave":
				hud.open_shop(false)
			"fixate":
				if e[2] == my_slot:
					toast("%s is coming for you." % MobDefs.get_def(view.mobs.get(e[1], {"kind": "wolf"})["kind"])["name"])


func on_dash(slot: int, from: Vector2, to: Vector2, dur: float, kind: String) -> void:
	if slot == my_slot:
		ctrl.start_dash(from, to, dur, kind)
	else:
		var hp: Dictionary = view.heroes.get(slot, {})
		if not hp.is_empty():
			hp["pos"] = to
			hp["to"] = to


func player_count() -> int:
	return view.heroes.size()


func toast(text: String) -> void:
	hud.toast(text)


# --- Each frame: the hero, the camera ------------------------------------------------

func _process(delta: float) -> void:
	ctrl.step(delta)
	var me: Dictionary = view.heroes.get(my_slot, {})
	if not me.is_empty():
		me["pos"] = ctrl.pos
		me["flip"] = ctrl.flip()
		me["moving"] = ctrl.moving
		me["swing"] = ctrl.swing
		if ctrl.cast_anim >= 0.0:
			me["cast_t"] = ctrl.cast_anim
		else:
			me.erase("cast_t")
		var lk := ctrl.look()
		if lk.has("aim"):
			me["aim_t"] = (1.0 - float(lk["aim"])) * 0.4 + 0.001
	for s: int in view.heroes:
		if s == my_slot:
			continue
		var hp: Dictionary = view.heroes[s]
		if hp.has("to"):
			hp["pos"] = (hp["pos"] as Vector2).lerp(hp["to"], minf(1.0, delta * 12.0))
		if hp.has("cast_t"):
			hp["cast_t"] = float(hp["cast_t"]) + delta * 2.5
			if float(hp["cast_t"]) > 1.0:
				hp.erase("cast_t")
	_camera(delta)
	overlay.queue_redraw()


func _camera(delta: float) -> void:
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	var size := vp.get_visible_rect().size
	if Touch.on:
		# Lead the camera a little the way the thumb is steering.
		cam_pos = cam_pos.lerp(ctrl.pos + ctrl.stick * 90.0, minf(1.0, delta * 8.0))
	elif Input.is_key_pressed(KEY_C) or cam_locked:
		var look := (get_global_mouse_position() - ctrl.pos) * 0.12
		cam_pos = cam_pos.lerp(ctrl.pos + look, minf(1.0, delta * 8.0))
	else:
		var pan := Vector2.ZERO
		var edge := 18.0
		var focused := DisplayServer.window_is_focused()
		if Tuning.edge_pan() and focused and Rect2(Vector2.ZERO, size).has_point(mouse):
			if mouse.x < edge: pan.x -= 1
			if mouse.x > size.x - edge: pan.x += 1
			if mouse.y < edge: pan.y -= 1
			if mouse.y > size.y - edge: pan.y += 1
		if Input.is_key_pressed(KEY_LEFT): pan.x -= 1
		if Input.is_key_pressed(KEY_RIGHT): pan.x += 1
		if Input.is_key_pressed(KEY_UP): pan.y -= 1
		if Input.is_key_pressed(KEY_DOWN): pan.y += 1
		cam_pos += pan * 1400.0 * delta / zoom
	cam_pos = cam_pos.clamp(Vector2(-200, -200), MapData.SIZE + Vector2(200, 200))
	trauma = maxf(0.0, trauma - delta * 1.8)
	var s := trauma * trauma * 26.0
	cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	cam.position = cam_pos
	cam.zoom = cam.zoom.lerp(Vector2(zoom, zoom), minf(1.0, delta * 10.0))


func _unhandled_input(event: InputEvent) -> void:
	if hud.blocks_input():
		return
	if Touch.on and event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # A finger: the HUD's touch pad handles it.
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 1.1, 0.55, 1.4)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom / 1.1, 0.55, 1.4)
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_Y:
				cam_locked = not cam_locked
				toast("Camera " + ("follows you" if cam_locked else "is free (C to jump back)"))
				return
			KEY_C:
				cam_pos = ctrl.pos
				return
			KEY_SPACE:
				send_ready()
				return
	if ctrl.unhandled_input(event, get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		return
	hud.unhandled_key(event)


func _draw_overlay() -> void:
	ctrl.draw_overlay(overlay, get_global_mouse_position())
	if view.dark:
		# The dark (every road fire out, or the Deep Wyrm): only the light
		# round each hero, each standing building and any fire still lit.
		var c := cam.get_screen_center_position()
		var size := get_viewport_rect().size / cam.zoom
		var r := Rect2(c - size * 0.5, size).grow(60)
		var holes: Array = []
		for hp: Dictionary in view.heroes.values():
			holes.append([hp["pos"], 260.0])
		var ruins: Dictionary = state.get("ruins", {})
		for id: String in TownDefs.ids():
			if not ruins.has(id):
				holes.append([TownDefs.foot(id) + Vector2(0, -60), 230.0])
		for f: Array in state.get("fires", []):
			if int(f[1]) == 1:
				holes.append([f[0], 240.0])
		var step := 40.0
		var y := r.position.y
		while y < r.end.y:
			var x := r.position.x
			while x < r.end.x:
				var p := Vector2(x, y)
				var d := INF
				for h: Array in holes:
					d = minf(d, p.distance_to(h[0]) - float(h[1]))
				var a := clampf(d / 260.0, 0.0, 0.88)
				if a > 0.01:
					overlay.draw_rect(Rect2(p, Vector2(step, step)), Color(0, 0, 0, a))
				x += step
			y += step
