class_name ChapterDefs
extends RefCounted
## One wave group for each of MatchRPG's five worlds, in its order: the
## things the heroes went down to fight are climbing up to the Town. Each
## chapter is WAVES long and shaped like a MatchRPG world: plain waves, the
## world's two elites (waves 3 and 5), a horde (wave 4) and its world boss
## last. Counts are per open corridor, so three players face three times
## the mob, each holding their own passage.
##
## Palettes are the world's backdrop colors in MatchRPG (Backdrop), so the
## map reads as the same place.

const WAVES := 6
const ELITE_WAVES := {2: 0, 4: 1}
const HORDE_WAVE := 3
const BOSS_WAVE := 5

## Mob HP and attack, chapter by chapter. Each step is a push-back the
## heroes' new levels, talents and Town have to answer. Talents, ability
## ranks and the Town multiply hero power far past what levels alone give,
## so these climb steeply: with the old [1, 2.3, 4.6, 8, 13] a Mage that
## built the Town cleared all 30 waves without dying. Tuned with the bot
## (tests/sim_bot.gd) on seeds 7, 11 and 23: a building Mage bot wins with
## 4-6 deaths, a building Fighter bot wins about one run in three, and a
## bot that never builds falls in chapters 3-5. Static vars, not consts, so
## the bot (--hp=... --atk=...) can try others.
static var HP_SCALE: Array = [1.0, 2.9, 7.0, 14.5, 28.0]
static var ATK_SCALE: Array = [1.0, 1.8, 3.0, 4.7, 6.8]

## The shape of a chapter, wave by wave. It is jagged on purpose (the
## curves study, A1 and A2): a push-back, a mow, a spike, the Horde, the
## hardest regular wave, then the boss. `hp` and `atk` multiply the
## chapter's scale. `tough` is the share of packs drawn from the roster's
## brutes, chargers and casters instead of its fodder. `more` multiplies
## the count.
const WAVE_SHAPE := [
	# Push-back: the chapter's new numbers, a mixed crowd.
	{"hp": 1.05, "atk": 1.0, "tough": 0.4, "more": 1.1},
	# The mow: a big crowd of fodder, to feel the levels just earned.
	{"hp": 0.8, "atk": 0.9, "tough": 0.1, "more": 1.25},
	# The first elite, with a guard of brutes.
	{"hp": 1.15, "atk": 1.1, "tough": 0.45, "more": 1.0},
	# The Horde: very many and soft, in three surges.
	{"hp": 0.7, "atk": 1.0, "tough": 0.15, "more": 1.0},
	# The wall: the second elite and the hardest crowd of the chapter.
	{"hp": 1.3, "atk": 1.25, "tough": 0.55, "more": 0.9},
	# The boss's adds.
	{"hp": 0.9, "atk": 1.15, "tough": 0.35, "more": 1.0},
]

## A mob's tier, from its brain: fodder is "soft", casters and archers
## "mid", brutes and chargers "tough". Soft mobs get softer next to the
## chapter each world, so there is always something to mow, and tough ones
## harder, so something always pushes back.
const TIER_HP := {
	"soft": [1.0, 0.9, 0.82, 0.76, 0.7],
	"mid": [1.0, 1.0, 1.0, 1.0, 1.0],
	"tough": [1.15, 1.35, 1.55, 1.75, 1.95],
}

