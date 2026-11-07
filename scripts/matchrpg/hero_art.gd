class_name HeroArt
extends RefCounted
## The hero's eight drawings, one for each of the names the talents give
## (RowDefs.title_id): the Wanderer, who has none, one for each branch, a
## knight (Blade and Arcane), a swashbuckler (Blade and Flow), a seer (Flow
## and Arcane), and the jester, who has a talent in each. Rank (how many
## talents the hero has taken, up to five) adds to a drawing and never changes
## it: the same hero, with more on it.
##
## HeroLook draws what these hand it, in the body's own space, 44 by 64, feet
## on the bottom edge, facing right. A drawing is made of three parts:
##   - `body`: what stays put, drawn once into HeroSprites' texture (so it
##     may use any call) with the cloth stirring in `frame`;
##   - `rest`: the near arm and what it holds at rest, baked with it;
##   - the near arm and `weapon` while the hero strikes, and `shoulder` over
##     them, drawn live through HeroLook's helpers, which make no mesh then.
## Every shape goes through `_p`, `_o`, `_l` and `_d`, which HeroLook's
## silhouette and its kept (live) drawing both reach.

const BLADE_C := Color("e8743b")
const ARCANE_C := Color("9b59d0")
const FLOW_C := Color("f2c53d")
## (Hearthguard) The Archer's green, the Scavenger branch's in MatchRPG.
const HUNT_C := Color("6fbf73")
const HUNT_D := Color("2f5a3a")
const CAST := Color("c58cff")
const RUNE := Color("b78cff")
const RUNE_L := Color("eadcff")
const STEEL := Color("d5dbe3")
const SKIN := Color("e9b98f")
const HAIR := Color("5a3a24")
const LEATHER := Color("6b4a2a")
const PANTS := Color("4a3f36")
const BOOT := Color("3a2a1e")
const WOOD := Color("7a5634")
const GOLD := Color("f2c53d")
const DARK := Color("1a1620")
const BONE := Color("f4efe6")
const ORB := Color("f2e6ff")

const PLATE := Color("5f5a82")
const PLATE_L := Color("8a84b4")
const COAT := Color("2e6470")
const SKIRT := Color("3b2a6a")
const CLOAK := Color("a89674")
const INDIGO := Color("34285a")
const CHARCOAL := Color("3a3248")

## Rank when a look has none (an old snapshot).
const DEFAULT_RANK := 3


# --- Which drawing ---------------------------------------------------------

## {"id", "rank"} for the gear HeroLook was given, or {} when it holds a
## piece this has no drawing for (the arms' bulwark and scavenger), which
## HeroLook draws as it always has. `gear` is the branches' pieces, and
## "t:<title>" and "r:<rank>" when the look says who it is (HeroLook.gear_of).
static func resolve(gear: Array) -> Dictionary:
	var title := ""
	var rank := -1
	var regions := {}
	for g: Variant in gear:
		var s := str(g)
		if s.begins_with("t:"):
			title = s.substr(2)
		elif s.begins_with("r:"):
			rank = int(s.substr(2))
		elif s in ["blade", "arcane", "cunning", "hunt"]:
			regions[s] = true
		else:
			return {}
	if title == "":
		title = "hunt" if regions.has("hunt") else _title_of(regions)
	var id := _id_of(title)
	if id == "":
		return {}
	rank = clampi(DEFAULT_RANK if rank < 0 else rank, 0, 5)
	# A branch dresses the hero over three talents: the first gives the
	# Wanderer the branch's color and a weapon, the second a piece to wear
	# (the `_part` drawings, by rank), the third the whole costume, which
	# the later ranks' drawings add to (rank 4 as the old rank 3, 5 as 5).
	if id in ["blade", "arcane", "flow", "archer"]:
		if rank <= 2:
			id += "_part"
		elif rank == 3:
			rank = 1
		elif rank == 4:
			rank = 3
	return {"id": id, "rank": rank}


## The title a set of branches gives when the look doesn't say.
static func _title_of(regions: Dictionary) -> String:
	var out: Array[String] = []
	for r: String in ["blade", "cunning", "arcane"]:
		if regions.has(r):
			out.append(r)
	match out.size():
		0:
			return "wanderer"
		3:
			return "journeyman"
	return "+".join(out)


static func _id_of(title: String) -> String:
	match title:
		"wanderer":
			return "wanderer"
		"hunt":
			return "archer"
		"blade":
			return "blade"
		"arcane":
			return "arcane"
		"cunning":
			return "flow"
		"blade+arcane", "arcane+blade":
			return "knight"
		"blade+cunning", "cunning+blade":
			return "swash"
		"cunning+arcane", "arcane+cunning":
			return "seer"
		"journeyman":
			return "jester"
	return ""


## How far above the body the drawing reaches, for the labels over it.
static func top(art: Dictionary) -> float:
	var r: int = art["rank"]
	match art["id"]:
		"arcane_part":
			return 14.0 if r >= 2 else 0.0
		"arcane":
			return 26.0 if r >= 5 else 20.0
		"blade":
			return 6.0 if r >= 4 else 2.0
		"knight":
			return 10.0 if r >= 4 else 4.0
		"swash":
			return 8.0
		"jester":
			return 14.0
		"archer":
			return 4.0 if r >= 4 else 0.0
	return 0.0


## The near arm's sleeve.
static func sleeve(art: Dictionary) -> Color:
	match art["id"]:
		"blade":
			return STEEL.darkened(0.3)
		"arcane":
			return ARCANE_C.darkened(0.1)
		"flow":
			return CHARCOAL
		"knight":
			return PLATE.darkened(0.2)
		"swash":
			return COAT.darkened(0.1)
		"seer":
			return SKIRT.lightened(0.1)
		"jester":
			return FLOW_C
		"archer", "archer_part":
			return HUNT_D
	return CLOAK.darkened(0.15)


## The hand at the end of that arm.
static func hand_color(art: Dictionary) -> Color:
	match art["id"]:
		"blade":
			return STEEL.darkened(0.1)
		"knight":
			return PLATE_L
		"jester":
			return BONE
	return SKIN


# --- Body ------------------------------------------------------------------

