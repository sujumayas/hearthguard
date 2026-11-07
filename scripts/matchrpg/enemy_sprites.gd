class_name EnemySprites
extends Node
## Each enemy look's poses (EnemyLook), drawn once into a texture the first
## time it's asked for, so the runner draws an enemy as one textured quad.
## Drawn shape by shape every frame, an enemy cost 0.15 to 0.9 ms; the old
## box cost almost nothing. Until a look's texture is ready (a couple of
## frames, while it's still off screen), `draw` says so and the runner
## draws the shapes instead.
##
## A transparent viewport's pixels come out with their color already
## multiplied by their alpha, which would darken every soft edge and glow
## when drawn again. So each bake is drawn twice: once as shapes, then
## copied into a second viewport that divides the alpha back out.

## Pixels per point of the enemy's size, so they stay sharp on a phone.
const SCALE := 2.0
## Room around the look's rect, as a share of its size, for the horns,
## fins and tails that reach past it.
const MARGIN := 0.12

const UNPREMULTIPLY := """
shader_type canvas_item;
render_mode blend_disabled;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
"""

## Look and size to {"view": the SubViewport holding its poses, "ready"}.
var _bakes := {}
var _unpremultiply: ShaderMaterial


func _init() -> void:
	var shader := Shader.new()
	shader.code = UNPREMULTIPLY
	_unpremultiply = ShaderMaterial.new()
	_unpremultiply.shader = shader


## Draws pose `pose` of `look` filling `r` (in `ci`'s space, under `xf`),
## multiplied by `modulate`, and returns true; or starts baking it and
## returns false.
func draw(ci: CanvasItem, look: String, r: Rect2, color: Color, pose: int, modulate: Color, xf: Transform2D) -> bool:
	var key := "%s %dx%d" % [look, r.size.x, r.size.y]
	var bake: Dictionary = _bakes.get(key, {})
	if bake.is_empty():
		_bakes[key] = {"ready": false}
		# Not from inside a draw: the bake adds nodes.
		_bake.call_deferred(key, look, r.size, color)
		return false
	if not bake["ready"]:
		return false
	var cell: Vector2 = bake["cell"]
	var pad := r.size * MARGIN
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect_region((bake["view"] as SubViewport).get_texture(), Rect2(r.position - pad, r.size + pad * 2.0),
		Rect2(pose * cell.x, 0, cell.x, cell.y), modulate)
	return true


func _bake(key: String, look: String, size: Vector2, color: Color) -> void:
	var bake: Dictionary = _bakes[key]
	var cell := (size * (1.0 + MARGIN * 2.0) * SCALE).ceil()
	var poses: int = EnemyLook.pose_count(look)
	var px := Vector2i(int(cell.x) * poses, int(cell.y))
	var shapes := _view(px)
	var painter := Node2D.new()
	painter.draw.connect(func() -> void:
		for i in poses:
			var r := Rect2(Vector2(i * cell.x, 0) + size * MARGIN * SCALE, size * SCALE)
			EnemyLook.draw_pose(painter, look, r, color, i))
	shapes.add_child(painter)
	add_child(shapes)
	await RenderingServer.frame_post_draw
	var view := _view(px)
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


static func _view(px: Vector2i) -> SubViewport:
	var v := SubViewport.new()
	v.size = px
	v.transparent_bg = true
	v.render_target_update_mode = SubViewport.UPDATE_ONCE
	return v
