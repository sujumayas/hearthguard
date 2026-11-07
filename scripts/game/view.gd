class_name View
extends Node2D
## Everything on the field, as every screen sees it: the mobs (from the
## host's snapshots, eased between them), the heroes, missiles, telegraphs,
## zones and the juice. The host's own screen reads the same snapshots and
## events as a client's, so there is one way the game looks.
##
## Juice, from the lab preset (Tuning): hit stop, flash, shake, particles,
## damage numbers. On top of it, for the feel of a hero defense: a kill
## pops the body and flings it on a big hit, an execute gets a gold cut and
## a beat of slow motion, multikills call out, and the camera kicks.

signal shake(amount: float)
signal banner(title: String, sub: String, color: Color)
signal callout(text: String, color: Color, size: float)

const NUMBER_LIFE := 0.8
const MAX_PARTICLES := 2200
const TELE_COLOR := Color("ffd98a")
const HELLFIRE := Color("8a7dff")

var map: MapData
var game: Node
var local_slot := 0
var chapter := 0
var enemy_sprites: EnemySprites
var hero_sprites: HeroSprites
var font: Font
var t := 0.0
## Render time scale (slow motion on executes and big multikills).
var slowmo_t := 0.0
var hitstop_t := 0.0

## Mob id to its drawn state.
var mobs := {}
var snap_dt := 1.0 / 20.0
## Slot to {pos, flip, anim...} for drawing; the local one is the controller's.
var heroes := {}
var hero_info := {}
var corpses: Array = []
var particles: Array = []
var numbers: Array = []
var projectiles := {}
var missiles: Array = []
var teles: Array = []
var zones := {}
var booms: Array = []
var barks := {}
var slashes: Array = []
var meteors: Array = []
var dark := false
var curses := {}
var draw_list: Array = []