## What stays put: everything but the near arm and what it holds. `frame` is
## the cloth's pose, 0 to 3.
static func body(ci: CanvasItem, art: Dictionary, frame: int) -> void:
	var r: int = art["rank"]
	var s := _sway(frame)
	match art["id"]:
		"wanderer":
			_body_wanderer(ci, s)
		"blade_part":
			_body_wanderer(ci, s, BLADE_C)
			if r >= 2:
				_p(ci, [15.5, 13, 15, 8, 20, 3.8, 27, 4, 31, 8, 30, 11.5, 22, 10, 17, 12], STEEL)
				_l(ci, 15.5, 12.4, 30.6, 11.8, GOLD, 1.3)
				_o(ci, 13.5, 24, 6, 5, STEEL.darkened(0.25))
		"arcane_part":
			_body_wanderer(ci, s, ARCANE_C)
			_d(ci, 24, 26, 1.8, Color(CAST, 0.9))
			if r >= 2:
				_o(ci, 23, 8.8, 13, 3.4, ARCANE_C.darkened(0.15))
				_p(ci, [15, 9, 31, 9, 26, -1, 21, -10, 12 + s[0], -14, 17, -5], ARCANE_C)
				_d(ci, 12 + s[0], -14, 1.8, GOLD)
		"flow_part":
			_body_wanderer(ci, s, FLOW_C)
			if r >= 2:
				_p(ci, [17, 26, 27, 26, 28, 44, 18, 44], CHARCOAL)
				_p(ci, [14, 28, 12, 14, 17, 4, 25, 0.5, 32, 5, 32, 9, 29, 8, 24, 6, 20, 9, 19, 18, 21, 26], FLOW_C)
		"blade":
			_body_blade(ci, r, s)
		"arcane":
			_body_arcane(ci, r, s)
		"flow":
			_body_flow(ci, r, s)
		"knight":
			_body_knight(ci, r, s, frame)
		"swash":
			_body_swash(ci, r, s)
		"seer":
			_body_seer(ci, r, s)
		"jester":
			_body_jester(ci, s)
		"archer_part":
			_body_wanderer(ci, s, HUNT_C)
			if r >= 2:
				_quiver(ci)
		"archer":
			_body_archer(ci, r, s)


## The near arm and what it holds at rest, and the shoulder over it.
static func rest(ci: CanvasItem, art: Dictionary) -> void:
	var r: int = art["rank"]
	match art["id"]:
		"wanderer":
			_l(ci, 28, 27, 34, 41, sleeve(art), 5)
			_o(ci, 34, 41, 2.6, 2.6, SKIN)
		"blade_part":
			_l(ci, 31, 27, 34, 38, sleeve(art), 5.5)
			_sword(ci, Vector2(34, 38), Vector2(40, 2), 2.3, LEATHER)
			_o(ci, 34, 38, 2.6, 2.6, SKIN)
		"arcane_part":
			_l(ci, 29, 27, 35, 41, sleeve(art), 5.5)
			_o(ci, 35, 41, 2.5, 2.5, SKIN)
			_l(ci, 35, 64, 35, 5, WOOD, 3.0)
			_o(ci, 35, 3, 3.4, 4.0, ORB)
			_d(ci, 35, 3, 7, Color(CAST, 0.25))
		"flow_part":
			_l(ci, 31, 28, 33, 43, sleeve(art), 5)
			_dagger(ci, Vector2(33, 43), Vector2(36, 54))
			_o(ci, 33, 43, 2.4, 2.4, SKIN)
		"blade":
			_l(ci, 31, 27, 34, 38, sleeve(art), 5.5)
			_sword(ci, Vector2(34, 38), Vector2(40, 2), 2.3, LEATHER)
			_o(ci, 34, 38, 2.8, 2.8, hand_color(art))
		"arcane":
			_l(ci, 29, 27, 35, 41, sleeve(art), 6.5)
			_o(ci, 35, 41, 2.5, 2.5, SKIN)
			_l(ci, 35, 64, 35, 3, WOOD, 3.2)
			_o(ci, 35, 0, 4.4, 5.2, ORB)
			_d(ci, 35, 0, 9, Color(CAST, 0.3))
		"flow":
			_l(ci, 31, 28, 33, 43, sleeve(art), 5)
			_dagger(ci, Vector2(33, 43), Vector2(36, 54))
			_o(ci, 33, 43, 2.4, 2.4, SKIN)
		"knight":
			_l(ci, 31, 27, 34, 38, sleeve(art), 5.5)
			_runed_sword(ci, r, Vector2(34, 38), Vector2(41, -8) if r >= 5 else Vector2(40, 2))
			_o(ci, 34, 38, 2.8, 2.8, hand_color(art))
		"swash":
			_l(ci, 31, 28, 35, 38, sleeve(art), 5)
			_sword(ci, Vector2(35, 38), Vector2(56, 24) if r >= 4 else Vector2(54, 28), 1.6 if r >= 4 else 2.6, LEATHER)
			_o(ci, 35, 38, 2.6, 2.6, SKIN)
		"seer":
			_l(ci, 27, 28, 33, 41, sleeve(art), 5)
			_ball(ci, Vector2(34, 35), 5.0)
			_o(ci, 33, 41, 2.6, 2.6, SKIN)
		"jester":
			_l(ci, 28, 27, 34, 41, sleeve(art), 5)
			_marotte(ci, Vector2(35, 47), Vector2(39, 17))
			_o(ci, 34, 41, 2.6, 2.6, BONE)
		"archer", "archer_part":
			_l(ci, 30, 27, 35, 39, sleeve(art), 5)
			bow(ci, Vector2(36, 39), Vector2(0.25, -1).normalized().orthogonal() * -1.0, 0.0, r)
			_o(ci, 35.5, 39, 2.6, 2.6, SKIN)
	shoulder(ci, art)


## The near shoulder's plate, over the arm.
static func shoulder(ci: CanvasItem, art: Dictionary) -> void:
	var r: int = art["rank"]
	match art["id"]:
		"blade_part":
			if r >= 2:
				_o(ci, 31.5, 24, 6, 5, STEEL.darkened(0.1))
				_l(ci, 27, 21.5, 35, 22.5, STEEL.darkened(0.3), 0.9)
		"blade":
			_o(ci, 31.5, 24, 7, 5.8, STEEL)
			_l(ci, 26, 21.5, 36, 23, STEEL.darkened(0.3), 0.9)
			_d(ci, 33, 22, 1, STEEL.lightened(0.3))
			if r >= 2:
				_l(ci, 25.5, 26.5, 37, 25.5, GOLD, 1.2)
			if r >= 4:
				_p(ci, [28, 20.5, 31.5, 13, 35, 19.5], STEEL)
		"knight":
			_o(ci, 31.5, 24, 7, 5.8, PLATE_L)
			_l(ci, 26, 26.5, 37, 25.5, RUNE, 1.2)
			if r >= 4:
				_p(ci, [29, 19, 32, 11, 35, 19], RUNE)


## What stands behind a casting hero: the mage's staff, put aside.
static func cast_extra(ci: CanvasItem, art: Dictionary) -> void:
	if art["id"] in ["arcane", "arcane_part"]:
		_l(ci, 9, 64, 6, 0, WOOD, 3.2)
		_o(ci, 6, -2, 4.4, 5, ORB)
		_d(ci, 6, -2, 9, Color(CAST, 0.3))


