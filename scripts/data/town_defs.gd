class_name TownDefs
extends RefCounted
## The Town round the Hearth: MatchRPG's nine buildings (its UpgradeDefs),
## each standing on the plaza's rim. Every building starts dark and empty.
## Gold activates it (level 1) and levels it up to MAX. The Town is shared:
## any hero can pay, and every hero gets the bonus.
##
## MatchRPG's bonuses are moved to this game. Its Barracks, Forge, Mage
## Tower, Armory and Mint give what they give there. Its Tinker, Woodcutter
## and Quarry made traps fail and brought wood and stone, which this game
## has none of, so here they feed the road fires and the Hearth instead. Its
## Alchemist adds potion belt slots there and sells cheaper here.

const MAX := 5
## A level costs `cost` times COST_GROWTH for every level already built.
const COST_GROWTH := 1.7
## How close a hero has to stand to a building's door to build it.
const BUILD_R := 210.0
## The art (BuildingIcon) has ten levels. A level here is two of them, so a
## maxed building wears MatchRPG's gold star.
const ART_STEP := 2

const BUILDINGS := [
	{"id": "barracks", "name": "Barracks", "cost": 130, "per": 0.05, "key": "hp",
		"desc": "+5% max HP for every hero, per level"},
	{"id": "armory", "name": "Armory", "cost": 120, "per": 1.5, "key": "armor",
		"desc": "+1.5 armor for every hero, per level"},
	{"id": "tower", "name": "Mage Tower", "cost": 150, "per": 0.05, "key": "spell",
		"desc": "+5% ability damage for every hero, per level"},
	{"id": "forge", "name": "Forge", "cost": 150, "per": 0.05, "key": "dmg",
		"desc": "+5% damage for every hero, per level"},
	{"id": "locksmith", "name": "Tinker", "cost": 110, "per": 0.3, "key": "fire_hp",
		"desc": "Road fires: +30% HP and kindle speed, per level"},
	{"id": "quarry", "name": "Quarry", "cost": 120, "per": 0.12, "key": "hearth",
		"desc": "Stone walls: +12% Hearth max HP, per level"},
	{"id": "alchemist", "name": "Alchemist", "cost": 100, "per": 0.08, "key": "discount",
		"desc": "Potions 8% off per level, sold at its door"},
	{"id": "mint", "name": "Mint", "cost": 120, "per": 0.12, "key": "gold",
		"desc": "+12% gold, per level"},
	{"id": "woodcutter", "name": "Woodcutter", "cost": 100, "per": 0.3, "key": "fire_heal",
		"desc": "Road fires heal 30% more, per level"},
]

## Where each building's foot is, in the order above: on a ring 480 px out
## from the Hearth. One stands in each gap between the gates up north (the
## gates are west at 198 degrees, north at 270, east at 342), and seven in a
## row along the south, backed by the town wall (WALL_IN, WALL_FROM to
## WALL_TO), so there is no notch between them to get stuck in.
const RING := 480.0
const ANGLES := [234.0, 36.0, 306.0, 9.0, 171.0, 63.0, 90.0, 117.0, 144.0]
const WALL_IN := 420.0
const WALL_FROM := 9.0
const WALL_TO := 171.0
## How wide a building is drawn, and how much of it is solid.
const DRAW := 176.0
const SOLID_R := 66.0


static func get_def(id: String) -> Dictionary:
	for b: Dictionary in BUILDINGS:
		if b["id"] == id:
			return b
	return {}


static func ids() -> Array:
	var out: Array = []
	for b: Dictionary in BUILDINGS:
		out.append(b["id"])
	return out


static func foot(id: String) -> Vector2:
	var i := ids().find(id)
	return MapData.HEARTH + Vector2.from_angle(deg_to_rad(ANGLES[i])) * RING


## Which way the building faces: toward the Hearth.
static func facing(id: String) -> Vector2:
	return (MapData.HEARTH - foot(id)).normalized()


## Where a hero stands to build it: just in front of it, toward the Hearth.
static func door(id: String) -> Vector2:
	return foot(id) + facing(id) * 125.0


static func level(town: Dictionary, id: String) -> int:
	return int(town.get(id, 0))


## The gold the next level costs, or -1 at MAX.
static func cost(town: Dictionary, id: String) -> int:
	var lv := level(town, id)
	if lv >= MAX:
		return -1
	return roundi(float(get_def(id)["cost"]) * pow(COST_GROWTH, lv) / 5.0) * 5


## A building's bonus at its level now (0 when not built): the share or the
## points its `key` adds.
static func bonus(town: Dictionary, key: String) -> float:
	for b: Dictionary in BUILDINGS:
		if b["key"] == key:
			return float(b["per"]) * level(town, b["id"])
	return 0.0


## A potion's price after the Alchemist's discount.
static func potion_price(town: Dictionary, id: String) -> int:
	return roundi(float(PotionDefs.get_def(id)["price"]) * (1.0 - bonus(town, "discount")))


## The building nearest `p` within BUILD_R of its door, or "".
static func near(p: Vector2, reach := BUILD_R) -> String:
	var best := ""
	var bd := reach
	for id: String in ids():
		var d := p.distance_to(door(id))
		if d < bd:
			bd = d
			best = id
	return best


## What the next level does, for the card: "Level 2: +10% max HP".
static func next_text(town: Dictionary, id: String) -> String:
	var b := get_def(id)
	var lv := level(town, id) + 1
	var per: float = b["per"]
	match str(b["key"]):
		"hp":
			return "+%d%% max HP" % roundi(per * lv * 100.0)
		"armor":
			return "+%s armor" % str(snappedf(per * lv, 0.1))
		"spell":
			return "+%d%% ability damage" % roundi(per * lv * 100.0)
		"dmg":
			return "+%d%% damage" % roundi(per * lv * 100.0)
		"fire_hp":
			return "road fires +%d%% HP and kindle speed" % roundi(per * lv * 100.0)
		"hearth":
			return "+%d%% Hearth HP" % roundi(per * lv * 100.0)
		"discount":
			return "potions %d%% off" % roundi(per * lv * 100.0)
		"gold":
			return "+%d%% gold" % roundi(per * lv * 100.0)
		"fire_heal":
			return "road fires heal +%d%%" % roundi(per * lv * 100.0)
	return ""
