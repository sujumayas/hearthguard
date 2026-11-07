class_name MobDefs
extends RefCounted
## Every creature of MatchRPG's five worlds, as a hero defense mob. Names,
## colors, lore, base HP and attack, attack interval and the sword/staff
## weaknesses (`phys`, `mag`) come from MatchRPG's EnemyDefs; HP_MULT and
## ATK_MULT turn its numbers into this game's (heroes here hit for ~30, not
## ~10). `look` is the EnemyLook id that draws it (the id itself).
##
## `ai` picks the brain, from the AI study's "start simple" advice:
##   fodder:  march the corridor, bite the nearest hero in aggro range.
##   ranged:  as fodder, but holds a ring at `reach` and backs off (kites).
##   brute:   as fodder, slower, hits harder, shoves the hero.
##   charger: winds up (a telegraphed line) and dashes through.
## `trait` is one small twist, read by MobSim (see MobSim._on_hit_hero and
## MobSim._on_death).

const HP_MULT := 3.2
const ATK_MULT := 3.6
## Damage taken multipliers are kept within this, so no team is walled by
## a ghost's 0.25 against swords. Sensation first: weak and strong still
## show, as a color on the number.
const RESIST_MIN := 0.6
const RESIST_MAX := 1.5

const MOBS := {
	# The Underground Forest
	"wolf": {"name": "Wolf", "hp": 16, "atk": 4, "interval": 1.2, "phys": 1.0, "mag": 1.0, "color": Color("8d8d99"),
		"xp": 3, "ai": "fodder", "speed": 205.0, "size": 0.5,
		"lore": "Hunts along the edge of the trees, quick to bite and quicker to bite again."},
	"goblin": {"name": "Goblin", "hp": 22, "atk": 5, "interval": 1.8, "phys": 1.25, "mag": 0.75, "color": Color("7fa04a"),
		"xp": 4, "ai": "ranged", "missile": "rock", "reach": 300.0, "speed": 150.0, "size": 0.48,
		"lore": "Throws rocks, then laughs at its own aim."},
	"treant_sapling": {"name": "Treant Sapling", "hp": 30, "atk": 5, "interval": 2.6, "phys": 0.5, "mag": 1.5,
		"color": Color("6b4f2a"), "xp": 5, "ai": "brute", "speed": 115.0, "size": 0.56,
		"lore": "A young tree that walked off in a temper. Its bark turns blades aside."},
	"giant_spider": {"name": "Giant Spider", "hp": 24, "atk": 6, "interval": 2.0, "phys": 1.0, "mag": 1.0,
		"color": Color("3d3342"), "xp": 5, "ai": "ranged", "missile": "web", "reach": 260.0, "speed": 170.0,
		"size": 0.52, "trait": "slow", "lore": "Spits webs from the canopy and waits."},
	"wicked_vine": {"name": "Wicked Vine", "hp": 26, "atk": 3, "interval": 3.0, "phys": 1.25, "mag": 0.5,
		"color": Color("3f7a38"), "xp": 5, "ai": "fodder", "speed": 120.0, "size": 0.52, "trait": "root",
		"lore": "A creeper that grows toward whoever walks past, and holds on to what it reaches."},
	"boar": {"name": "Boar", "hp": 30, "atk": 7, "interval": 2.8, "phys": 1.0, "mag": 1.25, "color": Color("8a5a3a"),
		"xp": 5, "ai": "charger", "speed": 150.0, "size": 0.54,
		"lore": "Rootling beast of the deep wood. It charges once, slow to start and hard to turn."},
	"dark_gnome": {"name": "Dark Gnome", "hp": 16, "atk": 4, "interval": 1.3, "phys": 1.25, "mag": 0.5,
		"color": Color("7a6a9a"), "xp": 5, "ai": "fodder", "speed": 190.0, "size": 0.42, "trait": "hex",
		"lore": "A gnome from the roots below, with a sack for coins and a hex for the rest."},
	# The Upper Dungeon
	"skeleton": {"name": "Skeleton", "hp": 28, "atk": 6, "interval": 2.0, "phys": 0.5, "mag": 1.5, "color": Color("e6e1d3"),
		"xp": 5, "ai": "ranged", "missile": "bone", "reach": 280.0, "speed": 140.0, "size": 0.52,
		"lore": "Bones held together by old orders. Blades slip between its ribs."},
	"ghost": {"name": "Ghost", "hp": 22, "atk": 5, "interval": 1.8, "phys": 0.25, "mag": 1.5, "color": Color("9fd8e8"),
		"xp": 5, "ai": "fodder", "speed": 175.0, "size": 0.5, "trait": "phase",
		"lore": "Cold air with a grudge. Steel passes right through it."},
	"imp": {"name": "Imp", "hp": 18, "atk": 5, "interval": 1.4, "phys": 1.5, "mag": 0.5, "color": Color("e8903a"),
		"xp": 4, "ai": "ranged", "missile": "fire", "reach": 270.0, "speed": 190.0, "size": 0.44,
		"lore": "A spark of mischief that throws fire and runs."},
	"orc": {"name": "Orc", "hp": 45, "atk": 9, "interval": 2.6, "phys": 1.0, "mag": 0.75, "color": Color("5c8a3a"),
		"xp": 8, "ai": "brute", "speed": 135.0, "size": 0.6, "lore": "Big, slow, and very sure of itself."},
	"cultist": {"name": "Cultist", "hp": 26, "atk": 7, "interval": 2.0, "phys": 1.25, "mag": 0.75, "color": Color("8a3a5c"),
		"xp": 6, "ai": "ranged", "missile": "bolt", "reach": 320.0, "speed": 145.0, "size": 0.5,
		"lore": "Mutters to something beneath the dungeon, and throws bolts of it."},
	# The Caves
	"bat_swarm": {"name": "Bat Swarm", "hp": 14, "atk": 3, "interval": 0.9, "phys": 1.0, "mag": 1.25, "color": Color("4a4058"),
		"xp": 4, "ai": "fodder", "speed": 225.0, "size": 0.46, "lore": "A hundred wings and one appetite. Fast, but fragile."},
	"kobold_miner": {"name": "Kobold Miner", "hp": 30, "atk": 7, "interval": 2.0, "phys": 1.0, "mag": 1.0,
		"color": Color("c28a4a"), "xp": 6, "ai": "ranged", "missile": "rock", "reach": 280.0, "speed": 150.0, "size": 0.48,
		"lore": "Digs for gems, finds adventurers, throws rocks at both."},
	"cave_crawler": {"name": "Cave Crawler", "hp": 40, "atk": 8, "interval": 2.4, "phys": 0.75, "mag": 1.25,
		"color": Color("6a7a5a"), "xp": 8, "ai": "brute", "speed": 140.0, "size": 0.58,
		"lore": "An armored thing that clicks in the dark."},
	"glowcap": {"name": "Glowcap", "hp": 24, "atk": 6, "interval": 1.8, "phys": 1.5, "mag": 0.5, "color": Color("5ad0c0"),
		"xp": 5, "ai": "ranged", "missile": "spore", "reach": 250.0, "speed": 130.0, "size": 0.48, "trait": "slow",
		"lore": "A mushroom that glows to lure the curious, then sneezes spores at them."},
	"stone_elemental": {"name": "Stone Elemental", "hp": 50, "atk": 10, "interval": 3.0, "phys": 0.5, "mag": 1.25,
		"color": Color("7d7f86"), "xp": 10, "ai": "ranged", "missile": "boulder", "reach": 300.0, "speed": 105.0,
		"size": 0.66, "lore": "The cave itself, angry and walking. It throws pieces of itself."},
	# The Drowned Temple
	"deep_one": {"name": "Deep One", "hp": 34, "atk": 7, "interval": 2.0, "phys": 1.0, "mag": 1.0, "color": Color("4f7f78"),
		"xp": 7, "ai": "fodder", "speed": 160.0, "size": 0.54,
		"lore": "It came up the well the cult dug, and it remembers the way back down."},
	"serpent_man": {"name": "Serpent Man", "hp": 28, "atk": 7, "interval": 2.0, "phys": 1.0, "mag": 0.75,
		"color": Color("6f8f4a"), "xp": 7, "ai": "ranged", "missile": "venom", "reach": 280.0, "speed": 160.0,
		"size": 0.52, "trait": "poison",
		"lore": "An old race of serpents in a cultist's robe. Its hood hides more than a face."},
	"drowned_acolyte": {"name": "Drowned Acolyte", "hp": 26, "atk": 7, "interval": 2.0, "phys": 1.25, "mag": 0.75,
		"color": Color("3e5f6e"), "xp": 6, "ai": "ranged", "missile": "bolt", "reach": 320.0, "speed": 145.0, "size": 0.5,
		"lore": "A cultist who walked into the temple pool to hear the Sleeper better."},
	"night_gaunt": {"name": "Night-gaunt", "hp": 18, "atk": 4, "interval": 1.0, "phys": 1.0, "mag": 1.25,
		"color": Color("2c2a36"), "xp": 6, "ai": "fodder", "speed": 230.0, "size": 0.48,
		"lore": "Faceless, silent and quick. It tickles before it takes."},
	"gibbering_mass": {"name": "Gibbering Mass", "hp": 56, "atk": 11, "interval": 3.0, "phys": 1.25, "mag": 0.5,
		"color": Color("8a9a6e"), "xp": 12, "ai": "brute", "speed": 110.0, "size": 0.66, "trait": "split",
		"lore": "Many mouths, many eyes, one terrible opinion."},
	# The Plains of Hell
	"hellhound": {"name": "Hellhound", "hp": 22, "atk": 5, "interval": 1.1, "phys": 1.0, "mag": 1.0, "color": Color("3d3436"),
		"xp": 6, "ai": "fodder", "speed": 215.0, "size": 0.52, "trait": "burn",
		"lore": "Hunts in packs across the ash. Its mane never stops burning."},
	"tortured_soul": {"name": "Tortured Soul", "hp": 26, "atk": 6, "interval": 1.8, "phys": 0.25, "mag": 1.5,
		"color": Color("b9b0c9"), "xp": 6, "ai": "fodder", "speed": 170.0, "size": 0.5, "trait": "phase",
		"lore": "Someone who lost a bargain. Steel passes through what's left of them."},
	"lilim": {"name": "Lilim", "hp": 30, "atk": 8, "interval": 2.0, "phys": 0.75, "mag": 1.25, "color": Color("8a5ca8"),
		"xp": 8, "ai": "ranged", "missile": "bolt", "reach": 320.0, "speed": 175.0, "size": 0.5,
		"lore": "A daughter of Lilith. Her charms land softer than her bolts, and hurt more."},
	"ualac": {"name": "Ualac", "hp": 28, "atk": 7, "interval": 2.0, "phys": 1.5, "mag": 0.5, "color": Color("b08a4a"),
		"xp": 7, "ai": "ranged", "missile": "fire", "reach": 280.0, "speed": 165.0, "size": 0.56, "trait": "gold",
		"lore": "A winged child on a two-headed dragon. He knows where every treasure is buried."},
	"fallen_angel": {"name": "Fallen Angel", "hp": 60, "atk": 12, "interval": 3.0, "phys": 1.0, "mag": 0.75,
		"color": Color("4b4f63"), "xp": 12, "ai": "brute", "speed": 130.0, "size": 0.68,
		"lore": "It fell a very long way, and landed in armor."},
	# Called by bosses.
	"spawnling": {"name": "Spawnling", "hp": 12, "atk": 4, "interval": 1.2, "phys": 1.0, "mag": 1.0, "color": Color("5d8a74"),
		"xp": 2, "ai": "fodder", "speed": 200.0, "size": 0.4, "lore": "It came out of something larger."},
}