# --- The weapon, in a swing ---------------------------------------------------

## What the hero holds, from `hand` to `tip` (a sword's blade, a staff's far
## end), with a hand gripping it when `fist`.
static func weapon(ci: CanvasItem, art: Dictionary, hand: Vector2, tip: Vector2, fist: bool) -> void:
	var r: int = art["rank"]
	var dir := (tip - hand).normalized()
	match art["id"]:
		"arcane", "arcane_part":
			_l(ci, hand.x - dir.x * 8, hand.y - dir.y * 8, tip.x, tip.y, WOOD, 3.2)
			_o(ci, tip.x, tip.y, 4.4, 4.4, ORB)
			_d(ci, tip.x, tip.y, 8, Color(CAST, 0.3))
		"flow", "flow_part":
			var t := hand + dir * minf(hand.distance_to(tip), 24.0)
			_dagger(ci, hand, t)
		"knight":
			_runed_sword(ci, r, hand, tip)
		"swash":
			_sword(ci, hand, tip, 1.6 if r >= 4 else 2.6, LEATHER)
		"seer":
			_ball(ci, hand + dir * 3.0, 4.6)
			_card(ci, tip.x, tip.y, dir.angle() + 0.5)
			_card(ci, tip.x - dir.x * 7.0, tip.y - dir.y * 7.0 + 5.0, dir.angle() - 0.2)
		"jester":
			_marotte(ci, hand - dir * 6.0, tip)
		"archer", "archer_part":
			bow(ci, hand, dir, 0.0, r)
		_:
			_sword(ci, hand, tip, 2.3, LEATHER)
	if fist:
		_o(ci, hand.x, hand.y, 2.6, 2.6, hand_color(art))


# --- The eight bodies ---------------------------------------------------------

## The cloth's sway in each of the four poses, for hems and tails.
static func _sway(frame: int) -> Array:
	var a := frame * TAU / 4.0
	return [sin(a) * 1.6, sin(a + 0.8) * 1.2, sin(a + 1.6) * 0.8, sin(a + 2.4) * 0.6]


static func _body_wanderer(ci: CanvasItem, s: Array, scarf := Color("e8dfc8")) -> void:
	_p(ci, [21, 21, 14, 23, 3 + s[0], 20, 5 + s[1], 25, 14, 27, 21, 25], scarf)
	_l(ci, 20, 44, 18, 60, PANTS.darkened(0.2), 5.5)
	_boots(ci, 17, 58, BOOT)
	_l(ci, 26, 44, 27, 60, PANTS, 5.5)
	_boots(ci, 27, 58, BOOT.lightened(0.06))
	_p(ci, [15, 24, 29, 24, 33, 44, 35 + s[3], 58, 24, 60, 13, 59, 9 + s[0], 56, 11, 44], CLOAK)
	_p(ci, [15, 24, 20, 24, 15, 58, 9 + s[0], 56, 11, 44], CLOAK.darkened(0.18), 0)
	_p(ci, [26, 30, 29, 30, 33, 44, 35 + s[3], 58, 31, 58], CLOAK.lightened(0.1), 0)
	_p(ci, [14, 42, 30, 42, 30, 46, 14, 46], LEATHER)
	_o(ci, 22, 44, 2.0, 2.0, GOLD)
	_l(ci, 24, 44, 9, 58, LEATHER.darkened(0.3), 3.4)
	_l(ci, 24, 44, 27, 40.5, LEATHER, 2.8)
	_l(ci, 22.5, 41, 29.5, 43, GOLD.darkened(0.2), 2.2)
	_d(ci, 27.6, 39.6, 1.6, STEEL)
	_d(ci, 24, 26, 1.8, GOLD)
	_o(ci, 24, 14.5, 7, 7.6, SKIN)
	_o(ci, 28.2, 14.8, 1.1, 1.5, DARK, 0)
	_l(ci, 25.5, 11.9, 30.6, 12.5, HAIR.darkened(0.2), 1.4)
	_p(ci, [30.5, 14.5, 33.5, 17.7, 30.5, 18.6], SKIN.darkened(0.04))
	_smile(ci, 25.8, 19.8, 4.2, SKIN.darkened(0.5))
	_p(ci, [16, 15, 16, 8, 21, 4, 27, 4.5, 31, 8, 29, 9, 22, 8.6, 20, 13, 19, 20, 16, 21], HAIR)


static func _body_blade(ci: CanvasItem, r: int, s: Array) -> void:
	var c := BLADE_C
	if r >= 5:
		_o(ci, 22, 34, 28, 34, Color(c, 0.2), 0)
	if r >= 3:
		_p(ci, [15, 24, 8 + s[0], 40, 3 + s[1], 58, 15, 59, 20, 46], c.darkened(0.35))
	_l(ci, 19, 44, 18, 59, STEEL.darkened(0.5), 6.5)
	_boots(ci, 17, 58, DARK)
	_l(ci, 26, 44, 27, 59, STEEL.darkened(0.15), 7)
	_boots(ci, 27, 58, DARK.lightened(0.08))
	_p(ci, [12, 23, 32, 23, 30, 46, 14, 46], STEEL.darkened(0.12))
	_p(ci, [13, 24, 19, 24, 18.5, 45, 15, 45], STEEL.lightened(0.1), 0)
	_p(ci, [18, 27, 26, 27, 28, 54, 22, 57, 16, 54], c)
	_l(ci, 22, 28, 22, 55, GOLD, 1.4)
	if r >= 2:
		_l(ci, 16, 54, 22, 57, GOLD, 1.6)
		_l(ci, 22, 57, 28, 54, GOLD, 1.6)
	_p(ci, [14, 43, 30, 43, 30, 47, 14, 47], LEATHER)
	_o(ci, 22, 45, 2.2, 2.2, GOLD)
	_o(ci, 12.5, 24, 6, 5, STEEL.darkened(0.25))
	_p(ci, [21, 20, 25, 20, 25, 25, 21, 25], SKIN.darkened(0.1), 0)
	_o(ci, 23, 14.5, 7, 7.6, SKIN)
	_smile(ci, 25.5, 19.2, 4.4, SKIN.darkened(0.5))
	_o(ci, 27.5, 15, 1.0, 1.5, DARK, 0)
	_l(ci, 25, 12.1, 30, 12.7, DARK.lightened(0.15), 1.4)
	_p(ci, [15.5, 15, 15, 8, 19, 4, 25, 3.5, 30, 7, 31, 12, 28, 11.5, 18, 12], STEEL)
	_p(ci, [27, 11, 29.4, 11, 29.4, 18, 28, 18], STEEL.darkened(0.2))
	if r >= 2:
		_l(ci, 15.2, 12.4, 30.6, 11.8, GOLD, 1.5)
	if r >= 4:
		_p(ci, [17, 5, 12, -4, 4, -6, -2, 2, 7, 1, 13, 4, 18, 9], c)
	else:
		_p(ci, [17, 5, 12, 0, 6, 1, 2, 7, 8, 5, 13, 6, 18, 9], c)
	if r >= 5:
		_p(ci, [15, 9, 9, 9, 4, -2, 11, 2], BONE)