func _ready() -> void:
	enemy_sprites = EnemySprites.new()
	add_child(enemy_sprites)
	hero_sprites = HeroSprites.new()
	add_child(hero_sprites)
	font = load("res://assets/fonts/kanit.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	var dt := delta
	if hitstop_t > 0.0:
		hitstop_t -= delta
		dt *= 0.05
	if slowmo_t > 0.0:
		slowmo_t -= delta
		dt *= 0.35
	t += dt
	_ease_mobs(dt)
	_step_fx(dt)
	queue_redraw()


# --- Snapshots ----------------------------------------------------------------

## Reads the mobs packed by Sim.pack_mobs and eases each toward its new
## place over the time snapshots come in.
func read_snapshot(buf: PackedByteArray, interval: float) -> void:
	snap_dt = interval
	var n := buf.decode_u32(0)
	var seen := {}
	var o := 4
	for i in n:
		var id := buf.decode_u16(o)
		var kidx := buf.decode_u8(o + 2)
		var flags := buf.decode_u8(o + 3)
		var p := Vector2(buf.decode_s16(o + 4), buf.decode_s16(o + 6))
		var m: Dictionary = mobs.get(id, {})
		if m.is_empty():
			var kind := MobDefs.id_at(kidx)
			m = {"id": id, "kind": kind, "pos": p, "from": p, "to": p, "k": 1.0, "size": MobDefs.body_size(kind),
				"color": MobDefs.get_def(kind)["color"], "rank": MobDefs.rank_of(kind), "seen": t, "lunge": 0.0}
			mobs[id] = m
		m["from"] = m["pos"]
		m["to"] = p
		m["k"] = 0.0
		m["flags"] = flags
		m["hp"] = buf.decode_u8(o + 8) / 255.0
		m["anim"] = buf.decode_u8(o + 9) / 255.0
		m["st"] = buf.decode_u8(o + 10)
		m["phase"] = buf.decode_u8(o + 11)
		seen[id] = true
		o += 12
	for id: int in mobs.keys():
		if not seen.has(id):
			mobs.erase(id)


func _ease_mobs(dt: float) -> void:
	for m: Dictionary in mobs.values():
		var k := minf(1.0, float(m["k"]) + dt / maxf(0.01, snap_dt))
		m["k"] = k
		m["pos"] = (m["from"] as Vector2).lerp(m["to"], k)


func mob_pos(id: int) -> Vector2:
	var m: Dictionary = mobs.get(id, {})
	return m["pos"] if not m.is_empty() else Vector2.INF


## The mob under a point, for clicks: the topmost whose body covers it.
func mob_at(p: Vector2) -> int:
	var best := -1
	var best_y := -INF
	for m: Dictionary in mobs.values():
		if int(m.get("flags", 0)) & 4:
			continue
		var s: Vector2 = m["size"]
		var r := Rect2(m["pos"] - Vector2(s.x * 0.5, s.y), s).grow(10)
		if r.has_point(p) and (m["pos"] as Vector2).y > best_y:
			best_y = (m["pos"] as Vector2).y
			best = m["id"]
	return best


func nearest_mob(p: Vector2, r: float) -> int:
	var best := -1
	var bd := r * r
	for m: Dictionary in mobs.values():
		if int(m.get("flags", 0)) & 4:
			continue
		var d := (m["pos"] as Vector2).distance_squared_to(p)
		if d < bd:
			bd = d
			best = m["id"]
	return best


func mob_radius(id: int) -> float:
	var m: Dictionary = mobs.get(id, {})
	return MobDefs.radius(m["kind"]) if not m.is_empty() else 16.0


# --- Events -----------------------------------------------------------------------

func handle(events: Array) -> void:
	for e: Array in events:
		_event(e)


func _event(e: Array) -> void:
	match e[0]:
		"hit":
			_on_hit(e)
		"die":
			_on_die(e)
		"proj":
			projectiles[e[1]] = {"kind": e[2], "pos": Vector2(e[3], e[4]), "vel": Vector2(e[5], e[6]), "target": e[7],
				"life": e[8] + 0.1, "src": e[9], "trail": []}
			if e[9] == local_slot and e[2] in ["arrow", "volley", "power"]:
				Sfx.play("wood", 0.35, 1.4)
		"proj_end":
			var p: Dictionary = projectiles.get(e[1], {})
			if not p.is_empty():
				if p["kind"] in ["arrow", "volley", "power", "knife"]:
					_burst(Vector2(e[2], e[3]) + Vector2(0, -24), Color("e8dfc8"), 4, 120.0, 0.25)
				projectiles.erase(e[1])
		"mmis":
			missiles.append({"kind": e[1], "from": Vector2(e[2], e[3]), "to": Vector2(e[4], e[5]), "dur": e[6], "t": 0.0})
		"tele":
			teles.append({"shape": e[1], "pos": Vector2(e[2], e[3]), "size": e[4], "angle": e[5], "dur": maxf(0.05, e[6]),
				"extra": e[7], "t": 0.0})
		"boom":
			_on_boom(e)
		"zone":
			zones[e[1]] = {"kind": e[2], "pos": Vector2(e[3], e[4]), "r": e[5], "dur": e[6], "t": 0.0}
		"zone_end":
			zones.erase(e[1])
		"fx":
			_on_fx(e)
		"meteor":
			meteors.append({"pos": Vector2(e[1], e[2]), "dur": e[3], "t": 0.0})
		"hhit":
			var hp: Dictionary = heroes.get(e[1], {})
			if not hp.is_empty():
				numbers.append({"pos": (hp["pos"] as Vector2) + Vector2(randf_range(-10, 10), -80), "text": str(e[2]),
					"color": Color("ff5a5a"), "size": 22.0 if e[1] == local_slot else 16.0, "life": NUMBER_LIFE, "vel": Vector2(0, -60)})
				hp["hurt"] = 0.25
				if e[1] == local_slot:
					emit_signal("shake", 0.12)
					Sfx.play("hurt", 0.5)
		"dodge":
			var hp2: Dictionary = heroes.get(e[1], {})
			if not hp2.is_empty():
				numbers.append({"pos": (hp2["pos"] as Vector2) + Vector2(0, -84), "text": "dodge", "color": Color("e8f4ff"),
					"size": 15.0, "life": 0.6, "vel": Vector2(0, -50)})
		"miss":
			var m: Dictionary = mobs.get(e[1], {})
			if not m.is_empty():
				numbers.append({"pos": (m["pos"] as Vector2) + Vector2(0, -(m["size"] as Vector2).y), "text": "miss",
					"color": Color("b0b0b0"), "size": 13.0, "life": 0.5, "vel": Vector2(0, -40)})
		"bark":
			barks[e[1]] = {"text": e[2], "t": 3.0}
		"lvl":
			var hp3: Dictionary = heroes.get(e[1], {})
			if not hp3.is_empty():
				_burst(hp3["pos"], Color("ffd98a"), 30, 260.0, 0.8)
				numbers.append({"pos": (hp3["pos"] as Vector2) + Vector2(0, -100), "text": "LEVEL %d" % e[2],
					"color": Color("ffd98a"), "size": 24.0, "life": 1.4, "vel": Vector2(0, -40)})
			if e[1] == local_slot:
				Sfx.play("levelup", 0.9)
		"dash":
			_on_dash(e)
		"multi":
			_on_multi(e)
		"potion":
			var hp4: Dictionary = heroes.get(e[1], {})
			if not hp4.is_empty():
				_burst(hp4["pos"] + Vector2(0, -30), PotionDefs.get_def(e[2])["color"], 24, 200.0, 0.6)
		"loot":
			var hp5: Dictionary = heroes.get(e[1], {})
			if not hp5.is_empty() and e[1] == local_slot:
				numbers.append({"pos": (hp5["pos"] as Vector2) + Vector2(0, -110), "text": "+ " + PotionDefs.get_def(e[2])["name"],
					"color": PotionDefs.get_def(e[2])["color"], "size": 18.0, "life": 1.6, "vel": Vector2(0, -30)})
				Sfx.play("potion_found", 0.8)
		"curse":
			curses[e[1]] = {"t": 0.0, "dur": e[2]}
		"dark":
			dark = e[1]
		"hdie":
			_burst(Vector2(e[2], e[3]) + Vector2(0, -30), Color("e8dfc8"), 40, 300.0, 1.0)
			if e[1] == local_slot:
				emit_signal("shake", 0.6)
		"respawn":
			_burst(Vector2(e[2], e[3]) + Vector2(0, -30), Color("ffd98a"), 30, 200.0, 0.8)
		"spin":
			var m2: Dictionary = mobs.get(e[1], {})
			if not m2.is_empty():
				m2["spin"] = e[2]
		"channel":
			var m3: Dictionary = mobs.get(e[1], {})
			if not m3.is_empty():
				m3["channel"] = e[2]
		"portal":
			var at := MapData.portal(e[1])
			_burst(at + Vector2(0, -40), ChapterDefs.get_def(chapter)["glow"], 50, 360.0, 1.0)
		"hearth":
			if randf() < 0.2:
				Sfx.play("dark_take", 0.5)
		"snd":
			Sfx.play(e[1], e[2])
		"aim":
			var hp6: Dictionary = heroes.get(e[1], {})
			if not hp6.is_empty():
				hp6["aim_t"] = e[2]


func _on_hit(e: Array) -> void:
	var m: Dictionary = mobs.get(e[1], {})
	if m.is_empty():
		return
	var flags: int = e[3]
	var mine: bool = e[4] == local_slot
	m["flash"] = Tuning.flash() + 0.04
	var p: Vector2 = m["pos"]
	var s: Vector2 = m["size"]
	if mine and (flags & 4) == 0:
		hitstop_t = maxf(hitstop_t, Tuning.hit_stop())
	if Tuning.damage_numbers() and (mine or flags & 1):
		var col := Color.WHITE
		var size := 17.0
		if flags & 2:
			col = Color("d9a8ff")
		if flags & 4:
			col = Color("ffb36b")
			size = 13.0
		if flags & 8:
			size += 3.0
		if flags & 16:
			col = col.darkened(0.35)
			size -= 3.0
		var text := str(e[2])
		if flags & 1:
			col = Color("ffe066")
			size += 8.0
			text += "!"
		if not mine:
			size *= 0.7
			col.a = 0.6
		if flags & 32:
			return
		numbers.append({"pos": p + Vector2(randf_range(-12, 12), -s.y - 6.0), "text": text, "color": col, "size": size,
			"life": NUMBER_LIFE, "vel": Vector2(randf_range(-30, 30), -110.0)})
	if mine and (flags & 4) == 0:
		_burst(p + Vector2(0, -s.y * 0.5), (m["color"] as Color).lightened(0.3), 3, 140.0, 0.3)
		if flags & 1:
			emit_signal("shake", 0.08)
			Sfx.play("crit", 0.45)


func _on_die(e: Array) -> void:
	var id: int = e[1]
	var m: Dictionary = mobs.get(id, {})
	var kind := MobDefs.id_at(e[4])
	var p := Vector2(e[2], e[3])
	var flags: int = e[5]
	var away := Vector2(e[6], e[7])
	var mine: bool = e[8] == local_slot
	var col: Color = MobDefs.get_def(kind)["color"]
	var size := MobDefs.body_size(kind)
	var big := (flags & 64) != 0
	var exec := (flags & 32) != 0
	var fling := Vector2.ZERO
	if big:
		fling = away * randf_range(240.0, 420.0) + Vector2(0, -randf_range(120, 260))
	corpses.append({"kind": kind, "pos": p, "flip": bool(int(m.get("flags", 0)) & 1), "t": 0.0, "color": col,
		"size": size, "vel": fling, "spin": randf_range(-6.0, 6.0) if big else 0.0, "exec": exec})
	mobs.erase(id)
	var n := int(lerpf(6.0, 26.0, Tuning.particles()) * (1.6 if big else 1.0))
	if MobDefs.rank_of(kind) != "mob":
		n *= 4
	_burst(p + Vector2(0, -size.y * 0.45), col.lightened(0.15), n, 220.0 if big else 150.0, 0.6, away)
	_burst(p + Vector2(0, -size.y * 0.45), Color("f4efe6"), n / 3, 120.0, 0.35)
	if exec:
		slashes.append({"pos": p + Vector2(0, -size.y * 0.5), "angle": away.angle() + PI * 0.25, "len": size.x * 1.6,
			"t": 0.0, "dur": 0.32, "color": Color("ffd24a"), "width": 7.0})
		if mine:
			numbers.append({"pos": p + Vector2(0, -size.y - 10.0), "text": "EXECUTE", "color": Color("ffd24a"), "size": 20.0,
				"life": 0.9, "vel": Vector2(0, -70)})
			hitstop_t = maxf(hitstop_t, 0.045)
			emit_signal("shake", 0.18)
			Sfx.play("crit", 0.7, 0.8)
	if mine:
		Sfx.play("kill", 0.35, randf_range(0.9, 1.2))
		if big:
			emit_signal("shake", 0.05)
	if MobDefs.rank_of(kind) == "boss":
		slowmo_t = 1.2
		emit_signal("shake", 1.0)


func _on_boom(e: Array) -> void:
	var kind: String = e[1]
	var p := Vector2(e[2], e[3])
	var r: float = e[4]
	var col := Color("ffd98a")
	match kind:
		"fireball", "meteor", "fire":
			col = Color("ff9a3d")
		"frost", "time_stop":
			col = Color("a8e4ff")
		"slam", "rock", "exec":
			col = Color("e8dfc8")
		"curse", "ritual", "seal":
			col = Color("b78cff")
		"cataclysm":
			col = Color("ff9a5a")
		"stun":
			col = Color("9da3ff")
		"war_cry":
			col = Color("ffb347")
		"blast":
			col = Color("c6f56b")
	var extra: Array = e.slice(5)
	booms.append({"kind": kind, "pos": p, "r": r, "t": 0.0, "dur": 0.45, "color": col, "extra": extra})
	if kind in ["line", "cone", "donut"]:
		return
	_burst(p + Vector2(0, -10), col, int(r / 6.0 * Tuning.particles() + 6), r * 2.2, 0.55)
	var near := 1.0
	var me: Dictionary = heroes.get(local_slot, {})
	if not me.is_empty():
		near = clampf(1.0 - (me["pos"] as Vector2).distance_to(p) / 1400.0, 0.0, 1.0)
	emit_signal("shake", Tuning.shake() * near * clampf(r / 220.0, 0.3, 1.6))


func _on_fx(e: Array) -> void:
	var kind: String = e[1]
	var p := Vector2(e[2], e[3])
	var slot: int = e[4]
	var hp: Dictionary = heroes.get(slot, {})
	match kind:
		"cleave":
			var ang: float = e[5]
			var full: bool = e[6] > 0.5
			slashes.append({"pos": p + Vector2(0, -28), "angle": ang, "arc": TAU if full else Tuning.cleave_arc(),
				"len": 130.0, "t": 0.0, "dur": 0.18, "color": Color("fff1d0"), "width": 5.0, "sweep": true})
			if not hp.is_empty():
				hp["swing"] = 0.0
		"whirl":
			slashes.append({"pos": p + Vector2(0, -28), "angle": t * 8.0, "arc": TAU, "len": e[5], "t": 0.0, "dur": 0.3,
				"color": HeroClasses.get_def("fighter")["color"].lightened(0.4), "width": 9.0, "sweep": true})
			if not hp.is_empty():
				hp["spin"] = 0.3
			if slot == local_slot:
				emit_signal("shake", 0.2)
		"sweep":
			slashes.append({"pos": p + Vector2(0, -28), "angle": 0.0, "arc": TAU, "len": 150.0, "t": 0.0, "dur": 0.22,
				"color": Color("ffd24a"), "width": 7.0, "sweep": true})
		"war_cry":
			booms.append({"kind": "war_cry", "pos": p, "r": 260.0, "t": 0.0, "dur": 0.5, "color": Color("ffb347"), "extra": []})
		"zap":
			slashes.append({"pos": p + Vector2(0, -30), "to": Vector2(e[5], e[6]) + Vector2(0, -30), "t": 0.0, "dur": 0.2,
				"color": Color("d9c2ff"), "width": 3.0, "bolt": true})
		"second_wind", "overcharge":
			_burst(p + Vector2(0, -30), Color("8fe36a") if kind == "second_wind" else Color("c58cff"), 24, 200.0, 0.6)
		"root":
			_burst(p, Color("3f7a38"), 14, 80.0, 0.5)


func _on_dash(e: Array) -> void:
	var slot: int = e[1]
	var from := Vector2(e[2], e[3])
	var to := Vector2(e[4], e[5])
	var kind: String = e[7]
	var col := Color("fff1d0")
	match kind:
		"blink":
			col = Color("c58cff")
			_burst(from + Vector2(0, -30), col, 18, 160.0, 0.4)
			_burst(to + Vector2(0, -30), col, 18, 160.0, 0.4)
		"flurry":
			slashes.append({"pos": from + Vector2(0, -30), "to": to + Vector2(0, -30), "t": 0.0, "dur": 0.16,
				"color": Color("ffe066"), "width": 4.0, "bolt": false})
		"charge", "tumble", "leap":
			for i in 8:
				_burst(from.lerp(to, i / 8.0) + Vector2(0, -6), Color("b8a888"), 2, 60.0, 0.4)
	if game != null:
		game.on_dash(slot, from, to, float(e[6]), kind)


func _on_multi(e: Array) -> void:
	var n: int = e[2]
	var words := ["", "", "", "", "Rout", "Rout", "Slaughter", "Slaughter", "Massacre", "Massacre"]
	var word: String = words[mini(n, words.size() - 1)] if n < words.size() else "Annihilation"
	if n >= 16:
		word = "Annihilation"
	var col := Color("ffd98a") if n < 8 else (Color("ffb347") if n < 16 else Color("ffe066"))
	if e[1] == local_slot:
		emit_signal("callout", "%s  x%d" % [word, n], col, 30.0 + minf(n, 30) * 0.8)
		Sfx.play("combo" if n < 10 else "match5", 0.8)
		if n >= 12:
			slowmo_t = maxf(slowmo_t, 0.18)


# --- Particles ------------------------------------------------------------------

func _burst(at: Vector2, col: Color, n: int, speed: float, life: float, bias := Vector2.ZERO) -> void:
	for i in n:
		if particles.size() >= MAX_PARTICLES:
			particles.pop_front()
		var dir := Vector2.from_angle(randf() * TAU)
		if bias != Vector2.ZERO:
			dir = (dir + bias * 0.8).normalized()
		particles.append({"pos": at, "vel": dir * speed * randf_range(0.3, 1.0) + Vector2(0, -60), "life": life * randf_range(0.6, 1.0),
			"max": life, "size": randf_range(2.0, 5.0), "color": col})


func _step_fx(dt: float) -> void:
	var keep: Array = []
	for p: Dictionary in particles:
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) > 0.0:
			p["vel"] = (p["vel"] as Vector2) * (1.0 - 3.0 * dt) + Vector2(0, 420.0 * dt)
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt
			keep.append(p)
	particles = keep
	keep = []
	for n: Dictionary in numbers:
		n["life"] = float(n["life"]) - dt
		if float(n["life"]) > 0.0:
			n["pos"] = (n["pos"] as Vector2) + (n["vel"] as Vector2) * dt
			n["vel"] = (n["vel"] as Vector2) * (1.0 - 2.5 * dt)
			keep.append(n)
	numbers = keep
	keep = []
	for c: Dictionary in corpses:
		c["t"] = float(c["t"]) + dt
		var v: Vector2 = c["vel"]
		if v != Vector2.ZERO:
			c["pos"] = (c["pos"] as Vector2) + v * dt
			c["vel"] = v * (1.0 - 4.0 * dt) + Vector2(0, 600.0 * dt) * (1.0 if float(c["t"]) < 0.3 else 0.0)
		if float(c["t"]) < 0.9:
			keep.append(c)
	corpses = keep
	for id: int in projectiles.keys():
		var p: Dictionary = projectiles[id]
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			projectiles.erase(id)
			continue
		var target: int = p["target"]
		if target >= 0 and mobs.has(target):
			var to: Vector2 = (mobs[target]["pos"] as Vector2) + Vector2(0, -(mobs[target]["size"] as Vector2).y * 0.5)
			var speed := (p["vel"] as Vector2).length()
			p["vel"] = (to - (p["pos"] as Vector2)).normalized() * speed
			if (p["pos"] as Vector2).distance_to(to) < 16.0:
				projectiles.erase(id)
				continue
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt
		var trail: Array = p["trail"]
		trail.push_front(p["pos"])
		if trail.size() > 8:
			trail.pop_back()
		if p["kind"] == "fireball" and randf() < 0.6:
			_burst(p["pos"], Color("ffb347"), 1, 40.0, 0.3)
	keep = []
	for m: Dictionary in missiles:
		m["t"] = float(m["t"]) + dt
		if float(m["t"]) < float(m["dur"]):
			keep.append(m)
		else:
			_burst(m["to"], Color("c9c2b0"), 5, 100.0, 0.3)
	missiles = keep
	for arr: Array in [teles, booms, slashes, meteors]:
		var k2: Array = []
		for x: Dictionary in arr:
			x["t"] = float(x["t"]) + dt
			if float(x["t"]) < float(x.get("dur", 0.4)):
				k2.append(x)
		arr.clear()
		arr.append_array(k2)
	for z: Dictionary in zones.values():
		z["t"] = float(z["t"]) + dt
	for id: int in barks.keys():
		barks[id]["t"] = float(barks[id]["t"]) - dt
		if float(barks[id]["t"]) <= 0.0:
			barks.erase(id)
	for slot: int in curses.keys():
		curses[slot]["t"] = float(curses[slot]["t"]) + dt
		if float(curses[slot]["t"]) > float(curses[slot]["dur"]):
			curses.erase(slot)
	for m: Dictionary in mobs.values():
		if m.has("flash"):
			m["flash"] = float(m["flash"]) - dt
		if m.has("spin"):
			m["spin"] = float(m["spin"]) - dt
			if float(m["spin"]) <= 0.0:
				m.erase("spin")
		if m.has("channel"):
			m["channel"] = float(m["channel"]) - dt
			if float(m["channel"]) <= 0.0:
				m.erase("channel")
	for hp: Dictionary in heroes.values():
		for k: String in ["hurt", "spin", "aim_t"]:
			if hp.has(k):
				hp[k] = float(hp[k]) - dt
				if float(hp[k]) <= 0.0:
					hp.erase(k)


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var view_rect := Rect2(Vector2.ZERO, MapData.SIZE)
	if cam != null:
		var size := get_viewport_rect().size / cam.zoom
		view_rect = Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(220)
	_draw_portals()
	_draw_hearth()
	for z: Dictionary in zones.values():
		_draw_zone(z)
	for tl: Dictionary in teles:
		_draw_tele(tl)
	for b: Dictionary in booms:
		_draw_boom(b)
	_draw_shadows(view_rect)
	# Bodies, sorted by their feet.
	draw_list.clear()
	for m: Dictionary in mobs.values():
		if view_rect.has_point(m["pos"]):
			draw_list.append([(m["pos"] as Vector2).y, 0, m])
	for c: Dictionary in corpses:
		draw_list.append([(c["pos"] as Vector2).y - 1.0, 1, c])
	for slot: int in heroes:
		draw_list.append([(heroes[slot]["pos"] as Vector2).y, 2, heroes[slot]])
	draw_list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for d: Array in draw_list:
		match d[1]:
			0: _draw_mob(d[2])
			1: _draw_corpse(d[2])
			2: _draw_hero(d[2])
	for s: Dictionary in slashes:
		_draw_slash(s)
	for p: Dictionary in projectiles.values():
		_draw_projectile(p)
	for m: Dictionary in missiles:
		EnemyMissile.draw(self, m["kind"], m["from"], m["to"], clampf(float(m["t"]) / float(m["dur"]), 0.0, 1.0))
	for mt: Dictionary in meteors:
		_draw_meteor(mt)
	for p: Dictionary in particles:
		var a := clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		Kept.disc(self, p["pos"], float(p["size"]) * (0.5 + a * 0.5), Color(p["color"], a))
	_draw_bars()
	for n: Dictionary in numbers:
		var a := clampf(float(n["life"]) / 0.35, 0.0, 1.0)
		var size: float = n["size"]
		var col: Color = n["color"]
		_text_outlined(n["pos"], n["text"], size, Color(col, col.a * a))
	_draw_barks()


