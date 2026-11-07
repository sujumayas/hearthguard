class_name TileTypes
extends RefCounted
## Tile kinds that can appear on the match board, with their colors. Each
## tile's symbol is drawn by TileIcon. BOULDER never spawns on its own:
## bosses drop it to clog the board. It has no symbol and matching it does
## nothing but clear it. DROSS never spawns either: a Dark Gnome's hex turns
## gold into it, and it matches nothing at all until the gnome falls.

enum Type { SWORD, STAFF, SHIELD, KIT, GOLD, WOOD, STONE, BOULDER, DROSS }

const COLORS := {
	Type.SWORD: Color("FD4C4E"),
	Type.STAFF: Color("C769ED"),
	Type.SHIELD: Color("61A0FF"),
	Type.KIT: Color("60E5CF"),
	Type.GOLD: Color("FFC935"),
	Type.WOOD: Color("DF8140"),
	Type.STONE: Color("DFDFDF"),
	Type.BOULDER: Color("5d6b4c"),
	Type.DROSS: Color("6a4c86"),
}

## Relative spawn chance. Upgrades will modify a copy of this later.
const DEFAULT_WEIGHTS := {
	Type.SWORD: 24,
	Type.STAFF: 22,
	Type.SHIELD: 14,
	Type.KIT: 10,
	Type.GOLD: 10,
	Type.WOOD: 10,
	Type.STONE: 10,
}

## What DEFAULT_WEIGHTS adds up to.
const DEFAULT_TOTAL := 100

## The tiles that fill material meters rather than fight.
const RESOURCES := [Type.GOLD, Type.WOOD, Type.STONE]
## What the player reads for a material kept as `key` ("gold", "wood",
## "stone"): gold is coins on screen, so it's never taken for a tier of
## mastery (see TierDefs).
const MATERIAL_NAMES := {"gold": "coins"}


static func material_name(key: String) -> String:
	return MATERIAL_NAMES.get(key, key)


## `weights` without the gold tile, for the no-gold game (see
## GameState.no_gold). Gold's share goes to wood and stone, so the fighting
## tiles come as often as before.
static func without_gold(weights: Dictionary) -> Dictionary:
	var w := weights.duplicate()
	var gold: int = w.get(Type.GOLD, 0)
	w.erase(Type.GOLD)
	w[Type.WOOD] += gold / 2
	w[Type.STONE] += gold - gold / 2
	return w


static func color(t: int) -> Color:
	return COLORS[t]
