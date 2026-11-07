class_name EnemyLook
extends RefCounted
## How each enemy is drawn: a flat-shaded silhouette in its color, facing
## left at the hero. Shared by the runner and the codex. Each look is drawn
## in a 100 by 100 space with the feet on the bottom edge, stretched to the
## encounter's rect, so hits, missiles and bars still line up with it.
## Accents come from the body color (darkened or lightened), so a hit's
## flash and a freeze's frost tint the whole creature. An id without a look
## gets the old box with two eyes.

const OUTLINE := Color(0, 0, 0, 0.45)
const BONE := Color("e6e1d3")
const STEEL := Color("c9d0da")
const GOLD := Color("f2c53d")
const WOOD := Color("7a5634")
const DARK := Color("1a1620")

## The current draw's opacity, applied by `_a`.
static var _alpha := 1.0
## While drawing a silhouette, the one color everything is drawn in.
static var _shade := Color.TRANSPARENT
## True while drawing what's drawn again every frame, not baked: then the
## shapes come from Kept, which makes no mesh for each.
static var _live := false


## Poses each look loops through, and how many it shows a second. Looks not
## listed hold one pose. Poses are what EnemySprites bakes, so they cover
## the moving parts (wings, hems, glows); the whole body's bob, breath and
## sway are MOTION, applied live, so they stay smooth.
const POSES := 4
const POSE_RATE := {"skeleton": 8.0, "ghost": 6.0, "imp": 12.0, "orc_warlord": 6.0, "cultist": 5.0,
	"bat_swarm": 10.0, "kobold_miner": 6.0, "cave_crawler": 8.0, "glowcap": 4.0, "stone_elemental": 4.0,
	"lich": 6.0, "crystal_golem": 5.0, "the_warden": 4.0, "deep_wyrm": 4.0,
	"hellhound": 8.0, "tortured_soul": 5.0, "lilim": 8.0, "ualac": 6.0, "fallen_angel": 4.0,
	"amdusias": 5.0, "belial": 8.0, "astaroth": 5.0,
	"deep_one": 6.0, "serpent_man": 6.0, "drowned_acolyte": 5.0, "night_gaunt": 10.0, "gibbering_mass": 5.0,
	"hierophant": 5.0, "shoggoth": 5.0, "sleeper_below": 4.0, "spawnling": 8.0, "wicked_vine": 4.0}
## Whole-body idle motion: [kind, speed, amount]. "breathe" stretches up
## from the feet, "wobble" squashes and stretches, "sway" leans from the
## feet, "hover" bobs up and down (amount in the look's units).
const MOTION := {"jeweller": ["breathe", 2.0, 0.015], "training_dummy": ["sway", 1.5, 0.03], "slime": ["wobble", 4.0, 0.06],
	"wolf": ["breathe", 3.0, 0.015], "goblin": ["breathe", 3.0, 0.025], "treant_sapling": ["sway", 1.6, 0.05],
	"giant_spider": ["breathe", 3.0, 0.02], "broodmother": ["breathe", 2.5, 0.02], "ghost": ["hover", 2.5, 4.0],
	"imp": ["hover", 4.0, 3.0], "orc": ["breathe", 2.0, 0.02], "orc_warlord": ["breathe", 2.0, 0.02],
	"kobold_miner": ["breathe", 3.5, 0.02], "glowcap": ["breathe", 2.5, 0.02], "stone_elemental": ["breathe", 2.0, 0.01],
	"ogre_king": ["wobble", 1.8, 0.02], "lich": ["hover", 2.0, 3.0], "myconid_matriarch": ["sway", 1.5, 0.025],
	"old_mossback": ["breathe", 1.4, 0.02], "the_warden": ["breathe", 1.8, 0.012], "deep_wyrm": ["sway", 1.6, 0.05],
	"hellhound": ["breathe", 3.5, 0.02], "tortured_soul": ["hover", 1.8, 3.0], "lilim": ["hover", 2.5, 3.0],
	"ualac": ["breathe", 2.8, 0.02], "fallen_angel": ["breathe", 1.6, 0.015], "amdusias": ["sway", 1.4, 0.02],
	"belial": ["breathe", 2.0, 0.012], "astaroth": ["breathe", 1.3, 0.015],
	"deep_one": ["breathe", 3.0, 0.02], "serpent_man": ["sway", 1.8, 0.03], "drowned_acolyte": ["breathe", 2.5, 0.02],
	"night_gaunt": ["hover", 4.0, 3.0], "gibbering_mass": ["wobble", 3.0, 0.05], "hierophant": ["breathe", 1.8, 0.015],
	"shoggoth": ["wobble", 2.0, 0.035], "sleeper_below": ["breathe", 1.2, 0.015], "spawnling": ["wobble", 4.5, 0.06],
	"wicked_vine": ["sway", 1.6, 0.025], "boar": ["breathe", 2.4, 0.02], "dark_gnome": ["breathe", 3.5, 0.025]}
## Floor shadows under the looks that hover: [x, half width].
const SHADOWS := {"ghost": [52.0, 22.0], "imp": [50.0, 16.0], "lich": [52.0, 24.0],
	"tortured_soul": [50.0, 20.0], "lilim": [52.0, 18.0], "night_gaunt": [50.0, 18.0]}
## Hellfire, as on burning tiles (Board.FIRE_COLOR): violet-blue brimstone.
const HELLFIRE := Color("8a7dff")
const HELLFIRE_CORE := Color("d8d2ff")
const EMBER := Color("ffb347")
## The cult's colors: its runes' cold teal and the Sleeper's green eyes.
const CULT_TEAL := Color("3fe0c5")
const ELDER_GREEN := Color("8fe36a")


## Draws enemy `look` filling `r`, shapes and all. `body` is its color right
## now, tints included. `t` is a clock in seconds for idle motion. `base` is
## the transform already in use (the runner squashes dying enemies),
## restored at the end. `shadow` is false when the caller drew it already.
## Costly: the runner draws EnemySprites' baked poses instead, and this only
## until they're ready.
static func draw(ci: CanvasItem, look: String, r: Rect2, body: Color, t := 0.0, base := Transform2D.IDENTITY,
		shadow := true) -> void:
	if shadow:
		draw_shadow(ci, look, r, body.a, base)
	var a := fmod(t * POSE_RATE.get(look, 0.0) / POSES, 1.0) * TAU
	_draw_at(ci, look, r, body, a, base * motion(look, t, r))
	ci.draw_set_transform_matrix(base)


## Draws pose `pose` of `look` filling `r`, still, for baking.
static func draw_pose(ci: CanvasItem, look: String, r: Rect2, body: Color, pose: int) -> void:
	_draw_at(ci, look, r, body, pose * TAU / POSES, Transform2D.IDENTITY)


## How many poses of `look` there are to bake.
static func pose_count(look: String) -> int:
	return POSES if POSE_RATE.has(look) else 1


## The pose `look` shows at `t` seconds.
static func pose_at(look: String, t: float) -> int:
	return int(t * POSE_RATE.get(look, 0.0)) % pose_count(look)


## The idle motion of `look` drawn in `r`, at `t` seconds.
static func motion(look: String, t: float, r: Rect2) -> Transform2D:
	if not MOTION.has(look):
		return Transform2D.IDENTITY
	var m: Array = MOTION[look]
	var k: float = sin(t * m[1]) * m[2]
	var xf := Transform2D.IDENTITY
	match m[0]:
		"hover":
			return Transform2D(0.0, Vector2(0.0, k * r.size.y / 100.0))
		"breathe":
			xf = Transform2D(0.0, Vector2(1.0 - k * 0.5, 1.0 + k), 0.0, Vector2.ZERO)
		"wobble":
			xf = Transform2D(0.0, Vector2(1.0 + k, 1.0 - k), 0.0, Vector2.ZERO)
		"sway":
			xf = Transform2D(0.0, Vector2.ONE, k, Vector2.ZERO)
	var feet := Vector2(r.get_center().x, r.end.y)
	return Transform2D(0.0, feet) * xf * Transform2D(0.0, -feet)


## The floor shadow under a look that hovers. It stays put as the look bobs.
static func draw_shadow(ci: CanvasItem, look: String, r: Rect2, alpha: float, base := Transform2D.IDENTITY) -> void:
	if not SHADOWS.has(look) or _shade.a > 0.0:
		return
	# A unit circle stretched flat: far cheaper than an oval's polygon.
	var at := r.position + Vector2(SHADOWS[look][0], 98.0) * r.size / 100.0
	var size := Vector2(SHADOWS[look][1], 3.5) * r.size / 100.0
	ci.draw_set_transform_matrix(base * Transform2D(0.0, size, 0.0, at))
	Kept.disc(ci, Vector2.ZERO, 1.0, Color(0, 0, 0, 0.3 * alpha))
	ci.draw_set_transform_matrix(base)


## `a` is the pose's angle, once round the loop of poses.
static func _draw_at(ci: CanvasItem, id: String, r: Rect2, body: Color, a: float, base: Transform2D) -> void:
	_alpha = body.a
	body.a = 1.0
	ci.draw_set_transform_matrix(base * Transform2D(0.0, r.size / 100.0, 0.0, r.position))
	match id:
		"training_dummy": _dummy(ci, body, a)
		"slime": _slime(ci, body, a)
		"wolf": _wolf(ci, body, a)
		"goblin": _goblin(ci, body, a)
		"treant_sapling": _treant(ci, body, a)
		"giant_spider": _spider(ci, body, a, false)
		"wicked_vine": _vine(ci, body, a)
		"boar": _boar(ci, body, a)
		"dark_gnome": _gnome(ci, body, a)
		"skeleton": _skeleton(ci, body, a)
		"ghost": _ghost(ci, body, a)
		"imp": _imp(ci, body, a)
		"orc": _orc(ci, body, a, false)
		"cultist": _cultist(ci, body, a)
		"jeweller": _jeweller(ci, body, a)
		"bat_swarm": _bats(ci, body, a)
		"kobold_miner": _kobold(ci, body, a)
		"cave_crawler": _crawler(ci, body, a)
		"glowcap": _glowcap(ci, body, a)
		"stone_elemental": _stone(ci, body, a)
		"ogre_king": _ogre(ci, body, a)
		"broodmother": _spider(ci, body, a, true)
		"lich": _lich(ci, body, a)
		"orc_warlord": _orc(ci, body, a, true)
		"crystal_golem": _golem(ci, body, a)
		"myconid_matriarch": _matriarch(ci, body, a)
		"old_mossback": _troll(ci, body, a)
		"the_warden": _warden(ci, body, a)
		"deep_wyrm": _wyrm(ci, body, a)
		"hellhound": _hellhound(ci, body, a)
		"tortured_soul": _soul(ci, body, a)
		"lilim": _lilim(ci, body, a)
		"ualac": _ualac(ci, body, a)
		"fallen_angel": _fallen(ci, body, a)
		"amdusias": _amdusias(ci, body, a)
		"belial": _belial(ci, body, a)
		"astaroth": _astaroth(ci, body, a)
		"deep_one": _deep_one(ci, body, a)
		"serpent_man": _serpent_man(ci, body, a)
		"drowned_acolyte": _drowned(ci, body, a)
		"night_gaunt": _night_gaunt(ci, body, a)
		"gibbering_mass": _gibbering(ci, body, a)
		"hierophant": _hierophant(ci, body, a)
		"shoggoth": _shoggoth(ci, body, a)
		"sleeper_below": _sleeper(ci, body, a)
		"spawnling": _spawnling(ci, body, a)
		_: _box(ci, body)
	ci.draw_set_transform_matrix(base)
	_alpha = 1.0


## Enemy `id`'s outline filled with flat `c`, for the codex's entries not
## met yet.
static func draw_silhouette(ci: CanvasItem, id: String, r: Rect2, c: Color, base := Transform2D.IDENTITY) -> void:
	_shade = c
	draw(ci, id, r, c, 0.0, base)
	_shade = Color.TRANSPARENT


## What shows of a burrowed enemy: a mound of earth with its back breaking
## through, filling `r`.
static func draw_burrowed(ci: CanvasItem, r: Rect2, body: Color, t: float, base := Transform2D.IDENTITY) -> void:
	_alpha = body.a
	body.a = 1.0
	_live = true
	ci.draw_set_transform_matrix(base * Transform2D(0.0, r.size / 100.0, 0.0, r.position))
	var heave := sin(t * 5.0) * 2.0
	_poly(ci, _arc(Vector2(50, 100), 50, 34 + heave, PI, TAU), Color("3b3328"))
	for i in 3:
		var x := 26.0 + i * 24.0
		_poly(ci, PackedVector2Array([Vector2(x - 8, 82), Vector2(x, 64 - heave * 2.0 - i % 2 * 6), Vector2(x + 8, 82)]), body.darkened(0.2))
	for i in 5:
		Kept.disc(ci, Vector2(12 + i * 19, 96 - (i % 2) * 6), 3.0, _a(Color("57493a")))
	ci.draw_set_transform_matrix(base)
	_alpha = 1.0
	_live = false


# Helpers. All take the 100 by 100 space.

static func _a(c: Color) -> Color:
	if _shade.a > 0.0:
		return _shade if c.a > 0.5 else Color.TRANSPARENT
	return Color(c, c.a * _alpha)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, c: Color, outline := true) -> void:
	if _live:
		Kept.poly(ci, pts, _a(c))
	else:
		ci.draw_colored_polygon(pts, _a(c))
	if outline:
		var loop := pts.duplicate()
		loop.append(pts[0])
		if _live:
			Kept.path(ci, loop, _a(OUTLINE), 1.5, true)
		else:
			ci.draw_polyline(loop, _a(OUTLINE), 1.5, true)


## Points along an ellipse from angle `from` to `to`.
static func _arc(c: Vector2, rx: float, ry: float, from: float, to: float, steps := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, i / float(steps))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, outline := true) -> void:
	var pts := _arc(c, rx, ry, 0.0, TAU, 24)
	pts.remove_at(pts.size() - 1)
	_poly(ci, pts, col, outline)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	ci.draw_line(a, b, _a(c), w, true)


static func _lines(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float) -> void:
	ci.draw_polyline(pts, _a(c), w, true)


static func _dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, _a(col), true, -1.0, true)


## A white eye with its pupil looking left at the hero.
static func _eye(ci: CanvasItem, c: Vector2, r: float, pupil := DARK) -> void:
	_dot(ci, c, r, Color.WHITE)
	_dot(ci, c + Vector2(-r * 0.35, r * 0.1), r * 0.55, pupil)