func _text_outlined(at: Vector2, text: String, size: float, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var p := at - Vector2(w * 0.5, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), 4, Color(0, 0, 0, col.a * 0.8))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), col)


func _draw_portals() -> void:
	var glow: Color = ChapterDefs.get_def(chapter)["glow"]
	for lane in 3:
		var p := MapData.portal(lane)
		var open: bool = game != null and lane in game.active_lanes()
		var a := 0.6 + 0.25 * sin(t * 2.0 + lane)
		if open:
			Kept.disc(self, p, 120.0, Color(glow, 0.12 * a))
			Kept.disc(self, p, 80.0, Color(0.03, 0.02, 0.05, 0.95))
			for k in 6:
				var ang := t * 1.4 + k * TAU / 6.0
				Kept.disc(self, p + Vector2.from_angle(ang) * 70.0, 9.0, Color(glow, 0.7 * a))
			Kept.arc(self, p, 86.0, 0.0, TAU, 32, Color(glow, 0.6), 4.0, true)
		else:
			Kept.disc(self, p, 70.0, Color(0.1, 0.09, 0.08, 0.9))


func _draw_hearth() -> void:
	var p := MapData.HEARTH
	var frac := 1.0
	if game != null:
		frac = game.hearth_frac()
	var flick := sin(t * 11.0) * 4.0 + sin(t * 7.3) * 3.0
	var size := lerpf(0.35, 1.0, frac)
	Kept.disc(self, p, 260.0 * size, Color(1.0, 0.6, 0.2, 0.06 + 0.04 * sin(t * 3.0)))
	Kept.disc(self, p, 150.0 * size, Color(1.0, 0.6, 0.2, 0.08))
	for i in 7:
		var x := (i - 3) * 14.0
		var h := (70.0 + flick + (3 - absf(i - 3)) * 12.0) * size
		var pts := PackedVector2Array([p + Vector2(x - 16, 10), p + Vector2(x + sin(t * 9.0 + i) * 6.0, -h), p + Vector2(x + 16, 10)])
		draw_colored_polygon(pts, Color("f0a23c") if i % 2 == 0 else Color("ffd27a"))
	Kept.disc(self, p + Vector2(0, -8), 26.0 * size, Color("fff1d0"))


