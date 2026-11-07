class_name IconShapes
extends RefCounted
## Shapes the drawn pictures of talents and items share (TalentIcon,
## ItemArt). Each draws in the space it's called in, so the caller sets the
## transform.


## A sword from `pommel` to `tip`, as the sword tile's (TileIcon), its blade
## `wide` times as broad.
static func sword(ci: CanvasItem, pommel: Vector2, tip: Vector2, col: Color, wide := 1.0) -> void:
	var length := pommel.distance_to(tip)
	var d := (tip - pommel) / length
	var n := Vector2(-d.y, d.x)
	var k := length / 63.0
	var guard := pommel + d * 19.0 * k
	var half := 6.0 * k * wide
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * 8.0 * k + n * half, guard + n * half,
		guard - n * half, tip - d * 8.0 * k - n * half]), col)
	ci.draw_line(guard + n * 14.0 * k, guard - n * 14.0 * k, col, 7.0 * k)
	ci.draw_line(guard, pommel + d * 3.0 * k, col, 6.0 * k)
	ci.draw_circle(pommel, 5.0 * k, col)


## A four-point twinkle, as the staff tile's.
static func twinkle(ci: CanvasItem, at: Vector2, big: float, small: float, col: Color) -> void:
	var star := PackedVector2Array()
	for i in 8:
		star.append(at + Vector2.from_angle(-PI / 2.0 + i * TAU / 8.0) * (big if i % 2 == 0 else small))
	ci.draw_colored_polygon(star, col)


## A cut from `a` to `b`: pointed at both ends and `half` wide each side of
## its middle, which bows `bow` off the straight line.
static func slash(ci: CanvasItem, a: Vector2, b: Vector2, half: float, bow: float, col: Color) -> void:
	var n := (b - a).orthogonal().normalized()
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(b, t) + n * (bow + half) * sin(t * PI))
	for i in range(steps - 1, 0, -1):
		var t := float(i) / steps
		pts.append(a.lerp(b, t) + n * (bow - half) * sin(t * PI))
	ci.draw_colored_polygon(pts, col)


## A flame standing on `base`, `k` times the size of the big one (62 tall).
static func flame(ci: CanvasItem, base: Vector2, k: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in [Vector2(2, -62), Vector2(13, -40), Vector2(20, -22), Vector2(18, -8), Vector2(9, 0),
			Vector2(-9, 0), Vector2(-18, -8), Vector2(-20, -24), Vector2(-13, -38), Vector2(-8, -28),
			Vector2(-5, -46)]:
		pts.append(base + p * k)
	ci.draw_colored_polygon(pts, col)


## A line with round ends.
static func stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float) -> void:
	ci.draw_polyline(pts, col, width)
	ci.draw_circle(pts[0], width * 0.5, col)
	ci.draw_circle(pts[pts.size() - 1], width * 0.5, col)


## A spike standing `from` to `to` out from `o` along `dir`, `half` wide
## each side at its foot.
static func spike(ci: CanvasItem, o: Vector2, dir: Vector2, from: float, to: float, half: float, col: Color) -> void:
	var side := dir.orthogonal() * half
	ci.draw_colored_polygon(PackedVector2Array([o + dir * from + side, o + dir * to, o + dir * from - side]), col)


## A hooded cloak seen from the front: `hem` its bottom edge, left to right.
static func cloak(ci: CanvasItem, hem: PackedVector2Array, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(-14, -7), Vector2(-16, -16), Vector2(-11, -27), Vector2(0, -31),
		Vector2(11, -27), Vector2(16, -16), Vector2(14, -7)])
	for i in range(hem.size() - 1, -1, -1):
		pts.append(hem[i])
	ci.draw_colored_polygon(pts, col)
