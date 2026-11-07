class_name EnemyMissile
extends RefCounted
## What throwing enemies throw, and how it flies. A missile is drawn from
## the enemy's attack timer alone: it leaves the enemy FLIGHT seconds before
## the attack and reaches the hero as the hit lands, so the damage stays on
## the enemy's beat. None of them are red: red is kept for health.

## Seconds in the air, and the lean back before the throw.
const FLIGHT := 0.4
const WIND_UP := 0.18

## How high each kind arcs, and whether it spins.
const KINDS := {
	"rock": {"arc": 70.0, "spin": true},
	"boulder": {"arc": 90.0, "spin": true},
	"bone": {"arc": 60.0, "spin": true},
	"web": {"arc": 40.0, "spin": false},
	"spore": {"arc": 30.0, "spin": false},
	"fire": {"arc": 18.0, "spin": false},
	"bolt": {"arc": 8.0, "spin": false},
	"venom": {"arc": 26.0, "spin": false},
}


## Where a missile `k` (0 to 1) of the way from `from` to `to` is.
static func position(kind: String, from: Vector2, to: Vector2, k: float) -> Vector2:
	var arc: float = KINDS.get(kind, KINDS["rock"])["arc"]
	return from.lerp(to, k) - Vector2(0, arc * 4.0 * k * (1.0 - k))


## Draws the missile `k` of the way along, turning as it flies if it spins.
static func draw(ci: CanvasItem, kind: String, from: Vector2, to: Vector2, k: float) -> void:
	var at := position(kind, from, to, k)
	var heading := (position(kind, from, to, minf(k + 0.05, 1.0)) - at).angle()
	var spin := k * TAU * 2.0 if KINDS.get(kind, KINDS["rock"])["spin"] else heading
	match kind:
		"rock":
			_rock(ci, at, 9.0, spin, Color("8d8a84"))
		"boulder":
			_rock(ci, at, 15.0, spin, Color("7d7f86"))
		"bone":
			var d := Vector2.from_angle(spin) * 10.0
			ci.draw_line(at - d, at + d, Color("eee8d6"), 5.0, true)
			for end: Vector2 in [at - d, at + d]:
				Kept.disc(ci, end, 4.0, Color("eee8d6"))
		"web":
			Kept.disc(ci, at, 10.0, Color(0.95, 0.95, 0.98, 0.85))
			for i in 4:
				var a := i * PI / 4.0
				ci.draw_line(at - Vector2.from_angle(a) * 13.0, at + Vector2.from_angle(a) * 13.0, Color(1, 1, 1, 0.6), 1.5, true)
		"spore":
			for i in 3:
				var off := Vector2.from_angle(k * 9.0 + i * TAU / 3.0) * 6.0
				Kept.disc(ci, at + off, 7.0, Color(0.35, 0.82, 0.75, 0.55))
		"fire":
			_trail(ci, kind, from, to, k, Color(1.0, 0.6, 0.2, 0.5))
			Kept.disc(ci, at, 10.0, Color("ff9a3c"))
			Kept.disc(ci, at, 5.0, Color("ffe07a"))
		"venom":
			# A gob of green spit, stretched along its flight, with drips.
			_trail(ci, kind, from, to, k, Color(0.55, 0.85, 0.3, 0.45))
			ci.draw_set_transform(at, heading, Vector2(1.5, 0.8))
			Kept.disc(ci, Vector2.ZERO, 7.0, Color("9ad84a"))
			Kept.disc(ci, Vector2(2, -2), 3.0, Color("e2f7a8"))
			ci.draw_set_transform(Vector2.ZERO)
		"bolt":
			_trail(ci, kind, from, to, k, Color(0.7, 0.4, 1.0, 0.5))
			Kept.disc(ci, at, 11.0, Color(0.6, 0.3, 0.9, 0.35))
			Kept.disc(ci, at, 6.0, Color("d9b3ff"))


static func _rock(ci: CanvasItem, c: Vector2, r: float, spin: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(spin + TAU * i / 6.0) * r * (0.8 + 0.2 * sin(i * 2.3)))
	Kept.poly(ci, pts, col)
	pts.append(pts[0])
	Kept.path(ci, pts, col.darkened(0.5), 2.0, true)


## A short fading tail behind fast missiles.
static func _trail(ci: CanvasItem, kind: String, from: Vector2, to: Vector2, k: float, col: Color) -> void:
	for i in 4:
		var back := k - 0.04 * (i + 1)
		if back <= 0.0:
			break
		Kept.disc(ci, position(kind, from, to, back), 7.0 - i * 1.5, Color(col, col.a * (1.0 - i / 4.0)))
