class_name Sim
extends RefCounted
## The game as the host runs it: mobs, damage, the Hearth, the waves. Only
## the host has one. Every tick it fills `events` (what happened, for every
## screen to show) and the snapshot the clients draw the mobs from.
##
## Mob brains follow the AI study's order (start simple, fun first):
##   - March down the corridor on one shared flow field.
##   - Aggro the nearest hero in range, with a leash (distance and time) so
##     nothing chases forever, then march again.
##   - Attack tokens: only TOKENS_MELEE mobs swing at one hero at a time;
##     the rest circle the hero at the "hate ring" and keep moving, so a
##     horde surrounds you and it reads as a horde, without a hundred hits
##     landing in one frame. Ranged mobs hold a ring and back off.
##   - Separation and ±10% speed, so a wave spills through a gate.
##   - Reaction jitter (0.15-0.35 s) so a crowd doesn't turn as one.
## Elites and bosses get their own brains (Brains).

const DT := 1.0 / 30.0
const GRID := 72.0
const TOKENS_MELEE := 6
const TOKENS_RANGED := 4
const HEARTH_HP := 6500.0
const HEARTH_R := 120.0
## Mobs below this share of HP die to any hit (the "execute" everyone has,
## so the last sliver never needs another swing). Talents raise it.
const EXECUTE_BASE := 0.08
const ELITE_HP := 4.5
const ELITE_ATK := 1.4

var map: MapData
var rng := RandomNumberGenerator.new()
var time := 0.0
var tick := 0
var mobs: Array = []
var by_id := {}
var next_id := 1
var heroes := {}
var projectiles: Array = []
var zones: Array = []
var later: Array = []
var events: Array = []
var hearth_hp := HEARTH_HP
var hearth_max := HEARTH_HP
var director: Director
var grid := {}
var used_tokens := {}
var freeze_all_t := 0.0
var players := 1
var over := ""
var next_zone := 1
## Kills in the last moment, per hero, for the multikill banners.
var multikill := {}


func _init(seed_value: int, slots: Dictionary, shared_map: MapData = null) -> void:
	rng.seed = seed_value
	map = shared_map if shared_map != null else MapData.new()
	for slot: int in slots:
		var p: Dictionary = slots[slot]
		var h := HeroState.new()
		h.slot = slot
		h.peer = p.get("peer", 1)
		h.name = p.get("name", "Hero")
		h.cls = p.get("cls", "fighter")
		h.pos = MapData.hero_start(slot)
		h.recompute()
		h.hp = h.max_hp()
		h.tumble_charges = 1
		heroes[slot] = h
	players = maxi(1, heroes.size())
	hearth_max = HEARTH_HP * (1.0 + 0.5 * (players - 1))
	hearth_hp = hearth_max
	director = Director.new(self)


# --- The tick -------------------------------------------------------------

func step() -> void:
	time += DT
	tick += 1
	if over != "":
		return
	director.step(DT)
	_step_heroes()
	_build_grid()
	freeze_all_t = maxf(0.0, freeze_all_t - DT)
	for m: Mob in mobs:
		if m.alive():
			_step_mob(m)
	_separate()
	Skills.step_projectiles(self)
	_step_zones()
	_step_later()
	if tick % 60 == 0:
		_audit_tokens()
	_reap()
	_step_multikills()
	if hearth_hp <= 0.0 and over == "":
		over = "defeat"
		emit(["banner", "The Hearth is out", "The Town has fallen.", Color("b9b0c9")])
		emit(["snd", "gameover", 1.0])


func emit(e: Array) -> void:
	events.append(e)


func take_events() -> Array:
	var out := events
	events = []
	return out


## Runs `fn` after `delay` seconds of sim time.
func after(delay: float, fn: Callable) -> void:
	later.append([time + delay, fn])


func _step_later() -> void:
	var due: Array = []
	var keep: Array = []
	for l: Array in later:
		if time >= float(l[0]):
			due.append(l)
		else:
			keep.append(l)
	later = keep
	for l: Array in due:
		(l[1] as Callable).call()


# --- Spawning -------------------------------------------------------------

func spawn(kind: String, at: Vector2, lane: int, hp_mult := 1.0, atk_mult := 1.0) -> Mob:
	var m := Mob.new()
	m.id = next_id
	next_id = next_id % 65000 + 1
	m.kind = kind
	m.kidx = MobDefs.index_of(kind)
	m.rank = MobDefs.rank_of(kind)
	m.def = MobDefs.get_def(kind)
	m.lane = lane
	m.pos = map.nearest_open(at + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)))
	m.radius = MobDefs.radius(kind)
	m.var_speed = rng.randf_range(0.9, 1.1)
	m.speed = float(m.def.get("speed", 150.0)) * m.var_speed
	var hp := float(m.def["hp"])
	var atk := float(m.def["atk"])
	match m.rank:
		"mob":
			hp *= MobDefs.HP_MULT
			atk *= MobDefs.ATK_MULT
		"elite":
			hp *= MobDefs.HP_MULT * ELITE_HP
			atk *= MobDefs.ATK_MULT * ELITE_ATK
		"boss":
			hp *= 1.0 + 0.75 * (players - 1)
	m.max_hp = hp * hp_mult
	m.hp = m.max_hp
	m.atk = atk * atk_mult
	m.interval = float(m.def["interval"])
	m.phys = MobDefs.resist(kind, "phys")
	m.mag = MobDefs.resist(kind, "mag")
	m.xp = float(m.def.get("xp", 3))
	m.gold = 1 + int(m.xp / 4.0)
	m.orbit = 1.0 if rng.randf() < 0.5 else -1.0
	m.think_t = rng.randf_range(0.0, 0.3)
	m.atk_cd = rng.randf_range(0.2, m.interval)
	if m.rank != "mob":
		Brains.setup(self, m)
	mobs.append(m)
	by_id[m.id] = m
	return m


