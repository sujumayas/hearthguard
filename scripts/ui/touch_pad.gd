class_name TouchPad
extends RefCounted
## The thumb controls for phones and tablets, drawn on the HUD's Control in
## its (scaled) units. Every finger is tracked on its own, so the left thumb
## can steer while the right one casts.
##
## - Left side: a floating joystick. Wherever the thumb lands is its center.
## - Right side: the attack button, with Q W E R in an arc round it. Tap an
##   ability to cast it at the nearest mob in range, or drag off it to aim and
##   let go to cast. Drag back onto the button to cancel. The gold "+" learns.
## - A tap on the field walks there or attacks the mob under the finger.
##   Two fingers on the field pinch to zoom.

const STICK_R := 70.0
const KNOB_R := 30.0
const AIM_R := 130.0
const ATTACK_R := 58.0
const ABILITY_R := 36.0
const BADGE_R := 17.0
const ARC := 136.0
const ANGLES := [180.0, 212.0, 244.0, 276.0]
const TAP_MS := 350
const TAP_SLOP := 26.0

var hud: Hud
var game: Node
## index -> {"kind": "stick" | "aim" | "world" | "button", ...}
var fingers := {}
var stick_base := Vector2.ZERO
var stick_knob := Vector2.ZERO
var pinch := {}
var pressed_fx := {}


func _init(h: Hud) -> void:
	hud = h
	game = h.game


# --- Layout (HUD units) -------------------------------------------------------

func attack_center(size: Vector2) -> Vector2:
	return Vector2(size.x - 96.0, size.y - 96.0)


func ability_center(size: Vector2, i: int) -> Vector2:
	return attack_center(size) + Vector2.from_angle(deg_to_rad(ANGLES[i])) * ARC


func ability_radius(i: int) -> float:
	return ABILITY_R + (4.0 if i == 3 else 0.0)


func badge_center(size: Vector2, i: int) -> Vector2:
	# On the outer rim, away from the attack button and the other spells.
	var c := ability_center(size, i)
	return c + (c - attack_center(size)).normalized() * (ability_radius(i) + 4.0)


func strip_rect(size: Vector2) -> Rect2:
	return Rect2(size.x * 0.5 - 220.0, size.y - 92.0, 440.0, 84.0)


func potion_rect(size: Vector2, i: int) -> Rect2:
	var s := strip_rect(size)
	return Rect2(s.position.x + 12.0 + i * 52.0, s.position.y + 34.0, 46.0, 44.0)


func stick_home(size: Vector2) -> Vector2:
	return Vector2(150.0, size.y - 140.0)


func in_stick_zone(size: Vector2, p: Vector2) -> bool:
	return p.x < size.x * 0.36 and p.y > size.y * 0.3


func can_learn(i: int) -> bool:
	var me: Dictionary = hud.me
	if me.is_empty():
		return false
	var ranks: Array = me["ranks"]
	return int(me["points"]) > 0 and int(ranks[i]) < HeroClasses.max_rank(i) \
		and int(me["level"]) >= HeroClasses.rank_level(i, int(ranks[i]))


# --- Input --------------------------------------------------------------------

## Takes every touch event. Returns true when it used one.
func input(e: InputEvent) -> bool:
	var s: float = hud.scale.x
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_press(st.index, st.position / s, st.position)
		else:
			_release(st.index, st.position / s, st.position, st.canceled)
		return true
	if e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		_drag(sd.index, sd.position / s, sd.position)
		return true
	return false


