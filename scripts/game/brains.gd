class_name Brains
extends RefCounted
## Elites and world bosses: the "a little more intelligent" layer, kept to
## what the AI study ranks highest for readable fights.
##   Elites: MatchRPG's one move each, as a telegraphed area move on a
##   cooldown. Otherwise they fight like a mob that always holds a token.
##   Bosses: phases at 70% and 35% HP that fire once and never revert, an
##   enrage timer, 3-4 weighted moves per phase with anti-repeat (a move's
##   weight halves for each recent use), a shared cooldown between big
##   moves, a telegraph before each and a recovery after it (the punish
##   window), and a threat table that only switches target at 110% (melee)
##   or 130% (ranged) of the current target's threat. Barks say what's
##   coming.
## `step` returns true while the brain moves the body itself (a wind-up, a
## channel, a burrow); otherwise the plain mob brain moves it.

const SHARED_CD := 2.2
const RECOVER := 0.7


static func setup(sim: Sim, m: Mob) -> void:
	m.brain = {"move_cd": 4.0 + sim.rng.randf() * 2.0, "busy": 0.0, "phase": 1, "used": {}, "shared": 3.0,
		"enrage_t": float(m.def.get("enrage", 0.0)), "song_t": 6.0, "regen_block": 0.0, "hp_mark": m.max_hp,
		"bark_t": 8.0}
	if m.rank == "boss":
		m.token = true
		sim.emit(["boss", m.id, m.kind])
		sim.emit(["snd", m.def.get("roar", "boss"), 1.0])
		_bark(sim, m, (m.def["barks"] as Array)[0])
	else:
		sim.emit(["elite", m.id, m.kind])
		sim.emit(["snd", "enraged", 0.7])


static func on_death(sim: Sim, m: Mob) -> void:
	sim.emit(["snd", "boss_stomp" if m.rank == "boss" else "kill", 1.0])
	if m.rank == "boss":
		sim.emit(["boss_down", m.id, m.kind])
		sim.emit(["banner", "%s falls" % m.def["name"], m.def["lore"], m.def["color"].lightened(0.3)])


static func _bark(sim: Sim, m: Mob, text: String) -> void:
	sim.emit(["bark", m.id, text])


static func step(sim: Sim, m: Mob) -> bool:
	var b := m.brain
	b["move_cd"] = float(b["move_cd"]) - Sim.DT
	b["shared"] = float(b["shared"]) - Sim.DT
	if float(b.get("war_cry_t", 0.0)) > 0.0:
		b["war_cry_t"] = float(b["war_cry_t"]) - Sim.DT
	if float(b["busy"]) > 0.0:
		b["busy"] = float(b["busy"]) - Sim.DT
		if b.has("channel"):
			(b["channel"] as Callable).call()
		if float(b["busy"]) <= 0.0:
			b.erase("channel")
			if b.has("after_busy"):
				var fn: Callable = b["after_busy"]
				b.erase("after_busy")
				fn.call()
		return true
	if m.rank == "boss":
		return _boss(sim, m)
	return _elite(sim, m)


# --- Elites ----------------------------------------------------------------------

