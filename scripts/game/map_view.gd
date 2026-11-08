class_name MapView
extends Node2D
## Draws the map in the chapter's world: MatchRPG's backdrop colors for the
## rock, the floor and its plants or bricks, the portals the mobs climb out
## of, the paths of the Town round the plaza and the Hearth's stones. Drawn once per
## chapter; the Hearth's fire and the portals' glow are drawn live by View.

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
		draw_circle(MapData.HEARTH, MapData.PLAZA_R + grow, col)
		for c: Dictionary in MapData.CORRIDORS:
			var pts: Array = c["points"]
			draw_circle(pts[MapData.CHAMBER_AT], MapData.CHAMBER_R + grow, col)
			draw_circle(pts[0], 170.0 + grow, col)
			for i in pts.size() - 1:
				var wdt := (MapData.GATE_W if i == pts.size() - 2 else MapData.CORRIDOR_W) + grow * 2.0
				draw_line(pts[i], pts[i + 1], col, wdt)
				draw_circle(pts[i + 1], wdt * 0.5, col)
	# A worn path down the middle of each corridor, toward the Hearth.
	for c: Dictionary in MapData.CORRIDORS:
		var pts: Array = c["points"]
		for i in pts.size() - 1:
			draw_line(pts[i], pts[i + 1], path_c, 70.0)
			draw_circle(pts[i + 1], 35.0, path_c)
		draw_line(pts[pts.size() - 1], MapData.HEARTH, path_c, 70.0)
	draw_circle(MapData.HEARTH, 260.0, path_c)
	# Speckle on the floor.
	for i in 2600:
		var p := Vector2(rng.randf() * MapData.SIZE.x, rng.randf() * MapData.SIZE.y)
		if not map.is_open(p):
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
		# Only on the rock right by the floor.
		if map.is_open(p) or not _near_floor(p, 70.0):
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


## The Town round the Hearth: a worn path from the Hearth to each building's
## door. The buildings themselves are drawn live by View (they grow as they
## level), and so is the Hearth's fire.
func _draw_town() -> void:
	var ch := ChapterDefs.get_def(chapter)
	var path_c: Color = ch["path"]
	# The town wall behind the southern row: a band of stone with a lit top.
	var band := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var a := deg_to_rad(lerpf(TownDefs.WALL_FROM, TownDefs.WALL_TO, float(i) / steps))
		band.append(MapData.HEARTH + Vector2.from_angle(a) * TownDefs.WALL_IN)
	for i in range(steps, -1, -1):
		var a := deg_to_rad(lerpf(TownDefs.WALL_FROM, TownDefs.WALL_TO, float(i) / steps))
		band.append(MapData.HEARTH + Vector2.from_angle(a) * (MapData.PLAZA_R + 30.0))
	draw_colored_polygon(band, Color("4a4540"))
	draw_polyline(band.slice(0, steps + 1), Color("6e6a64"), 10.0)
	for i in range(0, steps + 1, 2):
		var a := deg_to_rad(lerpf(TownDefs.WALL_FROM, TownDefs.WALL_TO, float(i) / steps))
		var at := MapData.HEARTH + Vector2.from_angle(a) * (TownDefs.WALL_IN + 22.0)
		draw_rect(Rect2(at - Vector2(14, 8), Vector2(28, 16)), Color("5c5650"))
	for id: String in TownDefs.ids():
		var door := TownDefs.door(id)
		draw_line(MapData.HEARTH, door, path_c, 56.0)
		draw_circle(door, 46.0, path_c)
		draw_circle(door, 30.0, path_c.lightened(0.06))
	# The Hearth's ring of stones.
	for k in 16:
		var p := MapData.HEARTH + Vector2.from_angle(k * TAU / 16.0) * 110.0
		draw_circle(p, 16.0, Color("6e6a64"))
		draw_circle(p + Vector2(-3, -4), 7.0, Color("8a857c"))
	draw_circle(MapData.HEARTH, 92.0, Color("2a2018"))
