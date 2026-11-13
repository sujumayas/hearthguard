class_name HeroControl
extends Node
## The player's own hero, moved on this screen so it never waits on the
## network. Controls are the lab's "moba" scheme: right-click to move or
## attack, A + click to attack-move, S (held) to stand down, H to hold, Q W E R to cast
## (confirm with a left click, Tuning's castMode "confirm"; F2 for quick
## cast), Ctrl + Q W E R to learn, 1-4 to drink. Movement is the preset's
## "heading" model: the hero turns at turn180Ms and only walks once it
## faces within moveTurnLimitDeg of where it's going.
##
## Attacks follow the preset too: cooldownMs between attacks, no wind-up
## (the hit leaves at once), a backswing that a move order cancels.

enum Order { IDLE, MOVE, ATTACK, AMOVE, HOLD }

const CAST_KIND := {"whirlwind": "self", "charge": "point", "war_cry": "self", "executioner": "point",
	"fireball": "point", "frost_nova": "self", "blink": "point", "meteor": "point",
	"fan_of_knives": "self", "shadow_step": "unit", "smoke": "self", "flurry": "self",
	"volley": "point", "power_shot": "point", "tumble": "point", "rain": "point"}
const CAST_RANGE := {"charge": 450.0, "executioner": 520.0, "fireball": 700.0, "blink": 420.0, "meteor": 900.0,
	"shadow_step": 700.0, "volley": 620.0, "power_shot": 1150.0, "tumble": 300.0, "rain": 800.0}
const AOE := {"executioner": 260.0, "fireball": 150.0, "meteor": 300.0, "rain": 300.0}

var game: Node
var map: MapData
var view: View
var slot := 0
var cls := "fighter"
var pos := Vector2.ZERO
var heading := 0.0
var alive := true
var info := {}
var stats := {}

var order := Order.IDLE
var path := PackedVector2Array()
var target := -1
var amove_to := Vector2.ZERO
var attack_cd := 0.0
var backswing := 0.0
var swing := -1.0
var swing_len := 0.4
var casting := {}
var cast_anim := -1.0
var targeting := -1
var amove_armed := false
var quick_cast := false
var moving := false
var knock := Vector2.ZERO
var dash := {}
var repath_t := 0.0
var auto := false
var local_cds := [0.0, 0.0, 0.0, 0.0]
var click_fx: Array = []
## True while S is held: the hero drops every order and ignores mobs, so you
## can walk to the Alchemist through a fight. On release it stands ready.
var stand_down := false
## Touch: the joystick's direction (zero when no thumb is on it), and the
## ability being aimed by a drag with where it points (`touch_at`).
var stick := Vector2.ZERO
var touch_aim := -1
var touch_at := Vector2.ZERO


func setup(g: Node, m: MapData, v: View, s: int, c: String) -> void:
	game = g
	map = m
	view = v
	slot = s
	cls = c
	pos = MapData.hero_start(s)
	heading = (MapData.SQUARE - pos).angle()
	quick_cast = str(Tuning.get_v("input.castMode", "confirm")) == "quick"
	stats = HeroStats.compute(cls, 1, [])


func apply_info(d: Dictionary) -> void:
	info = d
	var was_alive := alive
	alive = d.get("alive", true)
	if not alive and was_alive:
		order = Order.IDLE
		path = PackedVector2Array()
		targeting = -1
	stats = HeroStats.compute(cls, int(d.get("level", 1)), d.get("talents", []))
	var cds: Array = d.get("cds", [0, 0, 0, 0])
	for i in 4:
		# The host's cooldown wins, unless ours is fresher (just cast).
		if local_cds[i] <= 0.0 or float(cds[i]) > 0.0:
			local_cds[i] = float(cds[i])


func teleport(p: Vector2) -> void:
	pos = p
	dash = {}
	order = Order.IDLE
	path = PackedVector2Array()


func push(v: Vector2) -> void:
	knock += v * 2.4


func start_dash(from: Vector2, to: Vector2, dur: float, kind: String) -> void:
	if dur <= 0.0:
		pos = to
		dash = {}
		return
	dash = {"from": pos, "to": to, "dur": dur, "t": 0.0, "kind": kind}
	if absf(to.x - from.x) > 2.0:
		heading = (to - from).angle()


