class_name BuildingIcon
extends Control
## The picture of a town building (UpgradeDefs) beside its card: flat-shaded
## like the enemies (EnemyLook), each in the color of what it gives, so the
## Armory is shield blue and the Mage Tower magic purple. Drawn in a 100 by
## 100 space with the ground along the bottom, scaled to fit. A building
## not built yet is a dark shape of itself, its parts only just told apart.
## Each level built after the first adds a part to it (see Levels below).
## (Hearthguard: MatchRPG's UiTheme colors for the ground and the unbuilt
## shape are kept here, in its dusk look, and the Alchemist's id is spelled
## out. The town stands round the Hearth, see TownDefs.)

const SIZE := 128.0
const OUTLINE := Color(0, 0, 0, 0.26)
const DARK := Color("1a1620")
const STONE := Color("8d93a3")
const PALE := Color("d9d4c4")
const STEEL := Color("c9d0da")
const WOOD := Color("7a5634")
const GOLD := Color("f2c53d")
const GLOW := Color("ffe9a8")
const GROUND := Color("120f19", 0.4)
const UNBUILT := Color("4d4470")

var id := ""
var built := true

## While drawing an unbuilt building, the color everything is drawn near.
static var _shade := Color.TRANSPARENT
## While drawing one at night, how much darker it is, its lights left lit.
static var _night := 0.0
## What stays lit at night: windows and the forge's fire.
const LIT := [GLOW, Color("ff9a3c")]
## Where the lights of the buildings drawn are (windows, fire, torches), as
## Vector3(x, y, radius) in the drawing's own space, while `recording`: for a
## glow round each drawn over the night (see glow). Cleared by the caller.
static var lights: Array[Vector3] = []
static var recording := false
static var _at := Rect2()
## A light's glow, as wide as this many times the light, and as strong.
const GLOW_REACH := 3.2
const GLOW_STRENGTH := 0.45


func _init(p_id: String, p_built := true) -> void:
	id = p_id
	built = p_built
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_building(self, id, Rect2(Vector2.ZERO, size), built)


## Draws building `p_id` filling `r`, or its dark shape when not `p_built`.
## An id without a picture draws only the ground. In a picture with colors
## of its own (TownMap), the unbuilt shape is drawn near `unbuilt` and the
## shadow under it in `ground`, and `night` darkens all but its lights.
## A `level` above 1 adds that level's parts.
static func draw_building(ci: CanvasItem, p_id: String, r: Rect2, p_built := true,
		unbuilt := Color.TRANSPARENT, ground := Color.TRANSPARENT, night := 0.0, level := 0) -> void:
	ci.draw_set_transform(r.position, 0.0, r.size / 100.0)
	_at = r
	ci.draw_colored_polygon(_arc(Vector2(50, 94), 48, 5, 0.0, TAU, 24),
		ground if ground.a > 0.0 else GROUND)
	_shade = Color.TRANSPARENT if p_built else (unbuilt if unbuilt.a > 0.0 else UNBUILT)
	_night = night
	var more := level > 1 and p_built
	if more:
		_levels(ci, p_id, level, true)
	match p_id:
		"barracks":
			_barracks(ci)
		"forge":
			_forge(ci)
		"tower":
			_tower(ci)
		"armory":
			_armory(ci)
		"locksmith":
			_locksmith(ci)
		"mint":
			_mint(ci)
		"woodcutter":
			_woodcutter(ci)
		"quarry":
			_quarry(ci)
		"alchemist":
			_alchemist(ci)
	if more:
		_levels(ci, p_id, level, false)
	_shade = Color.TRANSPARENT
	_night = 0.0
	ci.draw_set_transform(Vector2.ZERO)


## Notes a light at `at` in the building's own 100 by 100 space, `r` wide.
static func _light(at: Vector2, r: float) -> void:
	if recording and _shade.a <= 0.0:
		lights.append(Vector3(_at.position.x + at.x * _at.size.x / 100.0, _at.position.y + at.y * _at.size.y / 100.0,
			r * _at.size.x / 100.0))


## A warm glow round each of `found` (see lights) on `ci`, `amount` strong
## (0 by day to 1 at night): fading out from each, lights near each other
## drawn once.
static func glow(ci: CanvasItem, found: Array[Vector3], amount: float) -> void:
	if amount <= 0.0:
		return
	var drawn: Array[Vector3] = []
	for l: Vector3 in found:
		if drawn.any(func(d: Vector3) -> bool: return Vector2(d.x, d.y).distance_to(Vector2(l.x, l.y)) < maxf(d.z, l.z) * 1.5):
			continue
		drawn.append(l)
		var reach := maxf(l.z, 3.0) * GLOW_REACH
		var at := Vector2(l.x, l.y)
		var pts := PackedVector2Array([at])
		var cols := PackedColorArray([Color(GLOW, GLOW_STRENGTH * amount)])
		for i in 25:
			pts.append(at + Vector2.from_angle(TAU * i / 24.0) * reach)
			cols.append(Color(GLOW, 0.0))
		# A fan from the light out, fading to nothing at its rim.
		var tris := PackedInt32Array()
		for i in 24:
			tris.append_array([0, i + 1, i + 2])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), tris, pts, cols)


