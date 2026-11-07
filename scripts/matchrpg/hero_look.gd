class_name HeroLook
extends RefCounted
## How the hero is drawn: a traveler in a long cloak of its color, facing
## right, and in web mode one piece of gear for each talent branch with
## enough talents (see GameState.hero_look): a sword on the back and a
## pauldron (Blade), a pointed hat and an amulet (Arcane), a hood and mask
## with a dagger (Trickster), a helmet and shield (Bulwark), and a pack with
## goggles (Scavenger). Shared by the runner, the menu's portrait and the
## codex. Drawn in the body's own space, 44 by 64, feet on the bottom edge,
## scaled to fit.
##
## HeroSprites bakes it for the runner, one texture per look: the whole hero
## at rest, and the body layer (cloak, head, and the gear that doesn't move)
## with the sword on the back or in hand. During an attack the arm, sword,
## shield, pauldron and spell move, so they're drawn live over the body
## layer: a handful of shapes.

const SIZE := Vector2(44, 64)
## The class mode hero, and a web hero with no look given.
const DEFAULT_COLOR := Color("4f8fe6")
const STEEL := Color("d5dbe3")
const OUTLINE := Color(0, 0, 0, 0.45)
const SKIN := Color("e9b98f")
const HAIR := Color("5a3a24")
const LEATHER := Color("6b4a2a")
const PANTS := Color("4a3f36")
const BOOT := Color("3a2a1e")
const WOOD := Color("7a5634")
const GOLD := Color("f2c53d")
const DARK := Color("1a1620")
## The flash of a hit taken.
const HURT := Color("ff4040")
## What the hero's colors sink toward in the dark at the left edge (pose
## "dim").
const DIM := Color("1d1828")
## The sword and shield a hero without that gear fights with.
const PLAIN_GRIP := Color("6b5640")
const PLAIN_SHIELD := Color("3d6a99")

## The build: the head's center and radii, the body's center line, and the
## shoulders' and hips' height.
const HEAD := Vector2(24, 12)
const HEAD_R := Vector2(8.5, 9.5)
const CX := 22.0
const SHOULDER_Y := 23.0
const HIP_Y := 44.0
const SHOULDER := Vector2(CX + 4, SHOULDER_Y + 3)

## The hand that holds the sword, and the sword's reach from it. The down
## swing cuts from behind the head to the floor in front.
const HAND := Vector2(CX + 9, SHOULDER_Y + 13)
const BLADE := 40.0
const SWING_DOWN := [-2.3, 0.7]
## Share of the swing spent slashing; the rest is the follow-through.
const SLASH := 0.4
## Where a spell flares, in front of the hero.
const CAST_AT := Vector2(CX + 26, SHOULDER_Y + 7)
const CAST_COLOR := Color("c58cff")

## The cloak's poses, looped this many a second.
const POSES := 4
const POSE_RATE := 6.0
## What HeroSprites bakes, each in every pose: the hero at rest, front and
## all; the body layer with the sword on the back; and with it in hand.
enum Layer { REST, SHEATHED, DRAWN }
## The room the body layer takes, gear and all, in the body's space.
const BODY_RECT := Rect2(-14, -30, 76, 100)

## While drawing a silhouette, the one color everything is drawn in.
static var _shade := Color.TRANSPARENT
## True while drawing the hero of a run, whose body is baked: what's drawn
## over it every frame (an arm, a blade, a slash) comes from Kept, which
## makes no mesh for each shape.
static var _live := false
## The drawing in use (HeroArt.resolve), or {} for the arms' old one, and the
## colour of the near sleeve with a hit's red and the dark on it.
static var _art := {}
static var _sleeve := Color.WHITE