func flip() -> bool:
	return cos(heading) < 0.0


func look() -> Dictionary:
	var d := {"moving": moving, "swing": swing, "flip": flip()}
	if cast_anim >= 0.0:
		d["cast_t"] = cast_anim
	if cls == "archer" and order == Order.ATTACK and swing < 0.0 and target >= 0:
		d["aim"] = clampf(1.0 - attack_cd / maxf(0.05, HeroStats.attack_interval(stats)), 0.0, 1.0)
	return d


# --- Input ------------------------------------------------------------------------

func unhandled_input(event: InputEvent, world_mouse: Vector2) -> bool:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if targeting >= 0:
				targeting = -1
				return true
			amove_armed = false
			var id := view.mob_at(world_mouse)
			if id >= 0:
				_order_attack(id, false)
				_click(world_mouse, Color("ff6a3d"))
			else:
				_order_move(world_mouse)
				_click(world_mouse, Color("5ad06a"))
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if targeting >= 0:
				_confirm_cast(targeting, world_mouse)
				targeting = -1
				return true
			if amove_armed:
				amove_armed = false
				order = Order.AMOVE
				amove_to = world_mouse
				path = map.path(pos, world_mouse)
				_cancel_backswing()
				_click(world_mouse, Color("ff6a3d"))
				return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		var slot_i := ["Q", "W", "E", "R"].find(OS.get_keycode_string(k.keycode))
		if slot_i >= 0:
			if k.ctrl_pressed or k.meta_pressed:
				game.send_learn(slot_i)
			else:
				_press_ability(slot_i, world_mouse)
			return true
		match k.keycode:
			KEY_A:
				amove_armed = true
				return true
			KEY_S:
				_stop()
				stand_down = true
				return true
			KEY_H:
				order = Order.HOLD
				path = PackedVector2Array()
				return true
			KEY_1, KEY_2, KEY_3, KEY_4:
				game.send_drink(k.keycode - KEY_1, world_mouse)
				return true
			KEY_F2:
				quick_cast = not quick_cast
				game.toast("Quick cast " + ("on" if quick_cast else "off"))
				return true
			KEY_ESCAPE:
				if targeting >= 0 or amove_armed:
					targeting = -1
					amove_armed = false
					return true
	if event is InputEventKey and not event.pressed and (event as InputEventKey).keycode == KEY_S:
		stand_down = false
		return true
	return false


# --- Touch -----------------------------------------------------------------------

## The joystick. A thumb on it is a move order that ignores mobs, so it also
## does what S does on a keyboard; letting go leaves the hero ready to fight.
func set_stick(v: Vector2) -> void:
	if v.length() > 0.18:
		if stick == Vector2.ZERO:
			_cancel_backswing()
			target = -1
			amove_armed = false
		stick = v.limit_length(1.0)
	elif stick != Vector2.ZERO:
		stick = Vector2.ZERO
		if order == Order.MOVE:
			order = Order.IDLE
			path = PackedVector2Array()


## A tap on the field: attack the mob under the finger, or walk there.
func tap_world(at: Vector2) -> void:
	var id := view.mob_at(at)
	if id < 0:
		id = view.nearest_mob(at, 48.0)
	if id >= 0:
		_order_attack(id, false)
		_click(view.mob_pos(id), Color("ff6a3d"))
	else:
		_order_move(at)
		_click(at, Color("5ad06a"))


## The attack button: the nearest mob in a generous reach, bosses and elites
## first when they're close.
func attack_nearest() -> bool:
	if not alive:
		return false
	var reach := maxf(acquire_reach() * 1.6, 320.0)
	var id := view.nearest_mob(pos, reach)
	if id < 0:
		Sfx.ui("denied", 0.4)
		return false
	_order_attack(id, false)
	_click(view.mob_pos(id), Color("ff6a3d"))
	return true


func cast_range(i: int) -> float:
	return CAST_RANGE.get(ability_id(i), 0.0)


func is_self_cast(i: int) -> bool:
	return CAST_KIND[ability_id(i)] == "self"


