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

## Mob HP and attack, chapter by chapter. Heroes grow faster than this
## inside a chapter, so its end feels like mowing, and the next one's first
## wave pushes back.
const HP_SCALE := [1.0, 2.3, 4.6, 8.0, 13.0]
const ATK_SCALE := [1.0, 1.6, 2.4, 3.3, 4.4]
## Each wave inside a chapter adds this much to both.
const WAVE_STEP := 0.07

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
	return roundi(_base_count(c, w) * WAVE_MORE)


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


static func hp_mult(c: int, w: int) -> float:
	return HP_SCALE[clampi(c, 0, 4)] * (1.0 + WAVE_STEP * w)


static func atk_mult(c: int, w: int) -> float:
	return ATK_SCALE[clampi(c, 0, 4)] * (1.0 + WAVE_STEP * w)


static func wave_title(c: int, w: int) -> String:
	var ch := get_def(c)
	if w == BOSS_WAVE:
		return MobDefs.get_def(ch["boss"])["name"]
	if ELITE_WAVES.has(w):
		return MobDefs.get_def(ch["elites"][ELITE_WAVES[w]])["name"]
	if w == HORDE_WAVE:
		return "The Horde"
	return "Wave %d" % (w + 1)