# --- Heroes ---------------------------------------------------------------

func _step_heroes() -> void:
	for h: HeroState in heroes.values():
		if not h.alive:
			h.respawn_t -= DT
			if h.respawn_t <= 0.0:
				h.alive = true
				h.hp = h.max_hp()
				h.pos = MapData.hero_start(h.slot)
				h.untouchable_t = 2.0
				emit(["respawn", h.slot, h.pos.x, h.pos.y])
				emit(["snd", "door", 0.8])
			continue
		for i in 4:
			h.cds[i] = maxf(0.0, h.cds[i] - DT)
		h.stun_t = maxf(0.0, h.stun_t - DT)
		h.root_t = maxf(0.0, h.root_t - DT)
		h.slow_t = maxf(0.0, h.slow_t - DT)
		h.untouchable_t = maxf(0.0, h.untouchable_t - DT)
		h.bloodlust_t = maxf(0.0, h.bloodlust_t - DT)
		h.aegis_t = maxf(0.0, h.aegis_t - DT)
		h.surge_t = maxf(0.0, h.surge_t - DT)
		h.echo_t = maxf(0.0, h.echo_t - DT)
		h.second_wind_cd = maxf(0.0, h.second_wind_cd - DT)
		h.hurt_t = maxf(0.0, h.hurt_t - DT)
		if h.headsman_t > 0.0:
			h.headsman_t -= DT
			if h.fx("avatar") > 0.0:
				h.avatar_t -= DT
				if h.avatar_t <= 0.0:
					h.avatar_t = 1.5
					Skills.whirlwind(self, h, maxi(1, h.ranks[0]))
		if h.rampage_t > 0.0:
			h.rampage_t -= DT
			if h.rampage_t <= 0.0:
				h.rampage = 0
		if h.flow > 0 and not (h.moving and h.fx("eternal_flow") > 0.0):
			h.flow_t -= DT
			if h.flow_t <= 0.0:
				h.flow = 0
		var regen: float = h.stats["regen"]
		if h.regen_burst_t > 0.0:
			h.regen_burst_t -= DT
			regen += h.regen_burst
		if h.poison_t > 0.0:
			h.poison_t -= DT
			regen -= h.poison_dps
		if h.burn_t > 0.0:
			h.burn_t -= DT
			regen -= h.burn_dps
		h.hp = minf(h.max_hp(), h.hp + regen * DT)
		if h.hp <= 0.0:
			_kill_hero(h)
			continue
		var ward_max := h.fx("ward") * h.max_hp()
		if ward_max > 0.0:
			h.ward_idle += DT
			if h.ward_idle > 8.0:
				h.ward = ward_max


## Gold per kill grows 70% a chapter (it was 100%): late chapters still pay
## more, but no longer enough to buy every potion on the shelf.
func gold_mult() -> float:
	return 1.0 + 0.7 * director.chapter


## Calling a wave early pays every hero for the seconds skipped.
const RUSH_GOLD_PER_S := 2.0


func rush_gold(seconds: float) -> int:
	var g := roundi(seconds * RUSH_GOLD_PER_S * gold_mult())
	if g <= 0:
		return 0
	for h: HeroState in heroes.values():
		h.gold += g
	emit(["rush", g])
	emit(["snd", "coin", 0.9])
	return g


func give_xp(amount: float, whole := false) -> void:
	# Every hero shares every kill, divided by the players: each corridor
	# feeds its own hero, and nobody falls behind for being far away. A
	# world boss (one for everyone) gives each hero its whole XP.
	var each := amount if whole else amount / players
	for h: HeroState in heroes.values():
		h.xp += each
		while h.level < HeroClasses.MAX_LEVEL and h.xp >= HeroClasses.xp_to_next(h.level):
			h.xp -= HeroClasses.xp_to_next(h.level)
			h.level += 1
			h.points += 1
			h.recompute()
			h.hp = minf(h.max_hp(), h.hp + h.max_hp() * 0.25)
			emit(["lvl", h.slot, h.level])