func _press(idx: int, p: Vector2, raw: Vector2) -> void:
	var size: Vector2 = hud.root.size
	var ctrl: HeroControl = game.ctrl
	var modal: bool = hud.blocks_input() or hud.talents_open or hud.shop_open
	if not modal and not hud.me.is_empty():
		for i in 4:
			if can_learn(i) and p.distance_to(badge_center(size, i)) <= BADGE_R + 8.0:
				game.send_learn(i)
				Touch.buzz()
				_button(idx, "learn%d" % i)
				return
		for i in 4:
			if p.distance_to(ability_center(size, i)) <= ability_radius(i) + 8.0:
				_button(idx, "ab%d" % i)
				if not ctrl.ready_to_cast(i):
					return
				Touch.buzz()
				if ctrl.is_self_cast(i):
					ctrl.touch_cast(i, ctrl.pos)
					return
				fingers[idx] = {"kind": "aim", "slot": i, "left": false, "start": p}
				return
		if p.distance_to(attack_center(size)) <= ATTACK_R + 10.0:
			_button(idx, "attack")
			if ctrl.attack_nearest():
				Touch.buzz()
			return
		for i in 4:
			if potion_rect(size, i).grow(4.0).has_point(p):
				_button(idx, "potion%d" % i)
				game.send_drink(i, ctrl.pos)
				Touch.buzz()
				return
	# The HUD's own buttons and panels, topmost first.
	var hits: Array = hud.hits
	for i in range(hits.size() - 1, -1, -1):
		var h: Array = hits[i]
		if (h[0] as Rect2).has_point(p):
			hud.mouse = p
			if (h[1] as Callable).is_valid():
				(h[1] as Callable).call()
				Sfx.ui("click", 0.5)
			_button(idx, "hud")
			return
	if hud.blocks_input():
		return
	if hud.talents_open or hud.shop_open:
		# A tap outside an open panel closes it.
		hud.talents_open = false
		hud.shop_open = false
		_button(idx, "hud")
		return
	if in_stick_zone(size, p) and not _has_kind("stick"):
		fingers[idx] = {"kind": "stick"}
		stick_base = p
		stick_knob = p
		return
	fingers[idx] = {"kind": "world", "start": p, "t": Time.get_ticks_msec(), "moved": false}
	_update_pinch()


func _drag(idx: int, p: Vector2, _raw: Vector2) -> void:
	var f: Dictionary = fingers.get(idx, {})
	if f.is_empty():
		return
	var ctrl: HeroControl = game.ctrl
	match f["kind"]:
		"button":
			hud.slider_move(p)
		"stick":
			var v := p - stick_base
			if v.length() > STICK_R * 1.5:
				# The base follows a thumb that slides too far.
				stick_base = p - v.normalized() * STICK_R * 1.5
				v = p - stick_base
			stick_knob = stick_base + v.limit_length(STICK_R)
			ctrl.set_stick(v / STICK_R)
		"aim":
			var i: int = f["slot"]
			var c := ability_center(hud.root.size, i)
			var v := p - c
			if v.length() > ability_radius(i) + 6.0:
				f["left"] = true
			var cancel: bool = f["left"] and v.length() <= ability_radius(i)
			ctrl.touch_aim = -1 if cancel else i
			if v.length() > 4.0:
				var k := clampf(v.length() / AIM_R, 0.0, 1.0)
				ctrl.touch_at = ctrl.pos + v.normalized() * ctrl.cast_range(i) * k
		"world":
			f["pos"] = p
			if p.distance_to(f["start"]) > TAP_SLOP:
				f["moved"] = true
			if not pinch.is_empty():
				var d := _pinch_distance()
				if d > 0.0 and float(pinch["d"]) > 0.0:
					game.zoom = clampf(float(pinch["zoom"]) * d / float(pinch["d"]), 0.55, 1.4)


func _release(idx: int, p: Vector2, raw: Vector2, canceled: bool) -> void:
	var f: Dictionary = fingers.get(idx, {})
	fingers.erase(idx)
	pressed_fx.erase(idx)
	if f.is_empty():
		return
	var ctrl: HeroControl = game.ctrl
	match f["kind"]:
		"button":
			hud.slider_end()
		"stick":
			ctrl.set_stick(Vector2.ZERO)
		"aim":
			var i: int = f["slot"]
			var c := ability_center(hud.root.size, i)
			ctrl.touch_aim = -1
			if canceled:
				return
			if not f["left"]:
				ctrl.touch_cast(i, ctrl.smart_target(i))
			elif p.distance_to(c) > ability_radius(i):
				ctrl.touch_cast(i, ctrl.touch_at)
		"world":
			var was_pinch := not pinch.is_empty()
			_update_pinch()
			if canceled or was_pinch or f["moved"]:
				return
			if Time.get_ticks_msec() - int(f["t"]) <= TAP_MS:
				var world: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * raw
				ctrl.tap_world(world)


