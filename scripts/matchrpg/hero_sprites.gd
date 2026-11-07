class_name HeroSprites
extends Node
## The hero's layers (HeroLook.Layer) drawn once per look into a texture,
## in each pose of the cloak. At rest, the runner draws the hero as one
## textured quad; during an attack, the body layer's quad and the arm,
## sword, shield and spell as shapes. Baked the way EnemySprites bakes, and
## for the same reason: shape by shape, the hero cost about 0.3 to 1 ms a
## frame. Until a look's texture is ready (a couple of frames), `draw` says
## so and HeroLook draws the shapes instead.

## Pixels per point of the hero's size, so it stays sharp on a phone.
const SCALE := 2.0

## Look to {"view": the SubViewport holding its poses, "ready"}.
var _bakes := {}
var _unpremultiply: ShaderMaterial


func _init() -> void:
	var shader := Shader.new()
	shader.code = EnemySprites.UNPREMULTIPLY
	_unpremultiply = ShaderMaterial.new()
	_unpremultiply.shader = shader


## Draws `layer` of the hero in `body` with `gear`, cloak pose `frame`, in
## the body's space (the caller has placed it), multiplied by `modulate`,
## and returns true; or starts baking it and returns false.
func draw(ci: CanvasItem, body: Color, gear: Array, layer: HeroLook.Layer, frame: int, modulate: Color) -> bool:
	var key := "%s %s" % [body.to_html(), ",".join(gear)]
	var bake: Dictionary = _bakes.get(key, {})
	if bake.is_empty():
		_bakes[key] = {"ready": false}
		# Not from inside a draw: the bake adds nodes.
		_bake.call_deferred(key, body, gear.duplicate())
		return false
	if not bake["ready"]:
		return false
	var cell: Vector2 = bake["cell"]
	var i := layer * HeroLook.POSES + frame % HeroLook.POSES
	ci.draw_texture_rect_region((bake["view"] as SubViewport).get_texture(), HeroLook.BODY_RECT,
		Rect2(i * cell.x, 0, cell.x, cell.y), modulate)
	return true


func _bake(key: String, body: Color, gear: Array) -> void:
	var bake: Dictionary = _bakes[key]
	var cell := (HeroLook.BODY_RECT.size * SCALE).ceil()
	var cells := HeroLook.POSES * HeroLook.Layer.size()
	var px := Vector2i(int(cell.x) * cells, int(cell.y))
	var shapes := EnemySprites._view(px)
	var painter := Node2D.new()
	painter.draw.connect(func() -> void:
		for i in cells:
			painter.draw_set_transform(Vector2(i * cell.x, 0) - HeroLook.BODY_RECT.position * SCALE, 0.0,
				Vector2(SCALE, SCALE))
			HeroLook.draw_layer(painter, body, gear, floori(i / float(HeroLook.POSES)) as HeroLook.Layer, i % HeroLook.POSES))
	shapes.add_child(painter)
	add_child(shapes)
	await RenderingServer.frame_post_draw
	var view := EnemySprites._view(px)
	var copy := Sprite2D.new()
	copy.centered = false
	copy.texture = shapes.get_texture()
	copy.material = _unpremultiply
	view.add_child(copy)
	add_child(view)
	await RenderingServer.frame_post_draw
	# The copy holds its pixels after its one update, so the shapes can go.
	copy.queue_free()
	shapes.queue_free()
	bake["view"] = view
	bake["cell"] = cell
	bake["ready"] = true