static func _elite(sim: Sim, m: Mob) -> bool:
	var b := m.brain
	var move: String = m.def.get("move", "")
	if move == "two_songs":
		b["song_t"] = float(b["song_t"]) - Sim.DT
		if float(b["song_t"]) <= 0.0:
			b["song_t"] = 6.0
			m.immune = "mag" if m.immune == "phys" else "phys"
			_bark(sim, m, "The Song of Swords!" if m.immune == "phys" else "The Song of Magic!")
			sim.emit(["snd", "song_sword" if m.immune == "phys" else "song_magic", 0.9])
	if m.state != Mob.State.CHASE or float(b["move_cd"]) > 0.0:
		return false
	var h: HeroState = sim.heroes.get(m.target)
	if h == null or not h.targetable():
		return false
	var atk := m.atk
	match move:
		"rock_throw":
			b["move_cd"] = 7.0
			var at := h.pos
			sim.emit(["mmis", "boulder", m.pos.x, m.pos.y - 60.0, at.x, at.y, 1.0])
			circle(sim, at, 130.0, 1.0, atk * 2.0, 0.8)
			_hold(m, 0.5)
		"brood":
			b["move_cd"] = 9.0
			sim.add_zone("web", h.pos, 170.0, 6.0)
			for i in 4:
				sim.spawn("giant_spider", m.pos, m.lane, sim.director.hp_mult() * 0.6, sim.director.atk_mult())
			_bark(sim, m, "Children!")
			_hold(m, 0.6)
		"curse":
			b["move_cd"] = 9.0
			var slot := h.slot
			sim.emit(["curse", slot, 2.6])
			sim.emit(["snd", "dark_near", 0.9])
			sim.after(2.6, func() -> void:
				var hh: HeroState = sim.heroes.get(slot)
				if hh == null or not hh.alive:
					return
				sim.emit(["boom", "curse", hh.pos.x, hh.pos.y, 210.0])
				for o: HeroState in sim.heroes.values():
					if o.alive and o.pos.distance_to(hh.pos) < 210.0:
						sim.damage_hero(o, atk * 2.4, null, "zone"))
			_hold(m, 0.4)
		"war_cry":
			b["move_cd"] = 12.0
			for o: Mob in sim.mobs_near(m.pos, 460.0):
				o.brain["war_cry_t"] = 6.0
				o.speed *= 1.0
			b["war_cry_t"] = 6.0
			_bark(sim, m, "FOR THE WARLORD!")
			sim.emit(["boom", "war_cry", m.pos.x, m.pos.y, 460.0])
			sim.emit(["snd", "enraged", 1.0])
			_hold(m, 0.6)
		"spin":
			b["move_cd"] = 10.0
			sim.emit(["tele", "circle", m.pos.x, m.pos.y, 150.0, 0.0, 0.6, 0.0])
			_hold(m, 0.6, func() -> void:
				b["busy"] = 3.0
				sim.emit(["spin", m.id, 3.0])
				b["channel"] = func() -> void:
					var t: HeroState = sim.heroes.get(m.target)
					if t != null and t.alive:
						m.pos = sim.map.slide(m.pos, (t.pos - m.pos).normalized() * m.speed * 0.8 * Sim.DT)
					if sim.tick % 8 == 0:
						for o: HeroState in sim.heroes.values():
							if o.targetable() and o.pos.distance_to(m.pos) < 150.0:
								sim.damage_hero(o, atk * 0.45, m))
		"poison":
			b["move_cd"] = 8.0
			for i in 3:
				var at := h.pos + Vector2.from_angle(sim.rng.randf() * TAU) * sim.rng.randf_range(0.0, 160.0)
				sim.emit(["tele", "circle", at.x, at.y, 110.0, 0.0, 0.8, 0.0])
				sim.after(0.8, func() -> void: sim.add_zone("poison", at, 110.0, 6.0, {"dps": atk * 0.7}))
			_hold(m, 0.5)
		"ritual":
			b["move_cd"] = 14.0
			b["ritual_hp"] = m.hp
			_bark(sim, m, "Kneel, and see!")
			sim.emit(["channel", m.id, 4.0])
			sim.emit(["snd", "chant", 1.0])
			b["busy"] = 4.0
			b["channel"] = func() -> void:
				if float(b["ritual_hp"]) - m.hp > m.max_hp * 0.12:
					b["busy"] = 0.0
					b.erase("after_busy")
					m.stun_t = 2.0
					_bark(sim, m, "The ritual... breaks...")
					sim.emit(["snd", "shatter", 1.0])
			b["after_busy"] = func() -> void:
				if m.stun_t > 0.0:
					return
				for i in 6:
					sim.spawn("deep_one", m.pos, m.lane, sim.director.hp_mult(), sim.director.atk_mult())
				for i in 2:
					sim.spawn("drowned_acolyte", m.pos, m.lane, sim.director.hp_mult(), sim.director.atk_mult())
				sim.emit(["boom", "ritual", m.pos.x, m.pos.y, 200.0])
		"tentacles":
			b["move_cd"] = 6.0
			var base := (h.pos - m.pos).angle()
			for k in [-0.45, 0.0, 0.45]:
				line(sim, m.pos, base + k, 440.0, 70.0, 0.9, atk * 1.8)
			sim.emit(["snd", "tentacle", 0.9])
			_hold(m, 1.0)
		"wildfire":
			b["move_cd"] = 9.0
			var dir := (h.pos - m.pos).normalized()
			sim.emit(["tele", "line", m.pos.x, m.pos.y, 520.0, dir.angle(), 0.6, 80.0])
			_hold(m, 0.6, func() -> void:
				b["busy"] = 0.6
				b["channel"] = func() -> void:
					m.pos = sim.map.slide(m.pos, dir * 860.0 * Sim.DT)
					if sim.tick % 4 == 0:
						sim.add_zone("fire_trail", m.pos, 70.0, 5.0, {"dps": atk * 0.8})
					for o: HeroState in sim.heroes.values():
						if o.targetable() and o.pos.distance_to(m.pos) < 70.0:
							sim.damage_hero(o, atk * 0.5, m))
			sim.emit(["snd", "ignite", 1.0])
		_:
			return false
	return float(b["busy"]) > 0.0


