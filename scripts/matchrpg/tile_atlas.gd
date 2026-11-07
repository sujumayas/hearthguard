class_name TileAtlas
extends RefCounted
## The one piece of MatchRPG's TileAtlas the talent icons draw with: a
## rounded box. Copied as-is from matchRPG/scripts/board/tile_atlas.gd.

static var _round := StyleBoxFlat.new()


static func rounded(ci: CanvasItem, r: Rect2, radius: float, color: Color, width := 0.0) -> void:
	_round.bg_color = color if width <= 0.0 else Color.TRANSPARENT
	_round.draw_center = width <= 0.0
	_round.border_color = color
	_round.set_border_width_all(int(ceilf(width)))
	_round.set_corner_radius_all(int(radius))
	_round.anti_aliasing = true
	ci.draw_style_box(_round, r)