## Draws the hero with its body's top-left corner at `pos`, `scale` times
## its usual size. `body` is its color; `gear` lists regions. `pose` may hold
## "swing" (0 to 1), with "sweep" for the flat cut from behind (the return
## swing and a charge's release) and "trail" for the slash's color, "cast"
## (0 to 1), "bash" (0 to 1), "ready" (the sword held low behind, for a
## charge), "tilt" (radians leaning on the feet, negative leans back),
## "hurt" (0 to 1, a hit's red flash), "frame" (the cloak's pose, see
## frame_at), "dim" (0 to 1, how far the dark has taken it), "shade" (a
## color to draw it all in, as a silhouette), "flip"
## (true to face left) and "reach" (where the near hand is, in the body's
## space, for the ending: see body_xform to draw what it holds).
## With `sprites`, the body layer is its baked texture once that's ready.
static func draw(ci: CanvasItem, pos: Vector2, scale: float, body: Color, gear: Array, pose := {},
		sprites: HeroSprites = null) -> void:
	_shade = pose.get("shade", Color.TRANSPARENT)
	_live = sprites != null
	_art = HeroArt.resolve(gear)
	var hurt: float = pose.get("hurt", 0.0)
	# In the dark, the hero's colors sink into it.
	var dim: float = pose.get("dim", 0.0)
	var tint := Color.WHITE.lerp(HURT, hurt).lerp(DIM, dim)
	if not _art.is_empty():
		_sleeve = HeroArt.sleeve(_art) * tint
	# What's drawn live (not from the baked sheet, keyed by `body`) takes the
	# dark in its body's color.
	var live_body := body.lerp(DIM, dim)
	_place(ci, pos, scale, pose.get("tilt", 0.0), pose.get("flip", false))
	var swing: float = pose.get("swing", -1.0)
	var sweep: bool = pose.get("sweep", false)
	# Held low behind for a charge: drawn, but nothing cut yet.
	if swing < 0.0 and pose.get("ready", false):
		swing = 0.0
		sweep = true
	var armed := swing >= 0.0
	var grip := _gear_color("blade") if gear.has("blade") else PLAIN_GRIP
	var trail: Color = pose.get("trail", Color.WHITE)
	if armed and sweep:
		_sweep(ci, swing, trail, grip, body, true)
	var frame: int = pose.get("frame", 0)
	var rest: bool = not armed and pose.get("cast", -1.0) < 0.0 and pose.get("bash", -1.0) < 0.0 \
		and not pose.has("reach") and not pose.has("aim")
	var layer := Layer.REST if rest else (Layer.DRAWN if armed else Layer.SHEATHED)
	if sprites != null and _shade.a == 0.0 and sprites.draw(ci, body, gear, layer, frame, tint):
		if not rest:
			_front(ci, live_body.lerp(HURT, hurt), gear, pose, swing, sweep, grip, trail)
	else:
		draw_layer(ci, live_body.lerp(HURT, hurt), gear, Layer.DRAWN if armed else Layer.SHEATHED, frame)
		_front(ci, live_body.lerp(HURT, hurt), gear, pose, swing, sweep, grip, trail)
	ci.draw_set_transform(Vector2.ZERO)
	_shade = Color.TRANSPARENT
	_live = false
	_art = {}


## The cloak's pose at `t` seconds.
static func frame_at(t: float) -> int:
	return int(t * POSE_RATE) % POSES


## Draws in the body's space from here on: top-left corner at `pos`, scaled,
## leaning `tilt` on the feet.
static func _place(ci: CanvasItem, pos: Vector2, scale: float, tilt: float, flip := false) -> void:
	ci.draw_set_transform_matrix(body_xform(pos, scale, tilt, flip))


## From the body's space to the canvas, for a hero drawn at `pos` (see draw).
static func body_xform(pos: Vector2, scale: float, tilt := 0.0, flip := false) -> Transform2D:
	var feet := Vector2(SIZE.x * 0.5, SIZE.y)
	return Transform2D(tilt, Vector2(-scale if flip else scale, scale), 0.0, pos + feet * scale) * Transform2D(0.0, -feet)


## How far above the body the gear reaches, so labels can sit clear of it.
static func top_extent(gear: Array) -> float:
	var art := HeroArt.resolve(gear)
	if not art.is_empty():
		return HeroArt.top(art)
	if gear.has("arcane"):
		return 16.0
	if gear.has("bulwark") and not gear.has("cunning"):
		return 4.0
	return 0.0


static func _gear_color(region: String) -> Color:
	return (HeroDefs.REGIONS[region]["color"] as Color).darkened(0.3)