func _draw_shadows(view_rect: Rect2) -> void:
	for m: Dictionary in mobs.values():
		var p: Vector2 = m["pos"]
		if not view_rect.has_point(p) or int(m.get("flags", 0)) & 4:
			continue
		var s: Vector2 = m["size"]
		Kept.oval(self, Rect2(p - Vector2(s.x * 0.36, s.x * 0.1), Vector2(s.x * 0.72, s.x * 0.2)), Color(0, 0, 0, 0.3))
	for hp: Dictionary in heroes.values():
		if not hp.get("alive", true):
			continue
		var p: Vector2 = hp["pos"]
		Kept.oval(self, Rect2(p - Vector2(20, 7), Vector2(40, 14)), Color(0, 0, 0, 0.35))
		if hp.get("slot", -1) == local_slot:
			Kept.arc(self, p, 26.0, 0.0, TAU, 24, Color(HeroClasses.get_def(hp["cls"])["color"], 0.7), 2.5, true)


func _draw_mob(m: Dictionary) -> void:
	var flags: int = m.get("flags", 0)
	if flags & 4:
		# Burrowed: the mound of earth MatchRPG draws for it.
		var s0: Vector2 = m["size"]
		EnemyLook.draw_burrowed(self, Rect2(m["pos"] - Vector2(s0.x * 0.5, s0.y * 0.4), Vector2(s0.x, s0.y * 0.4)), m["color"], t)
		return
	var p: Vector2 = m["pos"]
	var s: Vector2 = m["size"]
	var look: String = m["kind"]
	var anim: float = m.get("anim", 0.0)
	var lunge := 0.0
	if anim > 0.0:
		lunge = sin(anim * PI) * (10.0 if m["rank"] == "mob" else 18.0)
	var dir := 1.0 if flags & 1 else -1.0
	var r := Rect2(p - Vector2(s.x * 0.5, s.y) + Vector2(lunge * dir, 0), s)
	var xf := Transform2D.IDENTITY
	if flags & 1:
		xf = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(2.0 * r.get_center().x, 0))
	if m.has("spin"):
		xf = xf * Transform2D(t * 18.0, r.get_center()) * Transform2D(0.0, -r.get_center())
	xf = xf * EnemyLook.motion(look, t + float(m["id"]) * 0.37, r)
	var mod := Color.WHITE
	var st: int = m.get("st", 0)
	if st & 1:
		mod = Color(0.6, 0.85, 1.35)
	elif st & 2:
		mod = Color(1.25, 0.95, 0.75).lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 20.0))
	elif st & 16:
		mod = Color(0.8, 1.15, 0.75)
	if flags & 8:
		mod = mod * Color(1.25, 1.05, 0.85)
	if flags & 64:
		mod = mod * Color(0.75, 0.75, 1.3)
	if flags & 128:
		mod = mod * Color(1.3, 0.85, 1.3)
	if float(m.get("flash", 0.0)) > 0.0:
		mod = Color(3.0, 3.0, 3.0)
	# Spawning: rises out of the portal's dark.
	var age := t - float(m["seen"])
	if age < 0.35:
		mod.a = age / 0.35
	var pose := EnemyLook.pose_at(look, t + float(m["id"]) * 0.13)
	if not enemy_sprites.draw(self, look, r, m["color"], pose, mod, xf):
		EnemyLook.draw(self, look, r, (m["color"] as Color) * mod, t, xf, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if flags & 16 and m["rank"] != "mob":
		Kept.arc(self, p + Vector2(0, -s.y - 18.0), 9.0, -PI * 0.5, -PI * 0.5 + TAU * anim, 16, TELE_COLOR, 3.0, true)
	if st & 8:
		for k in 3:
			var a := t * 5.0 + k * TAU / 3.0
			Kept.disc(self, p + Vector2(cos(a) * 16.0, -s.y - 6.0 + sin(a) * 5.0), 3.0, Color("ffe066"))
	if st & 32:
		Kept.arc(self, p + Vector2(0, -s.y * 0.5), s.x * 0.45, 0.0, TAU, 20, Color("c6f56b", 0.7), 2.0, true)
	if m.has("channel"):
		Kept.arc(self, p + Vector2(0, -s.y * 0.5), s.x * 0.7 + sin(t * 8.0) * 6.0, 0.0, TAU, 28, Color(Color("3fe0c5"), 0.8), 3.0, true)


func _draw_corpse(c: Dictionary) -> void:
	var k := float(c["t"]) / 0.9
	var s: Vector2 = c["size"]
	var p: Vector2 = c["pos"]
	# Squash flat and fade, MatchRPG's death.
	var squash := Vector2(1.0 + k * 0.3, maxf(0.1, 1.0 - k * 0.9))
	var r := Rect2(p - Vector2(s.x * 0.5, s.y), s)
	var feet := Vector2(r.get_center().x, r.end.y)
	var xf := Transform2D(float(c["spin"]) * float(c["t"]), squash, 0.0, feet) * Transform2D(0.0, -feet)
	if c["flip"]:
		xf = xf * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(2.0 * r.get_center().x, 0))
	var mod := Color(1, 1, 1, 1.0 - k)
	if float(c["t"]) < 0.06:
		mod = Color(3, 3, 3, 1)
	if c.get("exec", false):
		mod = mod * Color(1.3, 1.15, 0.7)
	if not enemy_sprites.draw(self, c["kind"], r, c["color"], 0, mod, xf):
		EnemyLook.draw(self, c["kind"], r, Color(c["color"], 1.0 - k), 0.0, xf, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_hero(hp: Dictionary) -> void:
	if not hp.get("alive", true):
		return
	var p: Vector2 = hp["pos"]
	var cls: String = hp["cls"]
	var gear: Array = hp.get("gear", [HeroClasses.get_def(cls)["branch"], "r:1"])
	var scale := 1.0
	var pose := {"frame": HeroLook.frame_at(t), "flip": hp.get("flip", false)}
	var moving: bool = hp.get("moving", false)
	var bob := absf(sin(t * 11.0)) * 3.0 if moving else 0.0
	if moving:
		pose["tilt"] = 0.06 * (-1.0 if hp.get("flip", false) else 1.0)
	var swing: float = hp.get("swing", -1.0)
	if swing >= 0.0:
		if cls == "archer":
			pose["aim"] = 1.0 - swing
		elif cls == "mage":
			pose["cast"] = swing
		else:
			pose["swing"] = swing
			pose["trail"] = HeroClasses.get_def(cls)["color"].lightened(0.5)
	if hp.has("aim_t"):
		pose["aim"] = clampf(1.0 - float(hp["aim_t"]) / 0.4, 0.0, 1.0)
	if hp.has("cast_t"):
		pose["cast"] = clampf(float(hp["cast_t"]), 0.0, 1.0)
	if hp.has("hurt"):
		pose["hurt"] = clampf(float(hp["hurt"]) / 0.25, 0.0, 1.0) * 0.8
	var top := p - Vector2(22, 64 + bob) * scale
	var mod := Color.WHITE
	if float(hp.get("untouchable", 0.0)) > 0.0:
		mod.a = 0.55
	if hp.has("spin"):
		draw_set_transform_matrix(Transform2D(t * 30.0, p + Vector2(0, -32)) * Transform2D(0.0, -(p + Vector2(0, -32))))
	modulate = Color.WHITE
	HeroLook.draw(self, top, scale, HeroClasses.get_def(cls)["color"], gear, pose, hero_sprites)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if float(hp.get("aegis", 0.0)) > 0.0:
		Kept.arc(self, p + Vector2(0, -32), 44.0, 0.0, TAU, 28, Color("8fd0ff", 0.8), 3.0, true)
	if float(hp.get("ward", 0.0)) > 0.0:
		Kept.arc(self, p + Vector2(0, -32), 40.0, 0.0, TAU, 28, Color("c58cff", 0.5), 2.0, true)
	if float(hp.get("stun", 0.0)) > 0.0:
		for k in 3:
			var a := t * 5.0 + k * TAU / 3.0
			Kept.disc(self, p + Vector2(cos(a) * 16.0, -76.0 + sin(a) * 5.0), 3.0, Color("ffe066"))
	if float(hp.get("root", 0.0)) > 0.0:
		for k in 5:
			draw_line(p + Vector2(-20 + k * 10, 0), p + Vector2(-16 + k * 8, -22), Color("3f7a38"), 4.0)
	if float(hp.get("bloodlust", 0.0)) > 0.0 or float(hp.get("surge", 0.0)) > 0.0:
		Kept.disc(self, p + Vector2(randf_range(-14, 14), randf_range(-60, -10)), 3.0, Color("ffb347", 0.8))
	var slot: int = hp.get("slot", 0)
	if curses.has(slot):
		var c: Dictionary = curses[slot]
		var k := float(c["t"]) / float(c["dur"])
		Kept.arc(self, p, 210.0, 0.0, TAU, 40, Color("b78cff", 0.4 + 0.5 * k), 3.0, true)
		Kept.disc(self, p, 210.0 * k, Color("b78cff", 0.12))
	# Name over the head.
	var name_col := HeroClasses.get_def(cls)["color"].lightened(0.3) as Color
	_text_outlined(p + Vector2(0, -84), str(hp.get("name", "")), 13.0, name_col)


func _draw_bars() -> void:
	for m: Dictionary in mobs.values():
		var hpf: float = m.get("hp", 1.0)
		if m["rank"] == "boss":
			continue
		if hpf >= 0.999 and m["rank"] == "mob":
			continue
		var s: Vector2 = m["size"]
		var w := s.x * (0.8 if m["rank"] == "mob" else 1.0)
		var at := (m["pos"] as Vector2) + Vector2(-w * 0.5, -s.y - 10.0)
		var hgt := 4.0 if m["rank"] == "mob" else 8.0
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, hgt + 2)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(at, Vector2(w * hpf, hgt)), Color("e04848") if m["rank"] == "mob" else Color("ff6a3d"))
		if m["rank"] == "elite":
			_text_outlined(at + Vector2(w * 0.5, -6), MobDefs.get_def(m["kind"])["name"], 14.0, Color("ffd98a"))
	for hp: Dictionary in heroes.values():
		if not hp.get("alive", true):
			continue
		var at := (hp["pos"] as Vector2) + Vector2(-26, -78)
		var f := clampf(float(hp.get("hp", 1.0)) / maxf(1.0, float(hp.get("max_hp", 1.0))), 0.0, 1.0)
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(54, 7)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(at, Vector2(52 * f, 5)), Color("5ad06a"))


