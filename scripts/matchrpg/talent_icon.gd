class_name TalentIcon
extends RefCounted
## A talent's own picture (see RowDefs), and the frame it sits in. Drawn as
## a tile's symbol is (TileIcon): in a dark shade of the color it's on, its
## branch's, with a pale shade for what catches the light, in the same 80
## by 80 space around its center. A talent with no picture of its own (one
## the rows don't use) gets its branch's symbol.
##
## The bottom right corner is kept clear: the fan puts a talent's row
## there (TalentFan.RANK).

const INK := Color("15121c")
## (Hearthguard) The branch whose symbol a talent with no picture gets,
## set by the caller in place of MatchRPG's RowDefs lookup.
static var fallback_branch := "blade"
## How far the pale shade is pulled toward white from the color it's on.
const LIT := 0.6
## (Hearthguard: `framed` is left out; it needs MatchRPG's RowDefs and UiTheme.)
## The talents with a picture of their own: the rows'.
const PICTURES := ["cleave", "first_blood", "drive", "onslaught", "honed", "transmute", "wildfire", "stasis",
	"time_stop", "meteor", "dirty_fighting", "second_wind", "outrun", "flurry", "unstoppable"]
## Each branch's tile, for its symbol. Flow has none: its symbol is two
## links of a chain.
const SYMBOL := {"blade": TileTypes.Type.SWORD, "arcane": TileTypes.Type.STAFF}


## Draws talent `id`'s picture centered on `center`, `scale` times its usual
## size, on color `on`.
static func draw(ci: CanvasItem, id: String, center: Vector2, scale: float, on: Color) -> void:
	# Solid ink, so overlapping strokes don't show seams.
	var ink := Color(on.lerp(TileIcon.INK, TileIcon.INK_MIX), 1.0)
	var lit := Color(on.lerp(Color.WHITE, LIT), 1.0)
	ci.draw_set_transform(center, 0.0, Vector2(scale, scale))
	match id:
		"cleave":
			_cleave(ci, ink, lit)
		"first_blood":
			_first_blood(ci, ink, lit)
		"drive":
			_drive(ci, ink)
		"onslaught":
			_onslaught(ci, ink, on)
		"honed":
			_honed(ci, ink, lit)
		"transmute":
			_transmute(ci, ink, lit)
		"wildfire":
			_wildfire(ci, ink, lit)
		"stasis":
			_stasis(ci, ink, lit)
		"time_stop":
			_time_stop(ci, ink, lit)
		"meteor":
			_meteor(ci, ink, lit)
		"dirty_fighting":
			_dirty_fighting(ci, ink, lit)
		"second_wind":
			_second_wind(ci, ink)
		"outrun":
			_outrun(ci, ink, lit)
		"flurry":
			_flurry(ci, ink)
		"unstoppable":
			_unstoppable(ci, ink, lit)
		_:
			ci.draw_set_transform(Vector2.ZERO)
			branch(ci, fallback_branch, center, scale, on)
			return
	ci.draw_set_transform(Vector2.ZERO)


## Whether talent `id` has a picture of its own.
static func has(id: String) -> bool:
	return id in PICTURES


## A branch's symbol centered on `center`, on color `on`: its tile's, or for
## Flow two links of a chain.
static func branch(ci: CanvasItem, branch_id: String, center: Vector2, scale: float, on: Color) -> void:
	if SYMBOL.has(branch_id):
		TileIcon.draw(ci, SYMBOL[branch_id], center, scale, on)
		return
	var ink := Color(on.lerp(TileIcon.INK, TileIcon.INK_MIX), 1.0)
	ci.draw_set_transform(center, -0.5, Vector2(scale, scale))
	for x: float in [-13.0, 13.0]:
		ci.draw_arc(Vector2(x, 0), 17.0, 0.0, TAU, 28, ink, 8.0, true)
	ci.draw_set_transform(Vector2.ZERO)


# Blade

## A sword brought down through a tile, its halves falling away.
static func _cleave(ci: CanvasItem, ink: Color, lit: Color) -> void:
	# Half the tile, from the foot of its cut edge round its two corners.
	var half := PackedVector2Array([Vector2(0, 0), Vector2(0, -36)])
	for i in 5:
		half.append(Vector2(10, -28) + Vector2.from_angle((i - 4) * PI / 8.0) * 8.0)
	for i in 5:
		half.append(Vector2(10, -8) + Vector2.from_angle(i * PI / 8.0) * 8.0)
	for side: float in [-1.0, 1.0]:
		var fallen := PackedVector2Array()
		for p in half:
			fallen.append(Vector2(side * 10.5, 21) + Vector2(p.x * side, p.y).rotated(side * 0.2))
		ci.draw_colored_polygon(fallen, ink)
	IconShapes.sword(ci, Vector2(0, -38), Vector2(0, 30), ink, 1.15)
	ci.draw_line(Vector2(0, -9), Vector2(0, 17), lit, 3.0)