## Draws `layer` (see Layer) of the hero in the body's space, with the
## cloak in pose `frame`.
static func draw_layer(ci: CanvasItem, body: Color, gear: Array, layer: Layer, frame: int) -> void:
	_art = HeroArt.resolve(gear)
	if not _art.is_empty():
		HeroArt.body(ci, _art, frame)
		if layer == Layer.REST:
			_front_art(ci, {}, -1.0, false, Color.WHITE)
		return
	_draw_body(ci, body, gear, layer == Layer.DRAWN, frame)
	if layer == Layer.REST:
		_front(ci, body, gear, {}, -1.0, false, PLAIN_GRIP, Color.WHITE)


## The body layer: what's behind, the cloak, the head and the gear that
## doesn't move. `armed` takes the sword off the back. `frame` sways the
## cloak's hem.
static func _draw_body(ci: CanvasItem, body: Color, gear: Array, armed: bool, frame: int) -> void:
	var cx := CX
	var sy := SHOULDER_Y
	var hy := HIP_Y
	var hood := gear.has("cunning")
	var a := frame * TAU / POSES
	# Behind the body.
	if gear.has("scavenger"):
		_pack(ci, cx, sy, hy)
	if gear.has("blade") and not armed:
		_back_sword(ci, cx, sy, hy)
	if hood:
		_oval(ci, _u(Vector2(-0.15, 0.05)), HEAD_R.x * 1.3, HEAD_R.y * 1.3, _gear_color("cunning").darkened(0.2))
	_leg(ci, cx + 3, hy, PANTS.darkened(0.25), BOOT.darkened(0.25))
	_leg(ci, cx - 3, hy, PANTS, BOOT)
	# The cloak, its hem stirring.
	var s := [sin(a) * 1.6, sin(a + 0.8) * 1.2, sin(a + 1.6) * 0.8, sin(a + 2.4) * 0.6]
	_poly(ci, PackedVector2Array([Vector2(cx - 7, sy - 1), Vector2(cx + 7, sy - 1), Vector2(cx + 11, hy),
		Vector2(cx + 12 + s[3], 58), Vector2(cx + 3 + s[2], 59.5), Vector2(cx - 6 + s[1], 59), Vector2(cx - 14 + s[0], 57),
		Vector2(cx - 11, hy - 6)]), body)
	_poly(ci, PackedVector2Array([Vector2(cx + 4, sy + 1), Vector2(cx + 8, sy + 1), Vector2(cx + 11.5 + s[3], 57.5),
		Vector2(cx + 6 + s[2] * 0.5, 58.5)]), body.darkened(0.4), false)
	_poly(ci, PackedVector2Array([Vector2(cx - 7, sy - 1), Vector2(cx - 2, sy - 1), Vector2(cx - 9, hy - 2),
		Vector2(cx - 12, hy - 7)]), body.darkened(0.15), false)
	for f: Array in [[Vector2(cx - 3, sy + 4), Vector2(cx - 7 + s[1], 57)], [Vector2(cx + 1, sy + 6), Vector2(cx - 1 + s[2], 58.5)],
			[Vector2(cx - 8, sy + 6), Vector2(cx - 12 + s[0], 55)]]:
		_line(ci, f[0], f[1], body.darkened(0.2), 1.2)
	if hood:
		# A dagger at the hip, in the cloak's opening.
		_line(ci, Vector2(cx + 9, hy - 1), Vector2(cx + 12, hy + 7), STEEL, 1.8)
		_line(ci, Vector2(cx + 8, hy - 3), Vector2(cx + 9, hy - 1), PLAIN_GRIP, 2.2)
	if gear.has("blade") and not armed:
		_line(ci, Vector2(cx - 7, sy + 1), Vector2(cx + 8, hy - 3), LEATHER, 2.0)
	if gear.has("scavenger"):
		_line(ci, Vector2(cx + 3, sy), Vector2(cx + 1, sy + 12), LEATHER, 2.0)
	_dot(ci, Vector2(cx + 5, sy + 1), 1.8, GOLD)
	if gear.has("arcane"):
		_dot(ci, Vector2(cx + 3, sy + 7), 3.0, Color(CAST_COLOR, 0.35))
		_dot(ci, Vector2(cx + 3, sy + 7), 1.6, Color("f2e6ff"))
	_head(ci, gear)