static func _body_arcane(ci: CanvasItem, r: int, s: Array) -> void:
	var c := ARCANE_C
	if r >= 5:
		_o(ci, 22, 30, 26, 34, Color(CAST, 0.18), 0)
	_p(ci, [15, 24, 29, 24, 35 + s[3], 58, 31, 62, 22, 60, 13, 62, 9 + s[0], 58], c)
	_p(ci, [15, 24, 20, 24, 16, 60, 9 + s[0], 58], c.darkened(0.2), 0)
	if r >= 2:
		_p(ci, [9, 56, 13, 59, 22, 57.5, 31, 59, 35, 56, 35, 61, 31, 63, 22, 61, 13, 63, 9, 61], GOLD.darkened(0.25))
		_p(ci, [16, 39, 28, 39, 28.6, 43, 15.4, 43], GOLD.darkened(0.3))
	_d(ci, 22, 49, 2.0, Color(CAST, 0.7))
	if r >= 3:
		for st: Array in [[16, 47], [29, 53], [25, 33], [14, 54], [28, 44]]:
			_d(ci, st[0], st[1], 1.3, ORB)
	_p(ci, [13, 62, 19, 62, 22, 64, 13, 64], BOOT, 0.8)
	_p(ci, [25, 62, 31, 62, 34, 64, 25, 64], BOOT, 0.8)
	_o(ci, 23, 14.5, 6.5, 7.5, SKIN)
	_o(ci, 27, 14, 1.0, 1.4, DARK, 0)
	_p(ci, [30, 14, 33.5, 17.5, 30, 18.5], SKIN.darkened(0.05))
	_p(ci, [15, 18, 30, 19, 28, 28, 23, 38, 18, 28], Color("e8e8ef"))
	_l(ci, 19, 25, 22, 34, Color("c9c9d6"), 0.8)
	_p(ci, [26, 18.5, 32, 19, 30, 21, 26, 20.5], Color("f4f4fa"), 0.6)
	_l(ci, 24.5, 11.1, 29.5, 11.9, Color("f4f4fa"), 1.8)
	_o(ci, 23, 8.8, 13, 3.4, c.darkened(0.15))
	_p(ci, [15, 9, 31, 9, 26, -1, 21, -10, 12 + s[0], -14, 17, -5], c)
	_p(ci, [15.6, 6.5, 30.5, 6.5, 31, 9, 15, 9], GOLD.darkened(0.25), 0)
	_d(ci, 23, 2, 1.8, GOLD)
	_d(ci, 12 + s[0], -14, 1.8, GOLD)
	if r >= 4:
		_o(ci, 5, 22 + s[1], 2.8, 2.8, ORB)
		_o(ci, 3, 40 - s[1], 2.2, 2.2, ORB)
		_o(ci, 41, 8 + s[2], 2.2, 2.2, ORB)
	if r >= 5:
		_p(ci, [22, -24, 24.5, -17, 32, -17, 26, -12, 28, -5, 22, -9, 16, -5, 18, -12, 12, -17, 19.5, -17], GOLD)


static func _body_flow(ci: CanvasItem, r: int, s: Array) -> void:
	var c := FLOW_C
	var lean := 3.0
	if r >= 5:
		for i in 3:
			_l(ci, -8 - i * 2, 28 + i * 9, 8, 28 + i * 9, Color(c, 0.5), 2.0)
	if r >= 3:
		_p(ci, [21, 22, 13, 21, 3, 19 + s[0], -6 + s[1], 22 + s[0], 1, 27, 11, 27, 20, 29], c.darkened(0.15))
	else:
		_p(ci, [21, 22, 13, 21, 5, 22, 6, 27, 12, 27, 20, 29], c.darkened(0.15))
	_p(ci, [16, 25, 9 + s[0], 36, 10, 48, 16, 51, 20, 40], Color("2a2436"))
	_l(ci, 20, 44, 12, 58, PANTS.darkened(0.3), 5.5)
	_p(ci, [7, 57, 13, 57, 15, 61, 16, 64, 6, 64], BOOT.darkened(0.2))
	_l(ci, 24, 44, 32, 53, PANTS, 6)
	_l(ci, 32, 53, 29, 61, PANTS, 6)
	_p(ci, [26, 60, 32, 60, 34, 63, 38, 64, 26, 64], BOOT)
	_p(ci, [17 + lean, 24, 29 + lean, 26, 28, 46, 18, 46], CHARCOAL)
	_p(ci, [18 + lean, 25, 24 + lean, 25.5, 22, 46, 18, 46], Color("2c2638"), 0)
	_l(ci, 18.5 + lean, 26, 27.5, 43, LEATHER, 3.4)
	for i in 3:
		_d(ci, 20.5 + lean + i * 2.6 - i * 0.6, 29.5 + i * 5.2, 1.3, GOLD)
	_p(ci, [17, 43, 29, 43, 29, 47, 17, 47], LEATHER)
	_o(ci, 27, 49, 3.2, 3.6, GOLD.darkened(0.3))
	_d(ci, 27, 49, 1.2, GOLD.lightened(0.3))
	_p(ci, [20 + lean, 18, 20 + lean, 9, 27 + lean, 4.5, 34 + lean, 9, 35.5 + lean, 15, 31 + lean, 13, 26 + lean, 13.5,
		23 + lean, 19, 26 + lean, 27, 17 + lean, 26], c)
	_o(ci, 30 + lean, 16, 5, 6, SKIN.darkened(0.35))
	_p(ci, [27 + lean, 16.5, 35.5 + lean, 15.5, 34.5 + lean, 22, 29 + lean, 24], c.darkened(0.55))
	_o(ci, 32.5 + lean, 14.4, 1.7, 1.2, Color.WHITE, 0)
	_d(ci, 33.2 + lean, 14.4, 0.8, DARK)
	_l(ci, 30.5 + lean, 12, 35 + lean, 12.6, DARK, 1.0)
	# The far arm and its dagger.
	_l(ci, 19 + lean, 30, 15, 43, CHARCOAL.darkened(0.2), 4.5)
	_dagger(ci, Vector2(15, 43), Vector2(10, 53))
	_o(ci, 15, 43, 2.4, 2.4, SKIN)
	if r >= 2:
		_o(ci, 38, 31, 2.8, 3.1, GOLD)
		_d(ci, 37.3, 30, 0.9, Color("fff1d0"))
	if r >= 4:
		_d(ci, 41, 56, 1.5, Color.WHITE)
		_d(ci, 5, 52, 1.2, Color.WHITE)


