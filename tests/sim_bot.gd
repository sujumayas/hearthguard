extends Node
## A headless run of the host sim with bots for heroes, to check the code
## runs and to read the pacing: level per chapter, deaths, the Town's HP.
##   godot --headless --path . res://tests/sim_bot.tscn -- --cls=archer --players=1 --minutes=40
## --rush calls every wave early (Space), --god keeps heroes and the Town full.
## --hp=1,2.3,... and --atk=1,1.6,... try other chapter scales (ChapterDefs).
## --build has each bot spend its gold on the Town at every campfire (it
## steps to the door, builds, and steps back): ruins first, then the
## cheapest level.

var sim: Sim
var bots := {}
var minutes := 40.0
var last_report := 0.0
var t0 := 0
var god := false
var rush := false
var build := false


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	minutes = float(args.get("minutes", "40"))
	god = args.has("god")
	rush = args.has("rush")
	build = args.has("build")
	if args.has("hp"):
		ChapterDefs.HP_SCALE = Array(str(args["hp"]).split(",")).map(func(x: String) -> float: return float(x))
	if args.has("atk"):
		ChapterDefs.ATK_SCALE = Array(str(args["atk"]).split(",")).map(func(x: String) -> float: return float(x))
	var n := int(args.get("players", "1"))
	var classes: Array = str(args.get("cls", "fighter,mage,flow,archer")).split(",")
	var slots := {}
	for i in n:
		slots[i] = {"name": "Bot%d" % i, "cls": classes[i % classes.size()], "peer": 1}
	sim = Sim.new(int(args.get("seed", "7")), slots)
	t0 = Time.get_ticks_msec()
	var ticks := int(minutes * 60.0 * 30.0)
	var chapter_seen := -1
	for i in ticks:
		for h: HeroState in sim.heroes.values():
			_bot(h)
			if rush:
				sim.director.call_wave(h.slot)
		sim.step()
		sim.take_events()
		_watch_wave()
		var d := sim.director
		if d.chapter != chapter_seen:
			chapter_seen = d.chapter
			_report("chapter %d starts" % (d.chapter + 1))
		if sim.time - last_report > 60.0:
			last_report = sim.time
			_report("")
		if sim.over != "":
			_report("OVER: " + sim.over)
			break
	print("ms per tick: %.3f" % (float(Time.get_ticks_msec() - t0) / maxf(1, sim.tick)))
	get_tree().quit()


## Per wave: how long it took, how low each hero got, deaths and what the
## Town lost. One line when the wave ends, to read the difficulty's shape.
var wv := {}


func _watch_wave() -> void:
	var d := sim.director
	var fighting := d.phase == Director.Phase.WAVE
	if fighting and (wv.is_empty() or int(wv["c"]) != d.chapter or int(wv["w"]) != d.wave):
		wv = {"c": d.chapter, "w": d.wave, "t0": sim.time, "low": 1.0, "deaths": _deaths(), "town": sim.town_hp(),
			"kills": _kills(), "peak": 0, "leaks": {}}
	if wv.is_empty():
		return
	if fighting:
		for h: HeroState in sim.heroes.values():
			wv["low"] = minf(float(wv["low"]), h.hp / h.max_hp() if h.alive else 0.0)
		if sim.tick % 15 == 0:
			wv["peak"] = maxi(int(wv["peak"]), sim.living_count())
			for mm: Mob in sim.mobs:
				if mm.alive() and mm.state == Mob.State.SIEGE:
					wv["leaks"][mm.id] = true
		return
	var c: int = wv["c"]
	var w: int = wv["w"]
	print("  WAVE ch%d w%d %s  %ds low %d%% deaths %d town -%d%% kills %d lv %s peak %d leaks %d ruins %d" % [c + 1, w + 1,
		ChapterDefs.wave_title(c, w).replace(" ", "_"), roundi(sim.time - float(wv["t0"])),
		roundi(float(wv["low"]) * 100.0), _deaths() - int(wv["deaths"]),
		roundi((float(wv["town"]) - sim.town_hp()) / sim.town_max() * 100.0), _kills() - int(wv["kills"]), _levels(),
		int(wv["peak"]), (wv["leaks"] as Dictionary).size(), sim.ruins.size()])
	wv = {}


func _deaths() -> int:
	var n := 0
	for h: HeroState in sim.heroes.values():
		n += h.deaths
	return n


func _kills() -> int:
	var n := 0
	for h: HeroState in sim.heroes.values():
		n += h.kills
	return n


func _levels() -> String:
	var out := []
	for h: HeroState in sim.heroes.values():
		out.append(str(h.level))
	return ",".join(out)


func _report(tag: String) -> void:
	var d := sim.director
	var hs := []
	for h: HeroState in sim.heroes.values():
		hs.append("%s L%d hp%d/%d k%d d%d g%d" % [h.cls, h.level, h.hp, h.max_hp(), h.kills, h.deaths, h.gold])
	var fs := ""
	for f: Dictionary in sim.fires:
		fs += "x" if f["gone"] else ("F" if f["lit"] else "o")
	print("[%5.0fs] ch%d w%d ph%d mobs=%d townhp=%d/%d ruins=%s fires=%s%s town=%s %s %s" % [sim.time, d.chapter + 1,
		d.wave + 1, d.phase, sim.living_count(), sim.town_hp(), sim.town_max(), sim.ruins.keys(), fs,
		" DARK" if sim.dark else "", sim.town,
		" | ".join(hs), tag])