## The body stands still for `t`, then runs `then`.
static func _hold(m: Mob, t: float, then := Callable()) -> void:
	m.brain["busy"] = t
	m.wind = 0.0
	if then.is_valid():
		m.brain["after_busy"] = then


# --- Telegraphed areas -------------------------------------------------------------

static func circle(sim: Sim, at: Vector2, r: float, delay: float, dmg: float, stun := 0.0) -> void:
	sim.emit(["tele", "circle", at.x, at.y, r, 0.0, delay, 0.0])
	sim.after(delay, func() -> void:
		sim.emit(["boom", "rock", at.x, at.y, r])
		for h: HeroState in sim.heroes.values():
			if h.targetable() and h.pos.distance_to(at) < r + 14.0:
				sim.damage_hero(h, dmg, null, "zone")
				if stun > 0.0:
					h.stun_t = maxf(h.stun_t, stun))


static func line(sim: Sim, from: Vector2, angle: float, length: float, width: float, delay: float, dmg: float,
		root := 0.0) -> void:
	sim.emit(["tele", "line", from.x, from.y, length, angle, delay, width])
	sim.after(delay, func() -> void:
		var to := from + Vector2.from_angle(angle) * length
		sim.emit(["boom", "line", from.x, from.y, length, angle, width])
		for h: HeroState in sim.heroes.values():
			if h.targetable() and MapData._seg_dist(h.pos, from, to) < width * 0.5 + 14.0:
				sim.damage_hero(h, dmg, null, "zone")
				if root > 0.0:
					h.root_t = maxf(h.root_t, root))


static func cone(sim: Sim, from: Vector2, angle: float, arc: float, r: float, delay: float, dmg: float, push := 0.0) -> void:
	sim.emit(["tele", "cone", from.x, from.y, r, angle, delay, arc])
	sim.after(delay, func() -> void:
		sim.emit(["boom", "cone", from.x, from.y, r, angle, arc])
		for h: HeroState in sim.heroes.values():
			var d := h.pos - from
			if h.targetable() and d.length() < r and absf(Vector2.from_angle(angle).angle_to(d)) < arc * 0.5:
				sim.damage_hero(h, dmg, null, "zone")
				if push > 0.0:
					sim.emit(["push", h.slot, d.normalized().x * push, d.normalized().y * push]))


static func donut(sim: Sim, at: Vector2, r0: float, r1: float, delay: float, dmg: float) -> void:
	sim.emit(["tele", "donut", at.x, at.y, r1, 0.0, delay, r0])
	sim.after(delay, func() -> void:
		sim.emit(["boom", "donut", at.x, at.y, r1, r0])
		for h: HeroState in sim.heroes.values():
			var d := h.pos.distance_to(at)
			if h.targetable() and d > r0 and d < r1:
				sim.damage_hero(h, dmg, null, "zone"))


