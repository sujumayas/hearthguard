class_name Skills
extends RefCounted
## What heroes do, on the host: basic attacks, the sixteen abilities, the
## talents' hooks, potions and the Alchemist. The owner has already played
## the swing or the cast on its own screen; this decides what it hit.

const PROJ_SPEED_MULT := {"arrow": 1.25, "arcane": 1.0, "knife": 1.3, "fireball": 0.9, "shard": 1.1,
	"power": 2.2, "volley": 1.2}


# --- Basic attacks ------------------------------------------------------------

static func attack(sim: Sim, h: HeroState, target_id: int) -> void:
	if not h.alive or h.stun_t > 0.0:
		return
	var m: Mob = sim.by_id.get(target_id)
	if m == null or not m.alive() or m.untargetable:
		return
	var reach: float = float(h.stats["range"]) + m.radius + 160.0
	if h.pos.distance_to(m.pos) > reach:
		return
	h.swings += 1
	h.shots += 1
	var base: float = h.stats["dmg"]
	if h.cls == "flow":
		base *= 1.0 + 0.03 * h.flow
	var crit_chance: float = h.stats["crit"]
	var crit := sim.rng.randf() < crit_chance
	var mult := 1.0
	if crit:
		mult = float(h.stats["crit_dmg"])
		if h.fx("crescendo") > 0.0 and h.flow >= 20 + int(h.fx("flow_max")):
			mult = 3.0
	var opts := {"crit": crit}
	if h.fx("follow_through") > 0.0 and h.swings % 4 == 0:
		mult = maxf(mult, h.fx("follow_through"))
		opts["crit"] = true
		opts["sweep"] = true
		sim.emit(["fx", "sweep", h.pos.x, h.pos.y, h.slot])
	if h.fx("headshot") > 0.0 and sim.rng.randf() < h.fx("headshot"):
		mult = maxf(mult, 3.0)
		opts["crit"] = true
		opts["headshot"] = true
	if h.fx("focus") > 0.0:
		if h.focus_id == target_id:
			h.focus = mini(h.focus + 1, 10)
		else:
			h.focus_id = target_id
			h.focus = 0
		mult *= 1.0 + h.fx("focus") * h.focus
	if h.spellblade > 0:
		h.spellblade -= 1
		mult *= h.fx("spellblade")
	var dmg := base * mult
	var kind: String = h.stats["kind"]
	if h.stats["melee"]:
		_melee(sim, h, m, dmg, kind, opts)
		return
	# Ranged: the missile carries the hit.
	var missile: String = HeroClasses.get_def(h.cls).get("missile", "arrow")
	var targets: Array = [m]
	var extra := int(h.fx("split"))
	if h.split_shots > 0:
		h.split_shots -= 1
		extra = maxi(extra, 2)
	if extra > 0:
		for o: Mob in sim.mobs_near(m.pos, 260.0):
			if targets.size() > extra:
				break
			if o != m:
				targets.append(o)
	for i in targets.size():
		var t: Mob = targets[i]
		var o := opts.duplicate()
		o["main"] = i == 0
		var pierce := int(h.fx("pierce"))
		if pierce > 0:
			var dir := (t.pos - h.pos).normalized()
			fire(sim, h, missile, h.pos, dir, -1, dmg * (1.0 if i == 0 else 0.5), kind,
				{"pierce": pierce + 1, "range": float(h.stats["range"]) + 200.0, "o": o})
		else:
			fire(sim, h, missile, h.pos, (t.pos - h.pos).normalized(), t.id, dmg * (1.0 if i == 0 else 0.5), kind, {"o": o})
	if h.fx("hailfire") > 0.0 and h.shots % int(h.fx("hailfire")) == 0:
		volley(sim, h, maxi(1, h.ranks[0]), m.pos)


