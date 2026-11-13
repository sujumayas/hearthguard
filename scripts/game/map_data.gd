class_name MapData
extends RefCounted
## The one map: three corridors climbing from the worlds below, west, north
## and east, meet at the Crossroads, and one road runs south from there into
## the Town. The Town is open ground with MatchRPG's nine buildings laid out
## along its roads like a village (TownDefs), the Mage Tower at the back.
## Each corridor has two road fires (fire_spots).
## Each corridor is a winding passage with a chamber halfway (room to kite)
## and a narrow gate where it meets the Crossroads (a place to hold). A
## corridor only sends mobs while a player holds it: slot 0 is west, 1
## north, 2 east.
##
## The walkable ground is a grid of CELL pixels. Mobs read one flow field
## toward the nearest standing building (the AI study: one field per
## destination, so 500 mobs cost what one does). It is built again when a
## building falls. Heroes path with AStarGrid2D and smooth it.

const SIZE := Vector2(4000, 3400)
const CELL := 40.0
const CORRIDOR_W := 250.0
const GATE_W := 190.0
const CHAMBER_R := 230.0
## Where the three corridors meet, and the road from there into the Town.
const CROSSROADS := Vector2(2000, 1380)
const CROSSROADS_R := 210.0
const TOWN_ROAD_W := 280.0
## The Town's open ground, with rounded corners, and its square (where the
## road from the Crossroads meets the middle street): the market, where
## potions are sold.
const TOWN := Rect2(1130, 1700, 1740, 1420)
const TOWN_CORNER := 280.0
const SQUARE := Vector2(2000, 2410)

## Waypoints from the portal (first) to the Crossroads (last). The chamber is
## the waypoint at CHAMBER_AT; the gate is the last segment.
const CORRIDORS := [
	{"name": "West Passage", "points": [Vector2(140, 1300), Vector2(640, 1300), Vector2(900, 880), Vector2(1260, 960),
		Vector2(1420, 1260), Vector2(1800, 1380)]},
	{"name": "North Passage", "points": [Vector2(2000, 140), Vector2(2000, 440), Vector2(1640, 700), Vector2(1700, 950),
		Vector2(2000, 960), Vector2(2000, 1180)]},
	{"name": "East Passage", "points": [Vector2(3860, 1300), Vector2(3360, 1300), Vector2(3100, 880), Vector2(2740, 960),
		Vector2(2580, 1260), Vector2(2200, 1380)]},
]
const CHAMBER_AT := 2

var w: int
var h: int
var walk := PackedByteArray()
## Steps to the nearest standing building per cell (-1 where walls are), and each cell's flow.
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
	build_flow(TownDefs.ids())
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
	if TOWN.grow(40.0).has_point(p):
		# The Town's buildings are solid, ruins and all.
		if TownDefs.solid_at(p, 0.0) != "":
			return false
		if _in_town(p):
			return true
	if p.distance_to(CROSSROADS) < CROSSROADS_R:
		return true
	if _seg_dist(p, CROSSROADS, Vector2(CROSSROADS.x, TOWN.position.y + 60.0)) < TOWN_ROAD_W * 0.5:
		return true
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


## Inside the Town's rounded rectangle.
static func _in_town(p: Vector2) -> bool:
	if not TOWN.has_point(p):
		return false
	var inner := TOWN.grow(-TOWN_CORNER)
	var q := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
	return p.distance_to(q) <= TOWN_CORNER


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


## The direction the flow field says to walk from `p` toward the nearest
## standing building.
func flow_at(p: Vector2) -> Vector2:
	return flow[idx(p)]


func steps_to_town(p: Vector2) -> float:
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
	return SQUARE


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


## The flow toward the buildings in `standing` (ids): every mob walks to the
## nearest one. Built again by Sim when a building falls.
func build_flow(standing: Array) -> void:
	var n := w * h
	dist.resize(n)
	dist.fill(-1.0)
	flow.resize(n)
	flow.fill(Vector2.ZERO)
	# Dijkstra on 8 neighbors from the open cells round each standing building.
	var open: Array = []
	for id: String in standing:
		for i: int in _round_cells(id):
			if dist[i] < 0.0:
				dist[i] = 0.0
				open.append(i)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	# A plain queue is near enough: costs are 1 and 1.41.
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


## The open cells within a swing of building `id`, where its attackers stand.
var _round := {}


func _round_cells(id: String) -> Array:
	if _round.has(id):
		return _round[id]
	var out: Array = []
	var foot := TownDefs.foot(id)
	var reach := 45.0
	var lo := cell_of(foot - Vector2(TownDefs.SOLID_R + reach + 80.0, TownDefs.BODY + TownDefs.SOLID_R + reach + 80.0))
	var hi := cell_of(foot + Vector2(TownDefs.SOLID_R + reach + 80.0, TownDefs.SOLID_R + reach + 80.0))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var i := y * w + x
			if walk[i] == 1 and TownDefs.body_dist(id, Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)) < reach:
				out.append(i)
	_round[id] = out
	return out


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


## The road fires of corridor `slot`: one in its chamber, one where its
## gate begins. See Sim's road fires.
static func fire_spots(slot: int) -> Array:
	var pts: Array = CORRIDORS[slot]["points"]
	return [pts[CHAMBER_AT], pts[pts.size() - 2]]


static func portal(slot: int) -> Vector2:
	return CORRIDORS[slot]["points"][0]


## Where a hero of slot `slot` starts: in its corridor's gate.
static func hero_start(slot: int) -> Vector2:
	var pts: Array = CORRIDORS[slot]["points"]
	return (pts[pts.size() - 2] as Vector2).lerp(pts[pts.size() - 1], 0.7)