func damage_hero(h: HeroState, amount: float, src: Mob = null, kind := "hit") -> void:
	if not h.targetable() or h.aegis_t > 0.0:
		return
	if kind == "hit" and rng.randf() < float(h.stats["dodge"]):
		emit(["dodge", h.slot])
		if h.fx("dodge_flow") > 0.0:
			add_flow(h, int(h.fx("dodge_flow")))
		return
	var armor: float = h.stats["armor"]
	var dmg := amount / (1.0 + 0.06 * armor)
	if h.fx("hold_line") > 0.0 and count_near(h.pos, 160.0) >= 5:
		dmg *= 1.0 - h.fx("hold_line")
	if src != null and h.fx("thorns") > 0.0 and src.alive() and src.pos.distance_to(h.pos) < 140.0:
		damage_mob(src, amount * h.fx("thorns"), "phys", h.slot, {"thorns": true})
	h.ward_idle = 0.0
	if h.ward > 0.0:
		var soak := minf(h.ward, dmg)
		h.ward -= soak
		dmg -= soak
	h.hp -= dmg
	h.hurt_t = 0.2
	emit(["hhit", h.slot, roundi(dmg)])
	if h.hp < h.max_hp() * 0.3 and h.fx("second_wind") > 0.0 and h.second_wind_cd <= 0.0:
		h.second_wind_cd = 40.0
		h.regen_burst_t = 3.0
		h.regen_burst = h.max_hp() * h.fx("second_wind") / 3.0
		emit(["fx", "second_wind", h.pos.x, h.pos.y, h.slot])
		emit(["snd", "heal", 0.9])
	if h.hp <= 0.0:
		_kill_hero(h)


func heal_hero(h: HeroState, amount: float) -> void:
	if not h.alive or amount <= 0.0:
		return
	h.hp = minf(h.max_hp(), h.hp + amount)


func _kill_hero(h: HeroState) -> void:
	h.alive = false
	h.hp = 0.0
	h.deaths += 1
	h.respawn_t = Tuning.hero_respawn() + director.chapter * 1.5
	h.flow = 0
	_release_tokens_for(h.slot)
	emit(["hdie", h.slot, h.pos.x, h.pos.y])
	emit(["snd", "hero_death", 1.0])


func add_flow(h: HeroState, n: int) -> void:
	if h.cls != "flow":
		return
	var most := 20 + int(h.fx("flow_max"))
	h.flow = mini(most, h.flow + n)
	h.flow_t = 2.5 + h.fx("flow_time")


## Heroes still standing, for the mobs to pick from.
func living_heroes() -> Array:
	var out: Array = []
	for h: HeroState in heroes.values():
		if h.targetable():
			out.append(h)
	return out


func nearest_hero(p: Vector2, within: float) -> HeroState:
	var best: HeroState = null
	var bd := within
	for h: HeroState in heroes.values():
		if not h.targetable():
			continue
		var d := p.distance_to(h.pos)
		if d < bd:
			bd = d
			best = h
	return best


# --- Damage to mobs -------------------------------------------------------

## The one way mobs are hurt. `kind` is "phys", "mag" or "pure" (burns,
## poisons, potions). `opts`: crit, spell, aoe, thorns, no_exec. Returns
## the damage dealt.
func damage_mob(m: Mob, amount: float, kind: String, src: int, opts := {}) -> float:
	if not m.alive() or m.untargetable:
		return 0.0
	var h: HeroState = heroes.get(src)
	var mult := 1.0
	if kind == "phys":
		mult *= m.phys
	elif kind == "mag":
		mult *= m.mag
	if m.immune != "" and m.immune == kind:
		mult *= 0.15
	if m.sunder_t > 0.0:
		mult *= 1.0 + m.sunder
	if m.mark_t > 0.0:
		mult *= 1.0 + m.mark
	if m.freeze_t > 0.0 and h != null and h.fx("deep_freeze") > 0.0:
		mult *= 1.5
	if m.blind_t > 0.0:
		mult *= 1.0 + _smoke_amp()
	for other: HeroState in heroes.values():
		if other.fx("aura") > 0.0:
			mult *= 1.0 + other.fx("aura")
	if h != null:
		if h.surge_t > 0.0:
			mult *= 2.0
		if opts.get("spell", false):
			mult *= float(h.stats["spell"])
		if m.full and h.fx("first_blood") > 0.0:
			mult *= 1.0 + h.fx("first_blood")
	var dmg := amount * mult
	m.full = false
	m.hp -= dmg
	m.flash_t = Tuning.flash() + 0.04
	if src >= 0:
		m.threat[src] = float(m.threat.get(src, 0.0)) + dmg
		_provoke(m, src)
		if h != null:
			h.damage_done += dmg
			var ls: float = float(h.stats["lifesteal"]) + (h.bloodlust * 0.5 if h.bloodlust_t > 0.0 else 0.0)
			if ls > 0.0:
				heal_hero(h, dmg * ls * (0.35 if opts.get("aoe", false) else 1.0))
	var flags := 0
	if opts.get("crit", false):
		flags |= 1
	if kind == "mag":
		flags |= 2
	if kind == "pure":
		flags |= 4
	if mult > 1.2:
		flags |= 8
	elif mult < 0.8:
		flags |= 16
	# Executes: the sliver dies at once, with its own flourish.
	var exec_at := _execute_at(m, h, opts)
	if m.hp > 0.0 and m.hp < m.max_hp * exec_at and not opts.get("no_exec", false):
		dmg += m.hp
		m.hp = 0.0
		flags |= 32
	emit(["hit", m.id, roundi(dmg), flags, src])
	if m.hp <= 0.0:
		_kill_mob(m, src, flags, opts)
		if (flags & 32) != 0 and h != null and h.fx("exec_burst") > 0.0:
			Skills.exec_burst(self, h, m.pos)
	return dmg