static func _head(ci: CanvasItem, gear: Array) -> void:
	var hood := gear.has("cunning")
	var hat := gear.has("arcane")
	var helm := gear.has("bulwark") and not hood
	_rect(ci, Rect2(HEAD.x - 2.5, HEAD.y + HEAD_R.y - 3, 5, SHOULDER_Y - HEAD.y - HEAD_R.y + 4), SKIN.darkened(0.1))
	_oval(ci, HEAD, HEAD_R.x, HEAD_R.y, SKIN)
	_oval(ci, _u(Vector2(-0.2, 0.1)), HEAD_R.x * 0.17, HEAD_R.y * 0.2, SKIN.darkened(0.12), false)
	var eye := _u(Vector2(0.42, -0.02))
	_oval(ci, eye, HEAD_R.x * 0.13, HEAD_R.y * 0.2, DARK, false)
	_dot(ci, eye + Vector2(HEAD_R.x * 0.04, -HEAD_R.y * 0.08), HEAD_R.x * 0.05, Color.WHITE)
	_line(ci, _u(Vector2(0.25, -0.34)), _u(Vector2(0.64, -0.38)), HAIR.darkened(0.2), HEAD_R.y * 0.09)
	_poly(ci, _upts([Vector2(0.9, -0.12), Vector2(1.13, 0.22), Vector2(0.9, 0.28)]), SKIN.darkened(0.04))
	_line(ci, _u(Vector2(0.5, 0.56)), _u(Vector2(0.76, 0.5)), SKIN.darkened(0.45), HEAD_R.y * 0.07)
	_poly(ci, _upts([Vector2(-1.08, 0.35), Vector2(-1.05, -0.4), Vector2(-0.6, -0.98), Vector2(0.15, -1.1),
		Vector2(0.8, -0.8), Vector2(1.05, -0.35), Vector2(0.6, -0.5), Vector2(0.25, -0.42), Vector2(-0.1, -0.3),
		Vector2(-0.4, -0.05), Vector2(-0.5, 0.5), Vector2(-0.85, 0.75)]), HAIR)
	if hood:
		var c := _gear_color("cunning")
		_poly(ci, _upts([Vector2(1.12, -0.3), Vector2(0.85, -1.0), Vector2(0.0, -1.32), Vector2(-0.85, -1.15),
			Vector2(-1.3, -0.3), Vector2(-1.3, 0.7), Vector2(-0.8, 1.15), Vector2(-0.55, 0.45), Vector2(-0.2, -0.2),
			Vector2(0.4, -0.5)]), c)
		# The mask over nose and mouth.
		_poly(ci, _upts([Vector2(0.05, 0.3), Vector2(1.08, 0.22), Vector2(1.0, 0.8), Vector2(0.3, 1.02),
			Vector2(-0.25, 0.85)]), c.darkened(0.35))
	elif helm:
		_poly(ci, _arc(HEAD + Vector2(0, -0.15 * HEAD_R.y), HEAD_R.x * 1.12, HEAD_R.y * 1.05, PI, TAU, 16), STEEL.darkened(0.1))
		_poly(ci, _upts([Vector2(-1.12, -0.15), Vector2(-0.55, -0.15), Vector2(-0.7, 0.55), Vector2(-1.2, 0.5)]), STEEL.darkened(0.25))
		_line(ci, _u(Vector2(-1.15, -0.15)), _u(Vector2(1.15, -0.15)), STEEL.darkened(0.3), HEAD_R.y * 0.22)
		_poly(ci, _upts([Vector2(0.74, -0.2), Vector2(0.94, -0.2), Vector2(0.92, 0.38), Vector2(0.78, 0.38)]), STEEL.darkened(0.2))
		# The crest, in the branch's color.
		_poly(ci, _upts([Vector2(-0.9, -0.95), Vector2(-0.3, -1.5), Vector2(0.45, -1.38), Vector2(0.2, -1.12),
			Vector2(-0.4, -1.12)]), _gear_color("bulwark"))
	elif gear.has("scavenger") and not hat:
		_line(ci, _u(Vector2(-1.0, -0.48)), _u(Vector2(1.0, -0.55)), LEATHER, HEAD_R.y * 0.16)
		_dot(ci, _u(Vector2(0.5, -0.62)), HEAD_R.x * 0.24, GOLD.darkened(0.3))
		_dot(ci, _u(Vector2(0.5, -0.62)), HEAD_R.x * 0.15, Color("ffd98a"))
	if hat:
		var c := _gear_color("arcane")
		_poly(ci, _upts([Vector2(-0.85, -0.6), Vector2(0.95, -0.6), Vector2(0.35, -1.75), Vector2(-0.55, -2.55),
			Vector2(-0.4, -1.65)]), c)
		_line(ci, _u(Vector2(-0.8, -0.8)), _u(Vector2(0.88, -0.8)), c.lightened(0.35), HEAD_R.y * 0.14)
		_line(ci, _u(Vector2(-1.45, -0.55)), _u(Vector2(1.55, -0.5)), c.darkened(0.2), HEAD_R.y * 0.3)
		_dot(ci, _u(Vector2(-0.55, -2.55)), HEAD_R.x * 0.2, GOLD)