## Can slot i go now? Says why not, the same way a key press does.
func ready_to_cast(i: int) -> bool:
	if not alive:
		return false
	var ranks: Array = info.get("ranks", [0, 0, 0, 0])
	if int(ranks[i]) <= 0:
		game.toast("Not learned yet. Tap the gold + to learn it.")
		Sfx.ui("denied", 0.6)
		return false
	if local_cds[i] > 0.05:
		Sfx.ui("denied", 0.5)
		return false
	return true


## A tap on an ability, no drag: self spells go off, aimed ones pick the
## nearest mob in range, or go the way the hero is heading.
func smart_target(i: int) -> Vector2:
	var r := cast_range(i)
	var id := view.nearest_mob(pos, r)
	var fwd := stick.normalized() if stick != Vector2.ZERO else Vector2.from_angle(heading)
	if ability_id(i) in ["blink", "tumble"]:
		# Movement spells go where the thumb points, or away from the crowd.
		return pos + fwd * r * 0.8
	if id >= 0:
		return view.mob_pos(id)
	return pos + fwd * r * 0.6


func touch_cast(i: int, at: Vector2) -> void:
	if ready_to_cast(i):
		_confirm_cast(i, at)


func _stop() -> void:
	order = Order.IDLE
	path = PackedVector2Array()
	target = -1
	auto = false
	casting = {}
	targeting = -1
	amove_armed = false
	_cancel_backswing()


## How far auto-attack looks for a mob: 5% past a ranged hero's reach, twice
## a melee hero's. Further than that, mobs you haven't met yet stay unbothered.
func acquire_reach() -> float:
	var r: float = stats["range"]
	return r * 2.0 if bool(stats.get("melee", false)) else r * 1.05


func _press_ability(i: int, world_mouse: Vector2) -> void:
	if not alive:
		return
	var ranks: Array = info.get("ranks", [0, 0, 0, 0])
	if int(ranks[i]) <= 0:
		game.toast("Not learned yet. Ctrl + %s to learn." % ["Q", "W", "E", "R"][i])
		Sfx.ui("denied", 0.6)
		return
	if local_cds[i] > 0.05:
		Sfx.ui("denied", 0.5)
		return
	var id: String = HeroClasses.ability(cls, i)["id"]
	if CAST_KIND[id] == "self" or quick_cast:
		_confirm_cast(i, world_mouse)
	else:
		targeting = i


func ability_id(i: int) -> String:
	return HeroClasses.ability(cls, i)["id"]


func _confirm_cast(i: int, at: Vector2) -> void:
	var id := ability_id(i)
	var tid := -1
	if CAST_KIND[id] == "unit":
		tid = view.mob_at(at)
		if tid < 0:
			tid = view.nearest_mob(at, 160.0)
		if tid < 0:
			Sfx.ui("denied", 0.5)
			return
	var instant: bool = CAST_KIND[id] == "self"
	casting = {"slot": i, "at": at, "tid": tid, "t": 0.12 if instant else Tuning.cast_point(), "id": id}
	if not instant:
		heading = (at - pos).angle()
	order = Order.IDLE if order != Order.HOLD else Order.HOLD
	path = PackedVector2Array()
	cast_anim = 0.0


func _order_move(to: Vector2) -> void:
	order = Order.MOVE
	path = map.path(pos, to)
	target = -1
	_cancel_backswing()
	casting = {}


func _order_attack(id: int, is_auto: bool) -> void:
	order = Order.ATTACK
	target = id
	auto = is_auto
	path = PackedVector2Array()
	casting = {}


func _cancel_backswing() -> void:
	if Tuning.backswing_cancel():
		backswing = 0.0
		swing = -1.0


func _click(at: Vector2, col: Color) -> void:
	click_fx.append({"pos": at, "t": 0.0, "color": col})


# --- Each frame -------------------------------------------------------------------