func _execute_at(m: Mob, h: HeroState, opts: Dictionary) -> float:
	if m.rank == "boss":
		return 0.0
	var at := EXECUTE_BASE if m.rank == "mob" else 0.0
	if h != null:
		if m.rank == "mob":
			at = maxf(at, h.fx("execute"))
			if h.headsman_t > 0.0:
				at = maxf(at, 0.3)
			if opts.get("crit", false) and h.fx("crit_execute") > 0.0:
				at = maxf(at, h.fx("crit_execute"))
			if opts.get("headshot", false):
				at = maxf(at, 0.3)
		elif m.rank == "elite" and h.fx("execute") > 0.0:
			at = 0.06
	return at


func _smoke_amp() -> float:
	var best := 0.0
	for h: HeroState in heroes.values():
		best = maxf(best, h.fx("smoke_amp"))
	return best


func _kill_mob(m: Mob, src: int, flags: int, opts: Dictionary) -> void:
	m.state = Mob.State.DEAD
	m.token = false
	var h: HeroState = heroes.get(src)
	var big: bool = m.rank != "mob" or opts.get("aoe", false) or (flags & 32) != 0
	var away := Vector2.ZERO
	if h != null:
		away = (m.pos - h.pos).normalized()
	emit(["die", m.id, m.pos.x, m.pos.y, m.kidx, flags | (64 if big else 0), away.x, away.y, src])
	var xp_mult := 2.4 + 0.65 * director.chapter
	give_xp(m.xp * xp_mult, m.rank == "boss")
	var g := roundi(m.gold * gold_mult())
	if m.def.get("trait", "") == "gold":
		g *= 5
		emit(["snd", "coin", 0.8])
	for other: HeroState in heroes.values():
		var share := g if other.slot == src else int(ceil(g * 0.3))
		if other.slot == src and other.fx("gold_pct") > 0.0:
			share = int(share * (1.0 + other.fx("gold_pct")))
		other.gold += share
	if h != null:
		h.kills += 1
		multikill[src] = int(multikill.get(src, 0)) + 1
		multikill["t%d" % src] = time
		Skills.on_kill(self, h, m)
	if m.burn_t > 0.0 and m.burn_src >= 0:
		var bh: HeroState = heroes.get(m.burn_src)
		if bh != null and bh.fx("wildfire") > 0.0:
			for o: Mob in mobs_near(m.pos, 140.0):
				if o != m:
					burn(o, m.burn_dps, 3.0, m.burn_src)
			emit(["boom", "fire", m.pos.x, m.pos.y, 140.0])
	if m.def.get("trait", "") == "split":
		for i in 2:
			spawn("spawnling", m.pos, m.lane, director.hp_mult() * 0.8, director.atk_mult())
	_drop_loot(m, h)
	if m.rank != "mob":
		Brains.on_death(self, m)


func _drop_loot(m: Mob, h: HeroState) -> void:
	var chance := 0.0
	match m.rank:
		"elite":
			chance = 1.0
		"boss":
			chance = 1.0
		_:
			chance = 0.004
	if h != null and h.fx("potion_luck") > 0.0:
		chance *= 2.0
	if rng.randf() >= chance:
		return
	var n := 3 if m.rank == "boss" else 1
	for i in n:
		var who: HeroState = h
		if who == null or m.rank == "boss":
			who = heroes.values()[rng.randi() % heroes.size()]
		Skills.give_potion(self, who, PotionDefs.roll(rng, m.rank))


func _step_multikills() -> void:
	for h: HeroState in heroes.values():
		var n := int(multikill.get(h.slot, 0))
		if n > 0 and time - float(multikill.get("t%d" % h.slot, 0.0)) > 0.6:
			if n >= 4:
				emit(["multi", h.slot, n])
			multikill[h.slot] = 0


func burn(m: Mob, dps: float, dur: float, src: int) -> void:
	m.burn_t = maxf(m.burn_t, dur)
	m.burn_dps = maxf(m.burn_dps, dps)
	m.burn_src = src


func slow_mob(m: Mob, amount: float, dur: float) -> void:
	if m.rank == "boss":
		amount *= 0.5
	m.slow = maxf(m.slow if m.slow_t > 0.0 else 0.0, amount)
	m.slow_t = maxf(m.slow_t, dur)


func stun_mob(m: Mob, dur: float) -> void:
	if m.rank == "boss":
		dur *= 0.3
	elif m.rank == "elite":
		dur *= 0.6
	m.stun_t = maxf(m.stun_t, dur)
	m.wind = 0.0


func push_mob(m: Mob, dir: Vector2, force: float) -> void:
	if m.rank == "boss":
		return
	if m.rank == "elite":
		force *= 0.3
	m.knock += dir * force


# --- Space ----------------------------------------------------------------

func _build_grid() -> void:
	grid.clear()
	for m: Mob in mobs:
		if not m.alive():
			continue
		var k := Vector2i(int(m.pos.x / GRID), int(m.pos.y / GRID))
		if grid.has(k):
			(grid[k] as Array).append(m)
		else:
			grid[k] = [m]


## Living, targetable mobs within `r` of `p`.
func mobs_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	var lo := Vector2i(int((p.x - r) / GRID), int((p.y - r) / GRID))
	var hi := Vector2i(int((p.x + r) / GRID), int((p.y + r) / GRID))
	for gx in range(lo.x, hi.x + 1):
		for gy in range(lo.y, hi.y + 1):
			var cell: Array = grid.get(Vector2i(gx, gy), [])
			for m: Mob in cell:
				if m.alive() and not m.untargetable and m.pos.distance_squared_to(p) <= (r + m.radius) * (r + m.radius):
					out.append(m)
	return out