## Elites: twice a world, each with the one move MatchRPG gave it, as a
## telegraphed area move here (see EliteBrain).
const ELITES := {
	"ogre_king": {"name": "Ogre King", "hp": 160, "atk": 14, "interval": 2.4, "phys": 1.0, "mag": 1.0,
		"color": Color("b0763a"), "xp": 40, "move": "rock_throw", "speed": 125.0,
		"lore": "Rules a kingdom of one clearing, and defends it with whatever is lying around."},
	"broodmother": {"name": "Broodmother", "hp": 140, "atk": 10, "interval": 2.0, "phys": 1.0, "mag": 1.25,
		"color": Color("2e2436"), "xp": 40, "move": "brood", "speed": 130.0,
		"lore": "Mother of every spider in the Forest, and still expecting."},
	"lich": {"name": "Lich", "hp": 130, "atk": 12, "interval": 2.0, "phys": 0.5, "mag": 1.25, "color": Color("7a5cc9"),
		"xp": 40, "move": "curse", "speed": 120.0, "lore": "A wizard who simply refused to stop."},
	"orc_warlord": {"name": "Orc Warlord", "hp": 180, "atk": 15, "interval": 2.6, "phys": 1.0, "mag": 0.75,
		"color": Color("4a6e2e"), "xp": 50, "move": "war_cry", "speed": 125.0,
		"lore": "He leads with his voice, and his voice is very loud."},
	"crystal_golem": {"name": "Crystal Golem", "hp": 200, "atk": 14, "interval": 2.8, "phys": 0.5, "mag": 1.0,
		"color": Color("8fd6ea"), "xp": 60, "move": "spin", "speed": 115.0, "lore": "A geode that grew legs and a temper."},
	"myconid_matriarch": {"name": "Myconid Matriarch", "hp": 170, "atk": 12, "interval": 2.2, "phys": 1.25, "mag": 0.75,
		"color": Color("b86ab0"), "xp": 60, "move": "poison", "speed": 110.0,
		"lore": "Her spores remember every forest that ever fell."},
	"hierophant": {"name": "The Hierophant", "hp": 200, "atk": 13, "interval": 2.4, "phys": 1.25, "mag": 0.75,
		"color": Color("2f6b62"), "xp": 65, "move": "ritual", "speed": 110.0,
		"lore": "The cult's high priest, who shows the faithful what they should never see."},
	"shoggoth": {"name": "Shoggoth", "hp": 230, "atk": 14, "interval": 2.6, "phys": 0.75, "mag": 1.25,
		"color": Color("33463c"), "xp": 65, "move": "tentacles", "speed": 105.0,
		"lore": "A heaving mass of eyes and limbs, older than the cult that serves it."},
	"amdusias": {"name": "Amdusias", "hp": 190, "atk": 13, "interval": 2.2, "phys": 1.0, "mag": 1.0,
		"color": Color("6e4a7e"), "xp": 70, "move": "two_songs", "speed": 120.0,
		"lore": "Hell's court musician. His trumpet plays a song for every weakness."},
	"belial": {"name": "Belial", "hp": 210, "atk": 15, "interval": 2.6, "phys": 1.0, "mag": 1.0, "color": Color("c06a2a"),
		"xp": 70, "move": "wildfire", "speed": 130.0,
		"lore": "A king of Hell who arrives in a chariot of fire and calls it modesty."},
}