## A glowing eye, for things with no whites to their eyes.
static func _glow_eye(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_dot(ci, c, r * 2.2, Color(col, 0.25))
	_dot(ci, c, r, col)


# The roster.

## The old look: a box with two eyes.
static func _box(ci: CanvasItem, body: Color) -> void:
	ci.draw_rect(Rect2(0, 0, 100, 100), _a(body))
	ci.draw_rect(Rect2(15, 25, 12, 12), _a(Color.BLACK))
	ci.draw_rect(Rect2(40, 25, 12, 12), _a(Color.BLACK))


## A straw-stuffed sack on a post, with a target sewn on.
static func _dummy(ci: CanvasItem, body: Color, a: float) -> void:
	var post := WOOD.darkened(0.1)
	ci.draw_rect(Rect2(45, 40, 10, 60), _a(post))
	_line(ci, Vector2(10, 46), Vector2(90, 46), post, 7.0)
	_poly(ci, PackedVector2Array([Vector2(26, 38), Vector2(74, 38), Vector2(78, 76), Vector2(50, 84), Vector2(22, 76)]), body)
	for x in [36.0, 64.0]:
		_line(ci, Vector2(x, 40), Vector2(x + 2, 80), body.darkened(0.25), 1.5)
	# Straw poking out.
	for p: Vector2 in [Vector2(10, 46), Vector2(90, 46), Vector2(30, 80), Vector2(68, 80)]:
		for k in 3:
			var d := Vector2.from_angle(PI * 0.5 + (k - 1) * 0.5) * 8.0
			_line(ci, p, p + d, Color("e8c96a"), 2.0)
	_dot(ci, Vector2(48, 58), 12.0, Color("f2ead8"))
	_dot(ci, Vector2(48, 58), 8.0, Color("3d6a99"))
	_dot(ci, Vector2(48, 58), 3.5, Color("f2ead8"))
	var sway := 0.0
	_oval(ci, Vector2(50 + sway, 22), 15, 15, body)
	_line(ci, Vector2(38 + sway, 34), Vector2(62 + sway, 34), body.darkened(0.35), 3.0)
	for c: Vector2 in [Vector2(42 + sway, 20), Vector2(55 + sway, 20)]:
		_line(ci, c - Vector2(3, 3), c + Vector2(3, 3), DARK, 2.0)
		_line(ci, c + Vector2(-3, 3), c + Vector2(3, -3), DARK, 2.0)


## A wobbling dome of goo with a shine on top.
static func _slime(ci: CanvasItem, body: Color, a: float) -> void:
	var w := 0.0
	var pts := _arc(Vector2(50, 96), 46 + w, 66 - w, PI, TAU, 24)
	pts.append(Vector2(98 + w * 0.5, 100))
	pts.insert(0, Vector2(2 - w * 0.5, 100))
	_poly(ci, pts, body)
	_oval(ci, Vector2(50, 97), 40 + w, 4, body.darkened(0.25), false)
	_oval(ci, Vector2(66, 48 + w), 9, 6, Color(1, 1, 1, 0.55), false)
	_dot(ci, Vector2(76, 58 + w), 3.0, Color(1, 1, 1, 0.45))
	var y := 62.0 + w
	for x in [30.0, 50.0]:
		_oval(ci, Vector2(x, y), 5, 7, DARK, false)
		_dot(ci, Vector2(x - 1.5, y - 3), 1.8, Color.WHITE)
	_lines(ci, _arc(Vector2(40, y + 10), 6, 4, 0.2, PI - 0.2, 8), DARK, 2.0)


## A grey wolf in profile, head low, tail up.
static func _wolf(ci: CanvasItem, body: Color, a: float) -> void:
	var pant := 0.0
	var far := body.darkened(0.3)
	for x in [42.0, 78.0]:
		_line(ci, Vector2(x + 4, 62), Vector2(x + 6, 99), far, 7.0)
	_poly(ci, PackedVector2Array([Vector2(84, 52), Vector2(96, 34), Vector2(100, 22), Vector2(92, 28), Vector2(80, 46)]), body.darkened(0.1))
	_oval(ci, Vector2(60, 58 + pant), 32, 16, body)
	_oval(ci, Vector2(62, 66 + pant), 26, 7, body.lightened(0.25), false)
	for x in [34.0, 70.0]:
		_line(ci, Vector2(x, 64), Vector2(x - 2, 99), body, 8.0)
		_line(ci, Vector2(x - 6, 98), Vector2(x + 2, 98), body.darkened(0.2), 4.0)
	# Ruff, then the head with its snout pointed at the hero.
	_poly(ci, PackedVector2Array([Vector2(26, 34), Vector2(44, 40), Vector2(48, 62), Vector2(32, 72), Vector2(22, 58)]), body.lightened(0.1))
	var head := PackedVector2Array([Vector2(2, 50), Vector2(4, 44), Vector2(16, 38), Vector2(22, 16), Vector2(30, 30),
		Vector2(36, 18), Vector2(40, 36), Vector2(40, 50), Vector2(28, 58), Vector2(10, 58)])
	_poly(ci, head, body)
	_poly(ci, PackedVector2Array([Vector2(24, 24), Vector2(28, 31), Vector2(23, 32)]), body.darkened(0.35), false)
	_dot(ci, Vector2(4, 46), 3.0, DARK)
	_line(ci, Vector2(6, 54), Vector2(22, 54 + pant), DARK, 1.5)
	_poly(ci, PackedVector2Array([Vector2(16, 40), Vector2(26, 37), Vector2(24, 43)]), Color("f2e27a"), false)
	_dot(ci, Vector2(20, 41), 1.6, DARK)


## A big-eared goblin with a rock ready to throw.
static func _goblin(ci: CanvasItem, body: Color, a: float) -> void:
	var cloth := Color("6b4a2a")
	for x in [40.0, 56.0]:
		_line(ci, Vector2(x, 78), Vector2(x - 2, 98), body.darkened(0.15), 8.0)
		_oval(ci, Vector2(x - 5, 98), 7, 3, body.darkened(0.3), false)
	_poly(ci, PackedVector2Array([Vector2(34, 56), Vector2(64, 56), Vector2(66, 82), Vector2(32, 82)]), body)
	_poly(ci, PackedVector2Array([Vector2(30, 76), Vector2(68, 76), Vector2(62, 92), Vector2(48, 86), Vector2(36, 92)]), cloth)
	var bob := 0.0
	# The throwing arm, up and back, with the rock.
	_line(ci, Vector2(62, 62), Vector2(78, 50 + bob), body.darkened(0.1), 7.0)
	_line(ci, Vector2(78, 50 + bob), Vector2(82, 36 + bob), body.darkened(0.1), 7.0)
	_oval(ci, Vector2(84, 30 + bob), 9, 8, Color("8a8a92"))
	_line(ci, Vector2(36, 62), Vector2(26, 76), body.darkened(0.1), 7.0)
	_poly(ci, PackedVector2Array([Vector2(32, 34), Vector2(2, 20), Vector2(14, 34), Vector2(30, 46)]), body.darkened(0.05))
	_poly(ci, PackedVector2Array([Vector2(64, 34), Vector2(92, 12), Vector2(84, 30), Vector2(64, 46)]), body.darkened(0.05))
	_oval(ci, Vector2(48, 38), 19, 18, body)
	_poly(ci, PackedVector2Array([Vector2(34, 40), Vector2(20, 50), Vector2(36, 48)]), body.darkened(0.1))
	_eye(ci, Vector2(38, 34), 4.5, Color("c94a2a").darkened(0.5))
	_eye(ci, Vector2(53, 34), 4.5, Color("c94a2a").darkened(0.5))
	_line(ci, Vector2(32, 27), Vector2(43, 30), DARK, 2.5)
	_line(ci, Vector2(50, 30), Vector2(60, 27), DARK, 2.5)
	_lines(ci, PackedVector2Array([Vector2(36, 50), Vector2(42, 53), Vector2(52, 52)]), DARK, 2.0)
	_poly(ci, PackedVector2Array([Vector2(40, 52), Vector2(42, 56), Vector2(44, 52.5)]), Color.WHITE, false)


## A young tree that walked off: bark body, leafy crown, glowing eyes.
static func _treant(ci: CanvasItem, body: Color, a: float) -> void:
	var sway := 0.0
	var leaf := body.lerp(Color("5f9a3a"), 0.8)
	var bark := body.darkened(0.3)
	# Roots, trunk and twig arms.
	for d in [-1.0, 1.0]:
		_poly(ci, PackedVector2Array([Vector2(50 + d * 14, 82), Vector2(50 + d * 36, 100), Vector2(50 + d * 10, 100)]), body.darkened(0.1))
	_poly(ci, PackedVector2Array([Vector2(32, 36), Vector2(68, 36), Vector2(66, 100), Vector2(34, 100)]), body)
	for x in [40.0, 50.0, 60.0]:
		_lines(ci, PackedVector2Array([Vector2(x, 40), Vector2(x - 2, 60), Vector2(x + 1, 76), Vector2(x - 1, 96)]), bark, 1.5)
	_lines(ci, PackedVector2Array([Vector2(34, 58), Vector2(16, 46 + sway), Vector2(6, 48 + sway)]), body, 5.0)
	_line(ci, Vector2(16, 46 + sway), Vector2(12, 36 + sway), body, 3.0)
	_lines(ci, PackedVector2Array([Vector2(66, 56), Vector2(84, 44 + sway), Vector2(94, 46 + sway)]), body, 5.0)
	_dot(ci, Vector2(10, 34 + sway), 6.0, leaf)
	_dot(ci, Vector2(94, 40 + sway), 5.0, leaf)
	for c: Vector3 in [Vector3(30, 28, 18), Vector3(70, 26, 18), Vector3(50, 14, 20), Vector3(50, 32, 18)]:
		_oval(ci, Vector2(c.x + sway, c.y), c.z, c.z * 0.85, leaf)
	for c: Vector2 in [Vector2(38, 14), Vector2(62, 22), Vector2(46, 30)]:
		_dot(ci, c + Vector2(sway, 0), 4.0, leaf.lightened(0.25))
	_poly(ci, PackedVector2Array([Vector2(36, 52), Vector2(46, 50), Vector2(44, 56)]), DARK, false)
	_poly(ci, PackedVector2Array([Vector2(52, 50), Vector2(62, 52), Vector2(54, 56)]), DARK, false)
	_glow_eye(ci, Vector2(42, 53), 2.0, Color("e8f27a"))
	_glow_eye(ci, Vector2(56, 53), 2.0, Color("e8f27a"))
	_oval(ci, Vector2(48, 68), 5, 6, DARK, false)


## Eight legs, a round abdomen and a cluster of eyes. The Broodmother adds
## her markings, egg sacs and the thread she hangs from.
static func _spider(ci: CanvasItem, body: Color, a: float, mother: bool) -> void:
	var bob := 0.0
	var far := body.lightened(0.25)
	var near := body.lightened(0.4)
	if mother:
		_line(ci, Vector2(70, 0), Vector2(70, 40), Color(1, 1, 1, 0.5), 1.5)
	var hips := [Vector2(36, 66), Vector2(42, 62), Vector2(54, 62), Vector2(60, 66)]
	var knees := [Vector2(10, 40), Vector2(28, 30), Vector2(72, 30), Vector2(92, 40)]
	var feet := [Vector2(2, 100), Vector2(20, 100), Vector2(80, 100), Vector2(98, 100)]
	for i in 4:
		var o := Vector2(6, -4)
		_lines(ci, PackedVector2Array([hips[i] + o, knees[i] + o + Vector2(0, bob), feet[i] + Vector2(6, 0)]), far, 4.0)
	_oval(ci, Vector2(68, 56 + bob), 30, 25, body)
	_lines(ci, _arc(Vector2(68, 56 + bob), 27, 22, PI * 1.1, PI * 1.6, 8), body.lightened(0.35), 2.5)
	if mother:
		var mark := Color("c9a6ff")
		_poly(ci, PackedVector2Array([Vector2(60, 44 + bob), Vector2(76, 44 + bob), Vector2(70, 56 + bob),
			Vector2(76, 68 + bob), Vector2(60, 68 + bob), Vector2(66, 56 + bob)]), mark, false)
		for x in [58.0, 70.0, 82.0]:
			_poly(ci, PackedVector2Array([Vector2(x - 5, 34 + bob), Vector2(x, 22 + bob), Vector2(x + 5, 34 + bob)]), body.lightened(0.15))
		for c: Vector2 in [Vector2(80, 82), Vector2(88, 88), Vector2(74, 90)]:
			_line(ci, Vector2(80, 76 + bob), c + Vector2(0, bob), Color(1, 1, 1, 0.5), 1.0)
			_oval(ci, c + Vector2(0, bob), 6, 7, Color("e8e2d6"))
	else:
		_oval(ci, Vector2(70, 50 + bob), 10, 7, body.lightened(0.2), false)
	_oval(ci, Vector2(32, 66 + bob), 17, 14, body.lightened(0.05))
	for i in 4:
		_lines(ci, PackedVector2Array([hips[i], knees[i] + Vector2(0, bob), feet[i]]), near, 4.5)
	_line(ci, Vector2(20, 74 + bob), Vector2(17, 84 + bob), BONE, 3.0)
	_line(ci, Vector2(27, 76 + bob), Vector2(25, 86 + bob), BONE, 3.0)
	var eye := Color("d9b3ff") if mother else Color("c8f27a")
	for p: Vector2 in [Vector2(20, 60), Vector2(28, 58), Vector2(23, 66), Vector2(31, 64), Vector2(18, 70), Vector2(27, 70)]:
		_glow_eye(ci, p + Vector2(0, bob), 2.0, eye)


## A walking skeleton with a bone to throw.
static func _skeleton(ci: CanvasItem, body: Color, a: float) -> void:
	var rattle := sin(a) * 1.5
	var dim := body.darkened(0.2)
	_line(ci, Vector2(44, 76), Vector2(40, 98), dim, 5.0)
	_line(ci, Vector2(56, 76), Vector2(60, 98), dim, 5.0)
	_oval(ci, Vector2(37, 98), 6, 2.5, dim, false)
	_oval(ci, Vector2(57, 98), 6, 2.5, dim, false)
	_poly(ci, PackedVector2Array([Vector2(38, 70), Vector2(62, 70), Vector2(58, 80), Vector2(42, 80)]), body)
	_line(ci, Vector2(50, 38), Vector2(50, 72), dim, 4.0)
	for i in 3:
		_lines(ci, _arc(Vector2(50, 46 + i * 7), 15 - i * 2, 5, PI * 0.05, PI * 0.95, 10), body, 3.0)
	_lines(ci, PackedVector2Array([Vector2(36, 44), Vector2(28, 60), Vector2(30, 74)]), body, 4.0)
	_lines(ci, PackedVector2Array([Vector2(64, 44), Vector2(76, 34 + rattle), Vector2(82, 22 + rattle)]), body, 4.0)
	_line(ci, Vector2(76, 26 + rattle), Vector2(90, 16 + rattle), BONE, 5.0)
	_dot(ci, Vector2(76, 26 + rattle), 3.5, BONE)
	_dot(ci, Vector2(90, 16 + rattle), 3.5, BONE)
	_oval(ci, Vector2(46, 22 + rattle), 15, 15, body)
	_poly(ci, PackedVector2Array([Vector2(36, 32 + rattle), Vector2(54, 32 + rattle), Vector2(54, 42 + rattle), Vector2(38, 42 + rattle)]), body)
	for x in [40.0, 44.0, 48.0, 52.0]:
		_line(ci, Vector2(x, 34 + rattle), Vector2(x, 41 + rattle), dim, 1.0)
	_oval(ci, Vector2(39, 21 + rattle), 5, 5.5, DARK, false)
	_oval(ci, Vector2(51, 21 + rattle), 5, 5.5, DARK, false)
	_poly(ci, PackedVector2Array([Vector2(43, 30 + rattle), Vector2(45, 25 + rattle), Vector2(47, 30 + rattle)]), DARK, false)


## A banshee: a gaunt face half hidden by long hair, sunken eyes with a
## faint light in them, a crooked mouth hanging open, and a torn burial
## gown whose strips trail behind her as she reaches for the hero.
static func _ghost(ci: CanvasItem, body: Color, a: float) -> void:
	var y := -6.0
	var c := Color(body, 0.82)
	var hair := body.darkened(0.45)
	var pale := body.lightened(0.35)
	# A cold glow around her, fading out.
	for g in 3:
		_oval(ci, Vector2(52, 50 + y), 30 + g * 7.0, 36 + g * 7.0, Color(body, 0.06), false)
	# Hair streaming back off her head, each lock on its own wave.
	for k in 4:
		var root := Vector2(50 + k * 3.0, 18 + y + k * 4.0)
		var pts := PackedVector2Array([root])
		for n in range(1, 5):
			pts.append(root + Vector2(n * 11.0, n * 6.0 + sin(a + n * 0.9 + k) * (2.0 + n)))
		_lines(ci, pts, Color(hair, 0.85), 7.0 - k)
	# The gown: narrow at the shoulders, flaring into strips of different
	# lengths that drift back.
	var gown := PackedVector2Array([Vector2(36, 32 + y), Vector2(58, 30 + y), Vector2(70, 56 + y), Vector2(88, 80 + y)])
	var hem := [Vector2(90, 96), Vector2(80, 86), Vector2(74, 100), Vector2(64, 88), Vector2(56, 98), Vector2(46, 86),
		Vector2(38, 94), Vector2(30, 80)]
	for i in hem.size():
		var h: Vector2 = hem[i]
		gown.append(Vector2(h.x + sin(a + i) * 3.0 * float(i % 2 == 0), h.y + y))
	gown.append(Vector2(30, 60 + y))
	_poly(ci, gown, c)
	for x in [44.0, 54.0, 64.0]:
		_line(ci, Vector2(x, 40 + y), Vector2(x + 8, 82 + y), Color(body.darkened(0.25), 0.5), 1.5)
	# One arm reaching for the hero, long bare fingers spread.
	var hand := Vector2(10, 48 + y + sin(a) * 2.0)
	_lines(ci, PackedVector2Array([Vector2(38, 38 + y), Vector2(24, 46 + y), hand]), c, 4.5)
	for f in 4:
		_line(ci, hand, hand + Vector2(-7, -5 + f * 3.5), pale, 1.5)
	# The face: long and narrow, sunken under the brow, the jaw hanging
	# open and a little crooked.
	var jaw := sin(a) * 1.2
	_poly(ci, PackedVector2Array([Vector2(37, 12 + y), Vector2(45, 7 + y), Vector2(51, 12 + y), Vector2(50, 28 + y),
		Vector2(45, 40 + y + jaw), Vector2(40, 38 + y + jaw), Vector2(36, 24 + y)]), pale)
	_poly(ci, PackedVector2Array([Vector2(37, 17 + y), Vector2(42, 19 + y), Vector2(41, 22 + y), Vector2(37, 21 + y)]),
		Color(DARK, 0.9), false)
	_poly(ci, PackedVector2Array([Vector2(44, 19 + y), Vector2(49, 17 + y), Vector2(49, 21 + y), Vector2(45, 22 + y)]),
		Color(DARK, 0.9), false)
	_dot(ci, Vector2(39.5, 20 + y), 0.8, Color(pale.lightened(0.5), 0.8))
	_dot(ci, Vector2(46.5, 19.8 + y), 0.8, Color(pale.lightened(0.5), 0.8))
	_poly(ci, PackedVector2Array([Vector2(40, 28 + y), Vector2(44, 27 + y), Vector2(45, 37 + y + jaw), Vector2(41, 38 + y + jaw)]),
		DARK, false)
	# Hair hanging from the crown, down the back and over half her face.
	_poly(ci, PackedVector2Array([Vector2(36, 14 + y), Vector2(42, 5 + y), Vector2(52, 6 + y), Vector2(56, 14 + y),
		Vector2(58, 30 + y), Vector2(52, 24 + y), Vector2(50, 12 + y), Vector2(44, 10 + y)]), hair)
	for k in 3:
		var x := 37.0 + k * 2.5
		_lines(ci, PackedVector2Array([Vector2(x + 3, 9 + y), Vector2(x, 20 + y), Vector2(x - 1 + sin(a + k) * 1.5, 34 + y + k * 3.0)]),
			Color(hair, 0.9), 2.2)


## A hovering imp: horns, bat wings, a barbed tail and a fireball in hand.
static func _imp(ci: CanvasItem, body: Color, a: float) -> void:
	var y := -8.0
	var flap := sin(a) * 6.0
	var wing := body.darkened(0.45)
	_poly(ci, PackedVector2Array([Vector2(56, 46 + y), Vector2(84, 18 + y - flap), Vector2(98, 30 + y - flap * 0.5),
		Vector2(90, 40 + y), Vector2(94, 52 + y), Vector2(80, 50 + y), Vector2(70, 60 + y)]), wing)
	_lines(ci, PackedVector2Array([Vector2(62, 74 + y), Vector2(80, 86 + y), Vector2(92, 76 + y)]), body.darkened(0.2), 3.0)
	_poly(ci, PackedVector2Array([Vector2(88, 70 + y), Vector2(98, 72 + y), Vector2(92, 80 + y)]), body.darkened(0.2))
	_line(ci, Vector2(44, 78 + y), Vector2(42, 90 + y), body.darkened(0.15), 5.0)
	_line(ci, Vector2(56, 78 + y), Vector2(58, 90 + y), body.darkened(0.15), 5.0)
	_oval(ci, Vector2(50, 64 + y), 17, 16, body)
	_oval(ci, Vector2(48, 68 + y), 9, 8, body.lightened(0.2), false)
	_line(ci, Vector2(38, 58 + y), Vector2(24, 54 + y), body, 5.0)
	var f := sin(a + 1.0) * 1.5
	_dot(ci, Vector2(18, 50 + y), 9.0 + f, Color(1.0, 0.6, 0.24, 0.4))
	_dot(ci, Vector2(18, 50 + y), 6.0, Color("ff9a3c"))
	_dot(ci, Vector2(18, 50 + y), 3.0, Color("ffe07a"))
	var horn := Color("efe3c8")
	_poly(ci, PackedVector2Array([Vector2(32, 30 + y), Vector2(26, 12 + y), Vector2(40, 26 + y)]), horn)
	_poly(ci, PackedVector2Array([Vector2(50, 26 + y), Vector2(58, 10 + y), Vector2(58, 30 + y)]), horn)
	_oval(ci, Vector2(44, 38 + y), 15, 14, body)
	_poly(ci, PackedVector2Array([Vector2(32, 36 + y), Vector2(40, 38 + y), Vector2(34, 41 + y)]), Color("ffe07a"), false)
	_poly(ci, PackedVector2Array([Vector2(44, 38 + y), Vector2(52, 36 + y), Vector2(50, 41 + y)]), Color("ffe07a"), false)
	_lines(ci, PackedVector2Array([Vector2(34, 46 + y), Vector2(42, 49 + y), Vector2(50, 46 + y)]), DARK, 2.0)


## A hulking orc with an axe. The Warlord adds a horned helm, spiked
## pauldrons and a war banner.
static func _orc(ci: CanvasItem, body: Color, a: float, warlord: bool) -> void:
	var breathe := 0.0
	var pants := Color("4a3a2a")
	var dark := body.darkened(0.25)
	if warlord:
		_line(ci, Vector2(76, 4), Vector2(74, 70), WOOD, 3.0)
		var wave := sin(a) * 3.0
		_poly(ci, PackedVector2Array([Vector2(76, 4), Vector2(98, 6 + wave), Vector2(94, 16 + wave * 0.5), Vector2(99, 28 + wave),
			Vector2(76, 26)]), Color("8a6a2a"))
		_dot(ci, Vector2(87, 15 + wave * 0.6), 4.0, BONE)
	_poly(ci, PackedVector2Array([Vector2(32, 78), Vector2(48, 78), Vector2(46, 100), Vector2(30, 100)]), pants)
	_poly(ci, PackedVector2Array([Vector2(54, 78), Vector2(70, 78), Vector2(72, 100), Vector2(56, 100)]), pants)
	_poly(ci, PackedVector2Array([Vector2(18, 40 - breathe), Vector2(82, 40 - breathe), Vector2(74, 82), Vector2(28, 82)]), body)
	_poly(ci, PackedVector2Array([Vector2(26, 74), Vector2(76, 74), Vector2(75, 82), Vector2(27, 82)]), Color("5a4026"))
	_dot(ci, Vector2(50, 78), 4.0, GOLD if warlord else STEEL)
	_lines(ci, _arc(Vector2(50, 50), 16, 6, PI * 0.15, PI * 0.85, 8), dark, 2.0)
	_line(ci, Vector2(78, 46), Vector2(86, 72), body, 10.0)
	_line(ci, Vector2(22, 46), Vector2(12, 64), body, 10.0)
	# The axe, held up in front.
	var axe := Vector2(8, 70)
	_line(ci, axe, Vector2(6, 14), WOOD, 4.5)
	var blade := Color(STEEL, 1.0) if not warlord else STEEL.lightened(0.1)
	var top := Vector2(6, 22)
	var w := 16.0 if warlord else 12.0
	_poly(ci, PackedVector2Array([top + Vector2(0, -8), top + Vector2(-w * 0.4, -w), top + Vector2(-w * 0.9, 0),
		top + Vector2(-w * 0.4, w), top + Vector2(0, 8)]), blade)
	if warlord:
		_poly(ci, PackedVector2Array([top + Vector2(0, -8), top + Vector2(w * 0.4, -w), top + Vector2(w * 0.9, 0),
			top + Vector2(w * 0.4, w), top + Vector2(0, 8)]), blade)
	_dot(ci, Vector2(12, 64), 6.0, body)
	if warlord:
		for x in [22.0, 78.0]:
			_oval(ci, Vector2(x, 42), 12, 8, STEEL.darkened(0.3))
			for k in 3:
				var sx: float = x - 8 + k * 8
				_poly(ci, PackedVector2Array([Vector2(sx - 3, 36), Vector2(sx, 26), Vector2(sx + 3, 36)]), BONE)
	_poly(ci, PackedVector2Array([Vector2(36, 16), Vector2(62, 16), Vector2(64, 36), Vector2(60, 44), Vector2(36, 44), Vector2(32, 34)]), body)
	_poly(ci, PackedVector2Array([Vector2(36, 42), Vector2(38, 32), Vector2(41, 42)]), BONE, false)
	_poly(ci, PackedVector2Array([Vector2(50, 42), Vector2(52, 32), Vector2(55, 42)]), BONE, false)
	_dot(ci, Vector2(40, 26), 2.5, Color("f2e27a"))
	_dot(ci, Vector2(52, 26), 2.5, Color("f2e27a"))
	_line(ci, Vector2(35, 21), Vector2(44, 24), DARK, 3.0)
	_line(ci, Vector2(48, 24), Vector2(57, 21), DARK, 3.0)
	if warlord:
		_poly(ci, PackedVector2Array([Vector2(33, 22), Vector2(34, 10), Vector2(48, 6), Vector2(63, 10), Vector2(65, 22)]), STEEL.darkened(0.2))
		_poly(ci, PackedVector2Array([Vector2(34, 14), Vector2(18, 10), Vector2(10, 0), Vector2(26, 6), Vector2(36, 8)]), BONE)
		_poly(ci, PackedVector2Array([Vector2(62, 8), Vector2(74, 4), Vector2(86, -6), Vector2(78, 8), Vector2(64, 14)]), BONE)
	else:
		_poly(ci, PackedVector2Array([Vector2(36, 18), Vector2(48, 10), Vector2(62, 18)]), DARK)


## A hooded cultist conjuring a bolt.
static func _cultist(ci: CanvasItem, body: Color, a: float) -> void:
	var glow := 0.5 + 0.5 * sin(a)
	var magic := Color("c58cff")
	_poly(ci, PackedVector2Array([Vector2(32, 34), Vector2(68, 34), Vector2(82, 100), Vector2(18, 100)]), body)
	_poly(ci, PackedVector2Array([Vector2(20, 92), Vector2(80, 92), Vector2(82, 100), Vector2(18, 100)]), body.darkened(0.3), false)
	_line(ci, Vector2(28, 64), Vector2(72, 64), GOLD.darkened(0.2), 3.0)
	_line(ci, Vector2(40, 64), Vector2(38, 80), GOLD.darkened(0.2), 2.0)
	for x in [42.0, 58.0]:
		_line(ci, Vector2(x, 66), Vector2(x - 4, 92), body.darkened(0.2), 1.5)
	_poly(ci, PackedVector2Array([Vector2(28, 44), Vector2(36, 40), Vector2(22, 62), Vector2(12, 60)]), body.darkened(0.1))
	_dot(ci, Vector2(10, 58), 4.0, BONE.darkened(0.2))
	_dot(ci, Vector2(8, 52), 8.0 + glow * 4.0, Color(magic, 0.3))
	_dot(ci, Vector2(8, 52), 4.0 + glow, Color("e8d4ff"))
	_poly(ci, PackedVector2Array([Vector2(28, 42), Vector2(30, 18), Vector2(48, 4), Vector2(66, 16), Vector2(72, 42)]), body)
	_oval(ci, Vector2(44, 28), 11, 13, DARK, false)
	_glow_eye(ci, Vector2(39, 27), 2.2, magic.lerp(Color.WHITE, glow * 0.5))
	_glow_eye(ci, Vector2(48, 27), 2.2, magic.lerp(Color.WHITE, glow * 0.5))


## The Jeweller of the Threshold: a blind dwarf in a leather apron, his eyes
## shut, a cut stone held up in one hand to feel its weight (a room's
## character, see RoomDefs; he is no foe).
static func _jeweller(ci: CanvasItem, body: Color, a: float) -> void:
	var skin := Color("d9b38c")
	var beard := Color("b8a58a")
	var gem := Color("7fd8ff")
	var glint := 0.5 + 0.5 * sin(a)
	_poly(ci, PackedVector2Array([Vector2(30, 50), Vector2(70, 50), Vector2(78, 100), Vector2(22, 100)]), body)
	_poly(ci, PackedVector2Array([Vector2(36, 58), Vector2(64, 58), Vector2(68, 100), Vector2(32, 100)]), Color("6b4a32"))
	_line(ci, Vector2(36, 58), Vector2(64, 58), GOLD.darkened(0.2), 3.0)
	_poly(ci, PackedVector2Array([Vector2(30, 52), Vector2(24, 62), Vector2(16, 58), Vector2(24, 46)]), body.darkened(0.1))
	_dot(ci, Vector2(18, 54), 5.0, skin)
	_poly(ci, PackedVector2Array([Vector2(18, 44), Vector2(22, 38), Vector2(26, 44), Vector2(22, 50)]), gem)
	_dot(ci, Vector2(22, 41), 1.5 + glint, Color(1, 1, 1, 0.8))
	_oval(ci, Vector2(50, 34), 14, 15, skin)
	_poly(ci, PackedVector2Array([Vector2(35, 36), Vector2(65, 36), Vector2(60, 66), Vector2(50, 80), Vector2(40, 66)]), beard)
	_poly(ci, PackedVector2Array([Vector2(34, 28), Vector2(50, 6), Vector2(66, 28), Vector2(60, 24), Vector2(40, 24)]),
		body.darkened(0.2))
	for x in [43.0, 57.0]:
		_line(ci, Vector2(x - 3, 31), Vector2(x + 3, 31), DARK, 2.0)
	_dot(ci, Vector2(50, 39), 2.5, skin.darkened(0.15))


## A knot of bats, each on its own wingbeat.
static func _bats(ci: CanvasItem, body: Color, a: float) -> void:
	var spots := [Vector3(30, 36, 0.0), Vector3(66, 22, 1.7), Vector3(72, 60, 3.1), Vector3(36, 72, 4.4)]
	for s: Vector3 in spots:
		var c := Vector2(s.x + sin(a + s.z) * 4.0, s.y + cos(a + s.z) * 4.0)
		var flap := sin(a + s.z) * 10.0
		for d in [-1.0, 1.0]:
			_poly(ci, PackedVector2Array([c + Vector2(d * 4, -3), c + Vector2(d * 24, -4 - flap), c + Vector2(d * 16, 4 - flap * 0.3),
				c + Vector2(d * 5, 5)]), body.lightened(0.1))
		_oval(ci, c, 6, 8, body)
		_poly(ci, PackedVector2Array([c + Vector2(-5, -6), c + Vector2(-4, -13), c + Vector2(-1, -7)]), body, false)
		_poly(ci, PackedVector2Array([c + Vector2(1, -7), c + Vector2(4, -13), c + Vector2(5, -6)]), body, false)
		_dot(ci, c + Vector2(-3, -2), 1.6, Color("f2e27a"))
		_dot(ci, c + Vector2(1.5, -2), 1.6, Color("f2e27a"))


## A kobold in a miner's helmet with a lamp, pickaxe on the shoulder.
static func _kobold(ci: CanvasItem, body: Color, a: float) -> void:
	var bob := 0.0
	var lamp := 0.5 + 0.5 * sin(a)
	_poly(ci, PackedVector2Array([Vector2(60, 76), Vector2(98, 94), Vector2(96, 98), Vector2(58, 90)]), body.darkened(0.1))
	_lines(ci, PackedVector2Array([Vector2(42, 80), Vector2(36, 90), Vector2(40, 99)]), body.darkened(0.15), 6.0)
	_lines(ci, PackedVector2Array([Vector2(56, 80), Vector2(52, 90), Vector2(58, 99)]), body.darkened(0.15), 6.0)
	_poly(ci, PackedVector2Array([Vector2(36, 52 + bob), Vector2(62, 52 + bob), Vector2(64, 84), Vector2(36, 84)]), body)
	_poly(ci, PackedVector2Array([Vector2(36, 70), Vector2(64, 70), Vector2(64, 78), Vector2(36, 78)]), Color("5a4026"), false)
	_line(ci, Vector2(64, 66 + bob), Vector2(82, 22 + bob), WOOD, 4.0)
	_poly(ci, PackedVector2Array([Vector2(66, 14 + bob), Vector2(82, 18 + bob), Vector2(98, 30 + bob), Vector2(84, 24 + bob), Vector2(70, 22 + bob)]), STEEL)
	_line(ci, Vector2(60, 58 + bob), Vector2(68, 64 + bob), body, 6.0)
	_line(ci, Vector2(38, 58 + bob), Vector2(28, 70 + bob), body, 6.0)
	_poly(ci, PackedVector2Array([Vector2(12, 44 + bob), Vector2(26, 34 + bob), Vector2(50, 30 + bob), Vector2(60, 40 + bob),
		Vector2(56, 54 + bob), Vector2(30, 54 + bob), Vector2(12, 50 + bob)]), body)
	_line(ci, Vector2(14, 49 + bob), Vector2(28, 50 + bob), DARK, 1.5)
	_dot(ci, Vector2(15, 45 + bob), 1.5, DARK)
	_dot(ci, Vector2(36, 41 + bob), 3.5, Color("f2e27a"))
	_line(ci, Vector2(36, 38.5 + bob), Vector2(36, 43.5 + bob), DARK, 1.5)
	# Hard hat with its lamp.
	_poly(ci, _arc(Vector2(46, 34 + bob), 16, 12, PI, TAU, 12), Color("d9a72a"))
	_line(ci, Vector2(26, 34 + bob), Vector2(64, 34 + bob), Color("b8862b"), 3.0)
	_dot(ci, Vector2(30, 28 + bob), 10.0 + lamp * 4.0, Color(1.0, 0.95, 0.6, 0.18))
	_dot(ci, Vector2(30, 28 + bob), 4.0, Color("fff2a8"))


## A many-legged cave crawler with feelers round its mouth.
static func _crawler(ci: CanvasItem, body: Color, a: float) -> void:
	var segs := [Vector3(86, 76, 14), Vector3(72, 70, 17), Vector3(56, 64, 19), Vector3(40, 58, 19)]
	for i in segs.size():
		var s: Vector3 = segs[i]
		var step := sin(a + i * 1.3) * 3.0
		for d in [-5.0, 5.0]:
			_lines(ci, PackedVector2Array([Vector2(s.x + d, s.y + s.z * 0.5), Vector2(s.x + d - 4 + step, s.y + s.z + 6),
				Vector2(s.x + d - 6 + step, 99)]), body.darkened(0.35), 2.5)
	for i in segs.size():
		var s: Vector3 = segs[i]
		_oval(ci, Vector2(s.x, s.y), s.z, s.z * 0.85, body.darkened(0.05 * (segs.size() - i)))
		_lines(ci, _arc(Vector2(s.x - 4, s.y), s.z * 0.7, s.z * 0.75, -PI * 0.4, PI * 0.4, 8), body.lightened(0.15), 2.0)
	var head := Vector2(24, 52)
	for i in 4:
		var dir := PI * (0.55 + i * 0.12)
		var wig := sin(a + i) * 0.15
		var mid := head + Vector2.from_angle(dir + wig) * 16.0
		_lines(ci, PackedVector2Array([head + Vector2(-6, 6), mid, mid + Vector2.from_angle(dir + wig * 2.0 + 0.3) * 14.0]),
			Color("c9d6a8"), 2.5)
	_oval(ci, head, 16, 14, body.lightened(0.05))
	_poly(ci, PackedVector2Array([Vector2(12, 46), Vector2(22, 38), Vector2(36, 40), Vector2(30, 48)]), body.darkened(0.15), false)
	_glow_eye(ci, Vector2(16, 48), 2.2, Color("c8f27a"))
	_glow_eye(ci, Vector2(24, 46), 2.0, Color("c8f27a"))


## A glowing mushroom with a face on its stalk.
static func _glowcap(ci: CanvasItem, body: Color, a: float) -> void:
	var pulse := 0.5 + 0.5 * sin(a)
	var stalk := Color("e8e2cc")
	_dot(ci, Vector2(50, 36), 54.0, Color(body, 0.08 + 0.06 * pulse))
	_poly(ci, PackedVector2Array([Vector2(36, 44), Vector2(64, 44), Vector2(68, 96), Vector2(72, 100), Vector2(28, 100), Vector2(32, 96)]), stalk)
	_line(ci, Vector2(34, 66), Vector2(22, 74), stalk, 5.0)
	_line(ci, Vector2(66, 66), Vector2(78, 74), stalk, 5.0)
	_eye(ci, Vector2(40, 62), 4.0)
	_eye(ci, Vector2(53, 62), 4.0)
	_lines(ci, _arc(Vector2(46, 72), 5, 3, 0.2, PI - 0.2, 8), DARK, 2.0)
	var cap := _arc(Vector2(50, 46), 46, 40, PI, TAU, 20)
	cap.append(Vector2(90, 50))
	cap.append(Vector2(10, 50))
	_poly(ci, cap, body)
	for x in range(16, 86, 7):
		_line(ci, Vector2(x, 47), Vector2(50 + (x - 50) * 0.6, 52), body.darkened(0.3), 1.5)
	for c: Vector3 in [Vector3(30, 26, 6), Vector3(54, 14, 7), Vector3(72, 30, 5), Vector3(44, 36, 4)]:
		_dot(ci, Vector2(c.x, c.y), c.z + 3.0 * pulse, Color(1, 1, 1, 0.2))
		_dot(ci, Vector2(c.x, c.y), c.z, body.lightened(0.55))


## A heap of stone held together by a glowing core.
static func _stone(ci: CanvasItem, body: Color, a: float) -> void:
	var hover := sin(a) * 3.0
	var core := Color("ffc94a")
	var heat := 0.6 + 0.4 * sin(a)
	for x in [32.0, 54.0]:
		_poly(ci, PackedVector2Array([Vector2(x, 80), Vector2(x + 16, 78), Vector2(x + 18, 100), Vector2(x - 2, 100)]), body.darkened(0.15))
	_poly(ci, PackedVector2Array([Vector2(24, 40), Vector2(40, 30), Vector2(66, 30), Vector2(80, 44), Vector2(76, 76),
		Vector2(56, 84), Vector2(30, 80), Vector2(20, 62)]), body)
	_poly(ci, PackedVector2Array([Vector2(66, 30), Vector2(80, 44), Vector2(76, 76), Vector2(64, 58)]), body.darkened(0.15), false)
	_lines(ci, PackedVector2Array([Vector2(36, 46), Vector2(46, 56), Vector2(42, 66), Vector2(52, 74)]), Color(core, heat), 3.0)
	_lines(ci, PackedVector2Array([Vector2(46, 56), Vector2(58, 52)]), Color(core, heat), 2.0)
	_poly(ci, PackedVector2Array([Vector2(36, 12), Vector2(56, 8), Vector2(66, 20), Vector2(60, 32), Vector2(38, 32)]), body.lightened(0.08))
	_poly(ci, PackedVector2Array([Vector2(37, 19), Vector2(46, 21), Vector2(38, 23)]), Color(core, heat), false)
	_poly(ci, PackedVector2Array([Vector2(50, 21), Vector2(58, 19), Vector2(57, 23)]), Color(core, heat), false)
	_poly(ci, PackedVector2Array([Vector2(4, 50 + hover), Vector2(14, 40 + hover), Vector2(26, 46 + hover), Vector2(22, 62 + hover), Vector2(8, 62 + hover)]), body.lightened(0.04))
	_poly(ci, PackedVector2Array([Vector2(80, 50 - hover), Vector2(94, 46 - hover), Vector2(98, 62 - hover), Vector2(84, 68 - hover)]), body.darkened(0.08))


## A fat ogre king: crown, underbite and a club over his shoulder.
static func _ogre(ci: CanvasItem, body: Color, a: float) -> void:
	var breathe := 0.0
	for x in [36.0, 62.0]:
		_poly(ci, PackedVector2Array([Vector2(x - 9, 82), Vector2(x + 9, 82), Vector2(x + 10, 100), Vector2(x - 11, 100)]), body.darkened(0.15))
	_oval(ci, Vector2(52, 62), 36 + breathe, 30 + breathe * 0.5, body)
	_oval(ci, Vector2(50, 68), 22, 18, body.lightened(0.12), false)
	_poly(ci, PackedVector2Array([Vector2(22, 78), Vector2(82, 78), Vector2(76, 96), Vector2(54, 90), Vector2(28, 96)]), Color("6b4a2a"))
	_line(ci, Vector2(84, 54), Vector2(92, 80), body, 13.0)
	# The club: up over the shoulder, its knotted head behind.
	_line(ci, Vector2(22, 60), Vector2(30, 10), WOOD, 7.0)
	_oval(ci, Vector2(32, 10), 10, 13, WOOD.lightened(0.05))
	for p: Vector2 in [Vector2(26, 4), Vector2(38, 8), Vector2(30, 18)]:
		_dot(ci, p, 2.0, BONE)
	_line(ci, Vector2(24, 50), Vector2(20, 62), body, 13.0)
	_oval(ci, Vector2(42, 32), 15, 14, body)
	_poly(ci, PackedVector2Array([Vector2(28, 36), Vector2(52, 36), Vector2(50, 44), Vector2(30, 44)]), body.darkened(0.08))
	_poly(ci, PackedVector2Array([Vector2(32, 38), Vector2(34, 30), Vector2(37, 38)]), BONE, false)
	_poly(ci, PackedVector2Array([Vector2(44, 38), Vector2(46, 31), Vector2(49, 38)]), BONE, false)
	_dot(ci, Vector2(34, 26), 2.5, DARK)
	_dot(ci, Vector2(45, 26), 2.5, DARK)
	_oval(ci, Vector2(30, 31), 4, 3, body.darkened(0.15), false)
	_poly(ci, PackedVector2Array([Vector2(30, 20), Vector2(30, 8), Vector2(36, 14), Vector2(42, 4), Vector2(48, 14), Vector2(54, 8), Vector2(54, 20)]), GOLD)
	_dot(ci, Vector2(42, 15), 2.5, Color("4fd0e0"))


## The lich: a floating robed skeleton with a crown and a cursed orb.
static func _lich(ci: CanvasItem, body: Color, a: float) -> void:
	var y := -4.0
	var curse := Color("8ff27a")
	var pulse := 0.5 + 0.5 * sin(a)
	_line(ci, Vector2(14, 90 + y), Vector2(18, 20 + y), WOOD.darkened(0.3), 3.5)
	_dot(ci, Vector2(18, 16 + y), 11.0 + pulse * 3.0, Color(curse, 0.25))
	_dot(ci, Vector2(18, 16 + y), 6.0, curse.lerp(Color.WHITE, 0.3 * pulse))
	var robe := PackedVector2Array([Vector2(36, 30 + y), Vector2(66, 30 + y), Vector2(80, 90 + y)])
	for i in 6:
		robe.append(Vector2(80 - i * 10, 90 + y + (7.0 if i % 2 == 0 else 0.0) + sin(a + i) * 2.0))
	robe.append(Vector2(22, 90 + y))
	_poly(ci, robe, body)
	_line(ci, Vector2(50, 36 + y), Vector2(50, 86 + y), body.darkened(0.3), 3.0)
	_lines(ci, PackedVector2Array([Vector2(36, 40 + y), Vector2(24, 50 + y), Vector2(20, 54 + y)]), body.darkened(0.1), 8.0)
	_lines(ci, PackedVector2Array([Vector2(20, 54 + y), Vector2(16, 54 + y)]), BONE, 4.0)
	_poly(ci, PackedVector2Array([Vector2(32, 34 + y), Vector2(34, 10 + y), Vector2(50, 0 + y), Vector2(66, 10 + y), Vector2(70, 34 + y)]), body.darkened(0.2))
	_oval(ci, Vector2(48, 22 + y), 11, 12, BONE)
	_oval(ci, Vector2(43, 21 + y), 3.5, 4, DARK, false)
	_oval(ci, Vector2(52, 21 + y), 3.5, 4, DARK, false)
	_dot(ci, Vector2(43, 21 + y), 1.6, curse)
	_dot(ci, Vector2(52, 21 + y), 1.6, curse)
	_poly(ci, PackedVector2Array([Vector2(42, 30 + y), Vector2(54, 30 + y), Vector2(53, 34 + y), Vector2(43, 34 + y)]), BONE.darkened(0.15), false)
	_poly(ci, PackedVector2Array([Vector2(37, 12 + y), Vector2(38, 2 + y), Vector2(43, 7 + y), Vector2(48, -2 + y), Vector2(53, 7 + y),
		Vector2(58, 2 + y), Vector2(59, 12 + y)]), GOLD)


## A golem of crystal shards, lit from inside.
static func _golem(ci: CanvasItem, body: Color, a: float) -> void:
	var shine := 0.5 + 0.5 * sin(a)
	var lit := body.lightened(0.35)
	var deep := body.darkened(0.3)
	for x in [34.0, 58.0]:
		_poly(ci, PackedVector2Array([Vector2(x, 74), Vector2(x + 14, 74), Vector2(x + 12, 100), Vector2(x - 2, 100)]), deep)
	var chest := Vector2(50, 50)
	var ring := [Vector2(26, 34), Vector2(50, 22), Vector2(76, 34), Vector2(78, 64), Vector2(54, 80), Vector2(24, 66)]
	for i in ring.size():
		var c := lit if i < 2 else (body if i < 4 else deep)
		_poly(ci, PackedVector2Array([chest, ring[i], ring[(i + 1) % ring.size()]]), c)
	_dot(ci, chest, 8.0 + shine * 4.0, Color(1, 1, 1, 0.3))
	_dot(ci, chest, 4.0, Color.WHITE)
	for p: Array in [[Vector2(28, 34), Vector2(22, 12), Vector2(36, 30)], [Vector2(68, 30), Vector2(80, 8), Vector2(78, 34)]]:
		_poly(ci, PackedVector2Array(p), lit)
	_poly(ci, PackedVector2Array([Vector2(26, 40), Vector2(8, 52), Vector2(2, 76), Vector2(14, 72), Vector2(24, 56)]), body)
	_poly(ci, PackedVector2Array([Vector2(76, 40), Vector2(94, 50), Vector2(98, 74), Vector2(86, 70), Vector2(78, 56)]), deep)
	_poly(ci, PackedVector2Array([Vector2(36, 18), Vector2(48, 4), Vector2(62, 16), Vector2(58, 28), Vector2(40, 28)]), lit)
	_poly(ci, PackedVector2Array([Vector2(48, 4), Vector2(62, 16), Vector2(58, 28), Vector2(50, 18)]), body, false)
	_glow_eye(ci, Vector2(42, 18), 2.2, Color(1, 1, 1, 0.7 + 0.3 * shine))
	_glow_eye(ci, Vector2(51, 18), 2.2, Color(1, 1, 1, 0.7 + 0.3 * shine))


## A tall myconid with a frilled cap, a root staff and a sprout at her feet.
static func _matriarch(ci: CanvasItem, body: Color, a: float) -> void:
	var sway := 0.0
	var stalk := Color("e2d8c4")
	_line(ci, Vector2(14, 98), Vector2(18, 30), WOOD, 4.0)
	_lines(ci, PackedVector2Array([Vector2(18, 30), Vector2(12, 22), Vector2(14, 14)]), WOOD, 3.0)
	_lines(ci, PackedVector2Array([Vector2(18, 30), Vector2(24, 20)]), WOOD, 2.5)
	_poly(ci, PackedVector2Array([Vector2(36, 40), Vector2(64, 40), Vector2(72, 92), Vector2(78, 100), Vector2(22, 100), Vector2(28, 92)]), stalk)
	_poly(ci, PackedVector2Array([Vector2(36, 54), Vector2(64, 54), Vector2(68, 60), Vector2(32, 60)]), body.darkened(0.2), false)
	_line(ci, Vector2(36, 62), Vector2(18, 56), stalk, 5.0)
	_line(ci, Vector2(64, 62), Vector2(76, 76), stalk, 5.0)
	_glow_eye(ci, Vector2(42, 70), 2.0, Color("f2e27a"))
	_glow_eye(ci, Vector2(53, 70), 2.0, Color("f2e27a"))
	var cap := PackedVector2Array()
	for i in 13:
		var ang := lerpf(PI, TAU, i / 12.0)
		cap.append(Vector2(50 + sway + cos(ang) * 44, 40 + sin(ang) * 34))
	for i in 9:
		var x := 94.0 - i * 88.0 / 8.0
		cap.append(Vector2(x + sway, 40 + (8.0 if i % 2 == 1 else 2.0)))
	_poly(ci, cap, body)
	for c: Vector3 in [Vector3(28, 24, 5), Vector3(50, 12, 6), Vector3(70, 22, 5), Vector3(40, 32, 3.5), Vector3(62, 34, 3.5)]:
		_dot(ci, Vector2(c.x + sway, c.y), c.z, body.lightened(0.55))
	# A child sprout beside her.
	_poly(ci, PackedVector2Array([Vector2(84, 88), Vector2(92, 88), Vector2(93, 100), Vector2(83, 100)]), stalk)
	_poly(ci, _arc(Vector2(88, 88), 10, 9, PI, TAU, 10), body)
	_dot(ci, Vector2(86, 93), 1.2, DARK)
	_dot(ci, Vector2(90, 93), 1.2, DARK)


## Old Mossback, the forest troll: hunched under a mossy back with a sapling
## growing from it, dragging a log.
static func _troll(ci: CanvasItem, body: Color, a: float) -> void:
	var breathe := 0.0
	var moss := Color("7fae4a")
	var skin := body.lightened(0.1)
	# The log, trailing behind on the floor.
	_poly(ci, PackedVector2Array([Vector2(66, 86), Vector2(100, 78), Vector2(100, 92), Vector2(70, 98)]), WOOD)
	_oval(ci, Vector2(100, 85), 4, 7, WOOD.lightened(0.25))
	for x in [40.0, 64.0]:
		_poly(ci, PackedVector2Array([Vector2(x - 10, 70), Vector2(x + 10, 70), Vector2(x + 12, 100), Vector2(x - 12, 100)]), body.darkened(0.15))
	_poly(ci, PackedVector2Array([Vector2(18, 50), Vector2(30, 26 - breathe), Vector2(56, 14 - breathe), Vector2(82, 24 - breathe),
		Vector2(92, 50), Vector2(84, 76), Vector2(26, 78)]), body)
	_line(ci, Vector2(82, 44), Vector2(76, 82), body, 12.0)
	_dot(ci, Vector2(76, 84), 7.0, skin)
	# Moss, ferns and the sapling on his back.
	var back := PackedVector2Array([Vector2(30, 26 - breathe), Vector2(56, 14 - breathe), Vector2(82, 24 - breathe), Vector2(90, 40),
		Vector2(74, 34), Vector2(58, 30), Vector2(40, 34)])
	_poly(ci, back, moss, false)
	for p: Vector2 in [Vector2(44, 26), Vector2(70, 22), Vector2(84, 34)]:
		for k in 3:
			_line(ci, p + Vector2(0, -breathe), p + Vector2(0, -breathe) + Vector2.from_angle(-PI * 0.5 + (k - 1) * 0.5) * 8.0, moss.lightened(0.2), 2.0)
	var sway := 0.0
	_line(ci, Vector2(60, 16 - breathe), Vector2(62 + sway, 0), WOOD, 2.5)
	_dot(ci, Vector2(58 + sway, 2), 5.0, moss.lightened(0.1))
	_dot(ci, Vector2(66 + sway, -1), 5.0, moss)
	# The long arm reaching forward, then the head, slung low.
	_lines(ci, PackedVector2Array([Vector2(28, 40), Vector2(14, 64), Vector2(12, 90)]), body, 12.0)
	_dot(ci, Vector2(12, 92), 7.0, skin)
	_poly(ci, PackedVector2Array([Vector2(8, 40), Vector2(14, 28), Vector2(32, 24), Vector2(40, 34), Vector2(36, 52), Vector2(14, 54)]), skin)
	_poly(ci, PackedVector2Array([Vector2(26, 28), Vector2(42, 16), Vector2(36, 30)]), skin)
	_poly(ci, PackedVector2Array([Vector2(4, 40), Vector2(14, 36), Vector2(12, 46)]), skin.darkened(0.08))
	_poly(ci, PackedVector2Array([Vector2(12, 48), Vector2(14, 40), Vector2(17, 48)]), BONE, false)
	_poly(ci, PackedVector2Array([Vector2(24, 48), Vector2(26, 40), Vector2(29, 48)]), BONE, false)
	_glow_eye(ci, Vector2(18, 34), 2.0, Color("f2e27a"))
	_glow_eye(ci, Vector2(28, 33), 2.0, Color("f2e27a"))
	_line(ci, Vector2(14, 30), Vector2(31, 29), body.darkened(0.3), 2.5)


## The Warden: a jailer in plate with a ring of keys and a ball on a chain.
static func _warden(ci: CanvasItem, body: Color, a: float) -> void:
	var swing := sin(a) * 0.25
	var plate := body.lightened(0.15)
	var cloth := Color("2a2d3a")
	var eye := Color("bfe6ff")
	for x in [38.0, 62.0]:
		_poly(ci, PackedVector2Array([Vector2(x - 10, 76), Vector2(x + 10, 76), Vector2(x + 12, 100), Vector2(x - 12, 100)]), body)
	_poly(ci, PackedVector2Array([Vector2(22, 30), Vector2(78, 30), Vector2(74, 80), Vector2(26, 80)]), plate)
	_poly(ci, PackedVector2Array([Vector2(38, 44), Vector2(62, 44), Vector2(60, 96), Vector2(40, 96)]), cloth)
	_line(ci, Vector2(26, 64), Vector2(74, 64), Color("4a3a2a"), 5.0)
	# The key ring at his belt.
	_dot(ci, Vector2(66, 72), 6.0, Color(GOLD, 0.0))
	_lines(ci, _arc(Vector2(66, 72), 6, 6, 0.0, TAU, 12), GOLD.darkened(0.2), 2.0)
	for k in 3:
		var d := Vector2.from_angle(PI * 0.3 + k * 0.4)
		_line(ci, Vector2(66, 72) + d * 6.0, Vector2(66, 72) + d * 14.0, GOLD, 2.5)
	for x in [22.0, 78.0]:
		_oval(ci, Vector2(x, 32), 14, 10, plate.lightened(0.1))
	_line(ci, Vector2(80, 38), Vector2(86, 66), plate, 11.0)
	_dot(ci, Vector2(86, 68), 6.0, body.darkened(0.2))
	# The arm forward, the chain, and the iron ball swinging under it.
	_lines(ci, PackedVector2Array([Vector2(22, 38), Vector2(14, 54), Vector2(18, 64)]), plate, 11.0)
	var hand := Vector2(18, 66)
	var ball := hand + Vector2.from_angle(PI * 0.5 + swing) * 26.0
	for i in 6:
		_lines(ci, _arc(hand.lerp(ball, (i + 0.5) / 6.0), 2.2, 2.2, 0.0, TAU, 6), STEEL.darkened(0.2), 1.5)
	_dot(ci, hand, 6.0, body.darkened(0.2))
	_oval(ci, ball, 10, 10, Color("3a3d47"))
	for k in 4:
		var d := Vector2.from_angle(k * PI * 0.5 + 0.4)
		_poly(ci, PackedVector2Array([ball + d * 9.0 + d.orthogonal() * 3.0, ball + d * 15.0, ball + d * 9.0 - d.orthogonal() * 3.0]), STEEL.darkened(0.2), false)
	_poly(ci, PackedVector2Array([Vector2(34, 30), Vector2(34, 10), Vector2(50, 2), Vector2(66, 10), Vector2(66, 30), Vector2(50, 36)]), plate.lightened(0.05))
	_poly(ci, PackedVector2Array([Vector2(36, 15), Vector2(60, 15), Vector2(60, 19), Vector2(36, 19)]), DARK, false)
	_poly(ci, PackedVector2Array([Vector2(44, 15), Vector2(48, 15), Vector2(48, 30), Vector2(44, 30)]), DARK, false)
	_glow_eye(ci, Vector2(40, 17), 1.6, eye)
	_glow_eye(ci, Vector2(53, 17), 1.6, eye)
	_line(ci, Vector2(50, 2), Vector2(50, 10), plate.lightened(0.2), 2.0)


## The Deep Wyrm: a serpent risen from a hole in the floor, jaws open.
static func _wyrm(ci: CanvasItem, body: Color, a: float) -> void:
	var sway := 0.0
	var belly := body.lightened(0.35)
	var fin := Color("6ad0c0")
	_oval(ci, Vector2(72, 98), 26, 5, Color("1a1410"), false)
	# The neck as a chain of circles up an S from the hole to the head.
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		var x := lerpf(74.0, 34.0, k) + sin(k * PI * 1.6) * 16.0 + sway * k
		var y := lerpf(98.0, 34.0, k)
		pts.append(Vector2(x, y))
	for i in range(pts.size() - 1, -1, -1):
		var r := lerpf(17.0, 12.0, i / 12.0)
		_dot(ci, pts[i], r + 1.5, OUTLINE)
		_dot(ci, pts[i], r, body)
		_dot(ci, pts[i] + Vector2(-r * 0.45, 0), r * 0.5, belly)
	for i in range(2, 12, 2):
		var p := pts[i]
		_poly(ci, PackedVector2Array([p + Vector2(6, -6), p + Vector2(18, -10), p + Vector2(10, 2)]), fin)
	var h := pts[12] + Vector2(-4, -6)
	_poly(ci, PackedVector2Array([h + Vector2(14, -14), h + Vector2(30, -26), h + Vector2(22, -8)]), fin)
	_poly(ci, PackedVector2Array([h + Vector2(4, -16), h + Vector2(12, -32), h + Vector2(16, -12)]), fin)
	var jaw := 0.5 + 0.5 * sin(a)
	_poly(ci, PackedVector2Array([h + Vector2(14, 4), h + Vector2(-30, 10 + jaw * 6.0), h + Vector2(-28, 14 + jaw * 6.0), h + Vector2(10, 14)]), body.darkened(0.15))
	_poly(ci, PackedVector2Array([h + Vector2(18, -10), h + Vector2(0, -16), h + Vector2(-32, -2), h + Vector2(-30, 4), h + Vector2(16, 6)]), body)
	for k in 4:
		var x := -26.0 + k * 8.0
		_poly(ci, PackedVector2Array([h + Vector2(x, 3), h + Vector2(x + 2, 9), h + Vector2(x + 4, 3)]), BONE, false)
	_glow_eye(ci, h + Vector2(-8, -8), 2.6, Color("bff2e8"))
	_dot(ci, h + Vector2(-28, -2), 1.5, DARK)


# The Drowned Temple.

## A tentacle from `root` curling toward `tip`, `width` thick at the root and
## thin at the tip, with suckers along its underside. `a` sways it.
static func _tentacle(ci: CanvasItem, root: Vector2, tip: Vector2, width: float, col: Color, a: float, curl := 1.0) -> void:
	var pts := PackedVector2Array()
	var across := (tip - root).normalized().orthogonal()
	for i in 9:
		var u := i / 8.0
		pts.append(root.lerp(tip, u) + across * sin(u * PI * 1.4 + a) * width * 1.2 * u * curl)
	for i in 8:
		var w := lerpf(width, width * 0.2, i / 8.0)
		_line(ci, pts[i], pts[i + 1], OUTLINE, w + 2.0)
	for i in 8:
		_line(ci, pts[i], pts[i + 1], col, lerpf(width, width * 0.2, i / 8.0))
	for i in range(1, 8, 2):
		_dot(ci, pts[i] - across * lerpf(width, width * 0.2, i / 8.0) * 0.3, lerpf(width, width * 0.2, i / 8.0) * 0.22,
			col.lightened(0.4))


## A bulging eye with a green iris and a slit pupil, looking left at the
## hero. Shut while `blink` is true.
static func _elder_eye(ci: CanvasItem, c: Vector2, r: float, blink := false) -> void:
	if blink:
		_line(ci, c - Vector2(r, 0), c + Vector2(r, 0), DARK, maxf(r * 0.35, 1.2))
		return
	_dot(ci, c, r, BONE)
	var iris := c + Vector2(-r * 0.3, 0)
	_dot(ci, iris, r * 0.55, ELDER_GREEN)
	_line(ci, iris - Vector2(0, r * 0.45), iris + Vector2(0, r * 0.45), DARK, maxf(r * 0.22, 1.0))


## A Deep One: a hunched fish-man with a finned back, a wide mouth full of
## needles, a bulging eye and long webbed claws.
static func _deep_one(ci: CanvasItem, body: Color, a: float) -> void:
	var belly := body.lightened(0.3)
	var fin := body.darkened(0.3)
	var gape := 0.5 + 0.5 * sin(a)
	_lines(ci, PackedVector2Array([Vector2(70, 70), Vector2(80, 84), Vector2(72, 97)]), body.darkened(0.2), 7.0)
	_poly(ci, PackedVector2Array([Vector2(62, 100), Vector2(72, 94), Vector2(82, 100)]), fin)
	for k in 5:
		var p := Vector2(56 + k * 6.0, 28 + k * 8.0)
		_poly(ci, PackedVector2Array([p, p + Vector2(12, -6), p + Vector2(5, 7)]), fin)
	_poly(ci, PackedVector2Array([Vector2(30, 40), Vector2(44, 24), Vector2(64, 26), Vector2(80, 48), Vector2(82, 70),
		Vector2(66, 78), Vector2(44, 76), Vector2(34, 62)]), body)
	_oval(ci, Vector2(48, 60), 11, 13, belly, false)
	_lines(ci, PackedVector2Array([Vector2(52, 70), Vector2(44, 84), Vector2(48, 97)]), body, 7.0)
	_poly(ci, PackedVector2Array([Vector2(38, 100), Vector2(48, 94), Vector2(58, 100)]), fin)
	_oval(ci, Vector2(30, 40), 18, 14, body)
	# The mouth, opening and closing.
	_poly(ci, PackedVector2Array([Vector2(12, 43), Vector2(36, 45), Vector2(36, 48 + gape * 3.0), Vector2(14, 49 + gape * 4.0)]), DARK, false)
	for x in [15.0, 20.0, 25.0, 30.0]:
		_poly(ci, PackedVector2Array([Vector2(x, 43.5), Vector2(x + 2, 47.5), Vector2(x + 4, 44)]), BONE, false)
	for k in 3:
		_lines(ci, _arc(Vector2(40 + k * 3.5, 42), 1.6, 6.0, -PI * 0.5, PI * 0.5, 5), body.darkened(0.35), 1.5)
	_dot(ci, Vector2(22, 34), 5.5, belly)
	_elder_eye(ci, Vector2(21, 34), 3.8)
	# A long arm hanging forward, the claws webbed.
	_lines(ci, PackedVector2Array([Vector2(36, 52), Vector2(24, 64), Vector2(20, 80)]), body, 6.0)
	_poly(ci, PackedVector2Array([Vector2(20, 78), Vector2(10, 90), Vector2(18, 88), Vector2(22, 94), Vector2(26, 86)]), fin)
	for d in [-8.0, -2.0, 4.0]:
		_line(ci, Vector2(20, 80), Vector2(20 + d, 92 - absf(d) * 0.3), BONE.darkened(0.2), 1.5)


## A Serpent Man in a cultist's robe: a snake's head thrust out of the hood,
## a forked tongue flicking, a curved knife in a scaled hand, and its tail
## curling out from under the hem.
static func _serpent_man(ci: CanvasItem, body: Color, a: float) -> void:
	var robe := body.darkened(0.6)
	var flick := maxf(sin(a), 0.0)
	_lines(ci, PackedVector2Array([Vector2(72, 94), Vector2(86, 97), Vector2(96, 90), Vector2(93, 82)]), body, 5.0)
	_poly(ci, PackedVector2Array([Vector2(38, 36), Vector2(64, 34), Vector2(80, 99), Vector2(24, 99)]), robe)
	_line(ci, Vector2(26, 92), Vector2(78, 92), GOLD.darkened(0.35), 2.5)
	_line(ci, Vector2(34, 62), Vector2(70, 62), BONE.darkened(0.35), 2.0)
	_line(ci, Vector2(44, 62), Vector2(42, 76), BONE.darkened(0.35), 1.5)
	# The sleeve and the knife.
	_poly(ci, PackedVector2Array([Vector2(42, 42), Vector2(28, 56), Vector2(22, 52), Vector2(34, 38)]), robe.lightened(0.06))
	_line(ci, Vector2(20, 54), Vector2(10, 44), STEEL, 2.5)
	_line(ci, Vector2(10, 44), Vector2(6, 46), STEEL, 2.0)
	_dot(ci, Vector2(21, 54), 3.8, body)
	# The hood, and the head pushed out of it.
	_poly(ci, PackedVector2Array([Vector2(34, 42), Vector2(36, 16), Vector2(50, 6), Vector2(66, 14), Vector2(68, 42)]), robe.lightened(0.08))
	_oval(ci, Vector2(48, 26), 11, 13, DARK, false)
	_poly(ci, PackedVector2Array([Vector2(54, 21), Vector2(40, 16), Vector2(22, 20), Vector2(14, 26), Vector2(22, 31),
		Vector2(40, 33), Vector2(54, 33)]), body)
	_poly(ci, PackedVector2Array([Vector2(14, 26), Vector2(22, 31), Vector2(40, 33), Vector2(38, 28), Vector2(22, 27)]),
		body.lightened(0.25), false)
	for p in [Vector2(30, 20), Vector2(36, 19), Vector2(44, 21), Vector2(33, 24)]:
		_dot(ci, p, 1.3, body.darkened(0.25))
	_dot(ci, Vector2(18, 24), 1.0, DARK)
	_glow_eye(ci, Vector2(34, 23), 2.2, Color("e8e05a"))
	_line(ci, Vector2(34, 21), Vector2(34, 25), DARK, 1.0)
	if flick > 0.15:
		var tip := Vector2(14 - 10.0 * flick, 28)
		var tongue := Color("c77ab8")
		_lines(ci, PackedVector2Array([Vector2(15, 28), tip]), tongue, 1.6)
		_line(ci, tip, tip + Vector2(-4, -2), tongue, 1.3)
		_line(ci, tip, tip + Vector2(-4, 2), tongue, 1.3)


## A Drowned Acolyte: a cultist in a sodden robe hung with kelp, gills on its
## pale neck, a staff topped with a glowing eye, and water dripping off its
## hem.
static func _drowned(ci: CanvasItem, body: Color, a: float) -> void:
	var skin := Color("b9d0cc")
	var kelp := Color("456b4a")
	var glow := 0.5 + 0.5 * sin(a)
	_line(ci, Vector2(16, 98), Vector2(20, 22), WOOD.darkened(0.45), 3.0)
	_dot(ci, Vector2(20, 17), 10.0 + glow * 3.0, Color(CULT_TEAL, 0.22))
	_dot(ci, Vector2(20, 17), 6.0, body.lightened(0.35))
	_dot(ci, Vector2(19, 17), 2.6, CULT_TEAL.lerp(Color.WHITE, 0.4 * glow))
	var robe := PackedVector2Array([Vector2(34, 32), Vector2(64, 32), Vector2(76, 96)])
	for i in 6:
		robe.append(Vector2(76 - i * 10.0, 96 + (4.0 if i % 2 == 0 else 0.0) + sin(a + i) * 1.5))
	robe.append(Vector2(24, 96))
	_poly(ci, robe, body)
	for x in [40.0, 52.0, 62.0]:
		_lines(ci, PackedVector2Array([Vector2(x, 36), Vector2(x - 2 + sin(a + x) * 1.5, 56), Vector2(x + 1, 74)]), kelp, 2.5)
	_lines(ci, PackedVector2Array([Vector2(38, 44), Vector2(26, 52), Vector2(21, 50)]), body.darkened(0.1), 7.0)
	_dot(ci, Vector2(20, 50), 3.2, skin)
	_poly(ci, PackedVector2Array([Vector2(30, 38), Vector2(33, 12), Vector2(50, 3), Vector2(66, 12), Vector2(70, 40),
		Vector2(60, 30), Vector2(40, 30)]), body.darkened(0.2))
	_oval(ci, Vector2(45, 23), 9, 11, skin)
	for k in 3:
		_line(ci, Vector2(51, 25 + k * 3.0), Vector2(54, 26 + k * 3.0), skin.darkened(0.35), 1.2)
	_glow_eye(ci, Vector2(41, 21), 1.8, CULT_TEAL)
	_glow_eye(ci, Vector2(48, 21), 1.8, CULT_TEAL)
	_oval(ci, Vector2(43, 30), 2.0, 3.0, DARK, false)
	# Drops falling off the hem.
	for k in 3:
		var fall := fposmod(a / TAU + k * 0.33, 1.0)
		_dot(ci, Vector2(32 + k * 18.0, 96 + fall * 4.0), 1.5, Color(0.6, 0.9, 0.85, 0.85 * (1.0 - fall)))


## A Night-gaunt: a thin black shape with no face, curled horns, wide bat
## wings and a barbed tail, hovering with its claws out.
static func _night_gaunt(ci: CanvasItem, body: Color, a: float) -> void:
	var y := -8.0
	var flap := sin(a) * 9.0
	var wing := body.lightened(0.1)
	_poly(ci, PackedVector2Array([Vector2(56, 38 + y), Vector2(82, 6 + y - flap), Vector2(100, 18 + y - flap * 0.6),
		Vector2(94, 32 + y), Vector2(100, 46 + y), Vector2(84, 44 + y), Vector2(72, 58 + y)]), wing)
	_poly(ci, PackedVector2Array([Vector2(50, 38 + y), Vector2(60, 4 + y - flap * 0.8), Vector2(72, 14 + y - flap * 0.5),
		Vector2(66, 26 + y), Vector2(70, 40 + y), Vector2(60, 46 + y)]), wing.darkened(0.25))
	_lines(ci, PackedVector2Array([Vector2(58, 70 + y), Vector2(74, 86 + y), Vector2(90, 82 + y), Vector2(96, 72 + y)]), body, 3.0)
	_poly(ci, PackedVector2Array([Vector2(92, 74 + y), Vector2(100, 64 + y), Vector2(99, 76 + y)]), body)
	for x in [50.0, 58.0]:
		_lines(ci, PackedVector2Array([Vector2(x, 72 + y), Vector2(x + 4, 86 + y), Vector2(x - 2, 96 + y)]), body, 3.5)
	_poly(ci, PackedVector2Array([Vector2(42, 34 + y), Vector2(58, 34 + y), Vector2(62, 72 + y), Vector2(48, 76 + y), Vector2(40, 60 + y)]), body)
	_lines(ci, PackedVector2Array([Vector2(44, 40 + y), Vector2(28, 52 + y), Vector2(14, 48 + y)]), body, 3.5)
	for d in [-5.0, 0.0, 5.0]:
		_line(ci, Vector2(14, 48 + y), Vector2(6, 46 + y + d), body.lightened(0.25), 1.4)
	_poly(ci, PackedVector2Array([Vector2(41, 18 + y), Vector2(30, 6 + y), Vector2(34, 2 + y), Vector2(44, 14 + y)]), body.darkened(0.2))
	_poly(ci, PackedVector2Array([Vector2(50, 15 + y), Vector2(58, 2 + y), Vector2(61, 6 + y), Vector2(54, 17 + y)]), body.darkened(0.2))
	_oval(ci, Vector2(46, 25 + y), 9, 11, body.lightened(0.15))
	_oval(ci, Vector2(42, 21 + y), 3, 4, Color(1, 1, 1, 0.12), false)


## A Gibbering Mass: a heap of flesh covered in eyes that blink out of step
## and mouths that open and shut.
static func _gibbering(ci: CanvasItem, body: Color, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 22:
		var ang := PI + i * TAU / 22.0
		var r := 1.0 + 0.08 * sin(ang * 5.0 + a)
		pts.append(Vector2(52 + cos(ang) * 44.0 * r, minf(64 + sin(ang) * 38.0 * r, 99.0)))
	_poly(ci, pts, body)
	for l in [Vector3(36, 52, 12), Vector3(70, 72, 14), Vector3(56, 38, 9)]:
		_oval(ci, Vector2(l.x, l.y), l.z, l.z * 0.8, body.darkened(0.12), false)
	_oval(ci, Vector2(46, 40), 14, 6, body.lightened(0.18), false)
	var mouths := [Vector3(22, 76, 0.0), Vector3(56, 86, 2.1), Vector3(80, 66, 4.2)]
	for m: Vector3 in mouths:
		var open := 2.0 + 3.0 * (0.5 + 0.5 * sin(a + m.z))
		_oval(ci, Vector2(m.x, m.y), 7, open, DARK, false)
		for k in 3:
			_poly(ci, PackedVector2Array([Vector2(m.x - 5 + k * 4, m.y - open), Vector2(m.x - 4 + k * 4, m.y - open + 2.5),
				Vector2(m.x - 3 + k * 4, m.y - open)]), BONE, false)
	var eyes := [Vector3(26, 56, 6.0), Vector3(42, 30, 4.0), Vector3(62, 32, 5.0), Vector3(78, 48, 4.0),
		Vector3(50, 60, 3.5), Vector3(38, 80, 4.0), Vector3(70, 82, 4.5), Vector3(16, 66, 3.0)]
	for i in eyes.size():
		var e: Vector3 = eyes[i]
		_elder_eye(ci, Vector2(e.x, e.y), e.z, sin(a + i * 1.7) > 0.8)


## The Hierophant: the cult's high priest, tall in a gold-trimmed robe with a
## tentacled hem, a masked face with one glowing eye, a pointed mitre, and a
## staff crowned with hooks around a light.
static func _hierophant(ci: CanvasItem, body: Color, a: float) -> void:
	var y := 4.0
	var trim := GOLD.darkened(0.15)
	var glow := 0.5 + 0.5 * sin(a)
	_line(ci, Vector2(14, 99), Vector2(16, 14 + y), WOOD.darkened(0.35), 3.5)
	for d in [-1.0, 1.0]:
		_lines(ci, PackedVector2Array([Vector2(16, 16 + y), Vector2(16 + d * 8, 10 + y), Vector2(16 + d * 6, 2 + y)]), trim, 2.0)
	_dot(ci, Vector2(16, 8 + y), 9.0 + glow * 4.0, Color(CULT_TEAL, 0.25))
	_dot(ci, Vector2(16, 8 + y), 4.0, CULT_TEAL.lerp(Color.WHITE, 0.35 * glow))
	var robe := PackedVector2Array([Vector2(34, 28 + y), Vector2(66, 28 + y), Vector2(84, 99)])
	robe.append(Vector2(16, 99))
	_poly(ci, robe, body)
	for k in 6:
		var x := 22.0 + k * 11.0
		_lines(ci, _arc(Vector2(x, 96), 4.0, 3.0, PI, TAU + sin(a + k) * 0.8, 6), body.darkened(0.35), 2.0)
	_line(ci, Vector2(44, 32 + y), Vector2(40, 96), trim, 3.0)
	_line(ci, Vector2(56, 32 + y), Vector2(60, 96), trim, 3.0)
	_oval(ci, Vector2(50, 54 + y), 7, 3.5, trim, false)
	_dot(ci, Vector2(49, 54 + y), 2.0, DARK)
	_lines(ci, PackedVector2Array([Vector2(36, 38 + y), Vector2(24, 44 + y), Vector2(18, 42 + y)]), body.darkened(0.12), 8.0)
	_dot(ci, Vector2(17, 42 + y), 3.5, Color("cfd8cf"))
	_oval(ci, Vector2(48, 22 + y), 9, 10, BONE.darkened(0.1))
	# A dark veil hangs from the mask's eye down over the rest of the face.
	_poly(ci, PackedVector2Array([Vector2(39, 24 + y), Vector2(57, 24 + y), Vector2(56, 36 + y), Vector2(40, 36 + y)]),
		body.darkened(0.45), false)
	_glow_eye(ci, Vector2(45, 21 + y), 2.2, CULT_TEAL.lerp(Color.WHITE, 0.3 * glow))
	_poly(ci, PackedVector2Array([Vector2(38, 16 + y), Vector2(40, -2 + y), Vector2(48, -8 + y), Vector2(56, -2 + y),
		Vector2(58, 16 + y)]), body.lightened(0.15))
	_line(ci, Vector2(48, -6 + y), Vector2(48, 15 + y), trim, 2.0)
	_line(ci, Vector2(39, 14 + y), Vector2(57, 14 + y), trim, 2.5)


## The Shoggoth: a heaving mound of dark flesh, iridescent where the light
## catches it, with eyes everywhere, a gaping maw and tentacles reaching out.
static func _shoggoth(ci: CanvasItem, body: Color, a: float) -> void:
	_tentacle(ci, Vector2(34, 80), Vector2(0, 60 + sin(a) * 4.0), 13.0, body.lightened(0.1), a)
	_tentacle(ci, Vector2(40, 46), Vector2(4, 20 + cos(a) * 4.0), 11.0, body.lightened(0.05), a + 2.0, -1.0)
	var pts := PackedVector2Array()
	for i in 24:
		var ang := PI + i * TAU / 24.0
		var r := 1.0 + 0.06 * sin(ang * 6.0 + a * 2.0)
		pts.append(Vector2(58 + cos(ang) * 42.0 * r, minf(62 + sin(ang) * 40.0 * r, 99.0)))
	_poly(ci, pts, body)
	_oval(ci, Vector2(50, 36), 18, 8, Color(0.55, 0.85, 0.75, 0.18), false)
	_oval(ci, Vector2(70, 52), 12, 6, Color(0.7, 0.55, 0.9, 0.14), false)
	for k in 4:
		var bubble := 0.5 + 0.5 * sin(a * 2.0 + k * 1.9)
		_oval(ci, Vector2(42 + k * 12.0, 26 + (k % 2) * 4.0), 3.0 + bubble * 2.0, 3.0 + bubble * 2.0, body.lightened(0.2))
	_oval(ci, Vector2(34, 74), 12, 6.0 + 3.0 * (0.5 + 0.5 * sin(a)), DARK, false)
	for k in 5:
		_poly(ci, PackedVector2Array([Vector2(24 + k * 4.5, 70), Vector2(26 + k * 4.5, 75), Vector2(28 + k * 4.5, 70)]), BONE, false)
	var eyes := [Vector3(30, 50, 5.0), Vector3(48, 44, 7.0), Vector3(66, 36, 4.0), Vector3(80, 52, 5.0),
		Vector3(60, 64, 4.0), Vector3(84, 76, 4.5), Vector3(52, 84, 3.5), Vector3(72, 86, 3.0), Vector3(40, 30, 3.0)]
	for i in eyes.size():
		var e: Vector3 = eyes[i]
		_elder_eye(ci, Vector2(e.x, e.y), e.z, sin(a + i * 2.3) > 0.85)


## The Sleeper Below: a vast head risen from the temple pool, its face a
## beard of tentacles, small wings folded at its back, green eyes, and claws
## gripping the edge of the water.
static func _sleeper(ci: CanvasItem, body: Color, a: float) -> void:
	var wing := body.darkened(0.45)
	_oval(ci, Vector2(52, 97), 50, 6, Color("0f2024"), false)
	_poly(ci, PackedVector2Array([Vector2(68, 34), Vector2(92, 2), Vector2(100, 20), Vector2(94, 26), Vector2(98, 40), Vector2(80, 46)]), wing)
	_poly(ci, PackedVector2Array([Vector2(60, 30), Vector2(72, 0), Vector2(82, 14), Vector2(78, 30)]), wing.darkened(0.2))
	_poly(ci, PackedVector2Array([Vector2(14, 96), Vector2(20, 64), Vector2(34, 48), Vector2(72, 44), Vector2(90, 62),
		Vector2(94, 96)]), body.darkened(0.15))
	_oval(ci, Vector2(54, 28), 26, 25, body)
	for k in 3:
		_lines(ci, _arc(Vector2(56, 30), 20.0 - k * 6.0, 18.0 - k * 5.0, PI * 1.1, PI * 1.7, 8), body.lightened(0.15), 2.0)
	# The tentacle beard, swaying.
	for k in 6:
		var root := Vector2(30 + k * 7.0, 46 + absf(k - 2.5) * 1.5)
		var tip := root + Vector2(-8.0 + k * 1.5, 34.0 + (k % 2) * 8.0)
		_tentacle(ci, root, tip, 5.0, body.lightened(0.08), a + k * 0.9, 0.8)
	var glow := 0.5 + 0.5 * sin(a)
	for e in [Vector2(36, 34), Vector2(54, 34)]:
		_dot(ci, e, 7.0 + glow * 2.0, Color(ELDER_GREEN, 0.25))
		_dot(ci, e, 4.0, ELDER_GREEN.lerp(Color.WHITE, 0.3 * glow))
		_line(ci, e - Vector2(0, 3), e + Vector2(0, 3), DARK, 1.5)
	# Claws on the edge of the pool.
	for c in [Vector2(10, 92), Vector2(88, 92)]:
		for d in [-6.0, 0.0, 6.0]:
			_line(ci, c + Vector2(d * 0.4, -8), c + Vector2(d, 0), body.darkened(0.25), 3.0)
	var ripple := PackedVector2Array()
	for i in 21:
		var x := 2.0 + i * 4.8
		ripple.append(Vector2(x, 94 + sin(x * 0.3 + a * 2.0) * 1.5))
	_lines(ci, ripple, Color(CULT_TEAL, 0.6), 1.5)


## A Spawnling: a small polyp with one big eye, wriggling on its tentacles.
static func _spawnling(ci: CanvasItem, body: Color, a: float) -> void:
	for k in 5:
		var root := Vector2(34 + k * 8.0, 64)
		_tentacle(ci, root, root + Vector2(-6 + k * 3.0, 32), 5.0, body.darkened(0.1), a + k * 1.3, 0.6)
	_oval(ci, Vector2(50, 50), 22, 20, body)
	_oval(ci, Vector2(54, 40), 10, 5, body.lightened(0.25), false)
	_elder_eye(ci, Vector2(42, 50), 8.0, sin(a) > 0.92)
	_poly(ci, PackedVector2Array([Vector2(34, 62), Vector2(40, 60), Vector2(36, 66)]), DARK, false)


# The Plains of Hell.

## A tongue of hellfire rising from `base`, `h` tall, swaying with `a`.
static func _flame(ci: CanvasItem, base: Vector2, w: float, h: float, a: float) -> void:
	var tip := base + Vector2(sin(a * 2.0 + base.x) * w * 0.4, -h)
	_poly(ci, PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.6, -h * 0.45), tip,
		base + Vector2(w * 0.6, -h * 0.45), base + Vector2(w, 0)]), Color(HELLFIRE, 0.85), false)
	_poly(ci, PackedVector2Array([base + Vector2(-w * 0.45, 0), tip.lerp(base, 0.35), base + Vector2(w * 0.45, 0)]),
		Color(HELLFIRE_CORE, 0.9), false)


