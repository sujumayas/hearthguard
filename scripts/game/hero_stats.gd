class_name HeroStats
extends RefCounted
## A hero's numbers from its class, level and talents. Pure, so the host and
## every client compute the same from the same build.
##
## Damage grows by DMG_GROWTH a level (multiplying), faster than any one
## chapter's mobs: the end of a chapter is a mow, and the next chapter's
## first wave pushes back. That is the power curve the game is built on.

const DMG_GROWTH := 1.09
const ASPD_PER_LEVEL := 0.015
const ARMOR_PER_LEVEL := 0.3


## `talents` is the chosen talent ids, `town` the Town's building levels
## (TownDefs). Returns every number the game reads, plus "fx": the talents'
## effects summed.
static func compute(cls: String, level: int, talents: Array, town := {}) -> Dictionary:
	var c: Dictionary = HeroClasses.get_def(cls)
	var fx := {}
	for row: Array in c["talents"]:
		for t: Dictionary in row:
			if t["id"] in talents:
				for k: String in t["fx"]:
					fx[k] = float(fx.get(k, 0.0)) + float(t["fx"][k])
	var lv := level - 1
	var s := {}
	s["max_hp"] = (float(c["hp"]) + float(c["hp_lv"]) * lv) * (1.0 + float(fx.get("hp_pct", 0.0))) \
		* (1.0 + TownDefs.bonus(town, "hp"))
	s["dmg"] = float(c["dmg"]) * pow(DMG_GROWTH, lv) + float(c["dmg_lv"]) * lv * 0.5
	s["dmg"] *= (1.0 + float(fx.get("dmg_pct", 0.0))) * (1.0 + TownDefs.bonus(town, "dmg"))
	s["armor"] = float(c["armor"]) + ARMOR_PER_LEVEL * lv + float(fx.get("armor", 0.0)) + TownDefs.bonus(town, "armor")
	s["range"] = float(c["range"]) + float(fx.get("range", 0.0))
	s["speed"] = float(c["speed"]) * (1.0 + float(fx.get("speed_pct", 0.0)))
	s["aspd"] = float(c["aspd"]) * (1.0 + ASPD_PER_LEVEL * lv + float(fx.get("aspd", 0.0)))
	s["regen"] = float(c["regen"]) * (1.0 + lv * 0.12)
	s["crit"] = 0.08 + float(fx.get("crit", 0.0))
	s["crit_dmg"] = 2.0 + float(fx.get("crit_dmg", 0.0))
	s["lifesteal"] = float(c.get("lifesteal", 0.0)) + float(fx.get("lifesteal", 0.0))
	s["dodge"] = float(c.get("dodge", 0.0)) + float(fx.get("dodge", 0.0))
	s["cdr"] = float(fx.get("cdr", 0.0))
	s["spell"] = 1.0 + float(fx.get("spell_pct", 0.0)) + TownDefs.bonus(town, "spell")
	s["melee"] = c["melee"]
	s["kind"] = c["dmg_kind"]
	s["fx"] = fx
	return s


## The seconds between attacks.
static func attack_interval(stats: Dictionary, bonus_aspd := 0.0) -> float:
	return Tuning.attack_cooldown() / maxf(0.2, float(stats["aspd"]) * (1.0 + bonus_aspd))


## Ability `slot`'s cooldown at `rank` (1-based), after reductions.
static func cooldown(cls: String, slot: int, rank: int, stats: Dictionary) -> float:
	var a := HeroClasses.ability(cls, slot)
	var cds: Array = a["cd"]
	return float(cds[clampi(rank - 1, 0, cds.size() - 1)]) * (1.0 - float(stats["cdr"]))


static func power(cls: String, slot: int, rank: int) -> float:
	var p: Array = HeroClasses.ability(cls, slot)["power"]
	return float(p[clampi(rank - 1, 0, p.size() - 1)])


## The gear HeroLook draws for this hero: its branch and how many talents.
static func gear(cls: String, talents: Array) -> Array:
	var branch: String = HeroClasses.get_def(cls)["branch"]
	var rank := 0
	for t: Variant in talents:
		if str(t) != "":
			rank += 1
	# A hero with no talents yet still wears its class (rank 1's piece).
	return [branch, "r:%d" % clampi(rank + 1, 1, 5)]
