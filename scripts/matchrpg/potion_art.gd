class_name PotionArt
extends RefCounted
## MatchRPG's potion symbols, copied as-is from matchRPG/scripts/ui/potion_slot.gd
## (PotionSlot.draw_symbol and its helpers), so the belt shows the same potions.

const INK := Color(0.08, 0.06, 0.12)
const HEART_POINTS := 40


## The symbol of a potion of `kind` (its group, or its id), filling a circle
## of radius `r` round `c`.
static func draw_symbol(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color) -> void:
	var w := r * 0.18
	match kind:
		"health":
			# One outline, the classic heart curve, so its lobes and point
			# meet with no seam or notch between pieces.
			var heart: Array[Vector2] = []
			for k in HEART_POINTS:
				var t := k * TAU / HEART_POINTS
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				heart.append(c + Vector2(16.0 * pow(sin(t), 3.0), -y - 2.5) * r * 0.06)
			_poly(ci, heart, col)
		"explosive":
			var pts: Array[Vector2] = []
			for k in 16:
				var a := k * PI / 8.0 + 0.2
				pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 if k % 2 == 0 else 0.46))
			_poly(ci, pts, col)
		"freeze":
			for k in 3:
				var d := Vector2.from_angle(k * PI / 3.0 + PI / 2.0) * r
				ci.draw_line(c - d, c + d, col, w, true)
				for s: float in [-1.0, 1.0]:
					var p := c + d * 0.55 * s
					ci.draw_line(p, p + (d * 0.36 * s).rotated(0.8), col, w * 0.8, true)
					ci.draw_line(p, p + (d * 0.36 * s).rotated(-0.8), col, w * 0.8, true)
		"surge":
			_poly(ci, [c + Vector2(0.25, -1) * r, c + Vector2(-0.55, 0.1) * r, c + Vector2(-0.05, 0.1) * r,
				c + Vector2(-0.3, 1) * r, c + Vector2(0.55, -0.15) * r, c + Vector2(0.05, -0.15) * r], col)
		"reroll":
			for k in 2:
				var a0 := PI * k + 0.35
				var a1 := a0 + PI * 0.72
				Kept.arc(ci, c, r * 0.7, a0, a1, 16, col, w * 1.1, true)
				var tip := c + Vector2.from_angle(a1) * r * 0.7
				var along := Vector2.from_angle(a1 + PI / 2.0)
				var out := Vector2.from_angle(a1)
				_poly(ci, [tip + along * r * 0.42, tip + out * r * 0.32, tip - out * r * 0.32], col)
		"meteor":
			# A rock, its fiery tail behind it.
			var rock := c + Vector2(-0.38, 0.38) * r
			var d := Vector2(1, -1).normalized()
			var n := d.orthogonal()
			_poly(ci, [rock + n * r * 0.5, rock + d * r * 1.75, rock - n * r * 0.5], Color(col, 0.55))
			_poly(ci, [rock + n * r * 0.3, rock + d * r * 1.35, rock - n * r * 0.3], Color(col.lightened(0.4), 0.8))
			Kept.disc(ci, rock, r * 0.5, col)
			Kept.disc(ci, rock + Vector2(-0.12, 0.1) * r, r * 0.13, Color(INK, 0.45))
		"shatter":
			var a := Vector2(-0.14, 0.06) * r
			var b := Vector2(0.14, -0.06) * r
			_poly(ci, [c + a + Vector2(-0.78, -0.78) * r, c + a + Vector2(0.08, -0.78) * r,
				c + a + Vector2(-0.14, -0.28) * r, c + a + Vector2(0.14, 0.12) * r,
				c + a + Vector2(-0.1, 0.78) * r, c + a + Vector2(-0.78, 0.78) * r], col)
			_poly(ci, [c + b + Vector2(0.08, -0.78) * r, c + b + Vector2(0.78, -0.78) * r,
				c + b + Vector2(0.78, 0.78) * r, c + b + Vector2(-0.1, 0.78) * r,
				c + b + Vector2(0.14, 0.12) * r, c + b + Vector2(-0.14, -0.28) * r], col)
		"harvest":
			ci.draw_line(c + Vector2(0, 0.9) * r, c + Vector2(0, -0.15) * r, col, w, true)
			ci.draw_line(c + Vector2(-0.6, 0.9) * r, c + Vector2(0.6, 0.9) * r, col, w, true)
			_leaf(ci, c, c + Vector2(-0.9, -0.55) * r, r, col)
			_leaf(ci, c + Vector2(0, -0.2) * r, c + Vector2(0.9, -0.85) * r, r, col)
		"paint":
			ci.draw_line(c + Vector2(0.88, -0.88) * r, c + Vector2(0.1, -0.1) * r, col, w * 1.3, true)
			_poly(ci, [c + Vector2(0.18, -0.02) * r, c + Vector2(-0.02, 0.18) * r, c + Vector2(-0.62, 0.62) * r,
				c + Vector2(-0.3, 0.05) * r], col)
			_poly(ci, [c + Vector2(0.18, -0.02) * r, c + Vector2(-0.02, 0.18) * r, c + Vector2(-0.62, 0.62) * r,
				c + Vector2(-0.05, 0.3) * r], col)
			ci.draw_line(c + Vector2(-0.95, 0.88) * r, c + Vector2(0.55, 0.88) * r, col, w * 1.3, true)
		"stun":
			# Stars circling a dazed head.
			for k in 3:
				var a := PI * (0.95 + 0.55 * k)
				_twinkle(ci, c + Vector2(cos(a) * 0.62, sin(a) * 0.36 - 0.25) * r, r * (0.42 if k == 1 else 0.32), col)
			Kept.disc(ci, c + Vector2(0, 0.42) * r, 0.42 * r, col)
		"dawn":
			# A half sun on the horizon, rays above it.
			var sun: Array[Vector2] = []
			for k in 13:
				var a := PI + k * PI / 12.0
				sun.append(c + Vector2(0, 0.45) * r + Vector2(cos(a), sin(a)) * 0.6 * r)
			_poly(ci, sun, col)
			ci.draw_line(c + Vector2(-0.95, 0.55) * r, c + Vector2(0.95, 0.55) * r, col, w * 1.3, true)
			for k in 5:
				var d := Vector2.from_angle(PI + (k + 0.5) * PI / 5.0)
				ci.draw_line(c + Vector2(0, 0.45) * r + d * 0.8 * r, c + Vector2(0, 0.45) * r + d * 1.1 * r, col, w, true)
		"aegis":
			_poly(ci, [c + Vector2(-0.8, -0.85) * r, c + Vector2(0.8, -0.85) * r, c + Vector2(0.8, 0.05) * r,
				c + Vector2(0, 0.98) * r, c + Vector2(-0.8, 0.05) * r], col)
			# A plus on the shield.
			var arm := r * 0.38
			var thick := r * 0.16
			var mid := c + Vector2(0, -0.05) * r
			ci.draw_rect(Rect2(mid - Vector2(arm, thick * 0.5), Vector2(arm * 2.0, thick)), Color(INK, 0.5))
			ci.draw_rect(Rect2(mid - Vector2(thick * 0.5, arm), Vector2(thick, arm - thick * 0.5)), Color(INK, 0.5))
			ci.draw_rect(Rect2(mid + Vector2(-thick * 0.5, thick * 0.5), Vector2(thick, arm - thick * 0.5)), Color(INK, 0.5))
		"cataclysm":
			var pts: Array[Vector2] = []
			for k in 24:
				var a := k * PI / 12.0 + 0.1
				pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 if k % 2 == 0 else 0.55))
			_poly(ci, pts, col)
			Kept.disc(ci, c, r * 0.32, Color(INK, 0.45))
		"starlight":
			_twinkle(ci, c + Vector2(-0.12, 0.08) * r, r * 0.95, col)
			_twinkle(ci, c + Vector2(0.62, -0.62) * r, r * 0.4, col)
			_twinkle(ci, c + Vector2(0.6, 0.72) * r, r * 0.3, col)
		"echo":
			Kept.disc(ci, c, r * 0.26, col)
			Kept.arc(ci, c, r * 0.58, 0.0, TAU, 20, col, w * 1.1, true)
			Kept.arc(ci, c, r * 0.92, -0.9, 0.9, 12, col, w, true)
			Kept.arc(ci, c, r * 0.92, PI - 0.9, PI + 0.9, 12, col, w, true)
		"cleanse":
			Kept.disc(ci, c + Vector2(-0.1, 0.3) * r, 0.58 * r, col)
			_poly(ci, [c + Vector2(-0.64, 0.12) * r, c + Vector2(-0.1, -0.95) * r, c + Vector2(0.44, 0.12) * r], col)
			_twinkle(ci, c + Vector2(0.7, -0.55) * r, r * 0.36, col)


static func _leaf(ci: CanvasItem, base: Vector2, tip: Vector2, r: float, col: Color) -> void:
	var d := tip - base
	var n := d.orthogonal().normalized() * r * 0.26
	_poly(ci, [base, base + d * 0.5 + n, tip, base + d * 0.5 - n], col)


static func _twinkle(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var pts: Array[Vector2] = []
	for k in 8:
		pts.append(at + Vector2.from_angle(-PI / 2.0 + k * TAU / 8.0) * (s if k % 2 == 0 else s * 0.28))
	_poly(ci, pts, col)


static func _poly(ci: CanvasItem, pts: Array[Vector2], col: Color) -> void:
	Kept.poly(ci, PackedVector2Array(pts), col)