func _button(idx: int, id: String) -> void:
	fingers[idx] = {"kind": "button", "id": id}
	pressed_fx[idx] = id


func _has_kind(kind: String) -> bool:
	for f: Dictionary in fingers.values():
		if f["kind"] == kind:
			return true
	return false


func _world_fingers() -> Array:
	return fingers.values().filter(func(f: Dictionary) -> bool: return f["kind"] == "world")


func _pinch_distance() -> float:
	var w := _world_fingers()
	if w.size() < 2:
		return 0.0
	var a: Vector2 = w[0].get("pos", w[0]["start"])
	var b: Vector2 = w[1].get("pos", w[1]["start"])
	return a.distance_to(b)


func _update_pinch() -> void:
	var w := _world_fingers()
	if w.size() >= 2:
		for f: Dictionary in w:
			f["moved"] = true
		pinch = {"d": _pinch_distance(), "zoom": game.zoom}
	else:
		pinch = {}


## A finger lifted while the app was in the background never sends a release.
func reset() -> void:
	fingers.clear()
	pressed_fx.clear()
	pinch = {}
	if game != null and game.ctrl != null:
		game.ctrl.set_stick(Vector2.ZERO)
		game.ctrl.touch_aim = -1


# --- Drawing ------------------------------------------------------------------

func draw(size: Vector2) -> void:
	var root: Control = hud.root
	var me: Dictionary = hud.me
	if me.is_empty() or not hud.end_screen.is_empty():
		return
	_draw_stick(root, size)
	var cls: String = me["cls"]
	var col: Color = HeroClasses.get_def(cls)["color"]
	var pressed := pressed_fx.values()
	# Attack.
	var ac := attack_center(size)
	var down := "attack" in pressed
	Kept.disc(root, ac, ATTACK_R + 3.0, Color(0, 0, 0, 0.45))
	Kept.disc(root, ac, ATTACK_R, Color("8a2f2a") if down else Color("5e2422", 0.92))
	Kept.arc(root, ac, ATTACK_R, 0.0, TAU, 48, Color("ff6a3d", 0.9), 3.0, true)
	_draw_attack_icon(root, ac, cls)
	# Abilities.
	var ranks: Array = me["ranks"]
	var cds: Array = game.ctrl.local_cds
	var stats := HeroStats.compute(cls, int(me["level"]), me["talents"])
	for i in 4:
		var a := HeroClasses.ability(cls, i)
		var c := ability_center(size, i)
		var r := ability_radius(i)
		var learned := int(ranks[i]) > 0
		var aiming: bool = game.ctrl.touch_aim == i
		Kept.disc(root, c, r + 3.0, Color(0, 0, 0, 0.45))
		Kept.disc(root, c, r, col.darkened(0.5) if learned else Color(0.15, 0.13, 0.18, 0.9))
		hud._ability_icon(a["id"], c, learned, col)
		var cd: float = cds[i]
		if learned and cd > 0.05:
			var full := HeroStats.cooldown(cls, i, int(ranks[i]), stats)
			var k := clampf(cd / maxf(0.1, full), 0.0, 1.0)
			_pie(root, c, r, k, Color(0, 0, 0, 0.62))
			hud._text_c(c.x, c.y + 8, "%.0f" % ceilf(cd) if cd >= 1.0 else "%.1f" % cd, 22, Hud.BONE)
		var edge := Hud.BONE if aiming or ("ab%d" % i) in pressed else (col if learned else Hud.EDGE)
		Kept.arc(root, c, r, 0.0, TAU, 40, edge, 2.5, true)
		hud._text_c(c.x - r * 0.62, c.y - r * 0.5, a["key"], 13, Hud.BONE)
		for k2 in HeroClasses.max_rank(i):
			var n := HeroClasses.max_rank(i)
			var dx := (k2 - (n - 1) * 0.5) * 9.0
			Kept.disc(root, c + Vector2(dx, r + 8.0), 3.0, Hud.GOLD if k2 < int(ranks[i]) else Color(1, 1, 1, 0.25))
		if can_learn(i):
			var b := badge_center(size, i)
			var pulse := 1.0 + 0.08 * sin(hud.t * 6.0)
			Kept.disc(root, b, BADGE_R * pulse + 2.0, Color(0, 0, 0, 0.5))
			Kept.disc(root, b, BADGE_R * pulse, Color("ffd24a"))
			hud._text_c(b.x, b.y + 8, "+", 24, Hud.INK)
	# The aim: how far the drag reaches, and the cancel spot.
	for f: Dictionary in fingers.values():
		if f["kind"] != "aim":
			continue
		var i: int = f["slot"]
		var c := ability_center(size, i)
		Kept.arc(root, c, AIM_R, 0.0, TAU, 56, Color(1, 1, 1, 0.18), 2.0, true)
		if f["left"] and game.ctrl.touch_aim < 0:
			hud._text_c(c.x, c.y - ability_radius(i) - 26.0, "Cancel", 18, Color("ff8a8a"))