static func _melee(sim: Sim, h: HeroState, m: Mob, dmg: float, kind: String, opts: Dictionary) -> void:
	sim.damage_mob(m, dmg, kind, h.slot, opts)
	_on_hit(sim, h, m, dmg)
	var cleave := float(HeroClasses.get_def(h.cls).get("cleave", 0.0)) + h.fx("cleave")
	if opts.get("sweep", false):
		cleave = maxf(cleave, 1.0)
	if cleave > 0.0:
		var facing := (m.pos - h.pos).normalized()
		var full: bool = h.fx("cleave_full") > 0.0 or opts.get("sweep", false)
		var arc := Tuning.cleave_arc() * 0.5
		var hits := 0
		for o: Mob in sim.mobs_near(h.pos, float(h.stats["range"]) + 70.0):
			if o == m:
				continue
			if not full and absf(facing.angle_to(o.pos - h.pos)) > arc:
				continue
			sim.damage_mob(o, dmg * cleave, kind, h.slot, {"aoe": true, "crit": opts.get("crit", false)})
			_on_hit(sim, h, o, dmg * cleave)
			hits += 1
		sim.emit(["fx", "cleave", h.pos.x, h.pos.y, h.slot, facing.angle(), 1.0 if full else 0.0])
	if h.fx("twin") > 0.0:
		var other: Mob = null
		for o: Mob in sim.mobs_near(m.pos, 140.0):
			if o != m:
				other = o
				break
		if other != null:
			sim.damage_mob(other, dmg, kind, h.slot, opts)
			_on_hit(sim, h, other, dmg)
	sim.add_flow(h, 1)


## What every hit by a hero's own attack adds.
static func _on_hit(sim: Sim, h: HeroState, m: Mob, dmg: float) -> void:
	if not m.alive():
		return
	if h.fx("sunder") > 0.0:
		m.sunder_t = 4.0
		m.sunder = h.fx("sunder")
	if h.fx("mark") > 0.0:
		m.mark_t = 5.0
		m.mark = h.fx("mark")
	if h.fx("poison") > 0.0:
		m.poison_t = 4.0
		m.poison_dps = minf(m.poison_dps + dmg * h.fx("poison") / 4.0, dmg * 2.0)
		m.poison_src = h.slot
	if h.fx("bolt_burn") > 0.0:
		sim.burn(m, dmg * h.fx("bolt_burn") / 3.0, 3.0, h.slot)
	if h.fx("bolt_slow") > 0.0:
		sim.slow_mob(m, h.fx("bolt_slow"), 1.5)


# --- Projectiles --------------------------------------------------------------

## Launches a missile. `target` homes on a mob (-1 for a straight shot);
## `extra`: pierce (how many it goes through), range, o (hit options),
## explode (radius), on_end.
static func fire(sim: Sim, h: HeroState, kind: String, from: Vector2, dir: Vector2, target: int, dmg: float,
		dkind: String, extra := {}) -> void:
	var speed := Tuning.projectile_speed() * float(PROJ_SPEED_MULT.get(kind, 1.0))
	var p := {"id": sim.next_zone, "kind": kind, "pos": from + dir * 20.0, "dir": dir, "speed": speed,
		"src": h.slot, "dmg": dmg, "dkind": dkind, "target": target, "pierce": int(extra.get("pierce", 1)),
		"range": float(extra.get("range", 900.0)), "hit": {}, "o": extra.get("o", {}),
		"explode": float(extra.get("explode", 0.0)), "to": extra.get("to", Vector2.INF),
		"falloff": float(extra.get("falloff", 0.0)), "push": float(extra.get("push", 0.0)), "width": float(extra.get("width", 18.0))}
	sim.next_zone += 1
	sim.projectiles.append(p)
	sim.emit(["proj", p["id"], kind, from.x, from.y - 30.0, dir.x * speed, dir.y * speed, target, p["range"] / speed, h.slot])


static func step_projectiles(sim: Sim) -> void:
	var keep: Array = []
	for p: Dictionary in sim.projectiles:
		var h: HeroState = sim.heroes.get(p["src"])
		var done := false
		var pos: Vector2 = p["pos"]
		var target: int = p["target"]
		if target >= 0:
			var m: Mob = sim.by_id.get(target)
			if m == null or not m.alive():
				# Its target died: carry on straight and hit what's there.
				p["target"] = -1
				target = -1
			else:
				var to := m.pos - pos
				if to.length() < m.radius + 14.0:
					_proj_hit(sim, h, p, m)
					done = true
				else:
					p["dir"] = to.normalized()
		var step: float = float(p["speed"]) * Sim.DT
		pos += (p["dir"] as Vector2) * step
		p["pos"] = pos
		p["range"] = float(p["range"]) - step
		if not done and target < 0:
			for m: Mob in sim.mobs_near(pos, float(p["width"])):
				if (p["hit"] as Dictionary).has(m.id):
					continue
				p["hit"][m.id] = true
				_proj_hit(sim, h, p, m)
				p["pierce"] = int(p["pierce"]) - 1
				if int(p["pierce"]) <= 0:
					done = true
					break
		var to_point: Vector2 = p["to"]
		if not done and to_point != Vector2.INF and pos.distance_to(to_point) <= step:
			done = true
		if not done and (float(p["range"]) <= 0.0 or not sim.map.is_open(pos)):
			done = true
		if done:
			if float(p["explode"]) > 0.0 and h != null:
				_explode(sim, h, p)
			sim.emit(["proj_end", p["id"], pos.x, pos.y])
		else:
			keep.append(p)
	sim.projectiles = keep


