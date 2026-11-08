class_name Telemetry
extends RefCounted
## Turns what happens in the host's Sim into play log records, for balance
## and debugging. Game calls observe() after every tick with that tick's
## events, and sends what it returns along with them, so each player gets
## the records about their own hero and PlayLog stores those. Records about
## the whole match (waves, the Hearth) have slot -1, and only the host
## stores them.
##
## A record is ["log", slot, kind, t, chapter, wave, data]. The kinds:
##   death        how and by what, the hits of the last few seconds, the
##                hero's whole state, the potions it still had, what was near
##   respawn      seconds dead
##   level, learn, talent, loot, buy, drink
##   hero_wave    one per hero per wave: damage done and taken (by source),
##                kills, deaths, casts per skill, potions, gold, time dead
##   wave_start   mobs, multipliers, the heroes' levels
##   wave_end     length, what the Hearth lost, mobs left, early calls
##   game_over    the outcome, with every hero's final state

var sim: Sim
var wave_open := false
var wave_info := {}
## Per hero: counters at the start of the wave, to report the difference.
var base := {}
var casts := {}
var drinks := {}
var dead_s := {}
## Per hero: when this life began and the potions drunk in it.
var life := {}
var died_at := {}
var hearth_lost := 0.0
var hearth_hits := 0
var calls := 0
var over_sent := false


func _init(s: Sim) -> void:
	sim = s
	for slot: int in sim.heroes:
		life[slot] = {"t0": 0.0, "drinks": 0}
		_reset_wave_counters(slot)


func observe(ev: Array) -> Array:
	var out: Array = []
	for e: Array in ev:
		var slot: int = e[1] if e.size() > 1 and e[1] is int else -1
		var h: HeroState = sim.heroes.get(slot)
		match e[0]:
			"hdie":
				if h != null:
					out.append(_rec(slot, "death", _death(h)))
					died_at[slot] = sim.time
			"respawn":
				var gone := sim.time - float(died_at.get(slot, sim.time))
				dead_s[slot] = float(dead_s.get(slot, 0.0)) + gone
				died_at.erase(slot)
				life[slot] = {"t0": sim.time, "drinks": 0}
				out.append(_rec(slot, "respawn", {"dead_s": gone}))
			"lvl":
				out.append(_rec(slot, "level", {"level": e[2]}))
			"learn":
				if h != null:
					out.append(_rec(slot, "learn", {"skill": e[2], "rank": h.ranks[e[2]], "level": h.level}))
			"talent":
				if h != null:
					out.append(_rec(slot, "talent", {"row": e[2], "id": e[3], "level": h.level}))
			"loot":
				out.append(_rec(slot, "loot", {"potion": e[2]}))
			"buy":
				if h != null:
					out.append(_rec(slot, "buy", {"potion": e[2], "price": e[3], "gold_left": h.gold}))
			"drink":
				drinks[slot] = int(drinks.get(slot, 0)) + 1
				if life.has(slot):
					life[slot]["drinks"] = int(life[slot]["drinks"]) + 1
				out.append(_rec(slot, "drink", {"potion": e[2], "hp_frac": e[3], "mobs_near": e[4]}))
			"cast":
				if casts.has(slot) and int(e[2]) >= 0 and int(e[2]) < 4:
					casts[slot][e[2]] += 1
			"build":
				if h != null:
					out.append(_rec(slot, "build", {"building": e[2], "level": e[3], "price": e[4], "gold_left": h.gold}))
			"fire":
				# e[1] is the fire's index here, not a slot: a match record.
				out.append(_rec(-1, "road_fire", {"fire": e[1], "lit": e[2], "lane": e[3], "gone": e[4]}))
			"dark":
				out.append(_rec(-1, "dark", {"on": e[1]}))
			"hearth":
				hearth_lost += float(e[1])
				hearth_hits += 1
			"call":
				calls += 1
	var in_wave := sim.director.phase == Director.Phase.WAVE
	if in_wave and not wave_open:
		_open_wave(out)
	elif not in_wave and wave_open:
		_close_wave(out, "cleared")
	if sim.over != "" and not over_sent:
		over_sent = true
		if wave_open:
			_close_wave(out, sim.over)
		var heroes := {}
		for hh: HeroState in sim.heroes.values():
			heroes[str(hh.slot)] = hero_state(hh)
		out.append(_rec(-1, "game_over", {"outcome": sim.over, "hearth_frac": _hearth_frac(), "heroes": heroes}))
	return out