func count_near(p: Vector2, r: float) -> int:
	return mobs_near(p, r).size()


func nearest_mob(p: Vector2, r: float) -> Mob:
	var best: Mob = null
	var bd := INF
	for m: Mob in mobs_near(p, r):
		var d := m.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = m
	return best


## Mobs along a line from `a` to `b`, `half` wide on each side.
func mobs_on_line(a: Vector2, b: Vector2, half: float) -> Array:
	var out: Array = []
	var mid := (a + b) * 0.5
	for m: Mob in mobs_near(mid, a.distance_to(b) * 0.5 + half):
		if MapData._seg_dist(m.pos, a, b) <= half + m.radius:
			out.append(m)
	return out


func _separate() -> void:
	for m: Mob in mobs:
		if not m.alive() or m.state == Mob.State.BURROWED:
			continue
		var push := Vector2.ZERO
		var k := Vector2i(int(m.pos.x / GRID), int(m.pos.y / GRID))
		for gx in range(k.x - 1, k.x + 2):
			for gy in range(k.y - 1, k.y + 2):
				for o: Mob in grid.get(Vector2i(gx, gy), []):
					if o == m or not o.alive():
						continue
					var d := m.pos - o.pos
					var want := (m.radius + o.radius) * 0.85
					var l2 := d.length_squared()
					if l2 < want * want and l2 > 0.01:
						var l := sqrt(l2)
						# The bigger one barely moves.
						var share := o.radius / (m.radius + o.radius)
						push += d / l * (want - l) * share
		for h: HeroState in heroes.values():
			if not h.alive:
				continue
			var d := m.pos - h.pos
			var want := m.radius + 16.0
			if d.length_squared() < want * want and d.length_squared() > 0.01:
				# Heroes wade through: mobs give way (collision "soft").
				push += d.normalized() * (want - d.length()) * (0.2 if m.rank == "boss" else 0.7)
		if push != Vector2.ZERO:
			m.pos = map.slide(m.pos, push.limit_length(12.0))


# --- Mob brains ---------------------------------------------------------------

func _step_mob(m: Mob) -> void:
	m.flash_t = maxf(0.0, m.flash_t - DT)
	m.slow_t = maxf(0.0, m.slow_t - DT)
	m.sunder_t = maxf(0.0, m.sunder_t - DT)
	m.mark_t = maxf(0.0, m.mark_t - DT)
	m.blind_t = maxf(0.0, m.blind_t - DT)
	m.trait_cd = maxf(0.0, m.trait_cd - DT)
	if m.rank == "mob" and m.brain.has("war_cry_t"):
		m.brain["war_cry_t"] = float(m.brain["war_cry_t"]) - DT
		if float(m.brain["war_cry_t"]) <= 0.0:
			m.brain.erase("war_cry_t")
	if m.burn_t > 0.0:
		m.burn_t -= DT
		if tick % 10 == 0:
			damage_mob(m, m.burn_dps / 3.0, "pure", m.burn_src, {"no_exec": false, "aoe": true})
			if not m.alive():
				return
	if m.poison_t > 0.0:
		m.poison_t -= DT
		if tick % 10 == 5:
			damage_mob(m, m.poison_dps / 3.0, "pure", m.poison_src, {"aoe": true})
			if not m.alive():
				return
		if m.poison_t <= 0.0:
			m.poison_dps = 0.0
	if m.knock.length_squared() > 1.0:
		m.pos = map.slide(m.pos, m.knock * DT)
		m.knock *= 0.82
	if m.stun_t > 0.0:
		m.stun_t -= DT
		return
	if m.freeze_t > 0.0:
		m.freeze_t -= DT
		return
	if freeze_all_t > 0.0 and m.rank != "boss":
		return
	if m.rank != "mob":
		if Brains.step(self, m):
			return
	match m.state:
		Mob.State.MARCH:
			_march(m)
		Mob.State.CHASE:
			_chase(m)
		Mob.State.HEARTH:
			_at_hearth(m)
		Mob.State.CHARGE_WIND:
			m.charge_t -= DT
			if m.charge_t <= 0.0:
				m.state = Mob.State.CHARGING
				m.charge_t = 0.55
				m.charge_hit = {}
		Mob.State.CHARGING:
			_charging(m)


func _think(m: Mob) -> bool:
	m.think_t -= DT
	if m.think_t > 0.0:
		return false
	m.think_t = rng.randf_range(0.15, 0.35)
	return true


## Elites and bosses look this far for a hero, and follow 2.2 times as far.
const BIG_AGGRO := 620.0
## A hit holds a mob on the hero who landed it for this long, wherever they go.
const PROVOKE_TIME := 3.0
## Hitting a marching mob also turns the marching mobs this close to it.
const PACK_CALL := 140.0
## How far melee mobs notice and follow a hero: a typical ranged mob's 280 reach + 20%.
const MELEE_THREAT := 340.0