## World bosses: phases, weighted moves, telegraphs and an enrage timer
## (see Brains). `hp` and `atk` are already this game's, for one hero:
## the chapter scaling the other mobs get is not applied to them.
const BOSSES := {
	"old_mossback": {"name": "Old Mossback", "hp": 8000, "atk": 70, "interval": 2.4, "phys": 1.0, "mag": 1.25,
		"color": Color("4f6b3a"), "xp": 400, "speed": 115.0, "enrage": 150.0, "roar": "roar_mossback",
		"lore": "The Forest's troll, older than the trees he leans on.",
		"barks": ["Off my roots!", "Mossback remembers.", "The Forest keeps what falls in it."]},
	"the_warden": {"name": "The Warden", "hp": 16000, "atk": 95, "interval": 2.2, "phys": 1.0, "mag": 1.0,
		"color": Color("5a5f6e"), "xp": 700, "speed": 110.0, "enrage": 160.0, "roar": "roar_warden",
		"lore": "Jailer of the Upper Dungeon. His keys are the only way down.",
		"barks": ["Back in your cells.", "No one leaves.", "I have a key for each of you."]},
	"deep_wyrm": {"name": "The Deep Wyrm", "hp": 28000, "atk": 130, "interval": 2.6, "phys": 0.75, "mag": 1.25,
		"color": Color("3a6e6a"), "xp": 1100, "speed": 120.0, "enrage": 170.0, "roar": "roar_wyrm",
		"lore": "It sleeps beneath the Caves. Mostly.",
		"barks": ["...", "The ground listens.", "Down. Everything goes down."]},
	"sleeper_below": {"name": "The Sleeper Below", "hp": 42000, "atk": 160, "interval": 2.5, "phys": 1.0, "mag": 1.0,
		"color": Color("2f5a5a"), "xp": 1500, "speed": 70.0, "enrage": 180.0, "roar": "roar_sleeper",
		"lore": "What the cult has been calling. It was asleep, and now it is not.",
		"barks": ["You are in the dream now.", "Look at me.", "The angles are wrong. Good."]},
	"astaroth": {"name": "Astaroth", "hp": 60000, "atk": 190, "interval": 2.4, "phys": 1.0, "mag": 1.0,
		"color": Color("3f3a5c"), "xp": 2000, "speed": 115.0, "enrage": 200.0, "roar": "laugh_astaroth",
		"lore": "A great duke of Hell, who knows every secret and sells them dearly.",
		"barks": ["Every secret has a price.", "Your town is already mine.", "Kneel, and I may sell you back."]},
}