static func _body_knight(ci: CanvasItem, r: int, s: Array, frame: int) -> void:
	if r >= 5:
		_o(ci, 22, 34, 30, 36, Color(CAST, 0.14), 0)
		for i in 10:
			var a := TAU * i / 10.0
			_d(ci, 22 + cos(a) * 19, 15 + sin(a) * 19, 1.5, RUNE_L)
	if r >= 4:
		_p(ci, [15, 24, 6 + s[0], 40, 1 + s[1], 58, 15, 59, 20, 46], Color("2b2245"))
		_l(ci, 15, 24, 6, 40, RUNE, 1.0)
	_l(ci, 19, 44, 18, 59, PLATE.darkened(0.4), 6.5)
	_boots(ci, 17, 58, DARK)
	_l(ci, 26, 44, 27, 59, PLATE.darkened(0.1), 7)
	_boots(ci, 27, 58, DARK.lightened(0.08))
	_p(ci, [12, 23, 32, 23, 30, 46, 14, 46], PLATE)
	_p(ci, [13, 24, 19, 24, 18.5, 45, 15, 45], PLATE_L, 0)
	_p(ci, [18, 27, 26, 27, 28, 54, 22, 57, 16, 54], INDIGO)
	_l(ci, 16, 54, 22, 57, BLADE_C, 1.6)
	_l(ci, 22, 57, 28, 54, BLADE_C, 1.6)
	_l(ci, 22, 28, 22, 54, RUNE, 1.2)
	_d(ci, 22, 36, 1.8, RUNE_L)
	_p(ci, [14, 43, 30, 43, 30, 47, 14, 47], LEATHER.darkened(0.3))
	_o(ci, 22, 45, 2.2, 2.2, RUNE)
	_o(ci, 12.5, 24, 6, 5, PLATE.darkened(0.2))
	_p(ci, [21, 20, 25, 20, 25, 25, 21, 25], SKIN.darkened(0.1), 0)
	_o(ci, 23, 14.5, 7, 7.6, SKIN)
	_o(ci, 27.5, 15, 1.1, 1.5, Color("d9b8ff"), 0)
	_l(ci, 25, 11.8, 30, 12.4, DARK.lightened(0.15), 1.5)
	_smile(ci, 25.5, 19.2, 4.4, SKIN.darkened(0.5))
	_p(ci, [15.5, 15, 15, 8, 19, 4, 25, 3.5, 30, 7, 31, 12, 28, 11.5, 18, 12], PLATE)
	_p(ci, [15.5, 13, 19.5, 13, 19.5, 21, 16, 19], PLATE.darkened(0.2))
	_p(ci, [27, 11, 29.4, 11, 29.4, 17, 28, 17], PLATE.darkened(0.2))
	_p(ci, [20, 4, 26, 3, 23, -9 if r >= 4 else -3], ARCANE_C)
	_d(ci, 23, 6.5, 1.5, RUNE_L)
	if r >= 4:
		# The sigil at its off hand, turning a little in each pose.
		var sg := Vector2(5, 38)
		_o(ci, sg.x, sg.y, 11, 11, Color(CAST, 0.2), 0)
		for i in 12:
			var a := TAU * i / 12.0 + frame * 0.26
			_d(ci, sg.x + cos(a) * 8.5, sg.y + sin(a) * 8.5, 1.1, RUNE_L)
		_d(ci, sg.x, sg.y, 3.4, RUNE)
		_d(ci, sg.x, sg.y, 1.5, RUNE_L)


static func _body_swash(ci: CanvasItem, r: int, s: Array) -> void:
	var ln := 3.0
	var boot := Color("5a3a24")
	var legs := Color("3a3042")
	if r >= 5:
		_p(ci, [8, 26, -8, 30, -8, 50, 6, 56], Color(COAT, 0.28), 0)
		_p(ci, [6, 22, -12, 26, -12, 46, 4, 50], Color(COAT, 0.15), 0)
	_p(ci, [17, 28, 9 + s[0], 42, 6 + s[1], 58, 16, 53, 21, 42], COAT.darkened(0.3))
	_l(ci, 20, 44, 12, 57, legs, 6)
	_p(ci, [6, 54, 14, 54, 16, 59, 17, 64, 5, 64], boot)
	_p(ci, [6, 52, 14, 52, 14, 55, 6, 55], boot.lightened(0.15))
	_l(ci, 25, 44, 32, 53, legs, 6.5)
	_l(ci, 32, 53, 29, 60, legs, 6.5)
	_p(ci, [24, 58, 32, 58, 34, 62, 38, 64, 24, 64], boot)
	_p(ci, [24, 55, 32, 55, 32, 59, 24, 59], boot.lightened(0.15))
	_p(ci, [17 + ln, 24, 29 + ln, 26, 28, 47, 17, 47], COAT)
	_p(ci, [22 + ln, 26, 27 + ln, 26.5, 25, 41, 22, 41], BONE)
	_l(ci, 18 + ln, 27, 28, 44, LEATHER, 2.2)
	_p(ci, [16, 42, 30, 42, 30, 47, 16, 47], FLOW_C)
	_p(ci, [27, 46, 31, 46, 31, 58 + s[2], 27.5, 55], FLOW_C.darkened(0.1))
	_o(ci, 23, 44.5, 1.8, 1.8, GOLD.darkened(0.3))
	_o(ci, 26 + ln, 17, 6.8, 7.4, SKIN)
	_o(ci, 30.5 + ln, 15.5, 1.1, 1.5, DARK, 0)
	_l(ci, 28 + ln, 12.4, 33.5 + ln, 13.0, DARK, 1.4)
	_smile(ci, 26 + ln, 21.4, 5.6, DARK)
	_p(ci, [20 + ln, 17, 20 + ln, 10, 26 + ln, 7, 32 + ln, 9, 30 + ln, 12, 24 + ln, 12.5, 22 + ln, 20], HAIR)
	if r < 4:
		_p(ci, [19 + ln, 12.5, 34 + ln, 10.5, 33.5 + ln, 15, 20 + ln, 16], BLADE_C)
		_p(ci, [19 + ln, 13, 12 + ln, 11, 14 + ln, 17], BLADE_C.darkened(0.15))
	else:
		_p(ci, [14 + ln, 12, 22 + ln, 5, 34 + ln, 6, 41 + ln, 11, 34 + ln, 11, 26 + ln, 8, 18 + ln, 13], Color("3a2a22"))
		_p(ci, [19 + ln, 9, 14 + ln, 0, 6 + ln, -7, 10 + ln, 1, 15 + ln, 6], BLADE_C)
		if r >= 5:
			_p(ci, [22 + ln, 7, 20 + ln, -2, 14 + ln, -10, 17 + ln, -2, 20 + ln, 5], FLOW_C)
	# The far arm and its dagger.
	var far := COAT.darkened(0.3)
	_l(ci, 20 + ln, 30, 14, 42, far, 4.5)
	_dagger(ci, Vector2(14, 42), Vector2(9, 52))
	_o(ci, 14, 42, 2.4, 2.4, SKIN)
	if r >= 5:
		_l(ci, 14, 42, -4, 36, Color(FLOW_C, 0.6), 3.0)
		_l(ci, 14, 42, -8, 46, Color(FLOW_C, 0.4), 2.0)


