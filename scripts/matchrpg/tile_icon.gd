class_name TileIcon
extends RefCounted
## The symbol on a tile: a sword, sparkles for magic, a shield, a kit of picks,
## a pouch of coins, a campfire for wood and a crystal for stone. Drawn in a
## dark shade of the tile's own color, so each tile reads by its shape as
## well as its color. Shared by the board, the HUD's counters and the
## menu's tile guide. Drawn in the icon's own space, 80 by 80 around its
## center, scaled to fit.

const SIZE := 80.0
const INK := Color(0.08, 0.06, 0.12)
## How far the ink is pulled toward INK from the tile color.
const INK_MIX := 0.85
## On a board tile, the symbol is the tile's color darkened this much.
const TILE_INK_DARK := 0.72
## The shield's face inside its ink outline, as a share of its size.
const SHIELD_INSET := 0.62
## The stump: its cut top's middle, half width and half height, how tall
## its side stands under the top, and its ink rim.
const STUMP_TOP := Vector2(0, -14)
const STUMP_R := Vector2(21, 9)
const STUMP_H := 26.0
const STUMP_RIM := 4.0
## The shield's ink rim, as wide all round, and the boss in its middle.
const SHIELD_RIM := 7.0
const SHIELD_BOSS := 8.0
## Where the shield's boss is.
const SHIELD_BOSS_AT := Vector2(0, -1)
## How deep the hollows of the shield's crest dip, and how far its middle
## point stands over its corners.
const SHIELD_HOLLOW := 5.0
const SHIELD_PEAK := 2.0
const SHIELD_BOSS_RIM := 4.6
## How much taller than wide the shield is drawn, over its first shape.
const SHIELD_TALL := 1.07
## And how much narrower.
const SHIELD_WIDE := 1.03
## The coins' stacks: x, y of the bottom coin, and how many coins; a coin's
## half width, thickness, and how flat it lies seen at an angle.
const COIN_STACKS := [Vector3(5.5, -5, 3), Vector3(-11, 9.5, 2), Vector3(12, 13, 1)]
const COIN_R := 16.0
const COIN_THICK := 8.0
const COIN_GAP := 3.5
## How far each coin up a stack sits off the one under it, so a stack
## leans a little this way and that rather than standing straight.
const COIN_JIGGLE := [0.0, 2.0, -1.5, 1.5, -2.0]
const COIN_RIM := 4.0
const COIN_TILT := 0.5
## The kit turned this much (a quarter turn back, so its tools hang down),
## and moved by this to stand in the middle of its tile.
const KIT_TURN := -PI / 4.0
const KIT_SHIFT := Vector2(-1.6, 4.6)
## The kit's ring, before it's turned: where it is, how round, how thick.
const KIT_RING := Vector2(15, -12)
const KIT_RING_R := 12.0
const KIT_RING_W := 6.35
## How thick the kit's tools are drawn.
const KIT_W := 5.6
## Where the kit's key ends.
const KEY_FOOT := Vector2(-15.2, 19.1)
## The stacks drawn this much taller than they're laid out.
const COIN_STRETCH := 1.1
## How far down the stacks sit in their tile.
const COIN_DOWN := 3.0


## Draws tile `t`'s symbol centered on `center`, `scale` times its usual
## size, on a tile of color `tile_color`. Tiles without a symbol draw
## nothing.
static func draw(ci: CanvasItem, t: int, center: Vector2, scale: float, tile_color: Color) -> void:
	# Solid ink, so overlapping strokes don't show seams.
	# The tile's own color, very dark.
	var ink := Color(tile_color.darkened(TILE_INK_DARK), 1.0)
	ci.draw_set_transform(center, 0.0, Vector2(scale, scale))
	match t:
		TileTypes.Type.SWORD:
			_sword(ci, ink)
		TileTypes.Type.STAFF:
			_sparkles(ci, ink)
		TileTypes.Type.SHIELD:
			_shield(ci, ink, tile_color.lightened(0.25))
		TileTypes.Type.KIT:
			_kit(ci, ink, tile_color)
		TileTypes.Type.GOLD:
			_coin_stacks(ci, ink, tile_color.lightened(0.3))
		TileTypes.Type.WOOD:
			_stump(ci, ink, tile_color.lightened(0.35))
		TileTypes.Type.STONE:
			_boulder(ci, ink, tile_color, tile_color.lightened(0.45))
	ci.draw_set_transform(Vector2.ZERO)