## Every id in a fixed order: a mob's index here is what goes over the wire.
static var ORDER: Array = []


static func order() -> Array:
	if ORDER.is_empty():
		ORDER.append_array(MOBS.keys())
		ORDER.append_array(ELITES.keys())
		ORDER.append_array(BOSSES.keys())
	return ORDER


static func index_of(id: String) -> int:
	return order().find(id)


static func id_at(i: int) -> String:
	return order()[i]


static func get_def(id: String) -> Dictionary:
	if MOBS.has(id):
		return MOBS[id]
	if ELITES.has(id):
		return ELITES[id]
	return BOSSES[id]


## "mob", "elite" or "boss".
static func rank_of(id: String) -> String:
	if ELITES.has(id):
		return "elite"
	if BOSSES.has(id):
		return "boss"
	return "mob"


## On-screen body size (the look's rect) and the body's collision radius.
static func body_size(id: String) -> Vector2:
	match rank_of(id):
		"boss":
			return Vector2(190, 204) * (1.25 if id == "sleeper_below" else 1.0)
		"elite":
			return Vector2(104, 112)
	var s: float = MOBS[id].get("size", 0.5)
	return Vector2(84, 90) * s * 1.15


static func radius(id: String) -> float:
	var s := body_size(id)
	return s.x * (0.32 if rank_of(id) == "boss" else 0.36)


static func resist(id: String, kind: String) -> float:
	return clampf(float(get_def(id).get(kind, 1.0)), RESIST_MIN, RESIST_MAX)