static func _body_seer(ci: CanvasItem, r: int, s: Array) -> void:
	var under := Color("6a4aa8")
	if r >= 5:
		_o(ci, 22, 30, 28, 34, Color(CAST, 0.16), 0)
		for st: Array in [[2, 8], [42, 6], [-3, 30], [46, 30], [10, -6], [34, -9]]:
			_d(ci, st[0], st[1], 1.6, Color("fff1d0"))
	_p(ci, [13, 60, 20, 60, 24, 62, 24, 64, 12, 64], DARK)
	_p(ci, [24, 60, 31, 60, 35, 62, 35, 64, 24, 64], DARK.lightened(0.05))
	_p(ci, [14, 26, 30, 26, 36 + s[3], 61, 8 + s[0], 61], SKIRT)
	_p(ci, [14, 26, 20, 26, 14, 61, 8 + s[0], 61], SKIRT.darkened(0.25), 0)
	_p(ci, [17, 44, 28, 44, 34, 61, 11, 61], under)
	_p(ci, [11, 56, 34, 56, 35, 58, 10, 58], FLOW_C, 0)
	for k in 6:
		_d(ci, 12.5 + k * 3.9, 59.5, 1.2, GOLD)
	_p(ci, [12, 24, 32, 24, 27, 44, 17, 44], Color("2a1f4a"))
	_l(ci, 13, 25, 18, 43, GOLD.darkened(0.1), 1.0)
	_l(ci, 31, 25, 26, 43, GOLD.darkened(0.1), 1.0)
	if r >= 4:
		for k in 5:
			_d(ci, 14.5 + k * 3.8, 40.0 - absf(k - 2) * 2.5, 1.3, GOLD)
		_d(ci, 22, 31, 1.6, Color("7be0ff"))
	_o(ci, 23.5, 15, 6.2, 7, SKIN)
	_p(ci, [19, 16.6, 31, 15.6, 30, 22, 21, 23.5], under)
	_l(ci, 19.6, 17.5, 30.4, 16.8, Color(1, 1, 1, 0.25), 0.8)
	_p(ci, [25.5, 12.8, 30, 12.2, 30, 15.2, 25.7, 15.4], Color.WHITE, 0.6)
	_o(ci, 28.2, 13.8, 1.3, 1.5, DARK, 0)
	_l(ci, 25, 11.2, 30.4, 12.0, DARK, 1.2)
	_d(ci, 18.4, 19.5, 1.5, GOLD)
	_d(ci, 18.4, 21.6, 0.9, GOLD)
	_p(ci, [14, 14, 15, 6, 22, 2.5, 30, 5.5, 32, 12.5, 28, 9, 20, 9, 18, 16, 20, 24, 14, 21], FLOW_C)
	_p(ci, [15, 11, 6 + s[0], 12, 3 + s[1], 22, 8, 17, 13, 18], FLOW_C.darkened(0.15))
	_l(ci, 15, 8.5, 31, 8.0, under, 1.8)
	_d(ci, 23.5, 8.2, 1.6, Color("7be0ff"))
	if r >= 5:
		_o(ci, 24.5, 5.4, 2.0, 1.2, Color.WHITE, 0.6)
		_d(ci, 24.5, 5.4, 0.7, ARCANE_C)
	# The far arm, with a card.
	_l(ci, 20, 30, 15, 43, SKIRT.lightened(0.1).darkened(0.2), 4.6)
	_o(ci, 15, 43, 2.4, 2.4, SKIN)
	_card(ci, 14, 40, -0.4)
	if r >= 4:
		_card(ci, 5, 20, -0.4, Color("e6d4ff"))
		_card(ci, 2, 46, 0.5, Color("e6d4ff"))
		_card(ci, 41, 8, 0.3, Color("e6d4ff"))
	if r >= 5:
		_card(ci, 44, 44, -0.3, Color("e6d4ff"))


static func _body_jester(ci: CanvasItem, s: Array) -> void:
	var o := BLADE_C
	var v := ARCANE_C
	var y := FLOW_C
	_l(ci, 19, 44, 17, 60, v, 6)
	_p(ci, [13, 58, 19, 58, 22, 61, 27, 59, 27, 63, 13, 64], y)
	_d(ci, 27.5, 58.5, 1.7, GOLD)
	_l(ci, 26, 44, 28, 60, o, 6)
	_p(ci, [23, 58, 29, 58, 32, 61, 37, 59, 37, 63, 23, 64], y.darkened(0.1))
	_d(ci, 37.5, 58.5, 1.7, GOLD)
	_p(ci, [13, 24, 31, 24, 32, 46, 12, 46], o)
	_p(ci, [22, 24, 31, 24, 32, 46, 22, 46], v, 0)
	_p(ci, [22, 26, 27.5, 33.5, 22, 41, 16.5, 33.5], y)
	for i in 4:
		_p(ci, [12.5 + i * 4.9, 45, 17.4 + i * 4.9, 45, 14.95 + i * 4.9, 52], [v, o, v, o][i] if i % 2 == 0 else y)
	_p(ci, [12, 41, 32, 41, 32, 44, 12, 44], DARK.lightened(0.1))
	for bx: float in [16.0, 22.0, 28.0]:
		_d(ci, bx, 33.5 if bx == 22.0 else 39.0, 1.5, GOLD)
	for i in 5:
		_o(ci, 14.5 + i * 3.7, 24.5, 3.2, 3.0, BONE if i % 2 == 0 else y.lightened(0.5))
	_o(ci, 23, 15, 7, 7.6, BONE)
	_p(ci, [27.6, 9.4, 29.8, 11.6, 27.6, 13.8, 25.4, 11.6], v, 0.6)
	_o(ci, 27.6, 15, 1.2, 1.6, DARK, 0)
	_o(ci, 21, 15, 1.1, 1.5, DARK, 0)
	_p(ci, [29.5, 16.2, 32.5, 18, 29.5, 19.6], o)
	_l(ci, 23.5, 20.2, 30.5, 19.2, DARK, 1.3)
	_l(ci, 30.5, 19.2, 31.6, 17.8, DARK, 1.2)
	_o(ci, 25.5, 18.6, 1.5, 1.1, Color(v, 0.55), 0)
	_p(ci, [14, 10, 22, 4, -3 + s[0], 19 + s[1]], o)
	_p(ci, [18, 6, 28, 6, 30, -12], v)
	_p(ci, [26, 6, 33, 8, 43, -1], y)
	_p(ci, [14, 10, 32, 10, 32, 6, 14, 6], BONE)
	_d(ci, -3 + s[0], 19.5 + s[1], 2.4, GOLD)
	_d(ci, 30, -12.5, 2.4, GOLD)
	_d(ci, 43.5, -1.5, 2.4, GOLD)
	# The far arm, in a glove.
	_l(ci, 20, 30, 14, 42, v.darkened(0.1), 4.8)
	_o(ci, 14, 42, 2.5, 2.5, BONE)


