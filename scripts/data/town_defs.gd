class_name TownDefs
extends RefCounted
## The Town: MatchRPG's nine buildings (its UpgradeDefs), laid out along
## its streets like MatchRPG's Town screen turned upside down, so its open
## end faces north to the Crossroads and the Mage Tower stands at the back.
## Every building starts dark and empty. Gold activates it (level 1) and
## levels it up to MAX. The Town is shared: any hero can pay, and every hero
## gets the bonus.
##
## The buildings are what the heroes defend. Mobs that get past the heroes
## walk to the nearest standing building and bash it. A building at 0 HP is
## a ruin and gives nothing until a hero pays to rebuild it. When all nine
## are ruins, the Town has fallen and the run is lost.
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
	{"id": "quarry", "name": "Quarry", "cost": 120, "per": 0.15, "key": "walls",
		"desc": "Stone walls: +15% HP for every building, per level"},
	{"id": "alchemist", "name": "Alchemist", "cost": 100, "per": 0.08, "key": "discount",
		"desc": "Potions 8% off per level, sold at its door"},
	{"id": "mint", "name": "Mint", "cost": 120, "per": 0.12, "key": "gold",
		"desc": "+12% gold, per level"},
	{"id": "woodcutter", "name": "Woodcutter", "cost": 100, "per": 0.3, "key": "fire_heal",
		"desc": "Road fires heal 30% more, per level"},
]

## Where each building's foot is (the middle of its front, on the ground).
## Rows from north to south, as MatchRPG's Town screen flipped: the Mint and
## the Alchemist meet the road from the Crossroads first, then the
## Woodcutter, Forge, Tinker and Quarry, and the Barracks, Mage Tower and
## Armory at the back. Each row's doors open south onto its street.
const FEET := {
	"mint": Vector2(1560, 1960), "alchemist": Vector2(2440, 1960),
	"woodcutter": Vector2(1290, 2350), "forge": Vector2(1680, 2340),
	"locksmith": Vector2(2320, 2340), "quarry": Vector2(2710, 2350),
	"barracks": Vector2(1430, 2730), "tower": Vector2(2000, 2710), "armory": Vector2(2570, 2730),
}
## The streets, as polylines, drawn under the buildings (MapView). The
## first is the road from the Crossroads, down the middle to the Mage Tower.
const STREETS := [
	[Vector2(2000, 1380), Vector2(2000, 1720), Vector2(1975, 2030), Vector2(2020, 2270), Vector2(2000, 2415)],
	[Vector2(1390, 2035), Vector2(1700, 2030), Vector2(2300, 2040), Vector2(2610, 2035)],
	[Vector2(1160, 2418), Vector2(1700, 2410), Vector2(2300, 2410), Vector2(2840, 2420)],
	[Vector2(1730, 2410), Vector2(1712, 2600), Vector2(1735, 2800)],
	[Vector2(2270, 2410), Vector2(2290, 2600), Vector2(2265, 2800)],
	[Vector2(1280, 2802), Vector2(1700, 2798), Vector2(2300, 2800), Vector2(2720, 2805)],
]
## How wide a building is drawn, and its solid body: a capsule SOLID_R wide
## from just above its foot up BODY pixels.
const DRAW := 236.0
const SOLID_R := 78.0
const BODY := 140.0
## A building's HP at chapter 1 for one player. It grows with the chapter
## as fast as mob attack does (ChapterDefs.ATK_SCALE), so a leak costs about
## the same number of hits in every chapter, and with the party
## (HP_PER_PLAYER), its level and the Quarry.
const HP := 1500.0
const HP_PER_PLAYER := 0.5
const HP_PER_LEVEL := 0.15


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
	return FEET[id]


## Where a hero stands to build it: on the street in front of its door.
static func door(id: String) -> Vector2:
	return foot(id) + Vector2(0, 70)


## How far `p` is from building `id`'s solid body (0 or less inside it).
static func body_dist(id: String, p: Vector2) -> float:
	var f := foot(id) + Vector2(0, -30)
	return MapData._seg_dist(p, f, f - Vector2(0, BODY)) - SOLID_R


## The building whose body `p` is within `pad` of, or "".
static func solid_at(p: Vector2, pad: float) -> String:
	for id: String in ids():
		if body_dist(id, p) < pad:
			return id
	return ""


## Building `id`'s max HP in chapter `c` for `players` heroes.
static func max_hp(town: Dictionary, id: String, c: int, players: int) -> float:
	return HP * float(ChapterDefs.ATK_SCALE[clampi(c, 0, 4)]) * (1.0 + HP_PER_PLAYER * (players - 1)) \
		* (1.0 + HP_PER_LEVEL * level(town, id)) * (1.0 + bonus(town, "walls"))


static func level(town: Dictionary, id: String) -> int:
	return int(town.get(id, 0))


## The gold the next level costs, or -1 at MAX.
static func cost(town: Dictionary, id: String) -> int:
	var lv := level(town, id)
	if lv >= MAX:
		return -1
	return roundi(float(get_def(id)["cost"]) * pow(COST_GROWTH, lv) / 5.0) * 5


## The gold to rebuild a ruin that fell at level `lv`: that level's price
## again (an unbuilt ruin comes back at level 1, for the activation price).
static func rebuild_cost(id: String, lv: int) -> int:
	return roundi(float(get_def(id)["cost"]) * pow(COST_GROWTH, maxi(0, lv - 1)) / 5.0) * 5


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
		"walls":
			return "+%d%% HP for every building" % roundi(per * lv * 100.0)
		"discount":
			return "potions %d%% off" % roundi(per * lv * 100.0)
		"gold":
			return "+%d%% gold" % roundi(per * lv * 100.0)
		"fire_heal":
			return "road fires heal +%d%%" % roundi(per * lv * 100.0)
	return ""