static func _leg(ci: CanvasItem, x: float, hy: float, pants: Color, boot: Color) -> void:
	_line(ci, Vector2(x, hy), Vector2(x + 1, 59), pants, 5.5)
	_poly(ci, PackedVector2Array([Vector2(x - 2.5, 58), Vector2(x + 3.5, 58), Vector2(x + 4, 61.5), Vector2(x + 6.5, 62),
		Vector2(x + 6.5, 64), Vector2(x - 2.5, 64)]), boot)


## A pack on the back, a bedroll on top, a pick and a pan hanging off it.
static func _pack(ci: CanvasItem, cx: float, sy: float, hy: float) -> void:
	var c := _gear_color("scavenger")
	_line(ci, Vector2(cx - 14, hy), Vector2(cx - 19, sy - 10), WOOD, 2.0)
	_poly(ci, PackedVector2Array([Vector2(cx - 21, sy - 9), Vector2(cx - 18, sy - 12), Vector2(cx - 15, sy - 11),
		Vector2(cx - 19, sy - 9.5)]), STEEL)
	_poly(ci, PackedVector2Array([Vector2(cx - 15, sy - 3), Vector2(cx - 5, sy - 3), Vector2(cx - 4, hy + 1),
		Vector2(cx - 16, hy + 1)]), c)
	_poly(ci, PackedVector2Array([Vector2(cx - 15.5, sy - 3), Vector2(cx - 5, sy - 3), Vector2(cx - 5, sy + 5),
		Vector2(cx - 15.5, sy + 6)]), c.darkened(0.2))
	_dot(ci, Vector2(cx - 10, sy + 5), 1.5, GOLD)
	_oval(ci, Vector2(cx - 10, sy - 5), 7, 3, Color("c9a66b"))
	_oval(ci, Vector2(cx - 17, hy - 5), 3.5, 3.5, Color("4a4a52"))


## A sword slung across the back: the hilt over the left shoulder.
static func _back_sword(ci: CanvasItem, cx: float, sy: float, hy: float) -> void:
	var guard := Vector2(cx - 7, sy - 6)
	var tip := Vector2(cx + 8, hy + 6)
	var along := (tip - guard).normalized()
	var across := Vector2(-along.y, along.x)
	var c := _gear_color("blade")
	_line(ci, guard, tip, STEEL, 3.5)
	_line(ci, guard, guard - along * 8.0, c, 3.0)
	_line(ci, guard - across * 5.5, guard + across * 5.5, c, 3.0)
	_dot(ci, guard - along * 9.0, 2.0, STEEL)