## A sword held point down, and the first drop off it.
static func _first_blood(ci: CanvasItem, ink: Color, lit: Color) -> void:
	IconShapes.sword(ci, Vector2(26, -30), Vector2(-10, 8), ink)
	var drop := Vector2(-19, 21)
	ci.draw_colored_polygon(PackedVector2Array([drop + Vector2(-8.5, -2), drop + Vector2(2, -19), drop + Vector2(8.5, -2)]), ink)
	ci.draw_circle(drop, 9.5, ink)
	ci.draw_circle(drop + Vector2(-3, 1), 3.0, lit)


## A thrust, and the ground it gains.
static func _drive(ci: CanvasItem, ink: Color) -> void:
	IconShapes.sword(ci, Vector2(-32, -12), Vector2(34, -12), ink)
	for i in 3:
		var x := -22.0 + i * 20.0
		ci.draw_polyline(PackedVector2Array([Vector2(x, 6), Vector2(x + 11, 17), Vector2(x, 28)]), ink, 7.0)


## Two swords crossed.
static func _onslaught(ci: CanvasItem, ink: Color, on: Color) -> void:
	IconShapes.sword(ci, Vector2(-27, 27), Vector2(27, -27), ink)
	# A gap round the one on top, so they read as two.
	ci.draw_line(Vector2(9, 9), Vector2(-9, -9), on, 21.0)
	IconShapes.sword(ci, Vector2(27, 27), Vector2(-27, -27), ink)


## A sword stood point up, its edge catching the light.
static func _honed(ci: CanvasItem, ink: Color, lit: Color) -> void:
	IconShapes.sword(ci, Vector2(-4, 33), Vector2(-4, -34), ink, 1.25)
	ci.draw_line(Vector2(-4, -22), Vector2(-4, 8), lit, 3.0)
	IconShapes.twinkle(ci, Vector2(18, -20), 14.0, 3.5, ink)
	IconShapes.twinkle(ci, Vector2(-25, -4), 8.0, 2.2, ink)


# Arcane

## A tile turned to magic.
static func _transmute(ci: CanvasItem, ink: Color, lit: Color) -> void:
	TileAtlas.rounded(ci, Rect2(-30, -22, 50, 50), 11.0, ink)
	IconShapes.twinkle(ci, Vector2(-5, 3), 21.0, 5.0, lit)
	IconShapes.twinkle(ci, Vector2(26, -24), 11.0, 3.0, ink)


## A fire, and the one it starts beside it.
static func _wildfire(ci: CanvasItem, ink: Color, lit: Color) -> void:
	IconShapes.flame(ci, Vector2(-8, 28), 1.0, ink)
	IconShapes.flame(ci, Vector2(-8, 26), 0.48, lit)
	IconShapes.flame(ci, Vector2(22, 28), 0.5, ink)


## An hourglass, its sand barely falling.
static func _stasis(ci: CanvasItem, ink: Color, lit: Color) -> void:
	ci.draw_line(Vector2(-20, -28), Vector2(20, -28), ink, 7.0)
	ci.draw_line(Vector2(-20, 28), Vector2(20, 28), ink, 7.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-16, -26), Vector2(16, -26), Vector2(3.5, 0), Vector2(16, 26),
		Vector2(-16, 26), Vector2(-3.5, 0)]), ink)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, -19), Vector2(9, -19), Vector2(0, -3)]), lit)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 22), Vector2(10, 22), Vector2(0, 13)]), lit)


## A stopwatch that was stopped.
static func _time_stop(ci: CanvasItem, ink: Color, lit: Color) -> void:
	ci.draw_rect(Rect2(-5, -35, 10, 10), ink)
	ci.draw_line(Vector2(-10, -34), Vector2(10, -34), ink, 5.0)
	ci.draw_line(Vector2(17, -22), Vector2(23, -28), ink, 6.0)
	ci.draw_circle(Vector2(0, 4), 27.0, ink)
	ci.draw_circle(Vector2(0, 4), 20.0, lit)
	ci.draw_rect(Rect2(-10, -7, 7, 22), ink)
	ci.draw_rect(Rect2(3, -7, 7, 22), ink)