# --- Pieces -------------------------------------------------------------------

## A shape from a flat list of x, y, x, y..., with an outline `w` wide (none
## at 0).
static func _p(ci: CanvasItem, flat: Array, col: Color, w := 1.0) -> void:
	var pv := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pv.append(Vector2(flat[i], flat[i + 1]))
	_pv(ci, pv, col, w)


static func _pv(ci: CanvasItem, pv: PackedVector2Array, col: Color, w: float) -> void:
	HeroLook._fill(ci, pv, HeroLook._c(col))
	if w > 0.0 and HeroLook._shade.a == 0.0:
		var loop := pv.duplicate()
		loop.append(pv[0])
		HeroLook._loop(ci, loop, HeroLook.OUTLINE, w)


static func _o(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, col: Color, w := 1.0) -> void:
	var pv := HeroLook._arc(Vector2(cx, cy), rx, ry, 0.0, TAU, 20)
	pv.remove_at(pv.size() - 1)
	_pv(ci, pv, col, w)


static func _l(ci: CanvasItem, x1: float, y1: float, x2: float, y2: float, col: Color, w: float) -> void:
	HeroLook._line(ci, Vector2(x1, y1), Vector2(x2, y2), col, w)
	if w >= 2.5:
		HeroLook._dot(ci, Vector2(x1, y1), w * 0.5, col)
		HeroLook._dot(ci, Vector2(x2, y2), w * 0.5, col)


static func _d(ci: CanvasItem, x: float, y: float, r: float, col: Color) -> void:
	HeroLook._dot(ci, Vector2(x, y), r, col)


static func _boots(ci: CanvasItem, x: float, y: float, col: Color) -> void:
	_p(ci, [x - 3.0, y, x + 3.0, y, x + 3.5, y + 3, x + 8.0, y + 4.0, x + 8.0, 64, x - 3.0, 64], col)


## A small smile in profile: the front corner turns up.
static func _smile(ci: CanvasItem, x: float, y: float, w: float, col: Color) -> void:
	_l(ci, x, y - 0.3, x + w * 0.5, y + 0.7, col, 1.1)
	_l(ci, x + w * 0.5, y + 0.7, x + w, y - 0.9, col, 1.1)


## A sword from `h` to `t`: blade, guard, grip and pommel.
static func _sword(ci: CanvasItem, h: Vector2, t: Vector2, wide: float, grip: Color) -> void:
	var dir := (t - h).normalized()
	var side := Vector2(-dir.y, dir.x)
	var length := h.distance_to(t)
	if length > 6.0:
		_pv(ci, PackedVector2Array([h + side * wide, h + dir * (length - 6.0) + side * (wide - 0.3), t,
			h + dir * (length - 6.0) - side * (wide - 0.3), h - side * wide]), STEEL, 1.0)
		_l(ci, h.x + dir.x * 3, h.y + dir.y * 3, h.x + dir.x * (length - 7.0), h.y + dir.y * (length - 7.0),
			STEEL.darkened(0.25), 0.8)
	else:
		_l(ci, h.x, h.y, t.x, t.y, STEEL, 4.0)
	_l(ci, h.x - dir.x * 7, h.y - dir.y * 7, h.x, h.y, grip, 3.2)
	_l(ci, h.x - side.x * 6, h.y - side.y * 6, h.x + side.x * 6, h.y + side.y * 6, GOLD.darkened(0.2), 3.0)
	_d(ci, h.x - dir.x * 8.5, h.y - dir.y * 8.5, 2.2, GOLD)


## The knight's blade: a sword the runes run down, with a glow round it.
static func _runed_sword(ci: CanvasItem, r: int, h: Vector2, t: Vector2) -> void:
	var dir := (t - h).normalized()
	_l(ci, h.x, h.y, t.x, t.y, Color(CAST, 0.3), 9.0 if r >= 4 else 6.0)
	_sword(ci, h, t, 2.3, LEATHER)
	_l(ci, h.x + dir.x * 6, h.y + dir.y * 6, t.x - dir.x * 6, t.y - dir.y * 6, RUNE, 1.2)


static func _dagger(ci: CanvasItem, h: Vector2, t: Vector2) -> void:
	var dir := (t - h).normalized()
	var side := Vector2(-dir.y, dir.x)
	_pv(ci, PackedVector2Array([h + side * 1.8, t, h - side * 1.8]), STEEL, 1.0)
	_l(ci, h.x - dir.x * 4.5, h.y - dir.y * 4.5, h.x, h.y, LEATHER, 2.6)
	_l(ci, h.x - side.x * 3.5, h.y - side.y * 3.5, h.x + side.x * 3.5, h.y + side.y * 3.5, GOLD.darkened(0.3), 2.0)
	_d(ci, h.x - dir.x * 5.5, h.y - dir.y * 5.5, 1.5, GOLD)


## The seer's crystal ball, with its glow.
static func _ball(ci: CanvasItem, at: Vector2, r: float) -> void:
	_o(ci, at.x, at.y, r + 4.0, r + 4.0, Color(CAST, 0.28), 0)
	_o(ci, at.x, at.y, r, r, Color("d9c8ff"))
	_d(ci, at.x - r * 0.35, at.y - r * 0.4, r * 0.3, Color.WHITE)


static func _card(ci: CanvasItem, cx: float, cy: float, ang: float, col := BONE) -> void:
	var flat := []
	for v: Vector2 in [Vector2(-3, -4.5), Vector2(3, -4.5), Vector2(3, 4.5), Vector2(-3, 4.5)]:
		var rv := v.rotated(ang)
		flat.append(cx + rv.x)
		flat.append(cy + rv.y)
	_p(ci, flat, col)
	_d(ci, cx, cy, 1.1, FLOW_C.darkened(0.1))