func _draw_barks() -> void:
	for id: int in barks:
		var m: Dictionary = mobs.get(id, {})
		if m.is_empty():
			continue
		var b: Dictionary = barks[id]
		var s: Vector2 = m["size"]
		var a := clampf(float(b["t"]), 0.0, 1.0)
		var text: String = b["text"]
		var size := 20
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 24.0
		var at := (m["pos"] as Vector2) + Vector2(-w * 0.5, -s.y - 60.0)
		Kept.rect(self, Rect2(at, Vector2(w, 34)), Color(0.96, 0.93, 0.86, 0.92 * a))
		draw_colored_polygon(PackedVector2Array([at + Vector2(w * 0.5 - 8, 34), at + Vector2(w * 0.5 + 8, 34),
			at + Vector2(w * 0.5, 46)]), Color(0.96, 0.93, 0.86, 0.92 * a))
		draw_string(font, at + Vector2(12, 25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.08, 0.12, a))


func _draw_tele(tl: Dictionary) -> void:
	var k := clampf(float(tl["t"]) / float(tl["dur"]), 0.0, 1.0)
	var p: Vector2 = tl["pos"]
	var size: float = tl["size"]
	var col := TELE_COLOR
	var edge := Color(col, 0.75)
	var fill := Color(col, 0.10 + 0.22 * k)
	match tl["shape"]:
		"circle":
			Kept.disc(self, p, size, Color(col, 0.1))
			Kept.disc(self, p, size * k, fill)
			Kept.arc(self, p, size, 0.0, TAU, 40, edge, 3.0, true)
		"line":
			var ang: float = tl["angle"]
			var wdt: float = tl["extra"]
			var dir := Vector2.from_angle(ang)
			var side := dir.orthogonal() * wdt * 0.5
			var end := p + dir * size
			draw_colored_polygon(PackedVector2Array([p + side, end + side, end - side, p - side]), Color(col, 0.1))
			var mid := p + dir * size * k
			draw_colored_polygon(PackedVector2Array([p + side, mid + side, mid - side, p - side]), fill)
			draw_polyline(PackedVector2Array([p + side, end + side, end - side, p - side, p + side]), edge, 2.5, true)
		"cone":
			var ang: float = tl["angle"]
			var arc: float = tl["extra"]
			_fan(p, size, ang, arc, Color(col, 0.1))
			_fan(p, size * k, ang, arc, fill)
			Kept.arc(self, p, size, ang - arc * 0.5, ang + arc * 0.5, 24, edge, 3.0, true)
		"donut":
			var r0: float = tl["extra"]
			Kept.arc(self, p, (size + r0) * 0.5, 0.0, TAU, 48, Color(col, 0.1 + 0.2 * k), size - r0, true)
			Kept.arc(self, p, size, 0.0, TAU, 48, edge, 3.0, true)
			Kept.arc(self, p, r0, 0.0, TAU, 48, edge, 3.0, true)