## What moves: the near arm and what it holds, the pauldron over it, and a
## spell's flare.
static func _front(ci: CanvasItem, body: Color, gear: Array, pose: Dictionary, swing: float, sweep: bool, grip: Color,
		trail: Color) -> void:
	if not _art.is_empty():
		_front_art(ci, pose, swing, sweep, trail)
		return
	var sleeve := body.darkened(0.08)
	var shield := _gear_color("bulwark") if gear.has("bulwark") else PLAIN_SHIELD
	var cast: float = pose.get("cast", -1.0)
	var bash: float = pose.get("bash", -1.0)
	if swing >= 0.0:
		if gear.has("bulwark"):
			_shield(ci, Vector2(CX + 10, SHOULDER_Y + 12), shield)
		if sweep:
			_sweep(ci, swing, trail, grip, sleeve, false)
		else:
			_swing(ci, swing, trail, grip, sleeve)
	elif cast >= 0.0:
		var hand := Vector2(CX + 15, SHOULDER_Y + 7)
		_line(ci, SHOULDER, hand, sleeve, 4.5)
		_dot(ci, hand, 2.3, SKIN)
		if gear.has("bulwark"):
			_shield(ci, Vector2(CX + 8, SHOULDER_Y + 15), shield)
	elif pose.has("reach"):
		var hand: Vector2 = pose["reach"]
		if gear.has("bulwark"):
			_shield(ci, Vector2(CX + 8, SHOULDER_Y + 15), shield)
		_line(ci, SHOULDER, hand, sleeve, 4.5)
		_dot(ci, hand, 2.3, SKIN)
	elif gear.has("bulwark") or bash >= 0.0:
		var push := sin(clampf(bash, 0.0, 1.0) * PI) * 14.0
		var shove := Vector2(push, -push * 0.3)
		_line(ci, SHOULDER, Vector2(CX + 10, SHOULDER_Y + 11) + shove, sleeve, 4.5)
		_shield(ci, Vector2(CX + 13, SHOULDER_Y + 12) + shove, shield)
	else:
		_dot(ci, Vector2(CX + 9.5, HIP_Y - 5), 2.2, SKIN)
	if gear.has("blade"):
		_pauldron(ci)
	if cast >= 0.0:
		_flare(ci, cast)


## What moves, for a drawing of HeroArt's: the near arm and what it holds,
## the shoulder over it, and a spell's flare.
static func _front_art(ci: CanvasItem, pose: Dictionary, swing: float, sweep: bool, trail: Color) -> void:
	var cast: float = pose.get("cast", -1.0)
	# (Hearthguard) The Archer aims: bow out in front, string drawn to "aim".
	if pose.has("aim") and str(_art["id"]).begins_with("archer"):
		var grip := Vector2(CX + 19, SHOULDER_Y + 6)
		_line(ci, SHOULDER, grip, _sleeve, 4.5)
		HeroArt.bow(ci, grip, Vector2.RIGHT, clampf(pose["aim"], 0.0, 1.0), _art["rank"])
		_dot(ci, grip, 2.4, HeroArt.hand_color(_art))
		return
	if swing >= 0.0:
		if sweep:
			_sweep(ci, swing, trail, PLAIN_GRIP, _sleeve, false)
		else:
			_swing(ci, swing, trail, PLAIN_GRIP, _sleeve)
		HeroArt.shoulder(ci, _art)
	elif cast >= 0.0:
		HeroArt.cast_extra(ci, _art)
		var hand := Vector2(CX + 15, SHOULDER_Y + 7)
		_line(ci, SHOULDER, hand, _sleeve, 4.5)
		_dot(ci, hand, 2.3, HeroArt.hand_color(_art))
		HeroArt.shoulder(ci, _art)
		_flare(ci, cast)
	elif pose.has("reach"):
		var hand: Vector2 = pose["reach"]
		_line(ci, SHOULDER, hand, _sleeve, 4.5)
		_dot(ci, hand, 2.3, HeroArt.hand_color(_art))
		HeroArt.shoulder(ci, _art)
	else:
		HeroArt.rest(ci, _art)


## The look `look` (GameState.hero_look) as the gear HeroLook.draw reads: the
## branches' pieces, and who the hero is and how far along: its title and
## how many talents it has taken.
static func gear_of(look: Dictionary) -> Array:
	var gear: Array = (look.get("gear", []) as Array).duplicate()
	if look.has("title"):
		gear.append("t:%s" % look["title"])
	if look.has("rank"):
		gear.append("r:%d" % int(look["rank"]))
	return gear


