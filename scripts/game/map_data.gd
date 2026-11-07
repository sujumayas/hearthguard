class_name MapData
extends RefCounted
## The one map: the Town's plaza with the Hearth in the middle, and three
## corridors climbing to it from the worlds below, west, north and east.
## Each corridor is a winding passage with a chamber halfway (room to kite)
## and a narrow gate where it meets the plaza (a place to hold). A corridor
## only sends mobs while a player holds it: slot 0 is west, 1 north, 2 east.
##
## The walkable ground is a grid of CELL pixels. Mobs read one flow field
## toward the Hearth (the AI study: one field per destination, so 500 mobs
## cost what one does); heroes path with AStarGrid2D and smooth it.

const SIZE := Vector2(4000, 3400)
const CELL := 40.0
const HEARTH := Vector2(2000, 2080)
const PLAZA_R := 560.0
const CORRIDOR_W := 250.0
const GATE_W := 190.0
const CHAMBER_R := 230.0

## Waypoints from the portal (first) to the plaza (last). The chamber is the
## waypoint at CHAMBER_AT; the gate is the last segment.
const CORRIDORS := [
	{"name": "West Passage", "points": [Vector2(140, 1300), Vector2(640, 1300), Vector2(900, 880), Vector2(1260, 960),
		Vector2(1300, 1720), Vector2(1540, 1930)]},
	{"name": "North Passage", "points": [Vector2(2000, 140), Vector2(2000, 440), Vector2(1640, 700), Vector2(1720, 1060),
		Vector2(2080, 1150), Vector2(2000, 1540)]},
	{"name": "East Passage", "points": [Vector2(3860, 1300), Vector2(3360, 1300), Vector2(3100, 880), Vector2(2740, 960),
		Vector2(2700, 1720), Vector2(2460, 1930)]},
]
const CHAMBER_AT := 2

var w: int
var h: int
var walk := PackedByteArray()
## Steps to the Hearth per cell (-1 where walls are), and each cell's flow.
var dist := PackedFloat32Array()
var flow := PackedVector2Array()
## Distance to the nearest wall per cell, in cells.
var clearance := PackedFloat32Array()
var astar := AStarGrid2D.new()


func _init() -> void:
	w = int(SIZE.x / CELL)
	h = int(SIZE.y / CELL)
	walk.resize(w * h)
	for y in h:
		for x in w:
			walk[y * w + x] = 1 if _open(Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)) else 0
	_build_flow()
	_build_clearance()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = Vector2(CELL, CELL) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in h:
		for x in w:
			if walk[y * w + x] == 0:
				astar.set_point_solid(Vector2i(x, y), true)


## Whether a point is open ground, from the shapes (used to build the grid).
static func _open(p: Vector2) -> bool:
	if p.distance_to(HEARTH) < PLAZA_R:
		return true
	# The Town's lane south of the plaza, a short dead end with the houses.
	for c: Dictionary in CORRIDORS:
		var pts: Array = c["points"]
		if p.distance_to(pts[CHAMBER_AT]) < CHAMBER_R:
			return true
		if p.distance_to(pts[0]) < 170.0:
			return true
		for i in pts.size() - 1:
			var half := (GATE_W if i == pts.size() - 2 else CORRIDOR_W) * 0.5
			if _seg_dist(p, pts[i], pts[i + 1]) < half:
				return true
	return false


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, w - 1), clampi(int(p.y / CELL), 0, h - 1))


func idx(p: Vector2) -> int:
	var c := cell_of(p)
	return c.y * w + c.x


func is_open(p: Vector2) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= SIZE.x or p.y >= SIZE.y:
		return false
	return walk[idx(p)] == 1


## Where a body at `from` ends up moving by `delta`: it slides along walls.
func slide(from: Vector2, delta: Vector2) -> Vector2:
	var to := from + delta
	if is_open(to):
		return to
	var tx := from + Vector2(delta.x, 0)
	if is_open(tx):
		return tx
	var ty := from + Vector2(0, delta.y)
	if is_open(ty):
		return ty
	return from