func _fan(p: Vector2, r: float, ang: float, arc: float, col: Color) -> void:
	# A zero radius (the telegraph's first frame) is an empty triangle.
	if r < 1.0 or arc < 0.01:
		return
	arc = minf(arc, TAU - 0.01)
	var pts := PackedVector2Array([p])
	for i in 17:
		pts.append(p + Vector2.from_angle(ang - arc * 0.5 + arc * i / 16.0) * r)
	draw_colored_polygon(pts, col)


func _draw_boom(b: Dictionary) -> void:
	var k := clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)
	var p: Vector2 = b["pos"]
	var r: float = b["r"]
	var col: Color = b["color"]
	var a := 1.0 - k
	match b["kind"]:
		"line":
			var ex: Array = b["extra"]
			var dir := Vector2.from_angle(ex[0])
			draw_line(p, p + dir * r, Color(col, 0.5 * a), float(ex[1]))
		"cone":
			var ex2: Array = b["extra"]
			_fan(p, r, ex2[0], ex2[1], Color(col, 0.35 * a))
		"donut":
			var r0: float = (b["extra"] as Array)[0]
			Kept.arc(self, p, (r + r0) * 0.5, 0.0, TAU, 48, Color(col, 0.4 * a), r - r0, true)
		_:
			Kept.disc(self, p, r * (0.4 + 0.6 * k), Color(col, 0.28 * a))
			Kept.arc(self, p, r * (0.6 + 0.5 * k), 0.0, TAU, 40, Color(col, 0.8 * a), 6.0 * a + 1.0, true)
			if b["kind"] in ["fireball", "meteor", "cataclysm"]:
				Kept.disc(self, p, r * 0.35 * a, Color(1.0, 0.95, 0.8, a))