## How close a hero must be for a mob to notice it, and how far the mob
## follows before it gives up and goes for the Hearth. Tied to the mob's own
## reach: 20% past it for ranged mobs. Melee mobs get the same distance a
## typical ranged mob has (MELEE_THREAT), since twice a bite is too short to kite. A hero who stays out of that, or runs, leaves the
## mob to the Hearth. Hitting a mob pulls it back (PROVOKE_TIME).
func _threat_range(m: Mob) -> float:
	if m.rank != "mob":
		return BIG_AGGRO
	match str(m.def.get("ai", "fodder")):
		"ranged":
			return float(m.def.get("reach", 280.0)) * 1.2
		"charger":
			return 460.0
	return MELEE_THREAT


func _leash(m: Mob) -> float:
	return BIG_AGGRO * 2.2 if m.rank != "mob" else _threat_range(m)


## A hero's hit turns a marching (or Hearth-bashing) mob on them, and keeps
## one already on them from wandering off.
func _provoke(m: Mob, slot: int) -> void:
	if m.rank != "mob" or not m.alive():
		return
	var h: HeroState = heroes.get(slot)
	if h == null or not h.targetable():
		return
	if m.state == Mob.State.CHASE and m.target == slot:
		m.provoke_t = PROVOKE_TIME
		return
	if m.state == Mob.State.MARCH or m.state == Mob.State.HEARTH or (m.state == Mob.State.CHASE and not m.token):
		_turn_on(m, slot)
		# The pack turns with it: marching mobs close by come too.
		for o: Mob in mobs_near(m.pos, PACK_CALL):
			if o != m and o.rank == "mob" and o.alive() and o.state == Mob.State.MARCH:
				_turn_on(o, slot)


func _turn_on(m: Mob, slot: int) -> void:
	_release(m)
	m.state = Mob.State.CHASE
	m.target = slot
	m.chase_t = 0.0
	m.provoke_t = PROVOKE_TIME


func _march(m: Mob) -> void:
	if _think(m):
		var h := nearest_hero(m.pos, _threat_range(m))
		if h != null and map.line_open(m.pos, h.pos):
			m.state = Mob.State.CHASE
			m.target = h.slot
			m.chase_t = 0.0
			return
		if m.pos.distance_to(MapData.HEARTH) < HEARTH_R + m.radius + 30.0:
			m.state = Mob.State.HEARTH
			return
	var dir := map.flow_at(m.pos)
	if dir == Vector2.ZERO:
		dir = (MapData.HEARTH - m.pos).normalized()
	_move(m, dir, 1.0)


func _move(m: Mob, dir: Vector2, mult: float) -> void:
	if float(m.brain.get("war_cry_t", 0.0)) > 0.0:
		mult *= 1.35
	m.vel = dir * m.speed * mult * m.slow_mult()
	if absf(m.vel.x) > 4.0:
		m.flip = m.vel.x > 0.0
	m.pos = map.slide(m.pos, m.vel * DT)


func _release(m: Mob) -> void:
	if m.token:
		var key := "%d%s" % [m.target, "r" if m.def.get("ai", "") == "ranged" else "m"]
		used_tokens[key] = maxi(0, int(used_tokens.get(key, 0)) - 1)
	m.token = false


func _claim(m: Mob) -> bool:
	if m.token:
		return true
	if m.rank != "mob":
		m.token = true
		return true
	var ranged: bool = m.def.get("ai", "") == "ranged"
	var key := "%d%s" % [m.target, "r" if ranged else "m"]
	var cap := TOKENS_RANGED if ranged else TOKENS_MELEE
	# The horde chapters press harder: more mobs may swing at once.
	cap += director.chapter
	if int(used_tokens.get(key, 0)) >= cap:
		return false
	used_tokens[key] = int(used_tokens.get(key, 0)) + 1
	m.token = true
	return true


func _release_tokens_for(slot: int) -> void:
	for m: Mob in mobs:
		if m.target == slot and m.alive():
			m.token = false
			m.state = Mob.State.MARCH
			m.target = -1
	used_tokens.erase("%dm" % slot)
	used_tokens.erase("%dr" % slot)


## Every 2 s, count the tokens again from who really holds one: the dead and
## the stuck don't keep theirs.
func _audit_tokens() -> void:
	used_tokens.clear()
	for m: Mob in mobs:
		if m.alive() and m.token and m.state == Mob.State.CHASE:
			var key := "%d%s" % [m.target, "r" if m.def.get("ai", "") == "ranged" else "m"]
			used_tokens[key] = int(used_tokens.get(key, 0)) + 1
		elif m.token:
			m.token = false