## A black, heavy-shouldered hound with ember eyes and a mane of hellfire.
static func _hellhound(ci: CanvasItem, body: Color, a: float) -> void:
	var pant := sin(a) * 1.5
	var far := body.darkened(0.35)
	for x in [44.0, 80.0]:
		_line(ci, Vector2(x + 4, 62), Vector2(x + 6, 99), far, 8.0)
	_poly(ci, PackedVector2Array([Vector2(86, 50), Vector2(98, 40), Vector2(100, 30), Vector2(90, 34), Vector2(82, 46)]), body.darkened(0.1))
	_oval(ci, Vector2(62, 56), 32, 18, body)
	_oval(ci, Vector2(64, 66), 24, 7, body.lightened(0.15), false)
	for k in 4:
		_poly(ci, PackedVector2Array([Vector2(52 + k * 9, 40), Vector2(56 + k * 9, 30 - (k % 2) * 4), Vector2(60 + k * 9, 40)]), body.darkened(0.2))
	for x in [34.0, 72.0]:
		_line(ci, Vector2(x, 62), Vector2(x - 2, 99), body, 9.0)
		_line(ci, Vector2(x - 7, 98), Vector2(x + 2, 98), body.darkened(0.25), 4.0)
	# The flaming mane, then the broad head with its jaws open.
	for k in 4:
		_flame(ci, Vector2(30 + k * 7, 40 + k * 2), 5.0, 14.0 + (k % 2) * 6.0, a + k)
	_poly(ci, PackedVector2Array([Vector2(24, 34), Vector2(46, 36), Vector2(50, 62), Vector2(32, 72), Vector2(20, 58)]), body.lightened(0.05))
	var head := PackedVector2Array([Vector2(0, 50), Vector2(2, 42), Vector2(14, 36), Vector2(18, 16), Vector2(28, 30),
		Vector2(34, 18), Vector2(40, 34), Vector2(40, 50), Vector2(26, 56)])
	_poly(ci, head, body)
	_poly(ci, PackedVector2Array([Vector2(2, 52), Vector2(24, 56 + pant), Vector2(20, 60 + pant), Vector2(4, 58 + pant)]), body.darkened(0.2))
	for x in [6.0, 12.0, 18.0]:
		_poly(ci, PackedVector2Array([Vector2(x, 51), Vector2(x + 2, 56), Vector2(x + 4, 51)]), BONE, false)
	_dot(ci, Vector2(2, 44), 2.5, DARK)
	_glow_eye(ci, Vector2(18, 40), 2.4, EMBER)