func _rec(slot: int, kind: String, data: Dictionary) -> Array:
	var d := sim.director
	return ["log", slot, kind, snappedf(sim.time, 0.01), d.chapter, d.wave, data]


# --- Waves -----------------------------------------------------------------------

func _open_wave(out: Array) -> void:
	wave_open = true
	var d := sim.director
	wave_info = {"t0": sim.time, "hearth0": sim.hearth_hp, "chapter": d.chapter, "wave": d.wave}
	hearth_lost = 0.0
	hearth_hits = 0
	var levels := {}
	for h: HeroState in sim.heroes.values():
		_reset_wave_counters(h.slot)
		levels[str(h.slot)] = h.level
	out.append(_rec(-1, "wave_start", {"title": ChapterDefs.wave_title(d.chapter, d.wave), "mobs": d.wave_total,
		"hp_mult": d.hp_mult(), "atk_mult": d.atk_mult(), "players": sim.players, "levels": levels,
		"early_calls": calls, "hearth_frac": _hearth_frac(), "mobs_carried": sim.living_count()}))
	calls = 0


func _close_wave(out: Array, how: String) -> void:
	wave_open = false
	var d := sim.director
	for h: HeroState in sim.heroes.values():
		out.append(_rec(h.slot, "hero_wave", _hero_wave(h)))
	out.append(["log", -1, "wave_end", snappedf(sim.time, 0.01), wave_info["chapter"], wave_info["wave"], {
		"how": how, "dur_s": sim.time - float(wave_info["t0"]), "hearth_lost": hearth_lost,
		"hearth_hits": hearth_hits, "hearth_frac": _hearth_frac(), "mobs_total": d.wave_total,
		"mobs_spawned": d.spawned, "mobs_left": sim.living_count()}])


func _reset_wave_counters(slot: int) -> void:
	var h: HeroState = sim.heroes.get(slot)
	if h == null:
		return
	base[slot] = {"kills": h.kills, "dmg": h.damage_done, "taken": h.damage_taken, "deaths": h.deaths,
		"gold": h.gold, "level": h.level, "xp": h.xp, "taken_by": h.taken_by.duplicate()}
	casts[slot] = [0, 0, 0, 0]
	drinks[slot] = 0
	dead_s[slot] = 0.0


func _hero_wave(h: HeroState) -> Dictionary:
	var b: Dictionary = base.get(h.slot, {})
	var taken_by := {}
	var was: Dictionary = b.get("taken_by", {})
	for k: String in h.taken_by:
		var delta := float(h.taken_by[k]) - float(was.get(k, 0.0))
		if delta > 0.5:
			taken_by[k] = roundf(delta)
	var dead := float(dead_s.get(h.slot, 0.0))
	if died_at.has(h.slot):
		dead += sim.time - float(died_at[h.slot])
	return {
		"kills": h.kills - int(b.get("kills", 0)),
		"dmg_done": roundf(h.damage_done - float(b.get("dmg", 0.0))),
		"dmg_taken": roundf(h.damage_taken - float(b.get("taken", 0.0))),
		"taken_by": taken_by,
		"deaths": h.deaths - int(b.get("deaths", 0)),
		"dead_s": snappedf(dead, 0.1),
		"gold_earned": h.gold - int(b.get("gold", 0)),
		"level_start": int(b.get("level", h.level)),
		"level_end": h.level,
		"casts": casts.get(h.slot, [0, 0, 0, 0]),
		"drinks": int(drinks.get(h.slot, 0)),
		"hp_frac": h.hp / h.max_hp() if h.alive else 0.0,
		"alive": h.alive,
		"ranks": h.ranks.duplicate(),
		"talents": h.talents.duplicate(),
		"belt": h.belt.duplicate(true),
	}


# --- Deaths ------------------------------------------------------------------------

