class_name Director
extends RefCounted
## Paces the waves. The AI study's director cycle, kept to pacing (never
## difficulty): Build Up (the wave spawns, in packs), Peak (it reaches the
## heroes), Relax (the gap, Tuning.wave_gap()). Between chapters, the Town's
## campfire: heal, refill, buy potions, relight the road fires (until the
## dark of Sim.dark_chapter takes them). Each open corridor gets the whole
## wave; a corridor with no player sends nothing.

enum Phase { INTRO, WAVE, GAP, CAMP, VICTORY }

const INTRO_TIME := 5.0
const CAMP_TIME := 25.0
## A wave counts as cleared at this share of its mobs left, or this long
## after its last spawn: leftovers carry into the next wave, and pile up.
const CLEAR_SHARE := 0.15
const CLEAR_WAIT := 35.0
const BOSS_ADDS_EVERY := 5.0
## The campfire mends every standing building by this share of its max.
## Ruins stay ruins until a hero pays to rebuild them.
const CAMP_REPAIR := 0.5

var sim: Sim
var phase := Phase.INTRO
var chapter := 0
var wave := 0
var t := INTRO_TIME
var queue: Array = []
var spawned := 0
var wave_total := 0
var since_last := 0.0
var boss_id := -1
var adds_t := 0.0
## Who has pressed Space to call the next wave early, by slot.
var calls := {}


func _init(s: Sim) -> void:
	sim = s
	_announce_chapter()


func lanes() -> Array:
	var out: Array = sim.heroes.keys()
	out.sort()
	return out


func hp_mult() -> float:
	return ChapterDefs.hp_mult(chapter, wave)


func atk_mult() -> float:
	return ChapterDefs.atk_mult(chapter, wave)


func step(dt: float) -> void:
	match phase:
		Phase.INTRO:
			t -= dt
			if t <= 0.0:
				_start_wave()
		Phase.WAVE:
			_step_wave(dt)
		Phase.GAP:
			t -= dt
			if t <= 0.0:
				_start_wave()
		Phase.CAMP:
			t -= dt
			if t <= 0.0:
				chapter += 1
				wave = 0
				calls.clear()
				phase = Phase.INTRO
				t = INTRO_TIME
				sim.rescale_fires()
				sim.rescale_town()
				_announce_chapter()
				if chapter == Sim.dark_chapter():
					# After the world's own banner: the dark takes the road.
					sim.after(3.2, sim.snuff_fires)


func _announce_chapter() -> void:
	var ch := ChapterDefs.get_def(chapter)
	sim.emit(["chapter", chapter])
	sim.emit(["banner", ch["world"], ch["subtitle"], ch["glow"]])
	sim.emit(["music", "music_" + ch["music"]])


func _start_wave() -> void:
	phase = Phase.WAVE
	calls.clear()
	queue.clear()
	spawned = 0
	since_last = 0.0
	var ch := ChapterDefs.get_def(chapter)
	var ls := lanes()
	sim.emit(["wave", chapter, wave])
	sim.emit(["snd", "boss" if wave == ChapterDefs.BOSS_WAVE else "dread", 0.8])
	var title := ChapterDefs.wave_title(chapter, wave)
	var sub := "Wave %d of %d" % [wave + 1, ChapterDefs.WAVES]
	if wave == ChapterDefs.HORDE_WAVE:
		sub = "They are all coming at once."
	sim.emit(["banner", title, sub, ch["glow"]])
	sim.emit(["music", "music_" + ch["music"] + ("_boss" if wave == ChapterDefs.BOSS_WAVE else "_tense")])
	if wave == ChapterDefs.BOSS_WAVE:
		var lane: int = ls[sim.rng.randi() % ls.size()]
		queue.append([1.5, ch["boss"], lane])
		adds_t = 6.0
		wave_total = 1
		return
	var n := ChapterDefs.wave_count(chapter, wave)
	var span := ChapterDefs.wave_span(wave)
	var roster: Dictionary = ch["roster"]
	if wave == 0:
		roster = {}
		for id: String in ch["opening"]:
			roster[id] = 1
	var tough: float = ChapterDefs.shape(wave)["tough"]
	var soft := _tier_roster(roster, true)
	var hard := _tier_roster(roster, false)
	for lane: int in ls:
		if wave == ChapterDefs.HORDE_WAVE:
			_horde(lane, n, soft, hard, tough)
			continue
		var at := 0.5
		var left := n
		while left > 0:
			# Packs: 3-8 at once, growing with the chapters, so the late game
			# comes in crowds. Each is fodder or a tough pack (WAVE_SHAPE's
			# `tough`): a swarm to mow, then something that pushes back.
			var pack := mini(left, sim.rng.randi_range(3, 8) + chapter * 2)
			var from := hard if sim.rng.randf() < tough else soft
			if from == hard:
				# Tough packs come smaller: they are worth more each.
				pack = mini(left, maxi(2, pack * 2 / 3))
			var kind := _roll(from)
			for i in pack:
				# A pack is mostly one kind, with a stray.
				queue.append([at + i * 0.12, kind if sim.rng.randf() < 0.75 else _roll(from), lane])
			left -= pack
			at += span * float(pack) / n
		if ChapterDefs.ELITE_WAVES.has(wave):
			queue.append([span * 0.35, ch["elites"][ChapterDefs.ELITE_WAVES[wave]], lane])
	queue.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	wave_total = queue.size()