## A wraith lunging at the hero: a long gaunt skull with its jaw hanging
## open, clawed arms reaching out, a broken shackle on one wrist, and a body
## that thins into a curling tail of mist. Seen through, in a faint glow.
static func _soul(ci: CanvasItem, body: Color, a: float) -> void:
	var y := 4.0
	var drift := sin(a) * 3.0
	var mist := body.lightened(0.2)
	# The spine, from the neck down and back into the tail, and how wide the
	# body is along it.
	var spine := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in 13:
		var u := i / 12.0
		spine.append(Vector2(46 + u * 46.0 - sin(u * PI) * 6.0, 30 + y + u * 64.0 - u * u * 16.0
			+ sin(a + u * 4.0) * 3.0 * u))
		widths.append(lerpf(12.0, 0.6, pow(u, 0.8)))
	# A glow round it, layered so it fades out.
	for g in 3:
		for i in range(0, 9, 2):
			_dot(ci, spine[i], widths[i] + 10.0 - g * 4.0, Color(body, 0.06))
	# Mist trailing off the back, fainter than the body.
	for k in 3:
		var trail := PackedVector2Array()
		for i in 6:
			var u := i / 5.0
			trail.append(Vector2(58 + k * 4.0 + u * 30.0, 34 + y + k * 12.0 + u * (6.0 + k * 4.0)
				+ sin(a + u * 5.0 + k * 1.7) * 3.0))
		_lines(ci, trail, Color(mist, 0.22 - k * 0.04), 3.0 - k * 0.6)
	# The back arm, dimmer, reaching past the head.
	var back := Vector2(14, 26 + y - drift * 0.5)
	_lines(ci, PackedVector2Array([Vector2(48, 36 + y), Vector2(32, 36 + y), back]), Color(body.darkened(0.3), 0.7), 3.5)
	for f in 3:
		_lines(ci, PackedVector2Array([back, back + Vector2(-5, -3 + f * 3.0), back + Vector2(-7, -1 + f * 4.0)]),
			Color(body.darkened(0.3), 0.7), 1.4)
	# The body, from the spine's two edges.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in spine.size():
		var along := (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-along.y, along.x)
		left.append(spine[i] + side * widths[i])
		right.append(spine[i] - side * widths[i])
	right.reverse()
	var pts := left + right
	_poly(ci, pts, Color(body, 0.6), false)
	var rim := right.duplicate()
	rim.append(left[0])
	_lines(ci, rim, Color(mist, 0.55), 1.2)
	# Ribs showing through.
	for i in 3:
		_lines(ci, _arc(spine[1 + i] + Vector2(-2, 0), 8.0 - i * 1.5, 2.6, PI * 0.85, PI * 1.85, 6),
			Color(DARK, 0.3), 1.4)
	# The front arm, long and thin, clawing at the hero.
	var hand := Vector2(6, 46 + y + drift * 0.5)
	_lines(ci, PackedVector2Array([Vector2(42, 40 + y), Vector2(24, 50 + y), hand]), Color(body, 0.85), 4.0)
	for f in 3:
		_lines(ci, PackedVector2Array([hand, hand + Vector2(-6, -4 + f * 4.0), hand + Vector2(-8, -1 + f * 5.0)]),
			Color(mist, 0.9), 1.5)
	# A broken shackle at the wrist, two links still hanging.
	_lines(ci, _arc(Vector2(18, 52 + y), 3.5, 3.0, 0.0, TAU, 8), STEEL.darkened(0.3), 2.0)
	for i in 2:
		_lines(ci, _arc(Vector2(19 + i, 59 + y + i * 5.0), 2.0, 2.6, 0.0, TAU, 6), STEEL.darkened(0.35), 1.4)
	# The skull, long and gaunt, its jaw hung open in a silent scream.
	var jaw := drift * 0.4
	var head := PackedVector2Array([Vector2(32, 14 + y), Vector2(38, 7 + y), Vector2(47, 8 + y), Vector2(50, 16 + y),
		Vector2(46, 28 + y), Vector2(42, 42 + y + jaw), Vector2(36, 42 + y + jaw), Vector2(33, 30 + y), Vector2(30, 22 + y)])
	_poly(ci, head, Color(mist, 0.9), false)
	_lines(ci, PackedVector2Array([Vector2(33, 26 + y), Vector2(36, 30 + y)]), Color(DARK, 0.4), 1.2)
	_oval(ci, Vector2(39, 32 + y + jaw * 0.5), 2.6, 7.5 + jaw * 0.5, DARK, false)
	_poly(ci, PackedVector2Array([Vector2(32, 17 + y), Vector2(38, 18 + y), Vector2(37, 23 + y), Vector2(33, 22 + y)]), DARK, false)
	_poly(ci, PackedVector2Array([Vector2(41, 18 + y), Vector2(47, 16 + y), Vector2(46, 22 + y), Vector2(42, 23 + y)]), DARK, false)
	_glow_eye(ci, Vector2(35, 20 + y), 1.1, HELLFIRE_CORE)
	_glow_eye(ci, Vector2(44, 19.5 + y), 1.1, HELLFIRE_CORE)