static func _proj_hit(sim: Sim, h: HeroState, p: Dictionary, m: Mob) -> void:
	if h == null:
		return
	if float(p["explode"]) > 0.0:
		p["pos"] = m.pos
		p["pierce"] = 0
		return
	var dmg: float = p["dmg"]
	var o: Dictionary = p["o"]
	sim.damage_mob(m, dmg, p["dkind"], h.slot, o)
	if float(p["falloff"]) > 0.0:
		p["dmg"] = maxf(dmg * (1.0 - float(p["falloff"])), dmg * 0.4)
	if float(p["push"]) > 0.0:
		sim.push_mob(m, p["dir"], float(p["push"]))
	var kind: String = p["kind"]
	if kind in ["arrow", "arcane"]:
		_on_hit(sim, h, m, dmg)
	if kind == "arcane":
		var splash: float = HeroClasses.get_def("mage")["splash"]
		for o2: Mob in sim.mobs_near(m.pos, splash):
			if o2 != m:
				sim.damage_mob(o2, dmg * float(HeroClasses.get_def("mage")["splash_pct"]), "mag", h.slot, {"aoe": true})
		if h.fx("chain") > 0.0 and o.get("main", true):
			var last := m
			var done := {m.id: true}
			for i in int(h.fx("chain")):
				var next: Mob = null
				for c: Mob in sim.mobs_near(last.pos, 260.0):
					if not done.has(c.id):
						next = c
						break
				if next == null:
					break
				done[next.id] = true
				sim.emit(["fx", "zap", last.pos.x, last.pos.y, h.slot, next.pos.x, next.pos.y])
				sim.damage_mob(next, dmg * 0.6, "mag", h.slot, {"aoe": true})
				last = next
	if kind == "arrow" and h.fx("blast") > 0.0:
		for o2: Mob in sim.mobs_near(m.pos, 110.0):
			if o2 != m:
				sim.damage_mob(o2, dmg * h.fx("blast"), "phys", h.slot, {"aoe": true})
		sim.emit(["boom", "blast", m.pos.x, m.pos.y, 110.0])


static func _explode(sim: Sim, h: HeroState, p: Dictionary) -> void:
	var at: Vector2 = p["pos"]
	var r: float = p["explode"]
	var dmg: float = p["dmg"]
	for m: Mob in sim.mobs_near(at, r):
		sim.damage_mob(m, dmg, p["dkind"], h.slot, {"aoe": true, "spell": true})
		if p["kind"] == "fireball":
			sim.burn(m, dmg * 0.5 / 3.0, 3.0, h.slot)
			sim.push_mob(m, (m.pos - at).normalized(), 220.0)
	sim.emit(["boom", p["kind"], at.x, at.y, r])
	sim.emit(["snd", "blast", 0.9])
	if p["kind"] == "fireball" and h.fx("fire_pool") > 0.0:
		sim.add_zone("fire_pool", at, r * 0.8, 3.0, {"dps": dmg * 0.6, "src": h.slot})


# --- Abilities ------------------------------------------------------------------

## Casts ability `slot` at `tp` (a point) or `tid` (a mob). Returns whether
## it went off.
static func cast(sim: Sim, h: HeroState, slot: int, tp: Vector2, tid: int) -> bool:
	if not h.alive or h.stun_t > 0.0 or slot < 0 or slot > 3:
		return false
	var rank: int = h.ranks[slot]
	if rank <= 0 or h.cds[slot] > 0.05:
		return false
	var id: String = HeroClasses.ability(h.cls, slot)["id"]
	var ok := _cast(sim, h, id, rank, tp, tid)
	if not ok:
		return false
	h.cds[slot] = HeroStats.cooldown(h.cls, slot, rank, h.stats)
	h.spells_cast += 1
	if h.fx("spellblade") > 0.0:
		h.spellblade = 3
	if h.fx("overcharge") > 0.0 and h.spells_cast % int(h.fx("overcharge")) == 0 and id in ["fireball", "frost_nova", "meteor"]:
		sim.after(0.3, func() -> void: _cast(sim, h, id, rank, tp, tid))
		sim.emit(["fx", "overcharge", h.pos.x, h.pos.y, h.slot])
	sim.emit(["cast", h.slot, slot, tp.x, tp.y])
	return true