## Two steel plates over the shoulder.
static func _pauldron(ci: CanvasItem) -> void:
	var at := SHOULDER + Vector2(-1, -2)
	var plate := _arc(at, 5.5, 4.5, PI, TAU, 10)
	plate.append(at + Vector2(4.5, 2.5))
	plate.append(at + Vector2(-4.5, 2.5))
	_poly(ci, plate, STEEL.darkened(0.2))
	var lower := _arc(at + Vector2(0.5, 2.5), 5.0, 3.0, PI, TAU, 8)
	_poly(ci, lower, STEEL.darkened(0.05))
	_dot(ci, at + Vector2(1.5, -1.5), 0.9, STEEL.lightened(0.3))


## A kite shield held in front.
static func _shield(ci: CanvasItem, s: Vector2, c: Color) -> void:
	var kite := PackedVector2Array([s + Vector2(-7, -9), s + Vector2(7, -9), s + Vector2(7, 3), s + Vector2(0, 13),
		s + Vector2(-7, 3)])
	_poly(ci, kite, c, false)
	_poly(ci, PackedVector2Array([s + Vector2(-7, -9), s + Vector2(0, -9), s + Vector2(0, 13), s + Vector2(-7, 3)]),
		c.darkened(0.2), false)
	kite.append(kite[0])
	_loop(ci, kite, _c(STEEL), 1.8)
	_dot(ci, s + Vector2(0, -1), 2.3, STEEL)


## How far through its cut a swing is at `k`, 0 to 1, and how much of its
## trail is left.
static func _cut(k: float) -> Vector2:
	return Vector2(ease(clampf(k / SLASH, 0.0, 1.0), 0.4), 1.0 - clampf((k - SLASH) / (1.0 - SLASH), 0.0, 1.0))


## The sword in hand, `k` of the way through a swing down, with the arc it
## cut fading behind it.
static func _swing(ci: CanvasItem, k: float, trail: Color, grip: Color, sleeve: Color) -> void:
	var c := _cut(k)
	var angle := lerpf(SWING_DOWN[0], SWING_DOWN[1], c.x)
	if c.y > 0.0 and c.x > 0.05 and _shade.a == 0.0:
		var band := PackedVector2Array()
		var from: float = lerpf(SWING_DOWN[0], SWING_DOWN[1], maxf(c.x - 0.7, 0.0))
		for i in 11:
			band.append(HAND + Vector2.from_angle(lerpf(from, angle, i / 10.0)) * (BLADE + 4.0))
		for i in range(10, -1, -1):
			band.append(HAND + Vector2.from_angle(lerpf(from, angle, i / 10.0)) * BLADE * 0.6)
		_fill(ci, band, Color(trail, trail.a * 0.4 * c.y))
	_line(ci, SHOULDER, HAND, sleeve, 4.5)
	_blade(ci, HAND, HAND + Vector2.from_angle(angle) * BLADE, grip)


## The return swing and a charge's release: a flat cut at the waist, from
## behind the back to in front. Seen from the side, the blade points back,
## turns toward the viewer (short) as it passes the body, then points ahead.
## At k = 0 it's the charge's held pose, the sword low behind the hero. The
## blade is drawn `behind` the body until it passes it, the arm always in
## front.
static func _sweep(ci: CanvasItem, k: float, trail: Color, grip: Color, sleeve: Color, behind: bool) -> void:
	var c := _cut(k)
	var hand := _sweep_hand(c.x)
	if behind != (c.x < 0.5):
		if not behind:
			_line(ci, SHOULDER, hand, sleeve, 4.5)
			_dot(ci, hand, 2.4, SKIN)
		return
	if c.y > 0.0 and c.x > 0.05 and _shade.a == 0.0:
		var band := PackedVector2Array()
		var from := maxf(c.x - 0.8, 0.0)
		for i in 13:
			band.append(_sweep_tip(lerpf(from, c.x, i / 12.0)))
		for i in range(12, -1, -1):
			var at := lerpf(from, c.x, i / 12.0)
			band.append(_sweep_hand(at).lerp(_sweep_tip(at), 0.5))
		_fill(ci, band, Color(trail, trail.a * 0.4 * c.y))
	if not behind:
		_line(ci, SHOULDER, hand, sleeve, 4.5)
	_blade(ci, hand, _sweep_tip(c.x), grip, not behind)