func _draw_stick(root: Control, size: Vector2) -> void:
	if _has_kind("stick"):
		Kept.disc(root, stick_base, STICK_R, Color(0, 0, 0, 0.28))
		Kept.arc(root, stick_base, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.5, true)
		Kept.disc(root, stick_knob, KNOB_R, Color(1, 1, 1, 0.55))
		return
	var h := stick_home(size)
	Kept.arc(root, h, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 2.0, true)
	Kept.disc(root, h, KNOB_R, Color(1, 1, 1, 0.12))
	hud._text_c(h.x, h.y + STICK_R + 22.0, "Move", 14, Color(1, 1, 1, 0.35), hud.body_font)


func _draw_attack_icon(root: Control, c: Vector2, cls: String) -> void:
	var ink := Color("ffe2c8")
	if cls == "archer":
		Kept.arc(root, c + Vector2(6, 0), 24.0, PI * 0.6, PI * 1.4, 16, ink, 4.0, true)
		root.draw_line(c + Vector2(-13, -22), c + Vector2(-13, 22), Color(ink, 0.7), 1.5, true)
		root.draw_line(c + Vector2(-16, 0), c + Vector2(26, 0), ink, 3.0, true)
		root.draw_colored_polygon(PackedVector2Array([c + Vector2(32, 0), c + Vector2(22, -6), c + Vector2(22, 6)]), ink)
	elif cls == "mage":
		Kept.disc(root, c, 14.0, Color("b98cff", 0.9))
		Kept.disc(root, c, 7.0, ink)
		for k in 6:
			var d := Vector2.from_angle(k * TAU / 6.0 + hud.t)
			root.draw_line(c + d * 18.0, c + d * 26.0, ink, 3.0, true)
	else:
		var d := Vector2(1, -1).normalized()
		root.draw_line(c - d * 22.0, c + d * 26.0, ink, 6.0, true)
		root.draw_line(c - d * 10.0 + d.orthogonal() * 12.0, c - d * 10.0 - d.orthogonal() * 12.0, ink, 5.0, true)
		root.draw_line(c - d * 22.0, c - d * 30.0, Color("8a6a3d"), 6.0, true)
	hud._text_c(c.x, c.y + ATTACK_R - 10.0, "Attack", 12, Color(1, 1, 1, 0.7), hud.body_font)


func _pie(root: Control, c: Vector2, r: float, k: float, col: Color) -> void:
	if k <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var n := maxi(3, int(32 * k))
	for j in n + 1:
		var a := -PI * 0.5 + TAU * k * float(j) / float(n)
		pts.append(c + Vector2.from_angle(a) * r)
	root.draw_colored_polygon(pts, col)
