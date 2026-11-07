class_name HeroState
extends RefCounted
## A hero as the host keeps it. Its position comes from its owner (the
## owner moves its own hero, so its own walk never waits on the network);
## everything else is decided here.

const BELT := 4

var slot := 0
var peer := 1
var name := "Hero"
var cls := "fighter"
var pos := Vector2.ZERO
var flip := false
## Whether its owner says it is walking (Eternal Flow reads it).
var moving := false
var alive := true
var hp := 700.0
var respawn_t := 0.0
var level := 1
var xp := 0.0
var gold := 0
var points := 1
var ranks := [0, 0, 0, 0]
var talents := ["", "", "", "", ""]
var stats := {}
var cds := [0.0, 0.0, 0.0, 0.0]
var belt: Array = [["heal", 2], ["", 0], ["", 0], ["", 0]]

# Buffs and counters, in seconds or counts.
var bloodlust_t := 0.0
var bloodlust := 0.0
var headsman_t := 0.0
var avatar_t := 0.0
var untouchable_t := 0.0
var flow := 0
var flow_t := 0.0
var swings := 0
var rampage := 0
var rampage_t := 0.0
var ward := 0.0
var ward_idle := 0.0
var second_wind_cd := 0.0
var regen_burst_t := 0.0
var regen_burst := 0.0
var spellblade := 0
var spells_cast := 0
var split_shots := 0
var focus_id := -1
var focus := 0
var shots := 0
var tumble_charges := 1
var aegis_t := 0.0
var surge_t := 0.0
var echo_t := 0.0
var ambush_target := -1

# What mobs did to it, in seconds left.
var stun_t := 0.0
var root_t := 0.0
var slow_t := 0.0
var slow := 0.0
var poison_t := 0.0
var poison_dps := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var hurt_t := 0.0
var kills := 0
var damage_done := 0.0
var deaths := 0


func recompute() -> void:
	var was_max := float(stats.get("max_hp", 0.0))
	stats = HeroStats.compute(cls, level, talents)
	if was_max > 0.0:
		hp += float(stats["max_hp"]) - was_max
	hp = minf(hp, stats["max_hp"])


func fx(key: String) -> float:
	return float(stats["fx"].get(key, 0.0))


func max_hp() -> float:
	return float(stats["max_hp"])


func targetable() -> bool:
	return alive and untouchable_t <= 0.0


## What the owner needs to show: everything but the position, which it has.
func to_dict() -> Dictionary:
	return {"slot": slot, "name": name, "cls": cls, "alive": alive, "hp": hp, "max_hp": max_hp(),
		"respawn": respawn_t, "level": level, "xp": xp, "xp_next": HeroClasses.xp_to_next(level), "gold": gold,
		"points": points, "ranks": ranks.duplicate(), "talents": talents.duplicate(), "cds": cds.duplicate(),
		"belt": belt.duplicate(true), "flow": flow, "ward": ward, "stun": stun_t, "root": root_t,
		"slow": slow if slow_t > 0.0 else 0.0, "bloodlust": bloodlust_t, "headsman": headsman_t,
		"untouchable": untouchable_t, "aegis": aegis_t, "surge": surge_t, "split": split_shots,
		"kills": kills, "rampage": rampage, "bloodlust_amt": bloodlust, "tumble": tumble_charges, "pos": pos, "flip": flip, "deaths": deaths, "dmg": damage_done}