## A plain player: stays near its gate, shoots or swings at the nearest mob,
## casts what's ready at the thickest crowd, spends points, drinks when low.
## When nothing is near its gate and a mob is bashing a building, it goes
## back to defend the Town.
func _bot(h: HeroState) -> void:
	var b: Dictionary = bots.get(h.slot, {"cd": 0.0, "home": MapData.hero_start(h.slot)})
	bots[h.slot] = b
	if not h.alive:
		return
	if god:
		h.hp = h.max_hp()
		for id: String in sim.standing():
			sim.bhp[id] = sim.building_max(id)
	while h.points > 0:
		var learned := false
		for s in [3, 0, 1, 2]:
			var before := h.points
			Skills.learn(sim, h, s)
			if h.points < before:
				learned = true
				break
		if not learned:
			break
	for row in HeroClasses.TALENT_LEVELS.size():
		if h.level >= HeroClasses.TALENT_LEVELS[row] and h.talents[row] == "":
			Skills.pick_talent(sim, h, row, (h.slot + row) % 3)
	if h.hp < h.max_hp() * 0.35:
		for i in 4:
			if h.belt[i][0] != "" and h.belt[i][0] != "echo":
				Skills.drink(sim, h, i, h.pos)
				break
	if build and sim.director.phase == Director.Phase.CAMP:
		_spend_on_town(h)
	# Only mobs near its gate: a bot that follows the crowd up another
	# corridor leaves its own open.
	var m := sim.nearest_mob(h.pos, 700.0)
	if m != null and m.pos.distance_to(b["home"]) > 900.0 and not MapData.TOWN.has_point(m.pos):
		m = null
	if m == null:
		m = _sieger(h.pos)
	var range_: float = h.stats["range"]
	var speed: float = h.stats["speed"]
	if OS.get_cmdline_user_args().has("--trace") and sim.tick % 60 == 0:
		print("    t%.0f pos%s target %s %s st%d" % [sim.time, h.pos.round(), m.kind if m != null else "-",
			m.pos.round() if m != null else Vector2.ZERO, m.state if m != null else -1])
	if m != null:
		var d := h.pos.distance_to(m.pos)
		if d > range_ + m.radius or not sim.map.line_open(h.pos, m.pos):
			_walk(h, m.pos, speed)
		elif not h.stats["melee"] and d < range_ * 0.4:
			# Back off toward its gate, so it doesn't kite itself into a corner
			# of the Town's buildings.
			var home: Vector2 = b["home"]
			var away := (h.pos - m.pos).normalized() + (home - h.pos).normalized() * 0.8
			h.pos = sim.map.slide(h.pos, away.normalized() * speed * Sim.DT)
		b["cd"] = float(b["cd"]) - Sim.DT
		if float(b["cd"]) <= 0.0 and d <= range_ + m.radius + 20.0 and sim.map.line_open(h.pos, m.pos):
			b["cd"] = HeroStats.attack_interval(h.stats, h.bloodlust if h.bloodlust_t > 0.0 else 0.0)
			Skills.attack(sim, h, m.id)
		for s in 4:
			if h.ranks[s] > 0 and h.cds[s] <= 0.0:
				Skills.cast(sim, h, s, m.pos, m.id)
	else:
		var home: Vector2 = b["home"]
		if h.pos.distance_to(home) > 40.0:
			_walk(h, home, speed)


## The mob bashing a building nearest `p`, or null.
func _sieger(p: Vector2) -> Mob:
	var best: Mob = null
	var bd := INF
	for mm: Mob in sim.mobs:
		if mm.alive() and (mm.state == Mob.State.SIEGE or MapData.TOWN.has_point(mm.pos)):
			var d := p.distance_to(mm.pos)
			if d < bd:
				bd = d
				best = mm
	return best


## Buys the cheapest next level in the Town while the gold lasts, keeping
## a little for potions.
func _spend_on_town(h: HeroState) -> void:
	var back := h.pos
	while true:
		var best := ""
		var bc := 1 << 30
		for id: String in sim.ruins:
			var c := TownDefs.rebuild_cost(id, int(sim.ruins[id]))
			if c < bc:
				bc = c
				best = id
		for id: String in TownDefs.ids():
			var c := TownDefs.cost(sim.town, id)
			if best == "" and c >= 0 and c < bc and not sim.ruins.has(id):
				bc = c
				best = id
		if best == "" or h.gold - bc < 80:
			break
		h.pos = TownDefs.door(best)
		sim.build(h, best)
	h.pos = back


## A step toward `to`: straight when the way is open, else along the path a
## player's click would take (MapData.path), so the bot goes round the Town's
## buildings instead of pushing into them.
func _walk(h: HeroState, to: Vector2, speed: float) -> void:
	var step := speed * Sim.DT
	var next := to
	if not sim.map.line_open(h.pos, to):
		var way := sim.map.path(h.pos, to)
		if not way.is_empty():
			next = way[0]
			if h.pos.distance_to(next) < step and way.size() > 1:
				next = way[1]
	h.pos = sim.map.slide(h.pos, (next - h.pos).limit_length(step))
