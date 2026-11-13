class_name MapView
extends Node2D
## Draws the map in the chapter's world: MatchRPG's backdrop colors for the
## rock, the floor and its plants or bricks, the portals the mobs climb out
## of, the Crossroads, and the Town: night grass, its streets and the pines
## round it, as on MatchRPG's Town screen. Drawn once per chapter; the
## buildings and the portals' glow are drawn live by View.

var map: MapData
var chapter := 0
var active_lanes: Array = []


func setup(m: MapData, lanes: Array) -> void:
	map = m
	active_lanes = lanes
	queue_redraw()


func set_chapter(c: int) -> void:
	chapter = c
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var ch := ChapterDefs.get_def(chapter)
	var wall: Color = ch["wall"]
	var floor_c: Color = ch["floor"]
	var path_c: Color = ch["path"]
	var deco: Color = ch["deco"]
	draw_rect(Rect2(Vector2(-800, -800), MapData.SIZE + Vector2(1600, 1600)), wall.darkened(0.25))
	draw_rect(Rect2(Vector2.ZERO, MapData.SIZE), wall)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + chapter
	# The rock's texture: darker lumps everywhere off the paths.
	for i in 900:
		var p := Vector2(rng.randf() * MapData.SIZE.x, rng.randf() * MapData.SIZE.y)
		if map.is_open(p):
			continue
		draw_circle(p, rng.randf_range(20, 70), wall.darkened(rng.randf_range(0.05, 0.3)))
	# The floor: the open shapes, a lip of rock round them, then the ground.
	for pass_i in 2:
		var grow := 26.0 if pass_i == 0 else 0.0
		var col := deco.darkened(0.45) if pass_i == 0 else floor_c
		draw_circle(MapData.CROSSROADS, MapData.CROSSROADS_R + grow, col)
		draw_line(MapData.CROSSROADS, Vector2(MapData.CROSSROADS.x, MapData.TOWN.position.y + 60.0), col,
			MapData.TOWN_ROAD_W + grow * 2.0)
		for c: Dictionary in MapData.CORRIDORS:
			var pts: Array = c["points"]
			draw_circle(pts[MapData.CHAMBER_AT], MapData.CHAMBER_R + grow, col)
			draw_circle(pts[0], 170.0 + grow, col)
			for i in pts.size() - 1:
				var wdt := (MapData.GATE_W if i == pts.size() - 2 else MapData.CORRIDOR_W) + grow * 2.0
				draw_line(pts[i], pts[i + 1], col, wdt)
				draw_circle(pts[i + 1], wdt * 0.5, col)
	# A worn path down the middle of each corridor, to the Crossroads.
	for c: Dictionary in MapData.CORRIDORS:
		var pts: Array = c["points"]
		for i in pts.size() - 1:
			draw_line(pts[i], pts[i + 1], path_c, 70.0)
			draw_circle(pts[i + 1], 35.0, path_c)
		draw_line(pts[pts.size() - 1], MapData.CROSSROADS, path_c, 70.0)
	draw_circle(MapData.CROSSROADS, 90.0, path_c)
	# Speckle on the floor.
	for i in 2600:
		var p := Vector2(rng.randf() * MapData.SIZE.x, rng.randf() * MapData.SIZE.y)
		if not map.is_open(p) or MapData._in_town(p):
			continue
		draw_circle(p, rng.randf_range(1.5, 5.0), floor_c.lightened(rng.randf_range(0.03, 0.1)))
	_draw_world_deco(rng, deco, wall)
	_draw_town()
	# Closed corridors: rubble across the gate, so it reads as shut.
	for lane in 3:
		if lane in active_lanes:
			continue
		var pts: Array = MapData.CORRIDORS[lane]["points"]
		var a: Vector2 = pts[pts.size() - 2]
		var b: Vector2 = pts[pts.size() - 1]
		var mid := a.lerp(b, 0.7)
		var side := (b - a).normalized().orthogonal()
		for k in 9:
			var p := mid + side * (k - 4) * 26.0 + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
			draw_circle(p, rng.randf_range(18, 30), Color("4a4540"))
			draw_circle(p + Vector2(-5, -6), rng.randf_range(6, 12), Color("5c5650"))


