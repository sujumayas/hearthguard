class_name Kept
extends RefCounted
## Circles, arcs, lines and filled shapes for what's drawn again while it's
## on screen: an effect, a flame, a mark on a tile. CanvasItem's own
## draw_circle, draw_arc, draw_polyline and draw_colored_polygon build a
## mesh each time they run, which a browser makes and throws away, a vertex
## array and two buffers apiece: thousands a second over a run, which a
## phone pays for in heat and memory. These draw the same shapes from a kept
## picture of a disc and from lines, triangles and quads, which need none.
## They take what the calls they replace do, after the CanvasItem.
##
## What's drawn once and kept (a bake, a still screen) can use either.
##
## Boxes go through `rect`, as draw_rect's do, with their corners rounded a
## little: nothing on the screen ends in a sharp corner. A StyleBoxFlat's
## round corners are a mesh too.
##
## Text that changes size goes through `text`: a font makes a new set of
## glyphs for every size it's asked for, pictures and all, and keeps them.
## A world boss's name card and countdown, drawn a pixel bigger each frame,
## made 36 sizes in ten seconds: 120 MB of the game's memory and 60 MB of
## textures, on top of everything else, and a phone's browser closed the
## page there.

## How wide the kept picture of a disc is.
const DISC_PX := 128
## How far an antialiased arc's edge fades out.
const FEATHER := 1.0

## How round a box's corners are, unless it asks.
const CORNER := 6.0

static var _disc: ImageTexture
## A box's corners as kept pictures, by their radius and line width (0 for
## a filled box): stretched as a nine-patch, they make a box of any size.
static var _corners := {}


## A filled circle. Its edge is soft by a pixel of the picture.
static func disc(ci: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	oval(ci, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), color)


## A filled oval, filling `rect`.
static func oval(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	if _disc == null:
		var img := Image.create(DISC_PX, DISC_PX, false, Image.FORMAT_RGBA8)
		var half := DISC_PX * 0.5
		for y in DISC_PX:
			for x in DISC_PX:
				var d := Vector2(x + 0.5 - half, y + 0.5 - half).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(half - d, 0.0, 1.0)))
		_disc = ImageTexture.create_from_image(img)
	ci.draw_texture_rect(_disc, rect, false, color)


## A rectangle with its corners rounded by `radius`, filled, or its outline
## `width` wide centered on its edge, as draw_rect's. A box too small for
## its corners has them as round as it can. From a kept picture of the
## corners, stretched as a nine-patch: no mesh, however big.
static func rect(ci: CanvasItem, r: Rect2, color: Color, filled := true, width := 1.0, radius := CORNER) -> void:
	if not filled:
		r = r.grow(width * 0.5)
	var fit := floorf(minf(r.size.x, r.size.y) * 0.5)
	var key := Vector2i(int(clampf(radius, 0.0, fit)), 0 if filled else maxi(roundi(minf(width, fit)), 1))
	if key.x == 0 and filled:
		ci.draw_rect(r, color)
		return
	if not _corners.has(key):
		_corners[key] = _bake_corners(key.x, key.y)
	var tex: ImageTexture = _corners[key]
	var edge := float(maxi(key.x, key.y))
	RenderingServer.canvas_item_add_nine_patch(ci.get_canvas_item(), r, Rect2(Vector2.ZERO, tex.get_size()),
		tex.get_rid(), Vector2(edge, edge), Vector2(edge, edge), RenderingServer.NINE_PATCH_STRETCH,
		RenderingServer.NINE_PATCH_STRETCH, true, color)


## A white box `radius` round, filled or a line `width` wide, as small as
## its corners and one pixel more each way, to be stretched (see `rect`).
static func _bake_corners(radius: int, width: int) -> ImageTexture:
	var edge := maxi(radius, width)
	var side := edge * 2 + 1
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var half := side * 0.5
	for y in side:
		for x in side:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(half, half)
			var cover := clampf(0.5 - _round_box(p, half, radius), 0.0, 1.0)
			if width > 0:
				cover *= 1.0 - clampf(0.5 - _round_box(p, half - width, maxi(radius - width, 0)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, cover))
	return ImageTexture.create_from_image(img)


## How far `p` is outside a square `half` wide each way round its middle,
## with corners `radius` round: below 0 inside.
static func _round_box(p: Vector2, half: float, radius: float) -> float:
	var q := p.abs() - Vector2(half - radius, half - radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius


## A filled shape of any outline, as triangles.
static func poly(ci: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray([color])
	var none := PackedVector2Array()
	if points.size() == 3:
		ci.draw_primitive(points, colors, none)
		return
	var corners := Geometry2D.triangulate_polygon(points)
	for i in range(0, corners.size(), 3):
		ci.draw_primitive(PackedVector2Array([points[corners[i]], points[corners[i + 1]], points[corners[i + 2]]]),
			colors, none)


## A line through `points`, a segment at a time.
static func path(ci: CanvasItem, points: PackedVector2Array, color: Color, width := 1.0, antialiased := false) -> void:
	for i in points.size() - 1:
		ci.draw_line(points[i], points[i + 1], color, width, antialiased)


## An arc of `width` round `at`, through `points` points, as quads joined
## edge to edge. Antialiased, its two edges fade out over a pixel.
static func arc(ci: CanvasItem, at: Vector2, r: float, from: float, to: float, points: int, color: Color,
		width := 1.0, antialiased := false) -> void:
	var colors := PackedColorArray([color])
	var clear := Color(color, 0.0)
	var fade_out := PackedColorArray([color, clear, clear, color])
	var none := PackedVector2Array()
	var inner := maxf(r - width * 0.5, 0.0)
	var outer := r + width * 0.5
	var last := Vector2.from_angle(from)
	for i in range(1, points):
		var next := Vector2.from_angle(lerpf(from, to, i / float(points - 1)))
		ci.draw_primitive(PackedVector2Array([at + last * inner, at + last * outer, at + next * outer, at + next * inner]),
			colors, none)
		if antialiased:
			ci.draw_primitive(PackedVector2Array([at + last * outer, at + last * (outer + FEATHER),
				at + next * (outer + FEATHER), at + next * outer]), fade_out, none)
			if inner > FEATHER:
				ci.draw_primitive(PackedVector2Array([at + last * inner, at + last * (inner - FEATHER),
					at + next * (inner - FEATHER), at + next * inner]), fade_out, none)
		last = next


## `text` drawn `size` tall with its baseline's left end at `at`, from the
## glyphs of the one size `made`, scaled: whatever `size` is, no new glyphs
## are made. Pick `made` at the biggest the text gets, so it's only ever
## scaled down. It sets the canvas's draw transform, and leaves it reset.
static func text(ci: CanvasItem, font: Font, at: Vector2, text: String, size: float, made: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var k := size / made
	ci.draw_set_transform(at, 0.0, Vector2(k, k))
	ci.draw_string(font, Vector2.ZERO, text, align, width / k if width > 0.0 else -1.0, made, color)
	ci.draw_set_transform(Vector2.ZERO)


## How wide `text` drawn that way is.
static func text_width(font: Font, text: String, size: float, made: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, made).x * size / made