## A Lilim, a daughter of Lilith: horned, bat-winged, in a long gown, with a
## charm of violet light in her hand.
static func _lilim(ci: CanvasItem, body: Color, a: float) -> void:
	var y := -6.0
	var flap := sin(a) * 6.0
	var wing := body.darkened(0.45)
	_poly(ci, PackedVector2Array([Vector2(56, 40 + y), Vector2(84, 10 + y - flap), Vector2(100, 24 + y - flap * 0.5),
		Vector2(92, 34 + y), Vector2(98, 48 + y), Vector2(82, 46 + y), Vector2(70, 56 + y)]), wing)
	var gown := PackedVector2Array([Vector2(40, 40 + y), Vector2(58, 40 + y), Vector2(70, 92 + y)])
	for i in 5:
		gown.append(Vector2(70 - i * 9.0, 92 + y + (5.0 if i % 2 == 0 else 0.0) + sin(a + i) * 2.0))
	gown.append(Vector2(28, 92 + y))
	_poly(ci, gown, body)
	_line(ci, Vector2(40, 56 + y), Vector2(60, 56 + y), GOLD.darkened(0.2), 2.0)
	# Long dark hair down her back.
	_poly(ci, PackedVector2Array([Vector2(46, 14 + y), Vector2(62, 18 + y), Vector2(66, 50 + y), Vector2(54, 46 + y)]), DARK)
	var skin := Color("c9b2d8")
	_lines(ci, PackedVector2Array([Vector2(42, 44 + y), Vector2(28, 50 + y), Vector2(18, 44 + y)]), skin, 4.0)
	var glow := 0.5 + 0.5 * sin(a + 1.0)
	_dot(ci, Vector2(14, 42 + y), 8.0 + glow * 3.0, Color(0.7, 0.4, 1.0, 0.3))
	_dot(ci, Vector2(14, 42 + y), 4.0, Color("d9b3ff"))
	_oval(ci, Vector2(48, 26 + y), 10, 12, skin)
	var horn := Color("3a2a44")
	_poly(ci, PackedVector2Array([Vector2(42, 18 + y), Vector2(36, 4 + y), Vector2(46, 15 + y)]), horn)
	_poly(ci, PackedVector2Array([Vector2(52, 16 + y), Vector2(56, 2 + y), Vector2(57, 17 + y)]), horn)
	_glow_eye(ci, Vector2(43, 25 + y), 1.8, Color("e8b4ff"))
	_glow_eye(ci, Vector2(50, 25 + y), 1.8, Color("e8b4ff"))