## `c`, or the unbuilt shade, a little lighter or darker as `c` is. Glows
## and smoke are left out of the shape.
static func _a(c: Color) -> Color:
	if _shade.a > 0.0:
		if c.a <= 0.9:
			return Color.TRANSPARENT
		var lum := c.get_luminance() - 0.4
		return _shade.lightened(lum * 0.3) if lum > 0.0 else _shade.darkened(-lum * 0.9)
	if _night > 0.0 and c.a > 0.9 and not LIT.has(c):
		return c.darkened(_night)
	return c


static func _poly(ci: CanvasItem, pts: PackedVector2Array, c: Color, outline := true) -> void:
	if _a(c).a <= 0.0:
		return
	if c.a > 0.9 and LIT.has(c):
		var box := Rect2(pts[0], Vector2.ZERO)
		for p: Vector2 in pts:
			box = box.expand(p)
		_light(box.get_center(), maxf(box.size.x, box.size.y) * 0.5)
	ci.draw_colored_polygon(pts, _a(c))
	if outline and _shade.a <= 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, OUTLINE, 1.2, true)


static func _box(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color, outline := true) -> void:
	_poly(ci, PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), c, outline)


## Points along an ellipse from angle `from` to `to`.
static func _arc(c: Vector2, rx: float, ry: float, from: float, to: float, steps := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if col.a > 0.9 and (LIT.has(col) or col == FIRE):
		_light(c, r)
	if _a(col).a > 0.0:
		ci.draw_circle(c, r, _a(col), true, -1.0, true)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	if _a(c).a > 0.0:
		ci.draw_line(a, b, _a(c), w, true)


## A door or window with a round top, `w` wide, from `top` down to `bottom`.
static func _arch(ci: CanvasItem, cx: float, top: float, bottom: float, w: float, c: Color) -> void:
	var pts := _arc(Vector2(cx, top + w * 0.5), w * 0.5, w * 0.5, PI, TAU, 10)
	pts.append(Vector2(cx + w * 0.5, bottom))
	pts.append(Vector2(cx - w * 0.5, bottom))
	_poly(ci, pts, c, false)


## A stone keep with battlements, flying health's red.
static func _barracks(ci: CanvasItem) -> void:
	var red := Color("e0445c")
	_line(ci, Vector2(50, 44), Vector2(50, 10), WOOD, 2.5)
	_poly(ci, PackedVector2Array([Vector2(50, 11), Vector2(74, 17), Vector2(50, 25)]), red)
	# Corner towers, then the wall between them.
	for x: float in [10.0, 68.0]:
		_box(ci, x, 40, 22, 54, STONE.darkened(0.12))
		for k in 3:
			_box(ci, x - 1 + k * 8.5, 33, 7, 8, STONE.darkened(0.12))
		_box(ci, x + 9, 54, 4, 12, DARK, false)
	_box(ci, 30, 52, 40, 42, STONE)
	for k in 4:
		_box(ci, 31 + k * 10.3, 45, 7, 8, STONE)
	_arch(ci, 50, 66, 94, 18, DARK)
	_arch(ci, 50, 69, 94, 13, WOOD.darkened(0.2))
	_line(ci, Vector2(50, 70), Vector2(50, 94), DARK, 1.2)
	# A heart over the gate.
	for sx: float in [-1.0, 1.0]:
		_dot(ci, Vector2(50 + sx * 2.6, 57), 3.0, red)
	_poly(ci, PackedVector2Array([Vector2(44.6, 58), Vector2(55.4, 58), Vector2(50, 64.5)]), red, false)


## A smithy with its furnace lit, a smoking chimney and an anvil outside.
static func _forge(ci: CanvasItem) -> void:
	var wall := Color("6f6878")
	var fire := Color("ff9a3c")
	_dot(ci, Vector2(60, 15), 5.5, Color(0.8, 0.8, 0.85, 0.5))
	_dot(ci, Vector2(67, 6), 4.0, Color(0.8, 0.8, 0.85, 0.35))
	_box(ci, 52, 22, 13, 28, wall.darkened(0.25))
	_box(ci, 50, 19, 17, 5, wall.darkened(0.4))
	_box(ci, 12, 54, 58, 40, wall)
	_poly(ci, PackedVector2Array([Vector2(6, 56), Vector2(41, 30), Vector2(76, 56)]), Color("4a4458"))
	# The furnace mouth and its glow on the ground.
	_poly(ci, _arc(Vector2(36, 94), 20, 4, 0.0, TAU, 16), Color(fire, 0.25), false)
	_arch(ci, 36, 62, 94, 28, DARK)
	_arch(ci, 36, 68, 94, 20, Color("e0445c"))
	_arch(ci, 36, 74, 94, 14, fire)
	_arch(ci, 36, 81, 94, 8, GLOW)
	# The anvil.
	_poly(ci, PackedVector2Array([Vector2(72, 76), Vector2(97, 76), Vector2(92, 82), Vector2(88, 82), Vector2(88, 88),
		Vector2(92, 94), Vector2(76, 94), Vector2(80, 88), Vector2(80, 82), Vector2(76, 82)]), STEEL.darkened(0.25))
	_line(ci, Vector2(74, 77.5), Vector2(95, 77.5), STEEL, 1.5)


## A tall tower under a pointed roof, with a lit window and stars about it.
static func _tower(ci: CanvasItem) -> void:
	var magic := Color("b77bff")
	var wall := Color("8c84a8")
	_poly(ci, PackedVector2Array([Vector2(33, 94), Vector2(37, 38), Vector2(63, 38), Vector2(67, 94)]), wall)
	_poly(ci, PackedVector2Array([Vector2(52, 38), Vector2(63, 38), Vector2(67, 94), Vector2(54, 94)]), wall.darkened(0.14), false)
	# A turret hanging off one side.
	_box(ci, 62, 50, 16, 18, wall.darkened(0.08))
	_poly(ci, PackedVector2Array([Vector2(59, 51), Vector2(70, 34), Vector2(81, 51)]), magic.darkened(0.3))
	_box(ci, 68, 56, 4, 7, GLOW, false)
	_poly(ci, PackedVector2Array([Vector2(28, 40), Vector2(50, 5), Vector2(72, 40)]), magic.darkened(0.18))
	_poly(ci, PackedVector2Array([Vector2(50, 5), Vector2(72, 40), Vector2(56, 40)]), magic.darkened(0.34), false)
	_dot(ci, Vector2(50, 5), 3.5, GOLD)
	_dot(ci, Vector2(47, 58), 9.0, Color(GLOW, 0.22))
	_arch(ci, 47, 50, 66, 10, GLOW)
	_arch(ci, 49, 78, 94, 12, DARK)
	for s: Array in [[Vector2(18, 26), 7.0], [Vector2(84, 20), 5.0], [Vector2(14, 56), 4.0]]:
		_twinkle(ci, s[0], s[1], magic.lightened(0.25))


static func _twinkle(ci: CanvasItem, at: Vector2, r: float, c: Color) -> void:
	var star := PackedVector2Array()
	for i in 8:
		star.append(at + Vector2.from_angle(-PI / 2.0 + i * TAU / 8.0) * (r if i % 2 == 0 else r * 0.28))
	_poly(ci, star, c, false)


## A hall under a blue roof, with a shield and crossed swords over the door.
static func _armory(ci: CanvasItem) -> void:
	var blue := Color("38b6ff")
	_box(ci, 16, 50, 68, 44, STONE)
	_box(ci, 16, 86, 68, 8, STONE.darkened(0.2), false)
	_poly(ci, PackedVector2Array([Vector2(9, 52), Vector2(50, 22), Vector2(91, 52)]), blue.darkened(0.3))
	_line(ci, Vector2(14, 50.5), Vector2(86, 50.5), blue.darkened(0.5), 2.0)
	_arch(ci, 50, 72, 94, 18, DARK)
	for x: float in [26.0, 74.0]:
		_arch(ci, x, 64, 78, 8, DARK)
	# Swords crossed behind the shield.
	for sx: float in [-1.0, 1.0]:
		var d := Vector2(sx, -1).normalized()
		var hilt := Vector2(50 - sx * 15, 64)
		_line(ci, hilt, hilt + d * 38.0, STEEL, 3.0)
		_line(ci, hilt + d * 7.0 + d.orthogonal() * 4.5, hilt + d * 7.0 - d.orthogonal() * 4.5, GOLD.darkened(0.2), 2.5)
	_poly(ci, PackedVector2Array([Vector2(39, 34), Vector2(61, 34), Vector2(61, 50), Vector2(50, 64), Vector2(39, 50)]), blue)
	_poly(ci, PackedVector2Array([Vector2(43, 38), Vector2(57, 38), Vector2(57, 49), Vector2(50, 58), Vector2(43, 49)]),
		blue.lightened(0.45), false)
	_dot(ci, Vector2(50, 46), 3.0, blue.darkened(0.3))


## The Tinker's: a small shop with a trap kit for a sign, an open case
## with picks in both halves. Its id is still "locksmith", from when it
## sold keys.
static func _locksmith(ci: CanvasItem) -> void:
	var kit := Color("2fd6c4")
	_box(ci, 14, 54, 52, 40, Color("b39a72"))
	_poly(ci, PackedVector2Array([Vector2(8, 56), Vector2(40, 30), Vector2(72, 56)]), Color("c79a2a"))
	_box(ci, 26, 68, 16, 26, WOOD.darkened(0.15))
	_dot(ci, Vector2(38, 82), 1.8, GOLD)
	_box(ci, 48, 66, 12, 12, GLOW)
	_line(ci, Vector2(54, 66), Vector2(54, 78), WOOD.darkened(0.3), 1.2)
	_line(ci, Vector2(48, 72), Vector2(60, 72), WOOD.darkened(0.3), 1.2)
	# The sign: the kit hanging open from a bracket.
	_line(ci, Vector2(66, 56), Vector2(92, 56), DARK, 2.5)
	for x: float in [77.0, 89.0]:
		_line(ci, Vector2(x, 56), Vector2(x, 63), DARK, 1.5)
	_box(ci, 72, 63, 10.5, 24, kit)
	_box(ci, 83.5, 63, 10.5, 24, kit)
	for x: float in [75.5, 79.0, 87.0, 90.5]:
		_line(ci, Vector2(x, 67), Vector2(x, 83), DARK, 1.3)
		_line(ci, Vector2(x, 67), Vector2(x - 1.8, 66), DARK, 1.3)


## A bank front: columns on steps, and a coin in the gable.
static func _mint(ci: CanvasItem) -> void:
	var green := Color("4be38a")
	_box(ci, 18, 50, 64, 34, Color("5d566b"))
	_arch(ci, 50, 62, 84, 12, DARK)
	for x: float in [20.0, 35.0, 57.0, 72.0]:
		_box(ci, x, 50, 8, 34, PALE)
		_line(ci, Vector2(x + 5.5, 51), Vector2(x + 5.5, 83), PALE.darkened(0.18), 1.5)
	_box(ci, 14, 44, 72, 7, PALE.darkened(0.08))
	_poly(ci, PackedVector2Array([Vector2(11, 44), Vector2(50, 18), Vector2(89, 44)]), green.darkened(0.3))
	_dot(ci, Vector2(50, 34), 7.0, GOLD)
	_dot(ci, Vector2(50, 34), 4.5, GOLD.darkened(0.22))
	_box(ci, 14, 83, 72, 6, PALE.darkened(0.08))
	_box(ci, 9, 88, 82, 6, PALE.darkened(0.2))
	# Coins stacked on the steps.
	for k in 4:
		_poly(ci, _arc(Vector2(84, 86 - k * 3.2), 7, 2.6, 0.0, TAU, 14), GOLD.darkened(0.25 if k < 3 else 0.0))


## A log cabin with logs stacked outside and an axe left in them.
static func _woodcutter(ci: CanvasItem) -> void:
	var log_c := Color("9a6c3c")
	_box(ci, 32, 56, 52, 38, log_c)
	for y: float in [64.0, 72.0, 80.0, 88.0]:
		_line(ci, Vector2(32, y), Vector2(84, y), log_c.darkened(0.3), 1.5)
	for y: float in [60.0, 68.0, 76.0, 84.0, 91.0]:
		for x: float in [32.0, 84.0]:
			_dot(ci, Vector2(x, y), 3.4, log_c.lightened(0.25))
	_poly(ci, PackedVector2Array([Vector2(25, 58), Vector2(58, 32), Vector2(91, 58)]), Color("ff9a3c").darkened(0.25))
	_box(ci, 68, 34, 8, 14, STONE.darkened(0.2))
	_box(ci, 51, 70, 14, 24, DARK)
	_box(ci, 70, 68, 9, 9, GLOW)
	# The woodpile, and the axe.
	_line(ci, Vector2(17, 76), Vector2(30, 52), WOOD.darkened(0.2), 3.0)
	_poly(ci, PackedVector2Array([Vector2(26, 50), Vector2(37, 48), Vector2(39, 60), Vector2(31, 57)]), STEEL)
	for p: Vector2 in [Vector2(9, 87), Vector2(22, 87), Vector2(15.5, 76)]:
		_dot(ci, p, 7.0, log_c.darkened(0.25))
		_dot(ci, p, 4.8, Color("e0bd85"))
		_dot(ci, p, 1.6, log_c.darkened(0.1))


## A cut rock face, with dressed blocks in front and a pick leaning on it.
static func _quarry(ci: CanvasItem) -> void:
	var rock := Color("9aa1ad")
	var pale := Color("dfe6ee")
	_poly(ci, PackedVector2Array([Vector2(4, 94), Vector2(10, 58), Vector2(28, 34), Vector2(52, 24), Vector2(72, 40),
		Vector2(84, 66), Vector2(94, 94)]), rock)
	_poly(ci, PackedVector2Array([Vector2(28, 34), Vector2(52, 24), Vector2(48, 58), Vector2(22, 62)]), rock.lightened(0.3), false)
	_poly(ci, PackedVector2Array([Vector2(52, 24), Vector2(72, 40), Vector2(84, 66), Vector2(66, 94), Vector2(46, 94),
		Vector2(48, 58)]), rock.darkened(0.2), false)
	# Steps cut into the face.
	for s: Array in [[50.0, 58.0, 22.0], [54.0, 68.0, 22.0]]:
		_line(ci, Vector2(s[0], s[1]), Vector2(s[0] + s[2], s[1]), rock.darkened(0.42), 1.5)
	_box(ci, 56, 76, 20, 18, pale)
	_box(ci, 72, 84, 18, 10, pale.darkened(0.12))
	_box(ci, 60, 66, 14, 10, pale.darkened(0.06))
	_line(ci, Vector2(18, 93), Vector2(34, 62), WOOD, 3.0)
	_poly(ci, PackedVector2Array([Vector2(20, 62), Vector2(34, 57), Vector2(48, 66), Vector2(35, 62.5), Vector2(22, 66)]),
		STEEL.darkened(0.3))


## A crooked hut under a bent hat of a roof, bubbling, with flasks outside.
static func _alchemist(ci: CanvasItem) -> void:
	var teal := Color("2f9e8f")
	var brew := Color("8fe36a")
	for b: Array in [[Vector2(72, 26), 4.0, 0.7], [Vector2(79, 16), 3.2, 0.55], [Vector2(74, 7), 2.4, 0.4]]:
		_dot(ci, b[0], b[1], Color(brew, b[2]))
	_box(ci, 66, 32, 8, 20, STONE.darkened(0.3))
	_poly(ci, PackedVector2Array([Vector2(24, 94), Vector2(28, 54), Vector2(72, 56), Vector2(76, 94)]), Color("b7a98f"))
	for l: Array in [[Vector2(28, 70), Vector2(75, 72)], [Vector2(56, 56), Vector2(54, 94)]]:
		_line(ci, l[0], l[1], WOOD.darkened(0.2), 2.0)
	_poly(ci, PackedVector2Array([Vector2(16, 58), Vector2(40, 30), Vector2(44, 10), Vector2(56, 28), Vector2(84, 58)]), teal)
	_poly(ci, PackedVector2Array([Vector2(44, 10), Vector2(56, 28), Vector2(84, 58), Vector2(60, 58)]), teal.darkened(0.2), false)
	_box(ci, 33, 74, 14, 20, DARK)
	_dot(ci, Vector2(66, 82), 9.0, Color(brew, 0.22))
	_dot(ci, Vector2(66, 82), 6.5, WOOD.darkened(0.3))
	_dot(ci, Vector2(66, 82), 4.8, brew.lightened(0.3))
	_flask(ci, Vector2(88, 86), 7.0, Color("ff7ac0"))
	_flask(ci, Vector2(11, 88), 5.5, Color("38b6ff"))


## A round flask of `c`, its body centered on `at`.
static func _flask(ci: CanvasItem, at: Vector2, r: float, c: Color) -> void:
	_box(ci, at.x - r * 0.3, at.y - r * 1.9, r * 0.6, r * 1.2, c.lightened(0.3), false)
	_box(ci, at.x - r * 0.45, at.y - r * 2.2, r * 0.9, r * 0.4, WOOD, false)
	_dot(ci, at, r, c)
	_dot(ci, at + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.95))