static func _cast(sim: Sim, h: HeroState, id: String, rank: int, tp: Vector2, tid: int) -> bool:
	var dmg: float = h.stats["dmg"]
	var a := {}
	for ab: Dictionary in HeroClasses.get_def(h.cls)["abilities"]:
		if ab["id"] == id:
			a = ab
	var pw := float((a["power"] as Array)[rank - 1])
	match id:
		"whirlwind":
			whirlwind(sim, h, rank)
		"charge":
			var dir := (tp - h.pos).normalized()
			if dir == Vector2.ZERO:
				return false
			var length := minf(h.pos.distance_to(tp), Tuning.dash_distance())
			var end := _walk(sim, h.pos, dir, length)
			for m: Mob in sim.mobs_on_line(h.pos, end, 70.0):
				sim.damage_mob(m, dmg * pw, "phys", h.slot, {"aoe": true})
				sim.push_mob(m, dir.orthogonal() * (1.0 if dir.orthogonal().dot(m.pos - h.pos) > 0.0 else -1.0), 420.0)
				sim.stun_mob(m, 0.4)
			sim.emit(["dash", h.slot, h.pos.x, h.pos.y, end.x, end.y, 0.2, "charge"])
			h.pos = end
			h.untouchable_t = 0.3
			sim.emit(["snd", "leap", 0.9])
		"war_cry":
			h.bloodlust_t = float(a["dur"])
			h.bloodlust = pw
			for m: Mob in sim.mobs_near(h.pos, 260.0):
				sim.stun_mob(m, 0.6)
			sim.emit(["fx", "war_cry", h.pos.x, h.pos.y, h.slot])
			sim.emit(["snd", "song_sword", 0.9])
		"executioner":
			var to := _walk(sim, h.pos, (tp - h.pos).normalized(), minf(h.pos.distance_to(tp), 520.0))
			sim.emit(["dash", h.slot, h.pos.x, h.pos.y, to.x, to.y, 0.45, "leap"])
			sim.emit(["tele", "circle", to.x, to.y, float(a["radius"]), 0.0, 0.45, 0.0])
			h.pos = to
			h.untouchable_t = 0.5
			sim.emit(["snd", "leap", 1.0])
			sim.after(0.45, func() -> void:
				for m: Mob in sim.mobs_near(to, float(a["radius"])):
					sim.damage_mob(m, dmg * pw, "phys", h.slot, {"aoe": true})
					sim.push_mob(m, (m.pos - to).normalized(), 520.0)
				sim.emit(["boom", "slam", to.x, to.y, float(a["radius"])])
				sim.emit(["snd", "boss_stomp", 1.0])
				h.headsman_t = float(a["dur"])
				h.avatar_t = 0.0)
		"fireball":
			var dir := (tp - h.pos).normalized()
			var r := float(a["radius"]) * (1.0 + h.fx("fireball_wide"))
			var length := minf(h.pos.distance_to(tp), 700.0)
			fire(sim, h, "fireball", h.pos, dir, -1, dmg * pw, "mag",
				{"explode": r, "range": length, "to": h.pos + dir * length, "pierce": 1, "width": 30.0})
			sim.emit(["snd", "ignite", 0.9])
		"frost_nova":
			var r: float = a["radius"]
			var dur := float(a["dur"]) * (2.0 if h.fx("nova_long") > 0.0 else 1.0)
			for m: Mob in sim.mobs_near(h.pos, r):
				sim.damage_mob(m, dmg * pw, "mag", h.slot, {"aoe": true, "spell": true})
				sim.slow_mob(m, 0.5, dur)
				if h.fx("deep_freeze") > 0.0 and m.rank != "boss":
					m.freeze_t = h.fx("deep_freeze") * (0.5 if m.rank == "elite" else 1.0)
			sim.emit(["boom", "frost", h.pos.x, h.pos.y, r])
			sim.emit(["snd", "freeze", 0.9])
			var shards := int(h.fx("nova_shards"))
			for i in shards:
				fire(sim, h, "shard", h.pos, Vector2.from_angle(i * TAU / shards), -1, dmg * pw * 0.6, "mag",
					{"pierce": 3, "range": 520.0})
		"blink":
			var to := sim.map.nearest_open(h.pos + (tp - h.pos).limit_length(float(a.get("range", 420.0))))
			if h.fx("time_stop") > 0.0:
				for m: Mob in sim.mobs_near(h.pos, 260.0):
					if m.rank != "boss":
						m.freeze_t = h.fx("time_stop")
				sim.emit(["boom", "time_stop", h.pos.x, h.pos.y, 260.0])
			sim.emit(["dash", h.slot, h.pos.x, h.pos.y, to.x, to.y, 0.0, "blink"])
			h.pos = to
			sim.emit(["snd", "warp", 0.9])
		"meteor":
			var n := 10 * (2 if h.fx("meteor_double") > 0.0 else 1)
			var r: float = a["radius"]
			for i in n:
				var at := tp + Vector2.from_angle(sim.rng.randf() * TAU) * sqrt(sim.rng.randf()) * r
				var delay := 0.25 + 3.0 * i / n
				sim.after(delay, func() -> void:
					sim.emit(["tele", "circle", at.x, at.y, 120.0, 0.0, Tuning.aoe_delay(), 0.0])
					sim.emit(["meteor", at.x, at.y, Tuning.aoe_delay()]))
				sim.after(delay + Tuning.aoe_delay(), func() -> void:
					for m: Mob in sim.mobs_near(at, 120.0):
						sim.damage_mob(m, dmg * pw * 0.45, "mag", h.slot, {"aoe": true, "spell": true})
						sim.burn(m, dmg * 0.4, 3.0, h.slot)
						sim.push_mob(m, (m.pos - at).normalized(), 260.0)
					sim.emit(["boom", "meteor", at.x, at.y, 120.0])
					sim.emit(["snd", "meteor", 0.7]))
		"fan_of_knives":
			var n := int(a["count"]) * (2 if h.fx("fan_double") > 0.0 else 1)
			for i in n:
				fire(sim, h, "knife", h.pos, Vector2.from_angle(i * TAU / n + sim.rng.randf() * 0.1), -1, dmg * pw, "phys",
					{"pierce": 1, "range": 420.0})
			sim.add_flow(h, 2)
			sim.emit(["snd", "sword", 0.9])
		"shadow_step":
			var m: Mob = sim.by_id.get(tid)
			if m == null or not m.alive():
				m = sim.nearest_mob(tp, 160.0)
			if m == null or h.pos.distance_to(m.pos) > 700.0:
				return false
			var behind := m.pos + (m.pos - h.pos).normalized() * (m.radius + 22.0)
			behind = sim.map.nearest_open(behind)
			sim.emit(["dash", h.slot, h.pos.x, h.pos.y, behind.x, behind.y, 0.0, "blink"])
			h.pos = behind
			h.ambush_target = m.id
			var mult := float(h.stats["crit_dmg"]) * pw / 2.0
			sim.damage_mob(m, dmg * mult * (1.0 + 0.03 * h.flow), "phys", h.slot, {"crit": true})
			_on_hit(sim, h, m, dmg)
			sim.add_flow(h, 3)
			sim.emit(["snd", "crit", 1.0])
		"smoke":
			sim.add_zone("smoke", h.pos, float(a["radius"]), float(a["dur"]), {"slow": pw, "src": h.slot})
			sim.emit(["snd", "bomb", 0.8])
		"flurry":
			var n := int(a["count"]) * (2 if h.fx("flurry_double") > 0.0 else 1)
			var gap := 0.11
			h.untouchable_t = n * gap + 0.3
			var start := h.pos
			for i in n:
				sim.after(i * gap, func() -> void:
					if not h.alive:
						return
					var m := sim.nearest_mob(h.pos, float(a["radius"]))
					if m == null:
						m = sim.nearest_mob(start, float(a["radius"]))
					if m == null:
						return
					var at := sim.map.nearest_open(m.pos + Vector2.from_angle(sim.rng.randf() * TAU) * (m.radius + 18.0))
					sim.emit(["dash", h.slot, h.pos.x, h.pos.y, at.x, at.y, 0.0, "flurry"])
					h.pos = at
					var crit := sim.rng.randf() < float(h.stats["crit"]) + 0.3
					sim.damage_mob(m, dmg * pw * (float(h.stats["crit_dmg"]) if crit else 1.0) * (1.0 + 0.03 * h.flow),
						"phys", h.slot, {"crit": crit})
					sim.add_flow(h, 1)
					if h.fx("flurry_double") > 0.0:
						for k in 3:
							fire(sim, h, "knife", h.pos, Vector2.from_angle(sim.rng.randf() * TAU), -1, dmg * 0.6, "phys",
								{"pierce": 1, "range": 300.0}))
			sim.emit(["snd", "surge", 1.0])
		"volley":
			volley(sim, h, rank, tp)
		"power_shot":
			var dir := (tp - h.pos).normalized()
			if dir == Vector2.ZERO:
				return false
			sim.emit(["aim", h.slot, 0.4])
			sim.after(0.4, func() -> void:
				if not h.alive:
					return
				var dirs := [dir]
				if h.fx("power_triple") > 0.0:
					dirs = [dir, dir.rotated(0.21), dir.rotated(-0.21)]
				for d: Vector2 in dirs:
					fire(sim, h, "power", h.pos, d, -1, dmg * pw, "phys",
						{"pierce": 999, "range": 1150.0, "falloff": 0.08, "push": 160.0, "width": 34.0})
				sim.emit(["snd", "surge", 0.9]))
		"tumble":
			var dir := (tp - h.pos).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.LEFT if not h.flip else Vector2.RIGHT
			var to := _walk(sim, h.pos, dir, 300.0 * (1.0 + h.fx("tumble_far")))
			sim.emit(["dash", h.slot, h.pos.x, h.pos.y, to.x, to.y, 0.22, "tumble"])
			h.pos = to
			h.untouchable_t = 0.25
			h.split_shots = int(pw)
			sim.emit(["snd", "leap", 0.7])
		"rain":
			var big := h.fx("rain_big") > 0.0
			var r := float(a["radius"]) * (1.4 if big else 1.0)
			var dur := 6.0 if big else float(a["dur"])
			sim.add_zone("rain", tp, r, dur, {"dmg": dmg * pw, "src": h.slot})
			sim.emit(["snd", "chant", 0.8])
		_:
			return false
	return true