## Ualac: a winged child riding a small two-headed dragon, one head breathing
## fire.
static func _ualac(ci: CanvasItem, body: Color, a: float) -> void:
	var tail := body.darkened(0.2)
	_lines(ci, PackedVector2Array([Vector2(78, 70), Vector2(92, 76), Vector2(98, 66)]), tail, 6.0)
	for x in [40.0, 70.0]:
		_line(ci, Vector2(x, 72), Vector2(x - 2, 99), body.darkened(0.25), 7.0)
	_oval(ci, Vector2(58, 68), 26, 14, body)
	_oval(ci, Vector2(58, 76), 20, 5, body.lightened(0.25), false)
	for x in [34.0, 64.0]:
		_line(ci, Vector2(x, 74), Vector2(x - 2, 99), body, 7.0)
	# Two necks and heads, the front one breathing fire at the hero.
	for k in 2:
		var neck := Vector2(36 + k * 6, 62)
		var h := Vector2(12 + k * 14, 38 - k * 12)
		_line(ci, neck, h + Vector2(6, 2), body.darkened(0.08 * k), 7.0)
		_poly(ci, PackedVector2Array([h + Vector2(-10, 0), h + Vector2(2, -7), h + Vector2(10, -2), h + Vector2(8, 5), h + Vector2(-8, 4)]), body)
		_glow_eye(ci, h + Vector2(1, -2), 1.6, EMBER)
	var breath := 0.5 + 0.5 * sin(a)
	_dot(ci, Vector2(-2, 39), 5.0 + breath * 3.0, Color(1.0, 0.6, 0.24, 0.4))
	_dot(ci, Vector2(0, 39), 3.0, Color("ffe07a"))
	# The child, with small white wings.
	var wing := Color("e8e4f0")
	var flap := sin(a) * 4.0
	_poly(ci, PackedVector2Array([Vector2(62, 40), Vector2(80, 26 - flap), Vector2(84, 36 - flap * 0.5), Vector2(70, 46)]), wing)
	var skin := Color("e0c09a")
	_poly(ci, PackedVector2Array([Vector2(50, 40), Vector2(64, 40), Vector2(66, 58), Vector2(48, 58)]), Color("6b4a8a"))
	_line(ci, Vector2(52, 46), Vector2(42, 52), skin, 4.0)
	_oval(ci, Vector2(56, 32), 9, 9, skin)
	_poly(ci, PackedVector2Array([Vector2(48, 28), Vector2(56, 22), Vector2(64, 28), Vector2(56, 26)]), Color("e8c86a"), false)
	_dot(ci, Vector2(52, 32), 1.5, DARK)