## Tile `t`'s symbol alone, off the board: in `ink`, with `face` where the
## tile's lighter parts are (the page behind it, to read as cut out), and no
## tile under it. Drawn once, on a still screen.
static func draw_glyph(ci: CanvasItem, t: int, center: Vector2, scale: float, ink: Color, face: Color) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(scale, scale))
	match t:
		TileTypes.Type.SWORD:
			_sword(ci, ink)
		TileTypes.Type.STAFF:
			_sparkles(ci, ink)
		TileTypes.Type.SHIELD:
			_shield(ci, ink, face)
		TileTypes.Type.KIT:
			_kit(ci, ink, face)
		TileTypes.Type.GOLD:
			_coin_stacks(ci, ink, face)
		TileTypes.Type.WOOD:
			_stump(ci, ink, face)
		TileTypes.Type.STONE:
			_boulder(ci, ink, face, face)
	ci.draw_set_transform(Vector2.ZERO)


## One sword, point up and to the right.
static func _sword(ci: CanvasItem, ink: Color) -> void:
	var d := Vector2(1, -1).normalized()
	var n := Vector2(-d.y, d.x)
	var guard := -d * 12.0
	ci.draw_colored_polygon(PackedVector2Array([d * 32.0, d * 24.0 + n * 6.0, guard + n * 6.0,
		guard - n * 6.0, d * 24.0 - n * 6.0]), ink)
	ci.draw_line(guard + n * 14.0, guard - n * 14.0, ink, 7.0)
	ci.draw_line(guard, -d * 28.0, ink, 6.0)
	ci.draw_circle(-d * 31.0, 5.0, ink)


## A big four-point twinkle with two small ones beside it.
static func _sparkles(ci: CanvasItem, ink: Color) -> void:
	_twinkle(ci, Vector2(-4, 1), 27.0, 7.0, ink)
	_twinkle(ci, Vector2(20, -20), 10.0, 3.0, ink)
	_twinkle(ci, Vector2(22, 20), 7.0, 2.0, ink)


static func _twinkle(ci: CanvasItem, at: Vector2, big: float, small: float, ink: Color) -> void:
	var star := PackedVector2Array()
	for i in 8:
		star.append(at + Vector2.from_angle(-PI / 2.0 + i * TAU / 8.0) * (big if i % 2 == 0 else small))
	ci.draw_colored_polygon(star, ink)


## A heater shield, its sides curving down to the point: filled with the
## lighter face and outlined in ink.
static func _shield(ci: CanvasItem, ink: Color, face: Color) -> void:
	var outer := _shield_shape(1.0)
	ci.draw_colored_polygon(outer, ink)
	# The face inset by the same width all round, top and sides alike.
	var inner := Geometry2D.offset_polygon(outer, -SHIELD_RIM)
	if not inner.is_empty():
		ci.draw_colored_polygon(inner[0], face)
	# A boss in the middle: its own ink round a middle in the shield's face.
	ci.draw_circle(SHIELD_BOSS_AT, SHIELD_BOSS, ink)
	ci.draw_circle(SHIELD_BOSS_AT, SHIELD_BOSS - SHIELD_BOSS_RIM, face)