## The horde: three surges, each a wall of mobs out of the portal at once,
## a third of the wave apiece. It's meant to be more than one hero can
## stop; the gate, the abilities and the potions are for this.
func _horde(lane: int, n: int, soft: Dictionary, hard: Dictionary, tough: float) -> void:
	var surges := 3
	for k in surges:
		var count := n / surges + (n % surges if k == surges - 1 else 0)
		var kind := _roll(soft)
		for i in count:
			var from := hard if sim.rng.randf() < tough else soft
			queue.append([1.0 + k * 9.0 + i * 0.05, kind if from == soft and sim.rng.randf() < 0.6 else _roll(from), lane])


## The roster's fodder (`soft`) or the rest. A roster with none of one kind
## gives the whole roster.
func _tier_roster(roster: Dictionary, soft: bool) -> Dictionary:
	var out := {}
	for k: String in roster:
		if (ChapterDefs.tier(k) == "soft") == soft:
			out[k] = roster[k]
	return out if not out.is_empty() else roster


func _roll(roster: Dictionary) -> String:
	var total := 0
	for k: String in roster:
		total += int(roster[k])
	var r := sim.rng.randi() % total
	for k: String in roster:
		r -= int(roster[k])
		if r < 0:
			return k
	return roster.keys()[0]


func _step_wave(dt: float) -> void:
	t += dt
	since_last += dt
	while not queue.is_empty() and float(queue[0][0]) <= since_last:
		var q: Array = queue.pop_front()
		var lane: int = q[2]
		# World bosses' stats are already this game's, chapter and all.
		var boss: bool = MobDefs.rank_of(q[1]) == "boss"
		var m := sim.spawn(q[1], MapData.portal(lane), lane, 1.0 if boss else hp_mult() * ChapterDefs.tier_hp(q[1], chapter),
			1.0 if boss else atk_mult())
		spawned += 1
		if m.rank == "boss":
			boss_id = m.id
		if m.rank != "mob":
			sim.emit(["portal", lane, m.kind])
	if wave == ChapterDefs.BOSS_WAVE:
		_step_boss_wave(dt)
		return
	if queue.is_empty():
		var left := sim.living_count()
		if left <= int(wave_total * CLEAR_SHARE) or since_last > CLEAR_WAIT + ChapterDefs.wave_span(wave):
			_end_wave()


func _step_boss_wave(dt: float) -> void:
	var boss: Mob = sim.by_id.get(boss_id)
	if boss_id >= 0 and (boss == null or not boss.alive()) and queue.is_empty():
		boss_id = -1
		_chapter_cleared()
		return
	if boss != null and boss.alive():
		adds_t -= dt
		if adds_t <= 0.0:
			adds_t = BOSS_ADDS_EVERY
			var roster: Dictionary = ChapterDefs.get_def(chapter)["roster"]
			for lane: int in lanes():
				var kind := _roll(roster)
				for i in 3 + chapter:
					sim.spawn(kind, MapData.portal(lane), lane, hp_mult() * ChapterDefs.tier_hp(kind, chapter), atk_mult())


func _end_wave() -> void:
	wave += 1
	phase = Phase.GAP
	t = Tuning.wave_gap()
	sim.emit(["music", "music_" + ChapterDefs.get_def(chapter)["music"]])
	sim.emit(["cleared", chapter, wave])


func _chapter_cleared() -> void:
	# What's left of the chapter's mobs flees back down when its boss dies.
	for m: Mob in sim.mobs:
		if m.alive() and m.rank == "mob":
			sim.damage_mob(m, m.hp + 1.0, "pure", -1, {"aoe": true})
	if chapter >= ChapterDefs.count() - 1:
		phase = Phase.VICTORY
		sim.over = "victory"
		sim.emit(["banner", "Dawn", "Astaroth is gone, and the Town still stands.", Color("ffd98a")])
		sim.emit(["music", "music_results"])
		sim.emit(["snd", "achievement", 1.0])
		return
	phase = Phase.CAMP
	t = CAMP_TIME
	sim.boss_dark = false
	sim.relight_fires()
	sim.repair_town(CAMP_REPAIR)
	for h: HeroState in sim.heroes.values():
		if h.alive:
			h.hp = h.max_hp()
		h.cds = [0.0, 0.0, 0.0, 0.0]
	var lit := chapter < Sim.dark_chapter()
	sim.emit(["banner", "The campfire", ("Rest. The road fires burn again and the Town is mended. %d seconds." if lit
		else "Rest. The Town is mended. %d seconds.") % int(CAMP_TIME), Color("f0a23c")])
	sim.emit(["music", "music_menu"])
	sim.emit(["snd", "campfire", 1.0])
	sim.emit(["camp", true])


## A player presses Space during a countdown (the intro, the gap between
## waves, the campfire). Once every hero has called, the wave comes now and
## each hero gets gold for the seconds skipped.
func call_wave(slot: int) -> void:
	if not phase in [Phase.INTRO, Phase.GAP, Phase.CAMP] or t <= 0.5:
		return
	calls[slot] = true
	sim.emit(["call", slot])
	for s: int in sim.heroes:
		if not calls.has(s):
			return
	var skipped := t
	t = 0.0
	calls.clear()
	sim.rush_gold(skipped)


## What the HUD shows.
func view() -> Dictionary:
	return {"phase": phase, "chapter": chapter, "wave": wave, "t": t, "left": queue.size() + sim.living_count(),
		"total": wave_total, "calls": calls.keys(), "world": ChapterDefs.get_def(chapter)["world"],
		"title": ChapterDefs.wave_title(chapter, wave)}