# --- World bosses ---------------------------------------------------------------------

## [move, weight, cooldown, first phase, max range (0 = any)].
const MOVES := {
	"old_mossback": [["log_slam", 3.0, 5.0, 1, 260.0], ["boulder_toss", 2.0, 7.0, 1, 0.0],
		["saplings", 1.0, 16.0, 2, 0.0]],
	"the_warden": [["shackles", 3.0, 6.0, 1, 0.0], ["ball_and_chain", 3.0, 7.0, 2, 0.0],
		["lockdown", 2.0, 12.0, 3, 0.0], ["skeletons", 1.0, 14.0, 1, 0.0]],
	"deep_wyrm": [["burrow", 3.0, 12.0, 1, 0.0], ["breath", 3.0, 6.0, 1, 520.0], ["tail_sweep", 2.0, 5.0, 1, 240.0]],
	"sleeper_below": [["reaching", 3.0, 4.0, 1, 0.0], ["gaze", 2.0, 10.0, 1, 0.0], ["wrong_angles", 2.0, 9.0, 2, 0.0],
		["dream", 2.0, 8.0, 3, 0.0]],
	"astaroth": [["hellfire", 3.0, 6.0, 1, 460.0], ["lava_tide", 2.0, 10.0, 1, 0.0], ["seals", 2.0, 9.0, 2, 0.0],
		["hellstorm", 3.0, 7.0, 3, 0.0]],
}


static func _boss(sim: Sim, m: Mob) -> bool:
	var b := m.brain
	# Enrage: a hard timer, with a tell and a bigger move pool (faster moves).
	if not m.enraged and float(b["enrage_t"]) > 0.0:
		b["enrage_t"] = float(b["enrage_t"]) - Sim.DT
		if float(b["enrage_t"]) <= 0.0:
			m.enraged = true
			m.speed *= 1.3
			m.interval *= 0.7
			_bark(sim, m, "ENOUGH.")
			sim.emit(["snd", "enraged", 1.0])
			sim.emit(["banner", "%s is enraged" % m.def["name"], "Finish it.", Color("ffbf5e")])
	# Phases fire once, at 70% and 35%, and never go back.
	var frac := m.hp_frac()
	var phase: int = b["phase"]
	if phase == 1 and frac < 0.7 or phase == 2 and frac < 0.35:
		b["phase"] = phase + 1
		var barks: Array = m.def["barks"]
		_bark(sim, m, barks[mini(phase, barks.size() - 1)])
		sim.emit(["phase", m.id, phase + 1])
		sim.emit(["snd", m.def.get("roar", "boss"), 1.0])
		# The corridors answer the boss's call.
		for lane: int in sim.director.lanes():
			var roster: Dictionary = ChapterDefs.get_def(sim.director.chapter)["roster"]
			for i in 4 + 2 * phase:
				sim.spawn(roster.keys()[sim.rng.randi() % roster.size()], MapData.portal(lane), lane,
					sim.director.hp_mult(), sim.director.atk_mult())
		_hold(m, 1.2)
		return true
	if m.kind == "old_mossback":
		_mossback_regen(sim, m)
	_pick_target(sim, m)
	if m.state != Mob.State.CHASE or float(b["shared"]) > 0.0:
		return false
	var h: HeroState = sim.heroes.get(m.target)
	if h == null or not h.targetable():
		return false
	var move := _choose(sim, m, h)
	if move == "":
		return false
	_do_boss_move(sim, m, h, move)
	b["shared"] = SHARED_CD * (0.6 if m.enraged else 1.0)
	return true