## The shield's outline, `k` times its size about its middle: a crest of
## two hollows on top, straight sides, then curves meeting at the point.
static func _shield_shape(k: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var mid := Vector2(0, 0)
	# The top: a crest of two hollows, from each corner down and up again to
	# a point in the middle.
	for i in 17:
		var t := float(i) / 16.0
		var u := t * 2.0 if t < 0.5 else t * 2.0 - 1.0
		var rise := u if t < 0.5 else 1.0 - u
		pts.append(mid + Vector2(lerpf(-24, 24, t),
			lerpf(-25.0, -25.0 - SHIELD_PEAK, rise) + SHIELD_HOLLOW * sin(PI * u)) * k)
	pts.append(mid + Vector2(24, -4) * k)
	for i in range(1, 11):
		var t := float(i) / 10.0
		# From the right side's foot round to the point, bowing out.
		var a := Vector2(24, -4)
		var c := Vector2(22, 16)
		var b := Vector2(0, 28)
		pts.append(mid + a.lerp(c, t).lerp(c.lerp(b, t), t) * k)
	for i in range(1, 11):
		var t := float(i) / 10.0
		var a := Vector2(0, 28)
		var c := Vector2(-22, 16)
		var b := Vector2(-24, -4)
		pts.append(mid + a.lerp(c, t).lerp(c.lerp(b, t), t) * k)
	for i in pts.size():
		pts[i] *= Vector2(SHIELD_WIDE, SHIELD_TALL)
	return pts



## A trap kit: a ring of tools for a lock, at the top, and hanging down
## from it an old key, a pick with a hook, and a small hammer.
static func _kit(ci: CanvasItem, ink: Color, face: Color) -> void:
	# Laid out with the ring up on the right, then turned so the tools hang
	# down, and set in the middle of the tile.
	var xf := Transform2D(KIT_TURN, KIT_SHIFT)
	var ring := KIT_RING
	# The key, the longest, down to the left.
	var foot := KEY_FOOT
	var along := (foot - ring).normalized()
	var side := Vector2(along.y, -along.x)
	ci.draw_line(xf * (ring + along * KIT_RING_R), xf * foot, ink, KIT_W)
	for t: float in [3.0, 11.0]:
		var at := foot - along * t
		ci.draw_colored_polygon(xf * PackedVector2Array([at - along * 2.5, at + along * 2.5,
			at + along * 2.5 + side * 10.0, at - along * 2.5 + side * 10.0]), ink)
	# The pick, straight down, its tip hooked to the left.
	var pick_end := Vector2(11, 25)
	var down := (pick_end - ring).normalized()
	ci.draw_line(xf * (ring + down * KIT_RING_R), xf * pick_end, ink, KIT_W)
	ci.draw_line(xf * pick_end, xf * (pick_end + Vector2(-6, -4)), ink, KIT_W)
	ci.draw_circle(xf * pick_end, KIT_W * 0.5, ink)
	# A small hammer, out to the left: a handle, and its head across the end.
	var end := Vector2(-19, -9)
	var out := (end - ring).normalized()
	var norm := Vector2(out.y, -out.x)
	ci.draw_line(xf * (ring + out * KIT_RING_R), xf * end, ink, KIT_W)
	ci.draw_colored_polygon(xf * PackedVector2Array([end + norm * 8.0 - out * 2.0, end + norm * 8.0 + out * 5.0,
		end - norm * 6.0 + out * 5.0, end - norm * 6.0 - out * 2.0]), ink)
	# The ring over them all.
	ci.draw_circle(xf * ring, KIT_RING_R + KIT_RING_W * 0.5, ink)
	ci.draw_circle(xf * ring, KIT_RING_R - KIT_RING_W * 0.5, face)


## One coin, about the shield's size: a thick rim, a gap and a solid
## middle. Players found the pouch too busy on the board.
static func _ringed_coin(ci: CanvasItem, ink: Color) -> void:
	ci.draw_arc(Vector2.ZERO, 20.4, 0.0, TAU, 48, ink, 3.9, true)
	ci.draw_circle(Vector2.ZERO, 16.2, ink)


## A few short stacks of coins seen from above at an angle: each coin an
## edge in ink under a face in the lighter color, rimmed in ink. Back to
## front, so the nearer stacks stand over the far one.
static func _coin_stacks(ci: CanvasItem, ink: Color, face: Color) -> void:
	for n in COIN_STACKS.size():
		var st: Vector3 = COIN_STACKS[n]
		for i in int(st.z):
			var at := Vector2(st.x + COIN_JIGGLE[(i + n * 2) % COIN_JIGGLE.size()] * signf(i),
				(st.y - i * COIN_THICK) * COIN_STRETCH + COIN_DOWN)
			# The coin's edge, solid ink, then a gap of the face over the coin
			# under it, then its top: the stack reads by its gaps, as the kit's
			# picks do.
			var edge := (COIN_THICK - COIN_GAP) * COIN_STRETCH
			var tilt := COIN_TILT * COIN_STRETCH
			ci.draw_colored_polygon(_ellipse(at + Vector2(0, edge), COIN_R, tilt), ink)
			ci.draw_rect(Rect2(at.x - COIN_R, at.y, COIN_R * 2.0, edge), ink)
			ci.draw_colored_polygon(_ellipse(at, COIN_R, tilt), ink)
			ci.draw_colored_polygon(_ellipse(at, COIN_R - COIN_RIM, tilt), face)


## An ellipse round `at`, `r` wide and squashed as a coin lying flat seen
## at an angle.
static func _ellipse(at: Vector2, r: float, tilt := COIN_TILT) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(at + Vector2(cos(i * TAU / 20.0) * r, sin(i * TAU / 20.0) * r * tilt))
	return pts


## A rough rock, light catching its top. Players
## took the crystal for some other game's gems.
static func _boulder(ci: CanvasItem, ink: Color, _face: Color, light: Color) -> void:
	var rock := PackedVector2Array()
	for p: Vector2 in [Vector2(-1, 0.55), Vector2(-0.95, -0.2), Vector2(-0.5, -0.85), Vector2(0.25, -0.95),
			Vector2(0.85, -0.45), Vector2(1, 0.3), Vector2(0.6, 0.8), Vector2(-0.4, 0.85)]:
		rock.append(Vector2(0, 2) + p * Vector2(27, 25))
	ci.draw_colored_polygon(rock, ink)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-15, -10), Vector2(-4, -19), Vector2(8, -18),
		Vector2(2, -9), Vector2(-9, -5)]), light)