func _death(h: HeroState) -> Dictionary:
	var recent: Array = []
	var by_src := {}
	for r: Array in h.recent:
		if sim.time - float(r[0]) > Sim.RECENT_S:
			continue
		recent.append([snappedf(sim.time - float(r[0]), 0.01), roundf(float(r[1])), r[2]])
		by_src[r[2]] = roundf(float(by_src.get(r[2], 0.0)) + float(r[1]))
	var potions := 0
	var heals := 0
	for b: Array in h.belt:
		if str(b[0]) != "" and int(b[1]) > 0:
			potions += int(b[1])
			if str(b[0]) == "heal":
				heals += int(b[1])
	var near_mobs: Array = sim.mobs_near(h.pos, 600.0).filter(func(m: Mob) -> bool: return m.alive())
	var close := 0
	var elites: Array = []
	var boss := {}
	for m: Mob in near_mobs:
		if m.pos.distance_to(h.pos) < 300.0:
			close += 1
		if m.rank == "elite":
			elites.append({"kind": m.kind, "hp_frac": m.hp_frac(), "dist": roundf(m.pos.distance_to(h.pos))})
	for m: Mob in sim.mobs:
		if m.alive() and m.rank == "boss":
			boss = {"kind": m.kind, "hp_frac": m.hp_frac(), "dist": roundf(m.pos.distance_to(h.pos)),
				"phase": m.brain.get("phase", 1), "enraged": m.enraged}
	var allies := 0
	var ally_dist := -1.0
	for o: HeroState in sim.heroes.values():
		if o != h and o.alive:
			allies += 1
			var dd := o.pos.distance_to(h.pos)
			if ally_dist < 0.0 or dd < ally_dist:
				ally_dist = roundf(dd)
	return {
		"how": h.last_blow.get("how", "unknown"),
		"src": h.last_blow.get("src", "unknown"),
		"blow": roundf(float(h.last_blow.get("dmg", 0.0))),
		"killer": h.last_blow.get("mob", {}),
		"recent": recent,
		"recent_by_src": by_src,
		"poisoned": h.poison_dps if h.poison_t > 0.0 else 0.0,
		"burning": h.burn_dps if h.burn_t > 0.0 else 0.0,
		"potions_left": potions,
		"heals_left": heals,
		"life_s": snappedf(sim.time - float(life.get(h.slot, {}).get("t0", 0.0)), 0.1),
		"drinks_this_life": int(life.get(h.slot, {}).get("drinks", 0)),
		"mobs_300": close,
		"mobs_600": near_mobs.size(),
		"elites_near": elites,
		"boss": boss,
		"allies_alive": allies,
		"nearest_ally": ally_dist,
		"dist_hearth": roundf(h.pos.distance_to(MapData.HEARTH)),
		"hearth_frac": _hearth_frac(),
		"phase": Director.Phase.keys()[sim.director.phase],
		"respawn_s": h.respawn_t,
		"hero": hero_state(h),
	}


## Everything about a hero worth keeping, as plain JSON.
static func hero_state(h: HeroState) -> Dictionary:
	var stats := {}
	for k: String in h.stats:
		stats[k] = h.stats[k]
	return {
		"cls": h.cls, "level": h.level, "xp": roundf(h.xp), "hp": roundf(h.hp), "max_hp": roundf(h.max_hp()),
		"gold": h.gold, "points": h.points, "ranks": h.ranks.duplicate(), "talents": h.talents.duplicate(),
		"belt": h.belt.duplicate(true), "cds": h.cds.map(func(c: float) -> float: return snappedf(c, 0.1)),
		"stats": stats, "pos": [roundf(h.pos.x), roundf(h.pos.y)], "alive": h.alive,
		"kills": h.kills, "deaths": h.deaths, "dmg_done": roundf(h.damage_done), "dmg_taken": roundf(h.damage_taken),
		"flow": h.flow, "ward": roundf(h.ward), "rampage": h.rampage,
		"buffs": {"bloodlust": h.bloodlust_t, "headsman": h.headsman_t, "aegis": h.aegis_t, "surge": h.surge_t,
			"untouchable": h.untouchable_t},
		"debuffs": {"stun": h.stun_t, "root": h.root_t, "slow": h.slow if h.slow_t > 0.0 else 0.0,
			"poison_dps": h.poison_dps if h.poison_t > 0.0 else 0.0, "burn_dps": h.burn_dps if h.burn_t > 0.0 else 0.0},
	}


func _hearth_frac() -> float:
	return snappedf(clampf(sim.hearth_hp / sim.hearth_max, 0.0, 1.0), 0.001)