func _draw_zone(z: Dictionary) -> void:
	var p: Vector2 = z["pos"]
	var r: float = z["r"]
	var zt: float = z["t"]
	var fade := clampf(minf(zt / 0.3, (float(z["dur"]) - zt) / 0.5), 0.0, 1.0)
	match z["kind"]:
		"fire_pool", "fire_trail":
			var col := Color("ff9a3d") if z["kind"] == "fire_pool" else HELLFIRE
			Kept.disc(self, p, r, Color(col, 0.18 * fade))
			for k in 5:
				var q := p + Vector2.from_angle(k * 1.3 + zt) * r * 0.5
				Kept.disc(self, q, 10.0 + sin(t * 9.0 + k) * 4.0, Color(col.lightened(0.3), 0.55 * fade))
		"smoke":
			for k in 10:
				var q := p + Vector2.from_angle(k * 0.63 + zt * 0.3) * r * (0.3 + 0.5 * fmod(k * 0.37, 1.0))
				Kept.disc(self, q, r * 0.38, Color(0.55, 0.52, 0.6, 0.18 * fade))
		"rain":
			Kept.arc(self, p, r, 0.0, TAU, 40, Color("6fbf73", 0.6 * fade), 2.0, true)
			for k in 16:
				var q := p + Vector2(fmod(k * 97.0 + t * 400.0, r * 2.0) - r, fmod(k * 53.0 + t * 900.0, r * 2.0) - r)
				if q.distance_to(p) < r:
					draw_line(q - Vector2(-6, 26), q, Color("e8dfc8", 0.8 * fade), 2.0)
		"web":
			Kept.disc(self, p, r, Color(1, 1, 1, 0.06 * fade))
			for k in 8:
				draw_line(p, p + Vector2.from_angle(k * TAU / 8.0) * r, Color(1, 1, 1, 0.4 * fade), 1.5)
			for ring in 3:
				Kept.arc(self, p, r * (ring + 1) / 3.0, 0.0, TAU, 8, Color(1, 1, 1, 0.35 * fade), 1.5, true)
		"poison", "dream":
			var col2 := Color("8fe36a") if z["kind"] == "poison" else Color("3fe0c5")
			Kept.disc(self, p, r, Color(col2, 0.16 * fade))
			for k in 6:
				var q := p + Vector2.from_angle(k * 1.1 + zt * 0.5) * r * 0.55
				Kept.disc(self, q, 6.0 + 4.0 * sin(t * 4.0 + k), Color(col2, 0.5 * fade))
		"lava":
			Kept.disc(self, p, r, Color("3a1a14", 0.85 * fade))
			Kept.disc(self, p, r * 0.8, Color("ff7a2a", (0.35 + 0.1 * sin(t * 3.0)) * fade))
			Kept.arc(self, p, r, 0.0, TAU, 36, Color("ffb347", 0.7 * fade), 3.0, true)
		"seal":
			Kept.arc(self, p, r, 0.0, TAU, 28, Color("b78cff", 0.85 * fade), 3.0, true)
			for k in 5:
				var a0 := k * TAU / 5.0 + t * 0.6
				draw_line(p + Vector2.from_angle(a0) * r, p + Vector2.from_angle(a0 + TAU * 2.0 / 5.0) * r, Color("b78cff", 0.7 * fade), 2.0)