## The jester's stick, with a small jester's head on it.
static func _marotte(ci: CanvasItem, from: Vector2, hd: Vector2) -> void:
	_l(ci, from.x, from.y, hd.x, hd.y, WOOD, 1.8)
	_p(ci, [hd.x - 3, hd.y - 2, hd.x + 3, hd.y - 2, hd.x - 6, hd.y - 11], BLADE_C)
	_p(ci, [hd.x - 1, hd.y - 2, hd.x + 5, hd.y - 2, hd.x + 9, hd.y - 10], FLOW_C)
	_o(ci, hd.x, hd.y + 1, 4.2, 4.4, BONE)
	_d(ci, hd.x + 1.2, hd.y, 0.8, DARK)
	_l(ci, hd.x - 1, hd.y + 3, hd.x + 2.6, hd.y + 2.6, DARK, 0.8)
	_d(ci, hd.x - 6, hd.y - 11, 1.4, GOLD)
	_d(ci, hd.x + 9, hd.y - 10, 1.4, GOLD)


# --- The Archer (Hearthguard) --------------------------------------------------

## A hunter in a green hood with a quiver on the back: the Wanderer's build,
## in the same hand as the other drawings. Rank adds a feather (2), a
## mantle of leaves (4) and a glowing string (5).
static func _body_archer(ci: CanvasItem, r: int, s: Array) -> void:
	var c := HUNT_C
	# The hood's tail and the mantle behind.
	if r >= 4:
		_p(ci, [21, 22, 12, 22, 2 + s[0], 30, 4 + s[1], 46, 10, 50, 16, 40], c.darkened(0.35))
	_p(ci, [21, 21, 14, 23, 4 + s[0], 22, 6 + s[1], 28, 14, 28, 21, 26], c.darkened(0.15))
	_quiver(ci)
	_l(ci, 20, 44, 18, 60, PANTS.darkened(0.2), 5.5)
	_boots(ci, 17, 58, BOOT)
	_l(ci, 26, 44, 27, 60, PANTS, 5.5)
	_boots(ci, 27, 58, BOOT.lightened(0.06))
	# Tunic and its skirt.
	_p(ci, [15, 24, 29, 24, 31, 44, 32 + s[3], 52, 13, 52, 12, 44], HUNT_D)
	_p(ci, [15, 24, 20, 24, 16, 51, 13, 52, 12, 44], HUNT_D.darkened(0.2), 0)
	_l(ci, 16, 25, 28, 43, LEATHER, 3.0)
	_p(ci, [13, 42, 31, 42, 31, 46, 13, 46], LEATHER)
	_o(ci, 22, 44, 2.0, 2.0, GOLD)
	# Head, then the hood over it.
	_o(ci, 25, 14.5, 6.6, 7.4, SKIN)
	_o(ci, 28.6, 14.6, 1.1, 1.5, DARK, 0)
	_l(ci, 26, 11.9, 31, 12.4, HAIR.darkened(0.2), 1.3)
	_p(ci, [30.8, 14.4, 33.4, 17.4, 30.6, 18.2], SKIN.darkened(0.04))
	_smile(ci, 26.2, 19.6, 3.8, SKIN.darkened(0.5))
	_p(ci, [16, 22, 15, 10, 19, 4, 26, 2.5, 32, 6, 33.5, 10, 30, 8.5, 24, 8, 21, 12, 20, 21], c)
	_l(ci, 24, 8.2, 31.5, 9.2, c.darkened(0.3), 1.2)
	if r >= 2:
		_p(ci, [19, 6, 10, -4, 13, 5], GOLD)
		_l(ci, 17.6, 4.6, 12, -1.4, GOLD.darkened(0.3), 0.8)
	if r >= 4:
		for i in 3:
			_p(ci, [13.0 + i * 6.0, 23.0, 16.0 + i * 6.0, 19.5, 19.0 + i * 6.0, 23.0, 16.0 + i * 6.0, 26.0], c.lightened(0.15 * i))
	# The far arm.
	_l(ci, 18, 28, 14, 41, HUNT_D.darkened(0.25), 4.5)
	_o(ci, 14, 41, 2.4, 2.4, SKIN)


## The quiver on the back, its fletchings showing over the shoulder.
static func _quiver(ci: CanvasItem) -> void:
	_p(ci, [7, 23, 12, 20, 19, 39, 14, 42], LEATHER)
	_l(ci, 9, 25, 16, 39, LEATHER.darkened(0.3), 1.0)
	for i in 3:
		var base := Vector2(8.5 + i * 2.2, 22.0 - i * 0.6)
		_l(ci, base.x, base.y, base.x - 2.5, base.y - 7.0, WOOD, 1.2)
		_p(ci, [base.x - 2.5, base.y - 7.0, base.x - 5.5, base.y - 11.0, base.x - 1.5, base.y - 10.0], Color("e8dfc8"))


## A bow held at `grip`, the arrow pointing along `dir`, its string drawn
## back `pull` (0 to 1) with an arrow nocked while pulled. Public: HeroLook
## draws it live while the Archer aims.
static func bow(ci: CanvasItem, grip: Vector2, dir: Vector2, pull: float, r: int) -> void:
	var side := Vector2(-dir.y, dir.x)
	var limb := 19.0
	var bend := 5.0 + pull * 3.0
	var pts := PackedVector2Array()
	for i in 13:
		var k := lerpf(-1.0, 1.0, i / 12.0)
		pts.append(grip + side * k * limb + dir * (bend * (1.0 - k * k)) - dir * (absf(k) * pull * 5.0))
	var top := pts[0]
	var bottom := pts[pts.size() - 1]
	var nock := grip - dir * (2.0 + pull * 15.0)
	var string := Color("f4efe6") if r < 5 else Color("dfffd0")
	HeroLook._line(ci, top, nock, string, 1.0)
	HeroLook._line(ci, nock, bottom, string, 1.0)
	for i in pts.size() - 1:
		HeroLook._line(ci, pts[i], pts[i + 1], WOOD.darkened(0.1), 3.0)
	HeroLook._dot(ci, top, 1.6, GOLD.darkened(0.2))
	HeroLook._dot(ci, bottom, 1.6, GOLD.darkened(0.2))
	if pull > 0.0:
		var tip := nock + dir * 30.0
		HeroLook._line(ci, nock, tip, WOOD, 1.4)
		_pv(ci, PackedVector2Array([tip + dir * 5.0, tip + side * 2.4, tip - side * 2.4]), STEEL, 0.8)
		_pv(ci, PackedVector2Array([nock, nock - dir * 5.0 + side * 2.6, nock + dir * 1.0]), Color("e8dfc8"), 0.0)
		_pv(ci, PackedVector2Array([nock, nock - dir * 5.0 - side * 2.6, nock + dir * 1.0]), Color("e8dfc8"), 0.0)
		HeroLook._dot(ci, nock, 2.4, SKIN)