## The gold tile's symbol before the coin, kept while players vote
## between them (dev/coin_mockups.gd draws it beside the others).
## A drawstring pouch with three coins beside it: a round sack, a narrow
## neck tied with a cord whose ends hang down it, and a plain gathered mouth.
static func _pouch(ci: CanvasItem, ink: Color, face: Color) -> void:
	var o := Vector2(-9, -3)
	var body := PackedVector2Array()
	for i in 28:
		body.append(o + Vector2(0, 8) + Vector2(cos(i * TAU / 28.0) * 23.5, sin(i * TAU / 28.0) * 19.5))
	ci.draw_colored_polygon(body, ink)
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-18, -2), o + Vector2(-6, -17), o + Vector2(6, -17),
		o + Vector2(18, -2)]), ink)
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-6, -16), o + Vector2(-12, -26), o + Vector2(-4, -28),
		o + Vector2(4, -28), o + Vector2(12, -26), o + Vector2(6, -16)]), ink)
	ci.draw_line(o + Vector2(-9, -16), o + Vector2(9, -16), face, 3.5)
	ci.draw_line(o + Vector2(5, -15), o + Vector2(13, -2), face, 2.8)
	ci.draw_line(o + Vector2(5, -15), o + Vector2(4, 0), face, 2.8)
	ci.draw_circle(o + Vector2(13, -1), 3.2, face)
	ci.draw_circle(o + Vector2(4, 1), 3.2, face)
	_coin(ci, Vector2(20, 6), 12.0, ink, face)
	_coin(ci, Vector2(6, 21), 13.5, ink, face)
	_coin(ci, Vector2(26, 26), 9.0, ink, face)