func step(dt: float) -> void:
	for c: Dictionary in click_fx:
		c["t"] = float(c["t"]) + dt
	click_fx = click_fx.filter(func(c: Dictionary) -> bool: return float(c["t"]) < 0.4)
	for i in 4:
		local_cds[i] = maxf(0.0, local_cds[i] - dt)
	attack_cd -= dt
	# A release can be lost (focus change, a panel took the key): check the key.
	if stand_down and not Input.is_key_pressed(KEY_S):
		stand_down = false
	if not alive:
		moving = false
		return
	if not dash.is_empty():
		dash["t"] = float(dash["t"]) + dt
		var k := clampf(float(dash["t"]) / float(dash["dur"]), 0.0, 1.0)
		pos = (dash["from"] as Vector2).lerp(dash["to"], k)
		if k >= 1.0:
			dash = {}
		moving = true
		return
	if knock.length_squared() > 4.0:
		pos = map.slide(pos, knock * dt)
		knock *= 1.0 - 8.0 * dt
	if swing >= 0.0:
		swing += dt / swing_len
		if swing >= 1.0:
			swing = -1.0
	if float(info.get("stun", 0.0)) > 0.0:
		moving = false
		return
	if backswing > 0.0:
		backswing -= dt
	if not casting.is_empty():
		_step_cast(dt)
		moving = false
		return
	if cast_anim >= 0.0:
		cast_anim += dt * 2.5
		if cast_anim >= 1.0:
			cast_anim = -1.0
	if stick != Vector2.ZERO:
		order = Order.MOVE
		path = PackedVector2Array([pos + stick.normalized() * 60.0])
	match order:
		Order.IDLE, Order.HOLD:
			moving = false
			if Tuning.auto_acquire() and not stand_down:
				var reach: float = float(stats["range"]) if order == Order.HOLD else acquire_reach()
				var id := view.nearest_mob(pos, reach + 16.0)
				if id >= 0:
					if order == Order.HOLD:
						_try_attack(id)
					else:
						_order_attack(id, true)
		Order.MOVE:
			_follow(dt)
			if path.is_empty():
				order = Order.IDLE
		Order.ATTACK:
			_attack_step(dt)
		Order.AMOVE:
			var id := view.nearest_mob(pos, acquire_reach() + 16.0)
			if id >= 0:
				_order_attack(id, true)
				return
			_follow(dt)
			if path.is_empty():
				order = Order.IDLE


func _step_cast(dt: float) -> void:
	var id: String = casting["id"]
	var at: Vector2 = casting["at"]
	if CAST_KIND[id] != "self":
		heading = _turn_toward(heading, (at - pos).angle(), dt)
	cast_anim = clampf(1.0 - float(casting["t"]) / maxf(0.01, Tuning.cast_point()), 0.0, 1.0)
	casting["t"] = float(casting["t"]) - dt
	if float(casting["t"]) <= 0.0:
		var i: int = casting["slot"]
		game.send_cast(i, at, int(casting["tid"]))
		var rank := int((info.get("ranks", [1, 1, 1, 1]) as Array)[i])
		local_cds[i] = HeroStats.cooldown(cls, i, maxi(1, rank), stats)
		if cls != "mage":
			swing = 0.0
			swing_len = 0.3
		casting = {}
		backswing = Tuning.cast_backswing() * 0.5


func _attack_step(dt: float) -> void:
	var tp := view.mob_pos(target)
	if tp == Vector2.INF:
		target = -1
		order = Order.AMOVE if auto and amove_to != Vector2.ZERO else Order.IDLE
		if order == Order.AMOVE:
			path = map.path(pos, amove_to)
		return
	var d := pos.distance_to(tp) - view.mob_radius(target)
	var reach: float = stats["range"]
	if auto and d > acquire_reach() * 1.25:
		order = Order.IDLE
		return
	# Out of reach, or in reach behind rock (shots stop at walls): walk on.
	if d > reach or not map.line_open(pos, tp):
		if backswing > 0.0:
			return
		repath_t -= dt
		if map.line_open(pos, tp):
			path = PackedVector2Array([tp])
		elif repath_t <= 0.0 or path.is_empty():
			path = map.path(pos, tp)
			repath_t = 0.3
		_follow(dt)
		return
	moving = false
	_try_attack(target)
	heading = _turn_toward(heading, (tp - pos).angle(), dt)