# --- Levels ------------------------------------------------------------------
# Level 1 is the building as drawn above. Each level after it adds a part of
# the building, `behind` it or in front of it, so a maxed one has them all, and
# its last level a gold star. Renders: dev/renders/town_levels_v1/.

const FIRE := Color("ff9a3c")


static func _levels(ci: CanvasItem, p_id: String, lv: int, behind: bool) -> void:
	match p_id:
		"barracks":
			_barracks_at(ci, lv, behind)
		"forge":
			_forge_at(ci, lv, behind)
		"tower":
			_tower_at(ci, lv, behind)
		"armory":
			_armory_at(ci, lv, behind)
		"locksmith":
			_locksmith_at(ci, lv, behind)
		"mint":
			_mint_at(ci, lv, behind)
		"woodcutter":
			_woodcutter_at(ci, lv, behind)
		"quarry":
			_quarry_at(ci, lv, behind)
		"alchemist":
			_alchemist_at(ci, lv, behind)


## A pole up from `base`, `h` tall, flying a pennant of `c`.
static func _pennant(ci: CanvasItem, base: Vector2, h: float, c: Color, w := 13.0) -> void:
	var top := base - Vector2(0, h)
	_line(ci, base, top, WOOD.darkened(0.2), 1.8)
	_poly(ci, PackedVector2Array([top, top + Vector2(w, 3.5), top + Vector2(0, 7.5)]), c)