static func _choose(sim: Sim, m: Mob, h: HeroState) -> String:
	var b := m.brain
	var used: Dictionary = b["used"]
	var options: Array = []
	var total := 0.0
	var d := m.pos.distance_to(h.pos)
	for mv: Array in MOVES.get(m.kind, []):
		var id: String = mv[0]
		if int(mv[3]) > int(b["phase"]) or float(b.get("cd_" + id, 0.0)) > sim.time:
			continue
		if float(mv[4]) > 0.0 and d > float(mv[4]):
			continue
		var w := float(mv[1]) / pow(2.0, float(used.get(id, 0)))
		options.append([id, w, mv[2]])
		total += w
	if options.is_empty():
		return ""
	var r := sim.rng.randf() * total
	for o: Array in options:
		r -= float(o[1])
		if r <= 0.0:
			var id: String = o[0]
			b["cd_" + id] = sim.time + float(o[2]) * (0.6 if m.enraged else 1.0)
			# Anti-repeat: recent uses halve the weight; the others recover.
			for k: String in used.keys():
				used[k] = maxi(0, int(used[k]) - 1)
			used[id] = int(used.get(id, 0)) + 2
			return id
	return ""


## The threat table. Damage dealt is threat; the boss switches only when
## another hero has 110% (close) or 130% (far) of its target's threat.
static func _pick_target(sim: Sim, m: Mob) -> void:
	var cur: HeroState = sim.heroes.get(m.target)
	var best: HeroState = null
	var best_t := -1.0
	for h: HeroState in sim.living_heroes():
		var t := float(m.threat.get(h.slot, 0.0)) + 1000.0 / maxf(50.0, m.pos.distance_to(h.pos))
		if t > best_t:
			best_t = t
			best = h
	if best == null:
		if m.state == Mob.State.CHASE:
			m.state = Mob.State.MARCH
			m.target = -1
		return
	if m.pos.distance_to(best.pos) > 900.0 and (cur == null or not cur.targetable()):
		return
	if cur == null or not cur.targetable():
		m.target = best.slot
		m.state = Mob.State.CHASE
		return
	var cur_t := float(m.threat.get(cur.slot, 0.0)) + 1000.0 / maxf(50.0, m.pos.distance_to(cur.pos))
	var need := 1.1 if m.pos.distance_to(best.pos) < 200.0 else 1.3
	if best != cur and best_t > cur_t * need:
		m.target = best.slot
		sim.emit(["fixate", m.id, best.slot])
	m.state = Mob.State.CHASE


static func _mossback_regen(sim: Sim, m: Mob) -> void:
	var b := m.brain
	# MatchRPG's Regeneration: a big hit (a "wound") stops it for 4 s.
	if float(b["hp_mark"]) - m.hp > m.max_hp * 0.02:
		b["regen_block"] = 4.0
		sim.emit(["bark", m.id, "Hrrk!"])
	if sim.tick % 30 == 0:
		b["hp_mark"] = m.hp
	b["regen_block"] = float(b["regen_block"]) - Sim.DT
	if float(b["regen_block"]) <= 0.0:
		var rate := 0.006 if int(b["phase"]) >= 3 else 0.003
		m.hp = minf(m.max_hp, m.hp + m.max_hp * rate * Sim.DT)