func _chase(m: Mob) -> void:
	var h: HeroState = heroes.get(m.target)
	m.chase_t += DT
	m.provoke_t -= DT
	var leashed := m.provoke_t <= 0.0 and h != null and m.pos.distance_to(h.pos) > _leash(m)
	if h == null or not h.targetable() or leashed or (m.chase_t > 7.0 and not m.token and m.provoke_t <= 0.0):
		_release(m)
		m.state = Mob.State.MARCH
		m.target = -1
		return
	# Commitment: re-pick a closer hero only now and then.
	if _think(m) and m.rank == "mob" and not m.token:
		var other := nearest_hero(m.pos, m.pos.distance_to(h.pos) * 0.6)
		if other != null and other != h:
			_release(m)
			m.target = other.slot
			h = other
	var to := h.pos - m.pos
	var d := to.length()
	var dir := to / maxf(d, 0.01)
	if absf(to.x) > 3.0:
		m.flip = to.x > 0.0
	m.atk_cd -= DT
	if m.wind > 0.0:
		m.wind -= DT
		if m.wind <= 0.0:
			_land_attack(m, h)
		return
	var ai: String = m.def.get("ai", "fodder")
	if ai == "ranged":
		var reach: float = m.def.get("reach", 280.0)
		if d > reach:
			_move(m, _steer(m, dir), 1.0)
		elif d < reach * 0.5:
			# Too close: back off, keeping the shot (kiting).
			_move(m, _steer(m, -dir), 0.8)
		elif not m.token:
			_move(m, dir.orthogonal() * m.orbit, 0.35)
		if d <= reach + 20.0 and m.atk_cd <= 0.0 and _claim(m):
			_start_attack(m)
		return
	if ai == "charger" and m.trait_cd <= 0.0 and d > 140.0 and d < 420.0:
		m.trait_cd = 6.0
		m.state = Mob.State.CHARGE_WIND
		m.charge_t = 0.75
		m.charge_dir = dir
		emit(["tele", "line", m.pos.x, m.pos.y, 520.0, dir.angle(), 0.75, 34.0])
		emit(["snd", "windup", 0.5])
		return
	var reach_melee := m.radius + 18.0 + 22.0
	var ring := m.radius + 70.0 + 30.0 * float(m.id % 3)
	if d > ring:
		_move(m, _steer(m, dir), 1.0)
		return
	if not _claim(m):
		# No token: circle at the hate ring, never standing still.
		var tangent := dir.orthogonal() * m.orbit
		var keep := (d - ring) * 0.02
		_move(m, (tangent + dir * keep).normalized(), 0.45)
		if m.chase_t > 3.0 and rng.randf() < 0.01:
			m.orbit = -m.orbit
		return
	if d > reach_melee:
		_move(m, _steer(m, dir), 1.0)
	elif m.atk_cd <= 0.0:
		_start_attack(m)


## Straight at it if the way is open; down the corridor's flow otherwise.
func _steer(m: Mob, dir: Vector2) -> Vector2:
	if map.is_open(m.pos + dir * 30.0):
		return dir
	var f := map.flow_at(m.pos)
	return (dir + f).normalized() if f != Vector2.ZERO else dir


func _start_attack(m: Mob) -> void:
	m.wind_len = 0.35 if m.rank == "mob" else 0.55
	if m.def.get("ai", "") == "ranged":
		m.wind_len = EnemyMissile.WIND_UP + 0.1
	m.wind = m.wind_len
	m.atk_cd = m.interval


func _land_attack(m: Mob, h: HeroState) -> void:
	if not h.targetable():
		return
	var mult := 1.0
	if m.brain.get("war_cry_t", 0.0) > 0.0 or m.enraged:
		mult = 1.5
	if m.blind_t > 0.0 and rng.randf() < 0.6:
		emit(["miss", m.id])
		return
	if m.def.get("ai", "") == "ranged":
		var kind: String = m.def.get("missile", "rock")
		var at := h.pos
		var flight := clampf(m.pos.distance_to(at) / 650.0, 0.25, 0.7)
		emit(["mmis", kind, m.pos.x, m.pos.y - 24.0, at.x, at.y - 20.0, flight])
		var dmg := m.atk * mult
		var tr: String = m.def.get("trait", "")
		after(flight, func() -> void:
			for hh: HeroState in heroes.values():
				if hh.targetable() and hh.pos.distance_to(at) < 58.0:
					damage_hero(hh, dmg, null)
					_trait_hit(tr, hh, m)
					break)
		return
	if m.pos.distance_to(h.pos) > m.radius + 16.0 + 60.0:
		return
	damage_hero(h, m.atk * mult, m)
	_trait_hit(m.def.get("trait", ""), h, m)
	if m.kind == "fallen_angel":
		emit(["push", h.slot, (h.pos - m.pos).normalized().x * 160.0, (h.pos - m.pos).normalized().y * 160.0])


func _trait_hit(tr: String, h: HeroState, m: Mob) -> void:
	match tr:
		"slow":
			h.slow = 0.35
			h.slow_t = 1.5
		"hex":
			h.slow = 0.25
			h.slow_t = 2.0
		"root":
			if m.trait_cd <= 0.0:
				m.trait_cd = 5.0
				h.root_t = 0.7
				emit(["fx", "root", h.pos.x, h.pos.y, h.slot])
		"poison":
			h.poison_t = 4.0
			h.poison_dps = minf(h.poison_dps + m.atk * 0.25, m.atk * 1.0)
		"burn":
			h.burn_t = 2.0
			h.burn_dps = m.atk * 0.4


func _at_hearth(m: Mob) -> void:
	if _think(m):
		var h := nearest_hero(m.pos, _threat_range(m))
		if h != null:
			m.state = Mob.State.CHASE
			m.target = h.slot
			m.chase_t = 0.0
			return
	var d := m.pos.distance_to(MapData.HEARTH)
	if d > HEARTH_R + m.radius + 10.0:
		_move(m, (MapData.HEARTH - m.pos).normalized(), 1.0)
		return
	m.flip = MapData.HEARTH.x > m.pos.x
	m.atk_cd -= DT
	if m.wind > 0.0:
		m.wind -= DT
		if m.wind <= 0.0:
			var dmg := m.atk * (0.5 if m.rank == "boss" else 1.0)
			hearth_hp -= dmg
			emit(["hearth", roundi(dmg)])
		return
	if m.atk_cd <= 0.0:
		_start_attack(m)