## A fallen angel in black plate: tattered wings, a cracked halo gone dim,
## and a long sword.
static func _fallen(ci: CanvasItem, body: Color, a: float) -> void:
	var wing := body.darkened(0.4)
	var droop := sin(a) * 2.0
	for k in 2:
		var root := Vector2(62 - k * 6, 34)
		var pts := PackedVector2Array([root, root + Vector2(26, -26 - droop), root + Vector2(36, -10 - droop)])
		for i in 4:
			pts.append(root + Vector2(34 - i * 7, 10 + i * 6 + (5.0 if i % 2 == 0 else 0.0)))
		pts.append(root + Vector2(6, 26))
		_poly(ci, pts, wing.lightened(0.08 * k))
	for x in [40.0, 60.0]:
		_poly(ci, PackedVector2Array([Vector2(x - 8, 76), Vector2(x + 8, 76), Vector2(x + 10, 100), Vector2(x - 10, 100)]), body)
	_poly(ci, PackedVector2Array([Vector2(28, 30), Vector2(72, 30), Vector2(68, 80), Vector2(32, 80)]), body.lightened(0.12))
	_line(ci, Vector2(50, 34), Vector2(50, 78), body.darkened(0.2), 2.0)
	for x in [28.0, 72.0]:
		_oval(ci, Vector2(x, 32), 11, 8, body.lightened(0.2))
	# The sword held down and forward.
	_lines(ci, PackedVector2Array([Vector2(28, 36), Vector2(20, 54), Vector2(18, 62)]), body.lightened(0.12), 9.0)
	_line(ci, Vector2(18, 64), Vector2(2, 98), STEEL, 4.0)
	_line(ci, Vector2(10, 62), Vector2(26, 66), GOLD.darkened(0.3), 3.0)
	_oval(ci, Vector2(50, 18), 11, 12, body.lightened(0.25))
	_poly(ci, PackedVector2Array([Vector2(40, 18), Vector2(60, 18), Vector2(58, 22), Vector2(42, 22)]), DARK, false)
	_glow_eye(ci, Vector2(45, 20), 1.6, Color("d8d2ff"))
	_glow_eye(ci, Vector2(54, 20), 1.6, Color("d8d2ff"))
	# The halo, cracked and tilted.
	var halo := Color(GOLD, 0.55 + 0.2 * sin(a))
	_lines(ci, _arc(Vector2(52, 3), 13, 4, 0.2, PI - 0.3, 10), halo, 2.5)
	_lines(ci, _arc(Vector2(52, 3), 13, 4, PI + 0.4, TAU - 0.1, 10), halo, 2.5)


## Amdusias, the Duke of hell's music: a unicorn's head on a robed body, a
## long horn trumpet raised, notes drifting off it.
static func _amdusias(ci: CanvasItem, body: Color, a: float) -> void:
	var robe := body
	var trim := GOLD.darkened(0.2)
	_poly(ci, PackedVector2Array([Vector2(30, 36), Vector2(72, 36), Vector2(86, 100), Vector2(18, 100)]), robe)
	_poly(ci, PackedVector2Array([Vector2(18, 92), Vector2(86, 92), Vector2(86, 100), Vector2(18, 100)]), robe.darkened(0.3), false)
	_line(ci, Vector2(50, 40), Vector2(50, 92), trim, 3.0)
	for x in [24.0, 78.0]:
		_oval(ci, Vector2(x, 40), 12, 8, robe.lightened(0.15))
	# The trumpet: a long horn from his mouth to a bell over the hero.
	_lines(ci, PackedVector2Array([Vector2(28, 44), Vector2(18, 40), Vector2(14, 32)]), robe.lightened(0.1), 7.0)
	_line(ci, Vector2(24, 24), Vector2(-2, 14), GOLD, 4.0)
	_poly(ci, PackedVector2Array([Vector2(0, 6), Vector2(-4, 24), Vector2(4, 16)]), GOLD)
	for k in 3:
		var t := fmod(a / TAU + k / 3.0, 1.0)
		var at := Vector2(-2 - t * 10.0, 10 - t * 24.0 + sin(t * 9.0 + k) * 3.0)
		_dot(ci, at, 2.6, Color(Color("e8d0ff"), 1.0 - t))
		_line(ci, at + Vector2(2.4, 0), at + Vector2(2.4, -8), Color(Color("e8d0ff"), 1.0 - t), 1.5)
	# The unicorn head, long-faced, and its horn.
	var head := body.lightened(0.35)
	_poly(ci, PackedVector2Array([Vector2(36, 34), Vector2(32, 14), Vector2(22, 8), Vector2(18, 20), Vector2(24, 26), Vector2(30, 36)]), head)
	_poly(ci, PackedVector2Array([Vector2(34, 32), Vector2(40, 10), Vector2(50, 8), Vector2(56, 22), Vector2(52, 36)]), head)
	_poly(ci, PackedVector2Array([Vector2(46, 10), Vector2(52, -8), Vector2(52, 10)]), Color("f2ead8"))
	_poly(ci, PackedVector2Array([Vector2(52, 8), Vector2(62, 14), Vector2(60, 30), Vector2(54, 20)]), body.darkened(0.3), false)
	_glow_eye(ci, Vector2(40, 18), 2.0, Color("e8d0ff"))


## Belial in his chariot of fire: a crowned king behind the chariot's front,
## its wheel ringed with hellfire.
static func _belial(ci: CanvasItem, body: Color, a: float) -> void:
	var gold := GOLD
	var skin := Color("7a5a86")
	# The king, behind the chariot.
	_poly(ci, PackedVector2Array([Vector2(36, 24), Vector2(66, 24), Vector2(70, 60), Vector2(32, 60)]), body.darkened(0.2))
	_lines(ci, PackedVector2Array([Vector2(38, 30), Vector2(22, 34), Vector2(14, 26)]), body.darkened(0.2), 7.0)
	_line(ci, Vector2(12, 34), Vector2(16, 0), gold.darkened(0.2), 3.0)
	_flame(ci, Vector2(16, 4), 5.0, 14.0, a)
	_oval(ci, Vector2(50, 16), 11, 12, skin)
	_poly(ci, PackedVector2Array([Vector2(39, 8), Vector2(40, -4), Vector2(45, 3), Vector2(50, -6), Vector2(55, 3), Vector2(60, -4),
		Vector2(61, 8)]), gold)
	_glow_eye(ci, Vector2(45, 16), 1.8, EMBER)
	_glow_eye(ci, Vector2(53, 16), 1.8, EMBER)
	# The chariot, flames along its rim.
	_poly(ci, PackedVector2Array([Vector2(20, 50), Vector2(82, 50), Vector2(88, 80), Vector2(14, 80)]), body)
	_line(ci, Vector2(18, 54), Vector2(84, 54), gold.darkened(0.15), 3.0)
	for k in 5:
		_flame(ci, Vector2(24 + k * 14, 50), 6.0, 12.0 + (k % 2) * 6.0, a + k * 1.3)
	# The wheel, spinning in a ring of fire.
	var hub := Vector2(52, 84)
	_dot(ci, hub, 16.0, Color(HELLFIRE, 0.35))
	_lines(ci, _arc(hub, 14, 14, 0.0, TAU, 16), body.darkened(0.4), 4.0)
	for k in 4:
		var d := Vector2.from_angle(a + k * PI * 0.25)
		_line(ci, hub - d * 13.0, hub + d * 13.0, body.darkened(0.4), 2.5)
	_dot(ci, hub, 4.0, gold)


## Astaroth, a great duke of hell: crowned, wrapped in dark wings, a serpent
## coiled on his arm, standing in a ring of hellfire.
static func _astaroth(ci: CanvasItem, body: Color, a: float) -> void:
	var gold := GOLD
	var wing := body.darkened(0.45)
	var lift := sin(a) * 3.0
	for k in 2:
		var root := Vector2(58 + k * 8, 30)
		var pts := PackedVector2Array([root, root + Vector2(22, -28 - lift), root + Vector2(40, -20 - lift), root + Vector2(38, 0)])
		for i in 3:
			pts.append(root + Vector2(34 - i * 10, 14 + i * 10 + (6.0 if i % 2 == 0 else 0.0)))
		pts.append(root + Vector2(4, 36))
		_poly(ci, pts, wing.lightened(0.1 * k))
	for k in 6:
		_flame(ci, Vector2(14 + k * 15, 100), 7.0, 14.0 + (k % 3) * 6.0, a + k * 0.9)
	var robe := PackedVector2Array([Vector2(30, 30), Vector2(70, 30), Vector2(82, 98), Vector2(18, 98)])
	_poly(ci, robe, body)
	_line(ci, Vector2(50, 34), Vector2(50, 96), gold.darkened(0.3), 3.0)
	_line(ci, Vector2(26, 62), Vector2(74, 62), gold.darkened(0.3), 3.0)
	for x in [28.0, 72.0]:
		_oval(ci, Vector2(x, 32), 13, 9, body.lightened(0.15))
	# The arm forward with the serpent coiled on it, head raised at the hero.
	_lines(ci, PackedVector2Array([Vector2(28, 38), Vector2(16, 54), Vector2(10, 52)]), body.lightened(0.1), 10.0)
	var snake := ASTAROTH_SNAKE
	var coil := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		coil.append(Vector2(lerpf(26.0, 4.0, k), 46.0 + sin(k * TAU * 1.5) * 5.0 - k * 14.0))
	_lines(ci, coil, snake.darkened(0.3), 6.0)
	_lines(ci, coil, snake, 3.5)
	var sh := coil[12] + Vector2(-2, -2)
	_poly(ci, PackedVector2Array([sh + Vector2(6, -3), sh + Vector2(-6, -1), sh + Vector2(-5, 3), sh + Vector2(6, 3)]), snake)
	_line(ci, sh + Vector2(-6, 1), sh + Vector2(-10 - sin(a * 2.0) * 2.0, 2), Color("e8d0ff"), 1.0)
	_astaroth_head(ci, true)