static func _sweep_hand(cut: float) -> Vector2:
	return (HAND + Vector2(-16, 4)).lerp(HAND + Vector2(4, 0), cut)


static func _sweep_tip(cut: float) -> Vector2:
	var phi := lerpf(PI, 0.0, cut)
	return _sweep_hand(cut) + Vector2(cos(phi) * BLADE, -sin(phi) * BLADE * 0.22)


## A sword from the hand at `hand` to its tip at `tip`, with the hand
## gripping it.
static func _blade(ci: CanvasItem, hand: Vector2, tip: Vector2, grip: Color, fist := true) -> void:
	if not _art.is_empty():
		HeroArt.weapon(ci, _art, hand, tip, fist)
		return
	var dir := (tip - hand).normalized()
	var across := Vector2(-dir.y, dir.x)
	var length := hand.distance_to(tip)
	if length > 6.0:
		_poly(ci, PackedVector2Array([hand + across * 2.2, hand + dir * (length - 5) + across * 2.0, tip,
			hand + dir * (length - 5) - across * 2.0, hand - across * 2.2]), STEEL)
		_line(ci, hand + dir * 3, hand + dir * (length - 6), STEEL.darkened(0.25), 0.8)
	else:
		_line(ci, hand, tip, STEEL, 4.0)
	_line(ci, hand, hand - dir * 7.0, grip, 3.5)
	_line(ci, hand - across * 6.0, hand + across * 6.0, grip, 3.5)
	_dot(ci, hand - dir * 8.5, 2.3, STEEL)
	if fist:
		_dot(ci, hand - dir * 2.5, 2.4, SKIN)


## A spell gathering in front of the hero, `k` of the way through the cast.
static func _flare(ci: CanvasItem, k: float) -> void:
	var grow := sin(clampf(k, 0.0, 1.0) * PI)
	_dot(ci, CAST_AT, 6.0 + 14.0 * grow, Color(CAST_COLOR, 0.3 * grow))
	_dot(ci, CAST_AT, 3.0 + 6.0 * grow, Color(1, 0.95, 1, 0.9 * grow))
	for i in 4:
		var a := k * 6.0 + i * TAU / 4.0
		_dot(ci, CAST_AT + Vector2.from_angle(a) * (10.0 + 10.0 * k), 2.5, Color(CAST_COLOR, 1.0 - k))


# Helpers.

## `c`, or the silhouette's color while drawing one.
static func _c(c: Color) -> Color:
	if _shade.a > 0.0:
		return _shade if c.a > 0.5 else Color.TRANSPARENT
	return c


## A point on the head, in its radii from its center.
static func _u(p: Vector2) -> Vector2:
	return HEAD + p * HEAD_R


static func _upts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in arr:
		out.append(_u(p))
	return out


static func _poly(ci: CanvasItem, pts: PackedVector2Array, c: Color, outline := true) -> void:
	_fill(ci, pts, _c(c))
	if outline and _shade.a == 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		_loop(ci, loop, OUTLINE, 1.0)


## A filled shape, and a line through points: a mesh each when baked, and
## none when drawn again every frame (see _live).
static func _fill(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	if _live:
		Kept.poly(ci, pts, c)
	else:
		ci.draw_colored_polygon(pts, c)


static func _loop(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float) -> void:
	if _live:
		Kept.path(ci, pts, c, w, true)
	else:
		ci.draw_polyline(pts, c, w, true)


## Points along an ellipse from angle `from` to `to`.
static func _arc(c: Vector2, rx: float, ry: float, from: float, to: float, steps := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, i / float(steps))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, outline := true) -> void:
	var pts := _arc(c, rx, ry, 0.0, TAU, 20)
	pts.remove_at(pts.size() - 1)
	_poly(ci, pts, col, outline)


static func _rect(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(r, _c(c))


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	ci.draw_line(a, b, _c(c), w, true)


static func _dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _live:
		Kept.disc(ci, c, r, _c(col))
	else:
		ci.draw_circle(c, r, _c(col), true, -1.0, true)