const CHAPTERS := [
	{"world": "The Underground Forest", "music": "forest",
		"subtitle": "Something old is walking up out of the roots.",
		"roster": {"wolf": 5, "goblin": 3, "treant_sapling": 2, "giant_spider": 2, "wicked_vine": 2, "boar": 1, "dark_gnome": 2},
		"opening": ["wolf", "goblin", "dark_gnome"],
		"elites": ["ogre_king", "broodmother"], "boss": "old_mossback",
		"floor": Color("26331f"), "path": Color("2f3d25"), "wall": Color("13211a"), "deco": Color("3d5a2c"),
		"glow": Color(0.8, 1.0, 0.4)},
	{"world": "The Upper Dungeon", "music": "dungeon",
		"subtitle": "The Warden has opened the cells.",
		"roster": {"skeleton": 4, "ghost": 3, "imp": 3, "orc": 2, "cultist": 2},
		"opening": ["skeleton", "imp", "ghost"],
		"elites": ["lich", "orc_warlord"], "boss": "the_warden",
		"floor": Color("2e2838"), "path": Color("362f42"), "wall": Color("1b1726"), "deco": Color("3a3346"),
		"glow": Color("f0a23c")},
	{"world": "The Caves", "music": "caves",
		"subtitle": "The ground is listening.",
		"roster": {"bat_swarm": 5, "kobold_miner": 3, "cave_crawler": 2, "glowcap": 2, "stone_elemental": 1},
		"opening": ["bat_swarm", "kobold_miner"],
		"elites": ["crystal_golem", "myconid_matriarch"], "boss": "deep_wyrm",
		"floor": Color("1d242e"), "path": Color("232c38"), "wall": Color("10161f"), "deco": Color("2a3340"),
		"glow": Color(0.35, 0.82, 0.75)},
	{"world": "The Drowned Temple", "music": "lower",
		"subtitle": "The cult has finished its call.",
		"roster": {"deep_one": 4, "serpent_man": 3, "drowned_acolyte": 3, "night_gaunt": 3, "gibbering_mass": 1},
		"opening": ["deep_one", "night_gaunt"],
		"elites": ["hierophant", "shoggoth"], "boss": "sleeper_below",
		"floor": Color("0f2024"), "path": Color("142a2f"), "wall": Color("0d1719"), "deco": Color("1a2b2e"),
		"glow": Color(0.25, 0.88, 0.77)},
	{"world": "The Plains of Hell", "music": "hell",
		"subtitle": "Astaroth has come to collect.",
		"roster": {"hellhound": 5, "tortured_soul": 3, "lilim": 3, "ualac": 2, "fallen_angel": 1},
		"opening": ["hellhound", "tortured_soul"],
		"elites": ["amdusias", "belial"], "boss": "astaroth",
		"floor": Color("2a1e26"), "path": Color("33242c"), "wall": Color("1a1220"), "deco": Color("281826"),
		"glow": Color("8a7dff")},
]


static func count() -> int:
	return CHAPTERS.size()


static func get_def(c: int) -> Dictionary:
	return CHAPTERS[clampi(c, 0, CHAPTERS.size() - 1)]


## How many mobs wave `w` (0-based) of chapter `c` sends down each corridor.
## WAVE_MORE is a flat 8% on top of the base counts below.
const WAVE_MORE := 1.08


static func wave_count(c: int, w: int) -> int:
	return roundi(_base_count(c, w) * WAVE_MORE * float(shape(w)["more"]))


static func _base_count(c: int, w: int) -> int:
	match w:
		0: return 14 + 8 * c
		1: return 22 + 12 * c
		2: return 18 + 10 * c
		3: return 40 + 30 * c
		4: return 28 + 16 * c
	return 0


## Seconds a wave's spawns are spread over. The horde comes faster than it
## can be cleared, on purpose.
static func wave_span(w: int) -> float:
	match w:
		0: return 22.0
		3: return 26.0
		5: return 0.0
	return 28.0


static func shape(w: int) -> Dictionary:
	return WAVE_SHAPE[clampi(w, 0, WAVE_SHAPE.size() - 1)]


static func hp_mult(c: int, w: int) -> float:
	return HP_SCALE[clampi(c, 0, 4)] * float(shape(w)["hp"])


static func atk_mult(c: int, w: int) -> float:
	return ATK_SCALE[clampi(c, 0, 4)] * float(shape(w)["atk"])


static func tier(kind: String) -> String:
	match str(MobDefs.get_def(kind).get("ai", "fodder")):
		"fodder":
			return "soft"
		"brute", "charger":
			return "tough"
	return "mid"


## What a plain mob's tier does to its HP in chapter `c` (elites and bosses
## have their own numbers).
static func tier_hp(kind: String, c: int) -> float:
	if MobDefs.rank_of(kind) != "mob":
		return 1.0
	return float(TIER_HP[tier(kind)][clampi(c, 0, 4)])


static func wave_title(c: int, w: int) -> String:
	var ch := get_def(c)
	if w == BOSS_WAVE:
		return MobDefs.get_def(ch["boss"])["name"]
	if ELITE_WAVES.has(w):
		return MobDefs.get_def(ch["elites"][ELITE_WAVES[w]])["name"]
	if w == HORDE_WAVE:
		return "The Horde"
	return "Wave %d" % (w + 1)