static func _do_boss_move(sim: Sim, m: Mob, h: HeroState, move: String) -> void:
	var atk := m.atk * (1.25 if m.enraged else 1.0)
	var b := m.brain
	var to := h.pos - m.pos
	var ang := to.angle()
	m.flip = to.x > 0.0
	match move:
		"log_slam":
			var hp0 := m.hp
			cone(sim, m.pos, ang, deg_to_rad(120.0), 280.0, 1.1, atk * 2.2, 320.0)
			sim.emit(["snd", "windup", 1.0])
			b["busy"] = 1.1 + RECOVER
			b["channel"] = func() -> void:
				# A wound during the wind-up staggers him (MatchRPG's Log Slam).
				if hp0 - m.hp > m.max_hp * 0.05 and float(b["busy"]) > RECOVER:
					b["busy"] = 1.5
					m.stun_t = 1.5
					b.erase("channel")
					_bark(sim, m, "Hrrk... my roots!")
					sim.emit(["snd", "stun", 1.0])
		"boulder_toss":
			var per := 2 if int(b["phase"]) >= 2 else 1
			for o: HeroState in sim.living_heroes():
				for i in per:
					var at := o.pos + Vector2.from_angle(sim.rng.randf() * TAU) * (60.0 * i)
					sim.emit(["mmis", "boulder", m.pos.x, m.pos.y - 120.0, at.x, at.y, 1.2])
					circle(sim, at, 120.0, 1.2, atk * 1.6, 0.6)
			_hold(m, 0.8)
		"saplings":
			for i in 5:
				sim.spawn("treant_sapling", m.pos, m.lane, sim.director.hp_mult(), sim.director.atk_mult())
			_bark(sim, m, "Grow!")
			_hold(m, 0.8)
		"shackles":
			_bark(sim, m, (m.def["barks"] as Array)[2])
			line(sim, m.pos, ang, m.pos.distance_to(h.pos) + 120.0, 60.0, 0.9, atk * 1.0, 2.0)
			sim.emit(["snd", "chains", 1.0])
			_hold(m, 0.9 + RECOVER)
		"ball_and_chain":
			sim.emit(["mmis", "boulder", m.pos.x, m.pos.y - 100.0, h.pos.x, h.pos.y, 1.3])
			circle(sim, h.pos, 170.0, 1.3, atk * 2.5, 1.0)
			_hold(m, 0.9)
		"lockdown":
			donut(sim, m.pos, 170.0, 460.0, 1.5, atk * 2.4)
			_bark(sim, m, "Lockdown.")
			sim.emit(["snd", "seal", 1.0])
			_hold(m, 1.5 + RECOVER)
		"skeletons":
			for i in 6:
				sim.spawn("skeleton", m.pos, m.lane, sim.director.hp_mult(), sim.director.atk_mult())
			_hold(m, 0.6)
		"burrow":
			m.untargetable = true
			m.hidden = true
			sim.emit(["snd", "boulder_alarm", 1.0])
			var slot := h.slot
			b["busy"] = 2.6
			b["channel"] = func() -> void:
				var t: HeroState = sim.heroes.get(slot)
				if t != null and t.alive and float(b["busy"]) > 1.3:
					m.pos = sim.map.slide(m.pos, (t.pos - m.pos).limit_length(m.speed * 2.6 * Sim.DT))
				if absf(float(b["busy"]) - 1.3) < Sim.DT * 0.6:
					circle(sim, m.pos, 170.0, 1.25, atk * 2.6, 0.8)
					if int(b["phase"]) >= 2:
						for i in 6:
							var at := m.pos + Vector2.from_angle(sim.rng.randf() * TAU) * sim.rng.randf_range(160.0, 480.0)
							circle(sim, sim.map.nearest_open(at), 110.0, 1.4, atk * 1.4)
			b["after_busy"] = func() -> void:
				m.untargetable = false
				m.hidden = false
				sim.emit(["snd", "boulder_break", 1.0])
				if int(b["phase"]) >= 3 and not b.get("dark", false):
					b["dark"] = true
					sim.emit(["dark", true])
		"breath":
			line(sim, m.pos, ang, 620.0, 120.0, 1.0, atk * 2.0)
			sim.emit(["snd", "roar_wyrm", 0.7])
			_hold(m, 1.0 + RECOVER)
		"tail_sweep":
			sim.emit(["tele", "circle", m.pos.x, m.pos.y, 250.0, 0.0, 0.8, 0.0])
			var at := m.pos
			sim.after(0.8, func() -> void:
				sim.emit(["boom", "rock", at.x, at.y, 250.0])
				for o: HeroState in sim.heroes.values():
					if o.targetable() and o.pos.distance_to(at) < 250.0:
						sim.damage_hero(o, atk * 1.5, null, "zone")
						var d := (o.pos - at).normalized()
						sim.emit(["push", o.slot, d.x * 300.0, d.y * 300.0]))
			_hold(m, 0.8 + RECOVER)
		"reaching":
			for o: HeroState in sim.living_heroes():
				var from := m.pos + Vector2.from_angle(sim.rng.randf() * TAU) * 120.0
				line(sim, from, (o.pos - from).angle(), from.distance_to(o.pos) + 160.0, 80.0, 1.0, atk * 1.8)
			sim.emit(["snd", "tentacle", 1.0])
			_hold(m, 0.6)
		"gaze":
			_bark(sim, m, "Look at me.")
			cone(sim, m.pos, ang, deg_to_rad(70.0), 900.0, 1.8, atk * 1.4)
			var gaze_ang := ang
			sim.after(1.8, func() -> void:
				for o: HeroState in sim.heroes.values():
					var d := o.pos - m.pos
					if o.targetable() and d.length() < 900.0 and absf(Vector2.from_angle(gaze_ang).angle_to(d)) < deg_to_rad(35.0):
						o.stun_t = maxf(o.stun_t, 1.2))
			sim.emit(["snd", "dread", 1.0])
			_hold(m, 1.8 + RECOVER)
		"wrong_angles":
			for o: HeroState in sim.living_heroes():
				line(sim, o.pos - Vector2(520, 0), 0.0, 1040.0, 120.0, 1.4, atk * 2.0)
				line(sim, o.pos - Vector2(0, 520), PI * 0.5, 1040.0, 120.0, 1.7, atk * 2.0)
			sim.emit(["snd", "warp", 1.0])
			_hold(m, 0.8)
		"dream":
			for o: HeroState in sim.living_heroes():
				var at := o.pos
				sim.emit(["tele", "circle", at.x, at.y, 140.0, 0.0, 0.9, 0.0])
				sim.after(0.9, func() -> void: sim.add_zone("dream", at, 140.0, 8.0, {"dps": atk * 0.6}))
			for i in 6:
				sim.spawn("spawnling", m.pos, m.lane, sim.director.hp_mult(), sim.director.atk_mult())
			_hold(m, 0.7)
		"hellfire":
			cone(sim, m.pos, ang, deg_to_rad(90.0), 440.0, 1.0, atk * 2.2, 200.0)
			sim.emit(["snd", "ignite", 1.0])
			_hold(m, 1.0 + RECOVER)
		"lava_tide":
			var n := 2 + int(b["phase"])
			for o: HeroState in sim.living_heroes():
				for i in n:
					var at := sim.map.nearest_open(o.pos + Vector2.from_angle(sim.rng.randf() * TAU) * sim.rng.randf_range(150.0, 420.0))
					sim.emit(["tele", "circle", at.x, at.y, 160.0, 0.0, 1.5, 0.0])
					sim.after(1.5, func() -> void: sim.add_zone("lava", at, 160.0, 14.0, {"dps": atk * 0.8}))
			_bark(sim, m, "The tide rises.")
			sim.emit(["snd", "lava", 1.0])
			_hold(m, 0.8)
		"seals":
			for o: HeroState in sim.living_heroes():
				for i in 4:
					var at := sim.map.nearest_open(o.pos + Vector2.from_angle(i * TAU / 4.0 + sim.rng.randf()) * 160.0)
					sim.add_zone("seal", at, 70.0, 15.0, {"dmg": atk * 2.0})
			sim.emit(["snd", "seal", 1.0])
			_hold(m, 0.6)
		"hellstorm":
			_bark(sim, m, (m.def["barks"] as Array)[2])
			for o: HeroState in sim.living_heroes():
				for i in 4:
					var at := o.pos + Vector2.from_angle(sim.rng.randf() * TAU) * sim.rng.randf_range(0.0, 260.0)
					sim.emit(["meteor", at.x, at.y, 1.0])
					circle(sim, at, 120.0, 1.0 + i * 0.25, atk * 1.6)
			for i in 4:
				sim.spawn("hellhound", m.pos, m.lane, sim.director.hp_mult(), sim.director.atk_mult())
			sim.emit(["snd", "meteor", 1.0])
			_hold(m, 1.0)