## A coin face on, with a gap around it so it stands off what's behind.
static func _coin(ci: CanvasItem, c: Vector2, r: float, ink: Color, face: Color) -> void:
	ci.draw_circle(c, r + 3.0, face)
	ci.draw_circle(c, r, ink)
	ci.draw_arc(c, r * 0.55, 0.0, TAU, 24, face, 3.2, true)



## A tree stump: its cut top seen from a little above, with its rings, its
## bark side in ink, and roots spreading at its foot.
static func _stump(ci: CanvasItem, ink: Color, face: Color) -> void:
	var top := STUMP_TOP
	var foot := top + Vector2(0, STUMP_H)
	# Roots, under the rest: out to each side and one forward.
	for root: Array in [[Vector2(-STUMP_R.x + 3, foot.y - 10), Vector2(-STUMP_R.x - 10, foot.y + 8), Vector2(-6, foot.y + 4)],
			[Vector2(STUMP_R.x - 3, foot.y - 10), Vector2(STUMP_R.x + 11, foot.y + 6), Vector2(6, foot.y + 4)],
			[Vector2(-11, foot.y), Vector2(2, foot.y + 18), Vector2(13, foot.y)]]:
		ci.draw_colored_polygon(PackedVector2Array(root), ink)
	# The side, a little wider at its foot, and its round bottom.
	ci.draw_colored_polygon(PackedVector2Array([top - Vector2(STUMP_R.x, 0), top + Vector2(STUMP_R.x, 0),
		foot + Vector2(STUMP_R.x + 3, 0), foot - Vector2(STUMP_R.x + 3, 0)]), ink)
	ci.draw_colored_polygon(_oval(foot, STUMP_R + Vector2(3, 0)), ink)
	# The cut top: ink rim, face, a ring and the heart.
	ci.draw_colored_polygon(_oval(top, STUMP_R), ink)
	ci.draw_colored_polygon(_oval(top, STUMP_R - Vector2(STUMP_RIM, STUMP_RIM * 0.6)), face)
	ci.draw_polyline(_oval(top, (STUMP_R - Vector2(STUMP_RIM, STUMP_RIM * 0.6)) * 0.55, true), ink, 2.0)
	ci.draw_colored_polygon(_oval(top, Vector2(2.6, 1.6)), ink)


## An oval round `at`, `r` its half width and half height; `closed` ends it
## where it began, for a line.
static func _oval(at: Vector2, r: Vector2, closed := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(at + Vector2(cos(i * TAU / 24.0) * r.x, sin(i * TAU / 24.0) * r.y))
	if closed:
		pts.append(pts[0])
	return pts


## Two crossed logs with a small flame on top.
static func _campfire(ci: CanvasItem, ink: Color, glow: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var end := Vector2(22 * sx, 8)
		ci.draw_line(Vector2(-26 * sx, 26), end, ink, 9.0)
		ci.draw_circle(end, 4.5, ink)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -28), Vector2(9, -14), Vector2(12, -2),
		Vector2(8, 8), Vector2(-8, 8), Vector2(-12, -2), Vector2(-7, -10), Vector2(-4, -4)]), ink)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(5, 0), Vector2(4, 6),
		Vector2(-4, 6), Vector2(-5, 0)]), glow)


## The stone tile's symbol before the rock, kept while players vote
## between them (dev/stone_mockups.gd draws it beside the others).
## A six-sided crystal with light catching one face.
static func _crystal(ci: CanvasItem, ink: Color, light: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -30), Vector2(16, -14), Vector2(16, 18),
		Vector2(0, 30), Vector2(-16, 18), Vector2(-16, -14)]), ink)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(9, -12), Vector2(9, 14),
		Vector2(0, 20)]), light)