const ASTAROTH_SNAKE := Color("6ad0a0")
## Where Astaroth's head meets his shoulders, standing and fallen, and how
## far the fallen head is turned (it lies on its back, crown away from the
## hero).
const ASTAROTH_NECK := Vector2(48, 30)
const FALLEN_NECK := Vector2(70, 88)
const FALLEN_TURN := 1.45


## Astaroth's head: pale, horned, crowned, with violet-white eyes, shut once
## he's dead.
static func _astaroth_head(ci: CanvasItem, alive: bool) -> void:
	var skin := Color("6e6a8e")
	_oval(ci, Vector2(48, 18), 12, 13, skin)
	var horn := Color("2a2436")
	_poly(ci, PackedVector2Array([Vector2(38, 14), Vector2(24, -2), Vector2(36, 6)]), horn)
	_poly(ci, PackedVector2Array([Vector2(58, 12), Vector2(70, -4), Vector2(62, 10)]), horn)
	_poly(ci, PackedVector2Array([Vector2(38, 8), Vector2(39, -2), Vector2(44, 4), Vector2(48, -5), Vector2(52, 4), Vector2(57, -2),
		Vector2(58, 8)]), GOLD)
	if alive:
		_glow_eye(ci, Vector2(43, 18), 2.0, HELLFIRE_CORE)
		_glow_eye(ci, Vector2(52, 18), 2.0, HELLFIRE_CORE)
	else:
		_line(ci, Vector2(40.5, 18), Vector2(45.5, 19), DARK, 1.2)
		_line(ci, Vector2(49.5, 19), Vector2(54.5, 18), DARK, 1.2)
	_poly(ci, PackedVector2Array([Vector2(42, 26), Vector2(48, 34), Vector2(54, 26)]), DARK, false)


## Astaroth dead in `r`, for the ending: on his back, feet toward the hero,
## wings spread under him, the serpent limp across him, his fire out. His
## head isn't drawn: see draw_astaroth_head and fallen_neck.
static func draw_astaroth_fallen(ci: CanvasItem, r: Rect2, body: Color, base := Transform2D.IDENTITY) -> void:
	_alpha = body.a
	body.a = 1.0
	ci.draw_set_transform_matrix(base * Transform2D(0.0, r.size / 100.0, 0.0, r.position))
	var wing := body.darkened(0.45)
	_poly(ci, PackedVector2Array([Vector2(60, 90), Vector2(52, 66), Vector2(36, 56), Vector2(18, 60), Vector2(22, 70),
		Vector2(10, 74), Vector2(16, 84), Vector2(4, 90), Vector2(6, 99), Vector2(56, 99)]), wing.lightened(0.1))
	_poly(ci, PackedVector2Array([Vector2(4, 99), Vector2(10, 90), Vector2(26, 79), Vector2(46, 74), Vector2(62, 77),
		Vector2(72, 86), Vector2(73, 99)]), body)
	_line(ci, Vector2(12, 92), Vector2(66, 82), GOLD.darkened(0.3), 3.0)
	_line(ci, Vector2(40, 76), Vector2(42, 98), GOLD.darkened(0.3), 3.0)
	_poly(ci, PackedVector2Array([Vector2(20, 99), Vector2(30, 93), Vector2(50, 94), Vector2(64, 99)]), wing.lightened(0.2))
	var coil := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		coil.append(Vector2(lerpf(22.0, 52.0, k), lerpf(84.0, 78.0, k) + sin(k * TAU * 1.5) * 2.5))
	_lines(ci, coil, ASTAROTH_SNAKE.darkened(0.3), 6.0)
	_lines(ci, coil, ASTAROTH_SNAKE.darkened(0.1), 3.5)
	_lines(ci, PackedVector2Array([Vector2(64, 91), Vector2(56, 97), Vector2(44, 98)]), body.lightened(0.1), 9.0)
	_oval(ci, Vector2(65, 87), 8, 10, body.lightened(0.15))
	_oval(ci, FALLEN_NECK + Vector2(1.5, 0), 2.5, 5.5, DARK, false)
	ci.draw_set_transform_matrix(base)


## Where the head of an Astaroth fallen in `r` meets his shoulders.
static func fallen_neck(r: Rect2) -> Vector2:
	return r.position + FALLEN_NECK * r.size / 100.0


## Astaroth's head alone, dead, for the ending: its neck at `at`, turned
## `angle`, `scale` times its size on a body 100 by 100.
static func draw_astaroth_head(ci: CanvasItem, at: Vector2, scale: Vector2, angle: float, base := Transform2D.IDENTITY) -> void:
	_alpha = 1.0
	ci.draw_set_transform_matrix(base * Transform2D(angle, scale, 0.0, at) * Transform2D(0.0, -ASTAROTH_NECK))
	_astaroth_head(ci, false)
	ci.draw_set_transform_matrix(base)


## A vine that grows from the floor to a snapping bud, thorned tendrils
## curling out of the ground round it.
static func _vine(ci: CanvasItem, body: Color, a: float) -> void:
	var s := sin(a) * 3.0
	var dark := body.darkened(0.35)
	_oval(ci, Vector2(50, 97), 44, 6, dark, false)
	# Tendrils on the floor, one reaching left for whoever walks by.
	_lines(ci, PackedVector2Array([Vector2(34, 99), Vector2(20, 96), Vector2(10, 88), Vector2(8 + s, 78)]), dark, 5.0)
	_lines(ci, PackedVector2Array([Vector2(70, 99), Vector2(86, 94), Vector2(94, 80), Vector2(88, 64 - s)]), dark, 5.0)
	for p: Vector2 in [Vector2(20, 96), Vector2(10, 88), Vector2(86, 94), Vector2(94, 80)]:
		_poly(ci, PackedVector2Array([p + Vector2(-3, -2), p + Vector2(0, -9), p + Vector2(3, -2)]), body.lightened(0.3), false)
	_poly(ci, PackedVector2Array([Vector2(8 + s, 78), Vector2(2 + s, 70), Vector2(12 + s, 72)]), body.lightened(0.3), false)
	# The stem, thick and knotted, leaning toward the hero.
	_lines(ci, PackedVector2Array([Vector2(62, 100), Vector2(66, 84), Vector2(56, 68), Vector2(50, 52 + s * 0.4)]), body, 12.0)
	_lines(ci, PackedVector2Array([Vector2(62, 100), Vector2(66, 84), Vector2(56, 68), Vector2(50, 52 + s * 0.4)]),
		body.lightened(0.12), 4.0)
	for p: Vector2 in [Vector2(66, 82), Vector2(57, 68)]:
		_poly(ci, PackedVector2Array([p + Vector2(4, -3), p + Vector2(14, -8), p + Vector2(5, 3)]), body.lightened(0.3), false)
	# Two waving arms off the stem, tips curled, and a short one below.
	var arm_a := PackedVector2Array([Vector2(58, 66), Vector2(44, 74), Vector2(30, 70 + s), Vector2(22, 60 + s), Vector2(28, 54 + s)])
	var arm_b := PackedVector2Array([Vector2(60, 60), Vector2(76, 54), Vector2(86, 42 - s), Vector2(80, 32 - s), Vector2(72, 36 - s)])
	var arm_c := PackedVector2Array([Vector2(64, 84), Vector2(50, 88), Vector2(40, 84 - s * 0.5)])
	for arm: PackedVector2Array in [arm_a, arm_b, arm_c]:
		_lines(ci, arm, dark, 7.0)
		_lines(ci, arm, body, 4.5)
		var tip: Vector2 = arm[arm.size() - 1]
		_dot(ci, tip, 3.0, body.lightened(0.3))
		for k in range(1, arm.size() - 1):
			var out := (arm[k] - arm[k - 1]).orthogonal().normalized() * 5.0
			_poly(ci, PackedVector2Array([arm[k] + out * 0.4, arm[k] + out * 1.6, arm[k] + (arm[k + 1] - arm[k]).normalized() * 3.0]),
				body.lightened(0.3), false)
	# The bud: two jaws hinged at the back, a ring of teeth, a glow inside.
	var open := 7.0 + (sin(a) * 0.5 + 0.5) * 5.0
	var hinge := Vector2(52, 44 + s * 0.4)
	_poly(ci, PackedVector2Array([hinge + Vector2(0, 4), hinge + Vector2(-14, 8 + open), hinge + Vector2(-40, 12 + open * 0.5),
		hinge + Vector2(-46, 6 + open * 0.5), hinge + Vector2(-30, -2), hinge + Vector2(-8, -4)]), Color("5a2a4a"))
	_poly(ci, PackedVector2Array([hinge + Vector2(0, -4), hinge + Vector2(-8, -14 - open), hinge + Vector2(-30, -22 - open),
		hinge + Vector2(-46, -14 - open * 0.6), hinge + Vector2(-48, 2), hinge + Vector2(-26, 0)]), body.lightened(0.08))
	_lines(ci, PackedVector2Array([hinge + Vector2(-4, -6), hinge + Vector2(-22, -16 - open), hinge + Vector2(-42, -10 - open * 0.5)]),
		body.lightened(0.35), 2.0)
	_poly(ci, PackedVector2Array([hinge + Vector2(-2, 6), hinge + Vector2(-12, 14 + open), hinge + Vector2(-34, 16 + open * 0.5),
		hinge + Vector2(-44, 8 + open * 0.5), hinge + Vector2(-30, 2)]), body)
	for k in 5:
		var x := -10.0 - k * 8.0
		_poly(ci, PackedVector2Array([hinge + Vector2(x, -1), hinge + Vector2(x - 3, 8 + open * 0.4), hinge + Vector2(x - 6, -1)]), BONE, false)
		_poly(ci, PackedVector2Array([hinge + Vector2(x - 2, 5), hinge + Vector2(x - 5, -4 - open * 0.4), hinge + Vector2(x - 8, 5)]), BONE, false)
	_glow_eye(ci, hinge + Vector2(-24, -12 - open * 0.6), 2.2, Color("e8f27a"))
	_glow_eye(ci, hinge + Vector2(-10, -9 - open * 0.5), 2.0, Color("e8f27a"))


## A wild boar in profile, bristles up its back and tusks forward.
static func _boar(ci: CanvasItem, body: Color, a: float) -> void:
	var far := body.darkened(0.35)
	for x in [40.0, 74.0]:
		_line(ci, Vector2(x + 5, 70), Vector2(x + 6, 99), far, 8.0)
	# The tail, a short curl.
	_lines(ci, PackedVector2Array([Vector2(92, 50), Vector2(98, 46), Vector2(97, 38)]), body.darkened(0.2), 3.0)
	_oval(ci, Vector2(60, 62), 36, 25, body)
	_oval(ci, Vector2(62, 74), 30, 8, body.lightened(0.18), false)
	# The bristle ridge from neck to rump.
	_poly(ci, PackedVector2Array([Vector2(32, 52), Vector2(34, 40), Vector2(94, 44), Vector2(96, 54)]), body.darkened(0.45), false)
	for k in 9:
		var x := 32.0 + k * 7.0
		var up := 15.0 + (4 - absf(k - 4)) * 1.5
		_poly(ci, PackedVector2Array([Vector2(x - 3.5, 42), Vector2(x + 1.0, 42 - up), Vector2(x + 4.5, 42)]), body.darkened(0.55), false)
	for x in [30.0, 66.0]:
		_line(ci, Vector2(x, 82), Vector2(x - 2, 99), body, 9.0)
		_poly(ci, PackedVector2Array([Vector2(x - 8, 99), Vector2(x - 8, 94), Vector2(x + 3, 94), Vector2(x + 3, 99)]), DARK, false)
	# The head: heavy, low, the snout flat and wide.
	_poly(ci, PackedVector2Array([Vector2(2, 70), Vector2(4, 58), Vector2(20, 42), Vector2(42, 38), Vector2(50, 56),
		Vector2(46, 78), Vector2(24, 82), Vector2(8, 78)]), body.lightened(0.05))
	_poly(ci, PackedVector2Array([Vector2(36, 40), Vector2(46, 26), Vector2(52, 44)]), body.darkened(0.25))
	_oval(ci, Vector2(5, 66), 5, 8, body.darkened(0.5), false)
	_dot(ci, Vector2(4, 64), 1.3, body.lightened(0.5))
	# Tusks: two curved ivory horns rising from the lower jaw.
	for d in [0.0, 7.0]:
		_poly(ci, PackedVector2Array([Vector2(10 + d, 78), Vector2(4 + d, 66), Vector2(8 + d, 56), Vector2(13 + d, 68)]), BONE)
	_dot(ci, Vector2(24, 54), 3.0, Color("f2e27a"))
	_dot(ci, Vector2(23, 54), 1.3, DARK)
	_line(ci, Vector2(17, 49), Vector2(30, 52), DARK, 2.0)
	_lines(ci, PackedVector2Array([Vector2(12, 76), Vector2(26, 76)]), DARK, 1.5)


## A dusky gnome in a floppy pointed hat, a grey beard, a dagger in one hand
## and a sack over the other shoulder.
static func _gnome(ci: CanvasItem, body: Color, a: float) -> void:
	var cloth := body.darkened(0.5)
	var bob := 0.0
	for x in [40.0, 56.0]:
		_line(ci, Vector2(x, 80), Vector2(x - 1, 96), cloth, 7.0)
		_oval(ci, Vector2(x - 5, 98), 7, 3.5, DARK, false)
	# The sack on the back, tied at the neck.
	_oval(ci, Vector2(70, 64 + bob), 15, 17, WOOD)
	_poly(ci, PackedVector2Array([Vector2(62, 50 + bob), Vector2(70, 42 + bob), Vector2(76, 52 + bob)]), WOOD)
	_line(ci, Vector2(62, 52 + bob), Vector2(76, 52 + bob), DARK, 2.0)
	_dot(ci, Vector2(70, 66 + bob), 3.0, GOLD)
	_poly(ci, PackedVector2Array([Vector2(32, 52 + bob), Vector2(62, 52 + bob), Vector2(66, 88), Vector2(28, 88)]), cloth)
	_line(ci, Vector2(30, 76), Vector2(64, 76), DARK, 3.0)
	_poly(ci, PackedVector2Array([Vector2(44, 74), Vector2(50, 74), Vector2(50, 79), Vector2(44, 79)]), GOLD, false)
	# The dagger arm, thrust forward.
	_line(ci, Vector2(36, 60 + bob), Vector2(22, 64 + bob), body, 6.0)
	_poly(ci, PackedVector2Array([Vector2(22, 62 + bob), Vector2(2, 54 + bob), Vector2(4, 59 + bob), Vector2(20, 68 + bob)]), STEEL)
	_line(ci, Vector2(22, 61 + bob), Vector2(21, 69 + bob), WOOD, 3.0)
	_dot(ci, Vector2(22, 65 + bob), 4.0, body)
	# The beard, then the head over it.
	_poly(ci, PackedVector2Array([Vector2(30, 46 + bob), Vector2(62, 46 + bob), Vector2(50, 72 + bob), Vector2(42, 66 + bob)]), Color("b8b4c0"))
	_oval(ci, Vector2(46, 38 + bob), 16, 15, body)
	_poly(ci, PackedVector2Array([Vector2(60, 34 + bob), Vector2(80, 24 + bob), Vector2(64, 44 + bob)]), body.darkened(0.05))
	_poly(ci, PackedVector2Array([Vector2(32, 38 + bob), Vector2(16, 46 + bob), Vector2(32, 47 + bob)]), body.lightened(0.12))
	_glow_eye(ci, Vector2(40, 33 + bob), 2.4, Color("d9a6ff"))
	_glow_eye(ci, Vector2(52, 33 + bob), 2.4, Color("d9a6ff"))
	_line(ci, Vector2(34, 26 + bob), Vector2(44, 29 + bob), DARK, 2.0)
	_line(ci, Vector2(50, 29 + bob), Vector2(58, 26 + bob), DARK, 2.0)
	# The hat: a floppy cone folding over at its tip.
	_poly(ci, PackedVector2Array([Vector2(26, 28 + bob), Vector2(62, 28 + bob), Vector2(56, 12 + bob), Vector2(44, 10 + bob)]), cloth.darkened(0.15))
	_poly(ci, PackedVector2Array([Vector2(44, 10 + bob), Vector2(56, 12 + bob), Vector2(74, 18 + bob), Vector2(78, 8 + bob),
		Vector2(62, 2 + bob)]), cloth.darkened(0.15))
	_line(ci, Vector2(24, 29 + bob), Vector2(64, 29 + bob), DARK, 3.5)
	_poly(ci, PackedVector2Array([Vector2(44, 20 + bob), Vector2(54, 20 + bob), Vector2(54, 26 + bob), Vector2(44, 26 + bob)]), GOLD.darkened(0.2), false)