func _charging(m: Mob) -> void:
	m.charge_t -= DT
	_move(m, m.charge_dir, 3.4)
	for h: HeroState in heroes.values():
		if h.targetable() and not m.charge_hit.has(h.slot) and h.pos.distance_to(m.pos) < m.radius + 26.0:
			m.charge_hit[h.slot] = true
			damage_hero(h, m.atk * 2.0, m)
			emit(["push", h.slot, m.charge_dir.x * 260.0, m.charge_dir.y * 260.0])
	if m.charge_t <= 0.0:
		m.state = Mob.State.CHASE if m.target >= 0 else Mob.State.MARCH
		m.stun_t = 0.6


func _reap() -> void:
	if tick % 15 != 0:
		return
	var keep: Array = []
	for m: Mob in mobs:
		if m.alive():
			keep.append(m)
		else:
			by_id.erase(m.id)
	mobs = keep


func living_count() -> int:
	var n := 0
	for m: Mob in mobs:
		if m.alive():
			n += 1
	return n


# --- Zones -----------------------------------------------------------------

## A lasting area: fire pool, smoke, web, poison, rain of arrows, lava.
## `on_tick(zone)` runs every 0.25 s while it lasts.
func add_zone(kind: String, at: Vector2, r: float, dur: float, data := {}) -> Dictionary:
	var z := {"id": next_zone, "kind": kind, "pos": at, "r": r, "t": dur, "data": data, "acc": 0.0}
	next_zone += 1
	zones.append(z)
	emit(["zone", z["id"], kind, at.x, at.y, r, dur])
	return z


func _step_zones() -> void:
	var keep: Array = []
	for z: Dictionary in zones:
		z["t"] = float(z["t"]) - DT
		z["acc"] = float(z["acc"]) + DT
		if float(z["acc"]) >= 0.25:
			z["acc"] = 0.0
			Skills.zone_tick(self, z)
		if float(z["t"]) > 0.0:
			keep.append(z)
		else:
			emit(["zone_end", z["id"]])
	zones = keep


# --- What the clients draw -------------------------------------------------

## The mobs, packed: 12 bytes each (see View.read_snapshot).
func pack_mobs() -> PackedByteArray:
	var buf := PackedByteArray()
	var n := 0
	for m: Mob in mobs:
		if m.alive():
			n += 1
	buf.resize(4 + n * 12)
	buf.encode_u32(0, n)
	var o := 4
	for m: Mob in mobs:
		if not m.alive():
			continue
		var flags := 0
		if m.flip: flags |= 1
		if m.flash_t > 0.0: flags |= 2
		if m.hidden: flags |= 4
		if m.enraged or m.brain.get("war_cry_t", 0.0) > 0.0: flags |= 8
		if m.wind > 0.0 or m.state == Mob.State.CHARGE_WIND: flags |= 16
		if m.state == Mob.State.CHARGING: flags |= 32
		if m.immune == "phys": flags |= 64
		if m.immune == "mag": flags |= 128
		var st := 0
		if m.freeze_t > 0.0 or freeze_all_t > 0.0 and m.rank != "boss": st |= 1
		if m.burn_t > 0.0: st |= 2
		if m.slow_t > 0.0: st |= 4
		if m.stun_t > 0.0: st |= 8
		if m.poison_t > 0.0: st |= 16
		if m.mark_t > 0.0: st |= 32
		if m.sunder_t > 0.0: st |= 64
		if m.blind_t > 0.0: st |= 128
		buf.encode_u16(o, m.id)
		buf.encode_u8(o + 2, m.kidx)
		buf.encode_u8(o + 3, flags)
		buf.encode_s16(o + 4, int(m.pos.x))
		buf.encode_s16(o + 6, int(m.pos.y))
		buf.encode_u8(o + 8, int(ceil(m.hp_frac() * 255.0)))
		var anim := 0
		if m.wind > 0.0:
			anim = int((1.0 - m.wind / m.wind_len) * 255.0)
		buf.encode_u8(o + 9, clampi(anim, 0, 255))
		buf.encode_u8(o + 10, st)
		buf.encode_u8(o + 11, m.brain.get("phase", 0))
		o += 12
	return buf


## Everything but the mobs, small: heroes, the Hearth, the wave.
func pack_state() -> Dictionary:
	var hs := {}
	for h: HeroState in heroes.values():
		hs[h.slot] = h.to_dict()
	var boss := {}
	for m: Mob in mobs:
		if m.alive() and m.rank == "boss":
			boss = {"id": m.id, "kind": m.kind, "hp": m.hp_frac(), "phase": m.brain.get("phase", 1),
				"enrage": m.brain.get("enrage_t", 0.0), "enraged": m.enraged}
	return {"heroes": hs, "hearth": hearth_hp, "hearth_max": hearth_max, "dir": director.view(), "boss": boss,
		"alive": living_count(), "over": over, "t": time}