## A cloth hanging from a rod, notched at the bottom.
static func _banner(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	_poly(ci, PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h),
		Vector2(x + w * 0.5, y + h - w * 0.4), Vector2(x, y + h)]), c)
	_line(ci, Vector2(x - 1.5, y), Vector2(x + w + 1.5, y), DARK, 1.6)


## A lit torch on the wall, its foot at `at`.
static func _torch(ci: CanvasItem, at: Vector2) -> void:
	_line(ci, at, at + Vector2(0, -7), WOOD.darkened(0.3), 2.2)
	_dot(ci, at + Vector2(0, -10), 3.4, Color(FIRE, 0.35))
	_dot(ci, at + Vector2(0, -9.5), 2.4, FIRE)
	_dot(ci, at + Vector2(0, -9), 1.2, GLOW)


static func _cone(ci: CanvasItem, x0: float, x1: float, base_y: float, peak_y: float, c: Color) -> void:
	_poly(ci, PackedVector2Array([Vector2(x0, base_y), Vector2((x0 + x1) * 0.5, peak_y), Vector2(x1, base_y)]), c)
	_poly(ci, PackedVector2Array([Vector2((x0 + x1) * 0.5, peak_y), Vector2(x1, base_y), Vector2((x0 + x1) * 0.5 + 1, base_y)]),
		c.darkened(0.2), false)