static func whirlwind(sim: Sim, h: HeroState, rank: int) -> void:
	var a := HeroClasses.ability(h.cls, 0)
	var r := float(a["radius"]) * (1.0 + h.fx("whirl_wide"))
	var pw := float((a["power"] as Array)[rank - 1])
	for m: Mob in sim.mobs_near(h.pos, r):
		sim.damage_mob(m, float(h.stats["dmg"]) * pw, "phys", h.slot, {"aoe": true})
		sim.push_mob(m, (m.pos - h.pos).normalized(), 380.0)
		if h.fx("whirl_stun") > 0.0:
			sim.stun_mob(m, h.fx("whirl_stun"))
	sim.emit(["fx", "whirl", h.pos.x, h.pos.y, h.slot, r])
	sim.emit(["snd", "sword", 1.0])


static func volley(sim: Sim, h: HeroState, rank: int, tp: Vector2) -> void:
	var a := HeroClasses.ability("archer", 0)
	var pw := float((a["power"] as Array)[clampi(rank, 1, 4) - 1])
	var n := int(a["count"]) + int(h.fx("volley_more"))
	var dir := (tp - h.pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var spread := deg_to_rad(40.0 + n)
	for i in n:
		var d := dir.rotated(lerpf(-spread * 0.5, spread * 0.5, float(i) / maxf(1.0, n - 1)))
		fire(sim, h, "volley", h.pos, d, -1, float(h.stats["dmg"]) * pw, "phys",
			{"pierce": 2 + int(h.fx("pierce")), "range": 620.0})
	sim.emit(["snd", "wood", 0.8])


## How far a dash gets along `dir` before a wall.
static func _walk(sim: Sim, from: Vector2, dir: Vector2, length: float) -> Vector2:
	var at := from
	var stepn := int(length / 10.0)
	for i in stepn:
		var nxt := at + dir * 10.0
		if not sim.map.is_open(nxt):
			break
		at = nxt
	return at


# --- Talents' hooks -------------------------------------------------------------

static func on_kill(sim: Sim, h: HeroState, m: Mob) -> void:
	if h.fx("momentum") > 0.0:
		h.cds[0] = maxf(0.0, h.cds[0] - h.fx("momentum"))
		h.cds[1] = maxf(0.0, h.cds[1] - h.fx("momentum"))
	if h.fx("refund") > 0.0:
		for i in 4:
			h.cds[i] = maxf(0.0, h.cds[i] - h.fx("refund"))
	if h.fx("shadow_dance") > 0.0:
		h.cds[0] = maxf(0.0, h.cds[0] - h.fx("shadow_dance"))
		h.cds[1] = maxf(0.0, h.cds[1] - h.fx("shadow_dance"))
	if h.fx("rampage") > 0.0:
		h.rampage = mini(h.rampage + 1, 20)
		h.rampage_t = 5.0
	if h.fx("ambush_reset") > 0.0 and m.id == h.ambush_target:
		h.cds[1] = 0.0


## Executions burst for the Headsman (Sim.damage_mob calls it on an
## execute). The burst can't execute, so it never chains forever.
static func exec_burst(sim: Sim, h: HeroState, at: Vector2) -> void:
	for o: Mob in sim.mobs_near(at, 150.0):
		sim.damage_mob(o, float(h.stats["dmg"]) * h.fx("exec_burst"), "phys", h.slot, {"aoe": true, "no_exec": true})
	sim.emit(["boom", "exec", at.x, at.y, 150.0])


static func zone_tick(sim: Sim, z: Dictionary) -> void:
	var at: Vector2 = z["pos"]
	var r: float = z["r"]
	var data: Dictionary = z["data"]
	match z["kind"]:
		"fire_pool":
			for m: Mob in sim.mobs_near(at, r):
				sim.damage_mob(m, float(data["dps"]) * 0.25, "pure", data["src"], {"aoe": true})
		"smoke":
			for m: Mob in sim.mobs_near(at, r):
				m.blind_t = 0.6
				sim.slow_mob(m, float(data["slow"]), 0.6)
		"rain":
			for m: Mob in sim.mobs_near(at, r):
				sim.damage_mob(m, float(data["dmg"]) * 0.25, "phys", data["src"], {"aoe": true})
				sim.slow_mob(m, 0.3, 0.5)
		"web":
			for h: HeroState in sim.heroes.values():
				if h.alive and h.pos.distance_to(at) < r:
					h.slow = 0.5
					h.slow_t = 0.5
		"poison", "lava", "fire_trail", "dream":
			for h: HeroState in sim.heroes.values():
				if h.alive and h.pos.distance_to(at) < r:
					sim.damage_hero(h, float(data["dps"]) * 0.25, null, "zone")
		"seal":
			for h: HeroState in sim.heroes.values():
				if h.alive and h.pos.distance_to(at) < r:
					sim.damage_hero(h, float(data["dmg"]), null, "zone")
					sim.emit(["boom", "seal", at.x, at.y, r])
					z["t"] = 0.0
					break


# --- Potions and the Alchemist ---------------------------------------------------

static func give_potion(sim: Sim, h: HeroState, id: String) -> bool:
	var stack: int = PotionDefs.get_def(id)["stack"]
	for b: Array in h.belt:
		if b[0] == id and int(b[1]) < stack:
			b[1] = int(b[1]) + 1
			sim.emit(["loot", h.slot, id])
			return true
	for b: Array in h.belt:
		if b[0] == "" or int(b[1]) <= 0:
			b[0] = id
			b[1] = 1
			sim.emit(["loot", h.slot, id])
			return true
	h.gold += int(PotionDefs.get_def(id)["price"] / 2)
	return false


static func drink(sim: Sim, h: HeroState, i: int, tp: Vector2) -> void:
	if not h.alive or i < 0 or i >= h.belt.size():
		return
	var b: Array = h.belt[i]
	var id: String = b[0]
	if id == "" or int(b[1]) <= 0:
		return
	var def := PotionDefs.get_def(id)
	# Before the potion works, so the log shows what it was drunk at.
	sim.emit(["drink", h.slot, id, h.hp / h.max_hp(), sim.count_near(h.pos, 300.0)])
	match id:
		"heal":
			sim.heal_hero(h, h.max_hp() * 0.5)
		"stun":
			for m: Mob in sim.mobs_near(h.pos, 340.0):
				sim.stun_mob(m, 2.5)
			sim.emit(["boom", "stun", h.pos.x, h.pos.y, 340.0])
		"freeze":
			sim.freeze_all_t = 4.0
		"surge":
			h.surge_t = 10.0
		"meteor":
			var at := tp if tp.distance_to(h.pos) < 900.0 else h.pos
			sim.emit(["tele", "circle", at.x, at.y, 220.0, 0.0, Tuning.aoe_delay(), 0.0])
			sim.emit(["meteor", at.x, at.y, Tuning.aoe_delay()])
			sim.after(Tuning.aoe_delay(), func() -> void:
				for m: Mob in sim.mobs_near(at, 220.0):
					sim.damage_mob(m, float(h.stats["dmg"]) * 7.0, "pure", h.slot, {"aoe": true})
					sim.burn(m, float(h.stats["dmg"]), 3.0, h.slot)
					sim.push_mob(m, (m.pos - at).normalized(), 420.0)
				sim.emit(["boom", "meteor", at.x, at.y, 220.0])
				sim.emit(["snd", "meteor", 1.0]))
		"cataclysm":
			for m: Mob in sim.mobs_near(h.pos, 480.0):
				match m.rank:
					"mob":
						sim.damage_mob(m, m.hp + 1.0, "pure", h.slot, {"aoe": true})
					"elite":
						sim.damage_mob(m, m.max_hp * 0.5, "pure", h.slot, {"aoe": true, "no_exec": true})
					"boss":
						sim.damage_mob(m, m.max_hp * 0.1, "pure", h.slot, {"aoe": true, "no_exec": true})
			sim.emit(["boom", "cataclysm", h.pos.x, h.pos.y, 480.0])
		"aegis":
			h.aegis_t = 6.0
		"cleanse":
			h.stun_t = 0.0
			h.root_t = 0.0
			h.slow_t = 0.0
			h.poison_t = 0.0
			h.burn_t = 0.0
			for z: Dictionary in sim.zones:
				if z["kind"] in ["web", "poison", "lava", "fire_trail", "seal", "dream"] and (z["pos"] as Vector2).distance_to(h.pos) < 340.0:
					z["t"] = 0.0
		"echo":
			h.echo_t = 30.0
	if h.echo_t > 0.0 and id != "echo":
		h.echo_t = 0.0
	else:
		b[1] = int(b[1]) - 1
		if int(b[1]) <= 0:
			b[0] = ""
	sim.emit(["potion", h.slot, id])
	sim.emit(["snd", def.get("sound", "potion"), 0.9])


## The shop is open at the campfire, by the Hearth, and at the Alchemist's
## door once it is built.
static func can_shop(sim: Sim, h: HeroState) -> bool:
	return sim.director.phase == Director.Phase.CAMP or near_shop(h.pos, sim.town)


static func near_shop(p: Vector2, town: Dictionary) -> bool:
	return p.distance_to(MapData.HEARTH) < 340.0 \
		or (TownDefs.level(town, "alchemist") > 0 and p.distance_to(TownDefs.door("alchemist")) < TownDefs.BUILD_R)


static func buy(sim: Sim, h: HeroState, id: String) -> void:
	if not PotionDefs.POTIONS.has(id) or not can_shop(sim, h):
		return
	var price := TownDefs.potion_price(sim.town, id)
	if h.gold < price:
		sim.emit(["denied", h.slot])
		return
	if give_potion(sim, h, id):
		h.gold -= price
		sim.emit(["snd", "coin", 0.8])
		sim.emit(["buy", h.slot, id, price])


static func learn(sim: Sim, h: HeroState, slot: int) -> void:
	if slot < 0 or slot > 3 or h.points <= 0:
		return
	var rank: int = h.ranks[slot]
	if rank >= HeroClasses.max_rank(slot) or h.level < HeroClasses.rank_level(slot, rank):
		return
	h.ranks[slot] = rank + 1
	h.points -= 1
	sim.emit(["learn", h.slot, slot])


static func pick_talent(sim: Sim, h: HeroState, row: int, choice: int) -> void:
	if row < 0 or row >= HeroClasses.TALENT_LEVELS.size() or h.level < HeroClasses.TALENT_LEVELS[row]:
		return
	if h.talents[row] != "":
		return
	var rows: Array = HeroClasses.get_def(h.cls)["talents"]
	if choice < 0 or choice >= (rows[row] as Array).size():
		return
	h.talents[row] = rows[row][choice]["id"]
	h.recompute()
	if h.fx("ward") > 0.0:
		h.ward = h.fx("ward") * h.max_hp()
	sim.emit(["talent", h.slot, row, h.talents[row]])
	sim.emit(["snd", "achievement", 0.8])
