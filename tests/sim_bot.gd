extends Node
## A headless run of the host sim with bots for heroes, to check the code
## runs and to read the pacing: level per chapter, deaths, Hearth HP.
##   godot --headless --path . res://tests/sim_bot.tscn -- --cls=archer --players=1 --minutes=40
## --rush calls every wave early (Space), --god keeps heroes and Hearth full.

var sim: Sim
var bots := {}
var minutes := 40.0
var last_report := 0.0
var t0 := 0
var god := false
var rush := false


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	minutes = float(args.get("minutes", "40"))
	god = args.has("god")
	rush = args.has("rush")
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


func _report(tag: String) -> void:
	var d := sim.director
	var hs := []
	for h: HeroState in sim.heroes.values():
		hs.append("%s L%d hp%d/%d k%d d%d g%d" % [h.cls, h.level, h.hp, h.max_hp(), h.kills, h.deaths, h.gold])
	print("[%5.0fs] ch%d w%d ph%d mobs=%d hearth=%d/%d %s %s" % [sim.time, d.chapter + 1, d.wave + 1, d.phase,
		sim.living_count(), sim.hearth_hp, sim.hearth_max, " | ".join(hs), tag])


## A plain player: stays near its gate, shoots or swings at the nearest mob,
## casts what's ready at the thickest crowd, spends points, drinks when low.
func _bot(h: HeroState) -> void:
	var b: Dictionary = bots.get(h.slot, {"cd": 0.0, "home": MapData.hero_start(h.slot)})
	bots[h.slot] = b
	if not h.alive:
		return
	if god:
		h.hp = h.max_hp()
		sim.hearth_hp = sim.hearth_max
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
	var m := sim.nearest_mob(h.pos, 700.0)
	var range_: float = h.stats["range"]
	var speed: float = h.stats["speed"]
	if m != null:
		var d := h.pos.distance_to(m.pos)
		if d > range_ + m.radius:
			h.pos = sim.map.slide(h.pos, (m.pos - h.pos).normalized() * speed * Sim.DT)
		elif not h.stats["melee"] and d < range_ * 0.4:
			h.pos = sim.map.slide(h.pos, (h.pos - m.pos).normalized() * speed * Sim.DT)
		b["cd"] = float(b["cd"]) - Sim.DT
		if float(b["cd"]) <= 0.0 and d <= range_ + m.radius + 20.0:
			b["cd"] = HeroStats.attack_interval(h.stats, h.bloodlust if h.bloodlust_t > 0.0 else 0.0)
			Skills.attack(sim, h, m.id)
		for s in 4:
			if h.ranks[s] > 0 and h.cds[s] <= 0.0:
				Skills.cast(sim, h, s, m.pos, m.id)
	else:
		var home: Vector2 = b["home"]
		if h.pos.distance_to(home) > 40.0:
			h.pos = sim.map.slide(h.pos, (home - h.pos).normalized() * speed * Sim.DT)