## The direction the flow field says to walk from `p` toward the Hearth.
func flow_at(p: Vector2) -> Vector2:
	return flow[idx(p)]


func steps_to_hearth(p: Vector2) -> float:
	return dist[idx(p)]


func clearance_at(p: Vector2) -> float:
	return clearance[idx(p)] * CELL


## The nearest open point to `p`.
func nearest_open(p: Vector2) -> Vector2:
	if is_open(p):
		return p
	var c := cell_of(p)
	for r in range(1, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var q := Vector2((c.x + dx + 0.5) * CELL, (c.y + dy + 0.5) * CELL)
				if is_open(q):
					return q
	return HEARTH


## Whether a straight walk from `a` to `b` stays on open ground.
func line_open(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / (CELL * 0.4)) + 1
	for i in n + 1:
		if not is_open(a.lerp(b, float(i) / n)):
			return false
	return true


## A smoothed walk from `a` to `b` (both moved onto open ground).
func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var from := cell_of(nearest_open(a))
	var goal := nearest_open(b)
	var to := cell_of(goal)
	if line_open(a, goal):
		return PackedVector2Array([goal])
	var raw := astar.get_point_path(from, to, true)
	if raw.is_empty():
		return PackedVector2Array([goal])
	raw[raw.size() - 1] = goal
	# Smooth: skip every point the line of sight reaches past.
	var out := PackedVector2Array()
	var at := a
	var i := 0
	while i < raw.size():
		var j := raw.size() - 1
		while j > i and not line_open(at, raw[j]):
			j -= 1
		out.append(raw[j])
		at = raw[j]
		i = j + 1
	return out


func _build_flow() -> void:
	var n := w * h
	dist.resize(n)
	dist.fill(-1.0)
	flow.resize(n)
	flow.fill(Vector2.ZERO)
	# Dijkstra on 8 neighbors from the Hearth's cells.
	var open: Array = []
	var start := cell_of(HEARTH)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := start + Vector2i(dx, dy)
			dist[c.y * w + c.x] = 0.0
			open.append(c.y * w + c.x)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	# A bucketed queue is enough: costs are 1 and 1.41.
	var head := 0
	while head < open.size():
		var cur: int = open[head]
		head += 1
		var cx := cur % w
		var cy := cur / w
		for d: Vector2i in dirs:
			var nx := cx + d.x
			var ny := cy + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if walk[ni] == 0:
				continue
			if d.x != 0 and d.y != 0 and (walk[cy * w + nx] == 0 or walk[ny * w + cx] == 0):
				continue
			var nd := dist[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
			if dist[ni] < 0.0 or nd < dist[ni] - 0.01:
				dist[ni] = nd
				open.append(ni)
	for y in h:
		for x in w:
			var i := y * w + x
			if dist[i] < 0.0:
				continue
			# The flow points down the distance's slope, averaged a little.
			var g := Vector2.ZERO
			for d: Vector2i in dirs:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nd := dist[ny * w + nx]
				if nd < 0.0:
					continue
				g += Vector2(d).normalized() * (dist[i] - nd)
			flow[i] = g.normalized()


func _build_clearance() -> void:
	clearance.resize(w * h)
	clearance.fill(999.0)
	var q: Array = []
	for i in w * h:
		if walk[i] == 0:
			clearance[i] = 0.0
			q.append(i)
	var head := 0
	while head < q.size():
		var cur: int = q[head]
		head += 1
		var cx := cur % w
		var cy := cur / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cx + d.x
			var ny := cy + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if clearance[ni] > clearance[cur] + 1.0:
				clearance[ni] = clearance[cur] + 1.0
				q.append(ni)


static func portal(slot: int) -> Vector2:
	return CORRIDORS[slot]["points"][0]


## Where a hero of slot `slot` starts: inside its corridor's gate.
static func hero_start(slot: int) -> Vector2:
	var pts: Array = CORRIDORS[slot]["points"]
	return (pts[pts.size() - 1] as Vector2).lerp(HEARTH, 0.35)