func _draw_slash(s: Dictionary) -> void:
	var k := clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
	var col: Color = s["color"]
	var a := 1.0 - k
	if s.has("to"):
		var from: Vector2 = s["pos"]
		var to: Vector2 = s["to"]
		if s.get("bolt", false):
			var pts := PackedVector2Array([from])
			for i in range(1, 6):
				pts.append(from.lerp(to, i / 6.0) + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
			pts.append(to)
			draw_polyline(pts, Color(col, a), float(s["width"]), true)
		else:
			draw_line(from, to, Color(col, a), float(s["width"]) * a + 1.0, true)
		return
	var p: Vector2 = s["pos"]
	if s.get("sweep", false):
		var arc: float = s.get("arc", PI)
		var ang: float = s["angle"]
		var r: float = float(s["len"]) * (0.6 + 0.4 * k)
		Kept.arc(self, p, r, ang - arc * 0.5, ang + arc * 0.5, 24, Color(col, 0.85 * a), float(s["width"]) * a + 1.0, true)
		Kept.arc(self, p, r * 0.8, ang - arc * 0.5, ang + arc * 0.5, 24, Color(col, 0.4 * a), float(s["width"]) * 0.5 * a + 1.0, true)
		return
	var dir := Vector2.from_angle(float(s["angle"]))
	var half := float(s["len"]) * 0.5 * (0.4 + 0.6 * minf(1.0, k * 3.0))
	draw_line(p - dir * half, p + dir * half, Color(col, a), float(s["width"]) * a + 1.0, true)
	draw_line(p - dir * half * 0.8, p + dir * half * 0.8, Color(1, 1, 1, a), 2.0, true)


func _draw_projectile(p: Dictionary) -> void:
	var at: Vector2 = p["pos"]
	var v: Vector2 = p["vel"]
	var dir := v.normalized()
	var trail: Array = p["trail"]
	match p["kind"]:
		"arrow", "volley":
			if trail.size() > 2:
				draw_line(trail[trail.size() - 1], at, Color(1, 1, 1, 0.25), 2.0, true)
			draw_line(at - dir * 26.0, at, Color("7a5634"), 2.5, true)
			draw_colored_polygon(PackedVector2Array([at + dir * 8.0, at + dir.orthogonal() * 4.0, at - dir.orthogonal() * 4.0]), Color("d5dbe3"))
			draw_line(at - dir * 26.0, at - dir * 20.0 + dir.orthogonal() * 5.0, Color("e8dfc8"), 2.0)
			draw_line(at - dir * 26.0, at - dir * 20.0 - dir.orthogonal() * 5.0, Color("e8dfc8"), 2.0)
		"power":
			if trail.size() > 1:
				draw_polyline(PackedVector2Array(trail), Color("c6f56b", 0.6), 10.0, true)
			draw_line(at - dir * 40.0, at, Color("e8dfc8"), 5.0, true)
			Kept.disc(self, at, 10.0, Color("f4ffd0", 0.9))
		"arcane", "shard":
			var col := Color("c58cff") if p["kind"] == "arcane" else Color("a8e4ff")
			for i in trail.size():
				Kept.disc(self, trail[i], 9.0 - i, Color(col, 0.5 - i * 0.06))
			Kept.disc(self, at, 10.0, Color(col, 0.6))
			Kept.disc(self, at, 5.0, Color("f2e6ff"))
		"fireball":
			for i in trail.size():
				Kept.disc(self, trail[i], 16.0 - i * 1.5, Color("ff9a3d", 0.45 - i * 0.05))
			Kept.disc(self, at, 18.0, Color("ff9a3d", 0.8))
			Kept.disc(self, at, 9.0, Color("fff1d0"))
		"knife":
			var spin := Vector2.from_angle(t * 25.0)
			draw_line(at - spin * 9.0, at + spin * 9.0, Color("d5dbe3"), 3.0, true)
			draw_line(at - spin * 9.0, at - spin * 4.0, Color("6b4a2a"), 3.5, true)


func _draw_meteor(mt: Dictionary) -> void:
	var k := clampf(float(mt["t"]) / float(mt["dur"]), 0.0, 1.0)
	var to: Vector2 = mt["pos"]
	var from := to + Vector2(-260, -700)
	var at := from.lerp(to, k * k)
	draw_line(from.lerp(to, maxf(0.0, k * k - 0.2)), at, Color("ffbf5e", 0.5), 16.0 * (0.5 + k), true)
	Kept.disc(self, at, 20.0, Color("ff9a3d"))
	Kept.disc(self, at, 10.0, Color("fff1d0"))