func _try_attack(id: int) -> void:
	var tp := view.mob_pos(id)
	if tp == Vector2.INF:
		return
	var d := pos.distance_to(tp) - view.mob_radius(id)
	if d > float(stats["range"]) + 4.0:
		return
	var want := (tp - pos).angle()
	if absf(angle_difference(heading, want)) > Tuning.face_tolerance() * 2.5:
		heading = _turn_toward(heading, want, 1.0 / 60.0)
		return
	if attack_cd > 0.0:
		return
	var bonus := 0.0
	if float(info.get("bloodlust", 0.0)) > 0.0:
		bonus += float(info.get("bloodlust_amt", 0.0))
	bonus += 0.05 * float(info.get("rampage", 0))
	if cls == "flow":
		bonus += 0.03 * float(info.get("flow", 0))
	var interval := HeroStats.attack_interval(stats, bonus)
	attack_cd = interval
	backswing = minf(Tuning.backswing(), interval * 0.8)
	swing = 0.0
	swing_len = maxf(0.12, minf(Tuning.backswing(), interval * 0.9))
	heading = want
	game.send_attack(id)
	match cls:
		"fighter", "flow":
			Sfx.play("sword", 0.35, randf_range(1.1, 1.35))
		"mage":
			Sfx.play("magic", 0.3, 1.3)


func _follow(dt: float) -> void:
	if path.is_empty() or float(info.get("root", 0.0)) > 0.0:
		moving = false
		return
	var wp: Vector2 = path[0]
	if pos.distance_to(wp) < 10.0:
		path.remove_at(0)
		if path.is_empty():
			moving = false
			return
		wp = path[0]
	var want := (wp - pos).angle()
	heading = _turn_toward(heading, want, dt)
	if absf(angle_difference(heading, want)) > Tuning.move_turn_limit():
		moving = false
		return
	var speed: float = float(stats["speed"]) * (1.0 - float(info.get("slow", 0.0)))
	var step := minf(speed * dt, pos.distance_to(wp))
	var before := pos
	pos = map.slide(pos, Vector2.from_angle(heading) * step)
	moving = pos.distance_to(before) > 0.01


func _turn_toward(from: float, to: float, dt: float) -> float:
	var rate := PI / maxf(0.01, Tuning.turn_180())
	var diff := angle_difference(from, to)
	if absf(diff) <= rate * dt:
		return to
	return from + signf(diff) * rate * dt


# --- What the controller draws: orders, the targeting cursor ----------------------

func draw_overlay(ci: CanvasItem, mouse: Vector2) -> void:
	for c: Dictionary in click_fx:
		var k := float(c["t"]) / 0.4
		var col: Color = c["color"]
		for a in 4:
			var ang := a * TAU / 4.0 + PI * 0.25
			var r := 26.0 * (1.0 - k) + 6.0
			var tip := (c["pos"] as Vector2) + Vector2.from_angle(ang) * r
			ci.draw_line(tip, tip + Vector2.from_angle(ang) * 10.0, Color(col, 1.0 - k), 3.0, true)
	if order == Order.MOVE and not path.is_empty():
		var pts := PackedVector2Array([pos])
		pts.append_array(path)
		ci.draw_polyline(pts, Color(1, 1, 1, 0.12), 2.0, true)
	var aim_slot := targeting
	if touch_aim >= 0:
		aim_slot = touch_aim
		mouse = touch_at
	if aim_slot >= 0:
		var id := ability_id(aim_slot)
		var r: float = CAST_RANGE.get(id, 400.0)
		Kept.arc(ci, pos, r, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 2.0, true)
		var at := mouse
		if AOE.has(id):
			Kept.disc(ci, at, AOE[id], Color(HeroClasses.get_def(cls)["color"], 0.18))
			Kept.arc(ci, at, AOE[id], 0.0, TAU, 40, Color(HeroClasses.get_def(cls)["color"], 0.8), 2.5, true)
		elif id in ["volley", "power_shot", "charge", "tumble"]:
			var dir := (at - pos).normalized()
			var len := minf(r, pos.distance_to(at)) if id in ["charge", "tumble"] else r
			ci.draw_line(pos, pos + dir * len, Color(HeroClasses.get_def(cls)["color"], 0.6), 30.0 if id == "power_shot" else 6.0)
		else:
			Kept.arc(ci, at, 24.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 2.0, true)
	if amove_armed:
		Kept.arc(ci, mouse, 18.0, 0.0, TAU, 16, Color("ff6a3d", 0.9), 2.5, true)