## Each world's plants or stones along the corridor walls.
func _draw_world_deco(rng: RandomNumberGenerator, deco: Color, wall: Color) -> void:
	for i in 700:
		var p := Vector2(rng.randf() * MapData.SIZE.x, rng.randf() * MapData.SIZE.y)
		# Only on the rock right by the floor, and not by the Town (its pines).
		if map.is_open(p) or not _near_floor(p, 70.0) or MapData.TOWN.grow(140.0).has_point(p):
			continue
		match chapter:
			0:
				# The Forest: trees, dark canopies with a lit edge.
				draw_circle(p, rng.randf_range(30, 52), deco.darkened(0.2))
				draw_circle(p + Vector2(-8, -10), rng.randf_range(16, 28), deco)
				if rng.randf() < 0.15:
					draw_circle(p + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)), 3.0, Color(0.85, 1.0, 0.5, 0.7))
			1:
				# The Upper Dungeon: blocks of wall, and torches.
				var s := rng.randf_range(30, 56)
				draw_rect(Rect2(p - Vector2(s, s * 0.6) * 0.5, Vector2(s, s * 0.6)), deco)
				draw_rect(Rect2(p - Vector2(s, s * 0.6) * 0.5, Vector2(s, 4)), deco.lightened(0.15))
			2:
				# The Caves: crystal shards with a teal glow.
				var h := rng.randf_range(24, 60)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0), p + Vector2(0, -h), p + Vector2(12, 0)]), deco)
				if rng.randf() < 0.3:
					draw_circle(p + Vector2(0, -h * 0.5), 10.0, Color(0.35, 0.82, 0.75, 0.25))
					draw_circle(p + Vector2(0, -h * 0.5), 3.0, Color(0.6, 0.95, 0.9, 0.8))
			3:
				# The Drowned Temple: broken pillars and green flames.
				draw_rect(Rect2(p - Vector2(12, 40), Vector2(24, 40)), deco.lightened(0.1))
				draw_rect(Rect2(p - Vector2(16, 44), Vector2(32, 8)), deco.lightened(0.25))
				if rng.randf() < 0.2:
					draw_circle(p + Vector2(0, -52), 7.0, Color("8fe36a"))
			4:
				# The Plains of Hell: ash spires, hellfire at their feet.
				var h := rng.randf_range(30, 70)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 0), p + Vector2(-2, -h), p + Vector2(16, 0)]), deco.lightened(0.05))
				if rng.randf() < 0.25:
					draw_circle(p, 9.0, Color(0.54, 0.49, 1.0, 0.35))


func _near_floor(p: Vector2, r: float) -> bool:
	for a in 6:
		if map.is_open(p + Vector2.from_angle(a * TAU / 6.0) * r):
			return true
	return false


## The Town: night grass in its rounded square, the streets of TownDefs, the
## pines round its edge, grass tufts, and the market well in the square.
## The buildings themselves are drawn live by View (they grow as they
## level, and fall).
const GRASS := Color("2b3a2c")
const STREET := Color("5a534c")
const PINE := Color("1c2b22")


func _draw_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var box := MapData.TOWN
	var inner := box.grow(-MapData.TOWN_CORNER)
	# The grass: the rounded square as a cross of rects and four discs.
	for pass_i in 2:
		var grow := 22.0 if pass_i == 0 else 0.0
		var col := PINE.darkened(0.2) if pass_i == 0 else GRASS
		draw_rect(Rect2(box.position.x - grow, inner.position.y, box.size.x + grow * 2.0, inner.size.y), col)
		draw_rect(Rect2(inner.position.x, box.position.y - grow, inner.size.x, box.size.y + grow * 2.0), col)
		for c: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
			draw_circle(c, MapData.TOWN_CORNER + grow, col)
	# The road from the Crossroads reads as the Town's own street.
	draw_line(MapData.CROSSROADS, Vector2(MapData.CROSSROADS.x, box.position.y + 40.0), GRASS, MapData.TOWN_ROAD_W)
	# Grass tufts.
	for i in 900:
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if not MapData._in_town(p):
			continue
		var c := GRASS.darkened(rng.randf_range(0.1, 0.35))
		for k in 3:
			draw_line(p, p + Vector2((k - 1) * 5.0, -rng.randf_range(8, 15)), c, 2.0)
	# The streets.
	for st: Array in TownDefs.STREETS:
		var pts := PackedVector2Array(st)
		draw_polyline(pts, STREET.darkened(0.25), 84.0)
		for p: Vector2 in pts:
			draw_circle(p, 42.0, STREET.darkened(0.25))
	for st: Array in TownDefs.STREETS:
		var pts := PackedVector2Array(st)
		draw_polyline(pts, STREET, 70.0)
		for p: Vector2 in pts:
			draw_circle(p, 35.0, STREET)
	for id: String in TownDefs.ids():
		draw_circle(TownDefs.door(id), 40.0, STREET)
	# The market well in the square.
	var sq := MapData.SQUARE + Vector2(0, -10)
	Kept.oval(self, Rect2(sq - Vector2(46, 10), Vector2(92, 30)), Color(0, 0, 0, 0.3))
	draw_circle(sq, 34.0, Color("6e6a64"))
	draw_circle(sq, 24.0, Color("1a1820"))
	draw_line(sq + Vector2(-30, 0), sq + Vector2(-30, -56), Color("4a3424"), 6.0)
	draw_line(sq + Vector2(30, 0), sq + Vector2(30, -56), Color("4a3424"), 6.0)
	draw_colored_polygon(PackedVector2Array([sq + Vector2(-44, -50), sq + Vector2(0, -78), sq + Vector2(44, -50)]), Color("7a4a3a"))
	# Pines round the Town's edge, as on MatchRPG's Town screen.
	for i in 140:
		var a := rng.randf() * TAU
		var p := box.get_center() + Vector2(cos(a) * (box.size.x * 0.5 + 60.0), sin(a) * (box.size.y * 0.5 + 60.0))
		p += Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
		if map.is_open(p) or map.is_open(p + Vector2(0, 30)):
			continue
		_pine(p, rng.randf_range(0.8, 1.3))


func _pine(p: Vector2, k: float) -> void:
	draw_rect(Rect2(p + Vector2(-5, -6) * k, Vector2(10, 16) * k), Color("3a2a1c"))
	for t in 3:
		var w := (44.0 - t * 10.0) * k
		var y := p.y - (8.0 + t * 22.0) * k
		draw_colored_polygon(PackedVector2Array([Vector2(p.x - w * 0.5, y), Vector2(p.x, y - 34.0 * k), Vector2(p.x + w * 0.5, y)]),
			PINE.lightened(0.04 * t))