## A small lit window with a cross of bars.
static func _window(ci: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	_box(ci, x, y, w, h, GLOW)
	_line(ci, Vector2(x + w * 0.5, y), Vector2(x + w * 0.5, y + h), DARK, 1.0)
	_line(ci, Vector2(x, y + h * 0.5), Vector2(x + w, y + h * 0.5), DARK, 1.0)


## A gold star, the mark of a building at its last level.
static func _star(ci: CanvasItem, at: Vector2, r := 5.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(at + Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * (r if i % 2 == 0 else r * 0.45))
	_poly(ci, pts, GOLD)


static func _gear(ci: CanvasItem, at: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		pts.append(at + Vector2.from_angle(a) * (r if (i / 2) % 2 == 0 else r * 0.72))
	_poly(ci, pts, c)
	_dot(ci, at, r * 0.32, DARK)


static func _barracks_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	var red := Color("e0445c")
	if behind:
		# 9: a taller keep rises behind the wall.
		if lv >= 9:
			_box(ci, 36, 30, 28, 24, STONE.darkened(0.22))
			for k in 3:
				_box(ci, 36 + k * 10.5, 24, 7, 7, STONE.darkened(0.22))
			_box(ci, 47, 36, 6, 9, GLOW, false)
		return
	# 2, 3: a pennant on each corner tower; 8 roofs them first.
	for i in 2:
		var x: float = [21.0, 79.0][i]
		if lv >= 8:
			_cone(ci, x - 13, x + 13, 34, 20, red.darkened(0.35))
		if lv >= 2 + i:
			_pennant(ci, Vector2(x, 34 if lv < 8 else 21), 14, red, 10)
	# 4: arrow slits.
	if lv >= 4:
		for x: float in [36.0, 62.0]:
			_box(ci, x, 56, 3, 9, DARK, false)
	# 5: a portcullis over the gate.
	if lv >= 5:
		for x: float in [44.0, 48.0, 52.0, 56.0]:
			_line(ci, Vector2(x, 70), Vector2(x, 93), DARK, 1.3)
		_line(ci, Vector2(42, 80), Vector2(58, 80), DARK, 1.3)
	# 6: banners down the towers.
	if lv >= 6:
		for x: float in [15.0, 73.0]:
			_banner(ci, x, 70, 12, 17, red)
	# 7: torches by the gate.
	if lv >= 7:
		for x: float in [37.0, 63.0]:
			_torch(ci, Vector2(x, 82))
	# 10: a gold star on the flag.
	if lv >= 10:
		_star(ci, Vector2(59, 18), 4.5)


static func _forge_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	var wall := Color("6f6878")
	if behind:
		# 5: a second chimney, smoking.
		if lv >= 5:
			_dot(ci, Vector2(22, 24), 4.5, Color(0.8, 0.8, 0.85, 0.45))
			_box(ci, 17, 30, 10, 26, wall.darkened(0.3))
			_box(ci, 15, 28, 14, 4, wall.darkened(0.45))
		return
	# 2: shingles on the roof.
	if lv >= 2:
		for t: float in [0.35, 0.65]:
			_line(ci, Vector2(6, 56).lerp(Vector2(41, 30), t), Vector2(76, 56).lerp(Vector2(41, 30), t),
				Color("4a4458").lightened(0.22), 2.2)
	# 3: a lit window.
	if lv >= 3:
		_window(ci, 56, 62, 9, 9)
	# 4: an awning over the anvil.
	if lv >= 4:
		_line(ci, Vector2(95, 64), Vector2(95, 76), WOOD.darkened(0.2), 2.0)
		_poly(ci, PackedVector2Array([Vector2(70, 56), Vector2(99, 62), Vector2(99, 66), Vector2(70, 61)]), WOOD)
	# 6: a hammer for a sign, hanging from it.
	if lv >= 6:
		_line(ci, Vector2(84, 64), Vector2(84, 68), DARK, 1.2)
		_box(ci, 80, 68, 8, 4, STEEL.darkened(0.15))
		_line(ci, Vector2(84, 72), Vector2(84, 75), WOOD, 1.8)
	# 7: a grindstone at the corner.
	if lv >= 7:
		_line(ci, Vector2(3, 94), Vector2(7, 84), WOOD.darkened(0.2), 2.0)
		_line(ci, Vector2(15, 94), Vector2(11, 84), WOOD.darkened(0.2), 2.0)
		_dot(ci, Vector2(9, 82), 7.0, STONE.lightened(0.1))
		_dot(ci, Vector2(9, 82), 2.0, DARK)
	# 8: a gold weathervane on the roof.
	if lv >= 8:
		_line(ci, Vector2(41, 30), Vector2(41, 20), DARK, 1.4)
		_poly(ci, PackedVector2Array([Vector2(36, 21), Vector2(46, 19), Vector2(46, 23)]), GOLD)
	# 9: a horseshoe on the chimney.
	if lv >= 9:
		var shoe := _arc(Vector2(58.5, 36), 4.5, 4.5, 0.0, -PI * 1.0, 10)
		for i in shoe.size() - 1:
			_line(ci, shoe[i], shoe[i + 1], GOLD, 2.6)
		for sx: float in [-4.5, 4.5]:
			_line(ci, Vector2(58.5 + sx, 36), Vector2(58.5 + sx, 41), GOLD, 2.6)
	# 10: the fire roars: sparks over the chimney.
	if lv >= 10:
		for d: Array in [[Vector2(55, 12), 2.4], [Vector2(64, 8), 2.0], [Vector2(50, 5), 1.8], [Vector2(60, 1), 2.2]]:
			_dot(ci, d[0], d[1], FIRE)
			_dot(ci, d[0], d[1] * 0.5, GLOW)


static func _tower_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	var magic := Color("b77bff")
	var wall := Color("8c84a8")
	if behind:
		# 5: a second turret on the left.
		if lv >= 5:
			_box(ci, 21, 60, 14, 18, wall.darkened(0.08))
			_cone(ci, 18, 38, 61, 45, magic.darkened(0.3))
			_box(ci, 26, 65, 4, 7, GLOW, false)
		return
	# 2: a second window.
	if lv >= 2:
		_arch(ci, 57, 60, 73, 7, GLOW)
	# 3: a pennant on the turret.
	if lv >= 3:
		_pennant(ci, Vector2(70, 35), 11, magic.lightened(0.2), 9)
	# 4: a balcony round the tower.
	if lv >= 4:
		_box(ci, 31, 44, 38, 3.5, wall.darkened(0.35))
		for x: float in [33.0, 40.0, 47.0, 54.0, 61.0, 67.0]:
			_line(ci, Vector2(x, 44), Vector2(x, 40), wall.darkened(0.35), 1.2)
		_line(ci, Vector2(31, 40), Vector2(69, 40), wall.darkened(0.35), 1.2)
	# 6: a gold ring about the spire.
	if lv >= 6:
		var ring := _arc(Vector2(50, 24), 17, 3.5, 0.15 * PI, 0.85 * PI, 10)
		for i in ring.size() - 1:
			_line(ci, ring[i], ring[i + 1], GOLD, 1.6)
	# 7: more stars.
	if lv >= 7:
		_twinkle(ci, Vector2(88, 44), 4.5, magic.lightened(0.25))
		_twinkle(ci, Vector2(10, 40), 4.0, magic.lightened(0.25))
	# 8: runes glowing up the wall.
	if lv >= 8:
		for y: float in [70.0, 78.0, 86.0]:
			_poly(ci, PackedVector2Array([Vector2(40, y - 3.5), Vector2(43, y), Vector2(40, y + 3.5), Vector2(37, y)]),
				magic.lightened(0.5), false)
	# 9: a crystal over the spire.
	if lv >= 9:
		_poly(ci, PackedVector2Array([Vector2(50, -8), Vector2(54, -3), Vector2(50, 1), Vector2(46, -3)]), magic.lightened(0.45))
	# 10: the spire tipped in a gold star.
	if lv >= 10:
		_star(ci, Vector2(50, 5), 5.5)


static func _armory_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	var blue := Color("38b6ff")
	if behind:
		# 5: a lookout on the roof.
		if lv >= 5:
			_box(ci, 45, 14, 10, 14, STONE.darkened(0.15))
			_cone(ci, 42, 58, 15, 5, blue.darkened(0.3))
		return
	# 2: a spear rack on the left.
	if lv >= 2:
		for x: float in [3.0, 7.0, 11.0]:
			_line(ci, Vector2(x, 93), Vector2(x, 64), WOOD, 1.6)
			_poly(ci, PackedVector2Array([Vector2(x, 59), Vector2(x + 1.8, 65), Vector2(x - 1.8, 65)]), STEEL)
		_line(ci, Vector2(1, 80), Vector2(14, 80), WOOD.darkened(0.3), 1.8)
	# 3: tiles on the roof.
	if lv >= 3:
		for t: float in [0.4, 0.7]:
			_line(ci, Vector2(9, 52).lerp(Vector2(50, 22), t), Vector2(91, 52).lerp(Vector2(50, 22), t), blue.darkened(0.5), 1.3)
	# 4: blue banners on the wall.
	if lv >= 4:
		for x: float in [20.0, 72.0]:
			_banner(ci, x, 80, 8, 12, blue)
	# 6: round shields stacked on the right.
	if lv >= 6:
		for p: Vector2 in [Vector2(92, 88), Vector2(92, 77)]:
			_dot(ci, p, 5.5, blue.darkened(0.15))
			_dot(ci, p, 2.0, STEEL)
	# 7: iron bands on the door.
	if lv >= 7:
		for y: float in [80.0, 87.0]:
			_line(ci, Vector2(41.5, y), Vector2(58.5, y), STEEL.darkened(0.3), 1.6)
	# 8: pennants at the roof's ends.
	if lv >= 8:
		_pennant(ci, Vector2(12, 50), 14, blue, 9)
		_pennant(ci, Vector2(88, 50), 14, blue, 9)
	# 9: torches by the door.
	if lv >= 9:
		for x: float in [37.0, 63.0]:
			_torch(ci, Vector2(x, 84))
	# 10: a gold star on the shield.
	if lv >= 10:
		_star(ci, Vector2(50, 46), 5.5)


static func _locksmith_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	if behind:
		# 3: a chimney, letting off steam.
		if lv >= 3:
			_dot(ci, Vector2(26, 24), 4.0, Color(0.9, 0.9, 0.95, 0.5))
			_dot(ci, Vector2(21, 17), 3.0, Color(0.9, 0.9, 0.95, 0.35))
			_box(ci, 22, 30, 9, 20, STONE.darkened(0.2))
		return
	# 2: a gear in the gable.
	if lv >= 2:
		_gear(ci, Vector2(40, 45), 6.0, GOLD.darkened(0.15))
	# 3: a striped awning over the window, and its max star.
	if lv >= 3:
		for i in 4:
			_poly(ci, PackedVector2Array([Vector2(46 + i * 4, 59), Vector2(50 + i * 4, 59), Vector2(51.5 + i * 4.5, 66),
				Vector2(46.5 + i * 4.5, 66) - Vector2(2, 0)]), Color("2fd6c4") if i % 2 == 0 else PALE)
		_star(ci, Vector2(83, 58), 4.5)


static func _mint_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	if behind:
		# 5: a gold dome behind the gable.
		if lv >= 5:
			_poly(ci, _arc(Vector2(50, 26), 14, 14, PI, TAU, 14), GOLD.darkened(0.1))
		return
	# 2: gold bands on the columns.
	if lv >= 2:
		for x: float in [20.0, 35.0, 57.0, 72.0]:
			_box(ci, x - 1, 50, 10, 4.5, GOLD.darkened(0.05))
	# 3: a second stack of coins.
	if lv >= 3:
		for k in 3:
			_poly(ci, _arc(Vector2(16, 86 - k * 3.2), 6, 2.4, 0.0, TAU, 14), GOLD.darkened(0.25 if k < 2 else 0.0))
	# 4: gold finials on the gable.
	if lv >= 4:
		for p: Vector2 in [Vector2(12, 42), Vector2(88, 42)]:
			_dot(ci, p, 3.0, GOLD)
	# 5: and a star at its top.
	if lv >= 5:
		_star(ci, Vector2(50, 9), 5.0)


static func _woodcutter_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	var log_c := Color("9a6c3c")
	if behind:
		# 3: smoke from the chimney.
		if lv >= 3:
			_dot(ci, Vector2(73, 27), 4.0, Color(0.8, 0.8, 0.85, 0.5))
			_dot(ci, Vector2(78, 19), 3.0, Color(0.8, 0.8, 0.85, 0.35))
		return
	# 2: another log on the pile.
	if lv >= 2:
		_dot(ci, Vector2(28.5, 76), 7.0, log_c.darkened(0.25))
		_dot(ci, Vector2(28.5, 76), 4.8, Color("e0bd85"))
		_dot(ci, Vector2(28.5, 76), 1.6, log_c.darkened(0.1))
	# 3: a flower box under the window.
	if lv >= 3:
		_box(ci, 67, 77, 15, 4, WOOD.darkened(0.1))
		for x: float in [70.0, 74.5, 79.0]:
			_dot(ci, Vector2(x, 75.5), 2.6, Color("ff7ac0"))
	# 4: a dormer in the roof.
	if lv >= 4:
		_poly(ci, PackedVector2Array([Vector2(43, 50), Vector2(49, 42), Vector2(55, 50)]), Color("ff9a3c").darkened(0.4))
		_box(ci, 46, 48, 6, 5, GLOW, false)
	# 5: a lantern over the door, and the max star.
	if lv >= 5:
		_line(ci, Vector2(58, 62), Vector2(58, 66), DARK, 1.2)
		_box(ci, 56, 66, 4, 4, GLOW)
		_star(ci, Vector2(58, 38), 4.5)


static func _quarry_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	if behind:
		# 3: a hoist over the face.
		if lv >= 3:
			_line(ci, Vector2(66, 40), Vector2(80, 14), WOOD, 2.4)
			_line(ci, Vector2(90, 66), Vector2(80, 14), WOOD, 2.4)
			_line(ci, Vector2(80, 14), Vector2(94, 20), WOOD, 2.0)
			_line(ci, Vector2(94, 20), Vector2(94, 44), DARK, 1.0)
		return
	# 2: another block, on the pile.
	if lv >= 2:
		_box(ci, 61, 54, 13, 12, Color("dfe6ee").darkened(0.03))
	# 3: the hoist's load.
	if lv >= 3:
		_box(ci, 90, 44, 8, 6, Color("dfe6ee").darkened(0.1))
	# 4: a cart of stone.
	if lv >= 4:
		_poly(ci, PackedVector2Array([Vector2(1, 80), Vector2(19, 80), Vector2(17, 88), Vector2(3, 88)]), WOOD)
		_dot(ci, Vector2(6, 90), 3.0, DARK)
		_dot(ci, Vector2(15, 90), 3.0, DARK)
		_dot(ci, Vector2(7, 79), 3.5, Color("9aa1ad").lightened(0.15))
		_dot(ci, Vector2(13, 78), 3.5, Color("9aa1ad"))
	# 5: a seam of crystal in the rock, and the max star.
	if lv >= 5:
		for c: Array in [[Vector2(36, 46), 4.0], [Vector2(41, 50), 3.0], [Vector2(32, 51), 2.6]]:
			_poly(ci, PackedVector2Array([c[0] + Vector2(0, -c[1] * 1.5), c[0] + Vector2(c[1], 0), c[0] + Vector2(0, c[1]),
				c[0] + Vector2(-c[1], 0)]), Color("7fe0ff"))
		_star(ci, Vector2(52, 17), 4.5)


static func _alchemist_at(ci: CanvasItem, lv: int, behind: bool) -> void:
	var brew := Color("8fe36a")
	if behind:
		return
	# 2: a green lantern from the roof's edge.
	if lv >= 2:
		_line(ci, Vector2(80, 57), Vector2(80, 63), DARK, 1.2)
		_dot(ci, Vector2(80, 66), 4.5, Color(brew, 0.3))
		_dot(ci, Vector2(80, 66), 2.6, brew.lightened(0.3))
	# 3: a shelf of flasks by the door.
	if lv >= 3:
		_line(ci, Vector2(48, 69), Vector2(62, 69), WOOD.darkened(0.3), 2.4)
		_flask(ci, Vector2(51, 65), 3.6, Color("ffd23d"))
		_flask(ci, Vector2(59, 65), 3.6, Color("b77bff"))
	# 4: mushrooms by the hut, and the max star.
	if lv >= 4:
		for m: Array in [[Vector2(21, 94), 8.0], [Vector2(31, 94), 5.5]]:
			_line(ci, m[0], m[0] + Vector2(0, -m[1]), PALE, 2.6)
			_poly(ci, _arc(m[0] + Vector2(0, -m[1]), m[1], m[1] * 0.75, PI, TAU, 8), Color("e0445c").lightened(0.1))
		_star(ci, Vector2(44, 3), 4.5)