## A rock coming down, its fire behind it.
static func _meteor(ci: CanvasItem, ink: Color, lit: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-25, 2), Vector2(4, -20), Vector2(34, -34), Vector2(20, -6),
		Vector2(-2, 25)]), ink)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 4), Vector2(24, -26), Vector2(-2, 12)]), lit)
	ci.draw_circle(Vector2(-13, 13), 15.0, ink)
	ci.draw_circle(Vector2(-17, 10), 4.0, lit)
	ci.draw_circle(Vector2(-8, 19), 2.5, lit)


# Flow

## A fist.
static func _dirty_fighting(ci: CanvasItem, ink: Color, lit: Color) -> void:
	# Knuckles, a finger each, over the back of the hand and the wrist.
	for i in 4:
		ci.draw_circle(Vector2(-17.0 + i * 10.5, -12), 6.5, ink)
	ci.draw_rect(Rect2(-23.5, -12, 44.5, 26), ink)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-17, 12), Vector2(15, 12), Vector2(12, 32), Vector2(-14, 32)]), ink)
	for i in 3:
		ci.draw_line(Vector2(-11.75 + i * 10.5, -15), Vector2(-11.75 + i * 10.5, -2), lit, 2.5)
	# The thumb, folded across them.
	ci.draw_polyline(PackedVector2Array([Vector2(-23, 1), Vector2(8, 1), Vector2(14, 7), Vector2(8, 13)]), lit, 3.0)
	# What it lands.
	for a: float in [-1.15, -0.6, -0.05]:
		var d := Vector2.from_angle(a)
		ci.draw_line(Vector2(18, -14) + d * 12.0, Vector2(18, -14) + d * 22.0, ink, 5.0)


## Gusts of wind.
static func _second_wind(ci: CanvasItem, ink: Color) -> void:
	_gust(ci, Vector2(-32, -9), 38.0, 9.0, -1.0, ink)
	_gust(ci, Vector2(-34, 6), 56.0, 8.0, 1.0, ink)
	_gust(ci, Vector2(-22, 22), 20.0, 0.0, 1.0, ink)


## A boot with a wing at its heel.
static func _outrun(ci: CanvasItem, ink: Color, lit: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -24), Vector2(13, -24), Vector2(13, 2), Vector2(27, 9),
		Vector2(32, 17), Vector2(32, 26), Vector2(-4, 26)]), ink)
	ci.draw_line(Vector2(-4, 19), Vector2(32, 19), lit, 2.5)
	ci.draw_line(Vector2(-4, -15), Vector2(13, -15), lit, 2.5)
	# Three feathers, fanned back from the ankle.
	for feather: Array in [[-8.0, Vector2(-37, -25), 4.0], [-2.0, Vector2(-38, -9), 10.0], [4.0, Vector2(-32, 6), 16.0]]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-2, feather[0]), feather[1], Vector2(-2, feather[2])]), ink)


## Three cuts at once.
static func _flurry(ci: CanvasItem, ink: Color) -> void:
	IconShapes.slash(ci, Vector2(-33, 14), Vector2(-9, -30), 5.0, 3.0, ink)
	IconShapes.slash(ci, Vector2(-17, 30), Vector2(13, -32), 6.5, 3.0, ink)
	IconShapes.slash(ci, Vector2(6, 26), Vector2(30, -18), 5.0, 3.0, ink)


## A chain with no end to it.
static func _unstoppable(ci: CanvasItem, ink: Color, lit: Color) -> void:
	var loop := PackedVector2Array()
	for i in 49:
		var t := i * TAU / 48.0
		var k := 34.0 / (1.0 + sin(t) * sin(t))
		loop.append(Vector2(cos(t) * k, sin(t) * cos(t) * k * 1.25 - 2.0))
	ci.draw_polyline(loop, ink, 10.0)
	ci.draw_polyline(loop, lit, 2.5)
	IconShapes.twinkle(ci, Vector2(0, -27), 9.0, 2.5, ink)


# Shapes

## A gust from `from`, `length` long, that curls round at its end: up for a
## `turn` of -1, down for 1. `curl` is the curl's radius, 0 for none.
static func _gust(ci: CanvasItem, from: Vector2, length: float, curl: float, turn: float, ink: Color) -> void:
	var pts := PackedVector2Array([from])
	var end := from + Vector2(length, 0)
	if curl > 0.0:
		var c := end + Vector2(0, curl * turn)
		for i in 15:
			var a := -turn * PI / 2.0 + turn * i * (PI * 1.6) / 14.0
			pts.append(c + Vector2.from_angle(a) * curl)
	else:
		pts.append(end)
	IconShapes.stroke(ci, pts, ink, 7.0)
