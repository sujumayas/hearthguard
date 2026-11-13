extends Node
## Checks the Town and the road fires on a bare Sim, no screen:
##   godot --headless --path . res://tests/town_test.tscn
## Building costs gold and needs the door, its bonus reaches every hero,
## mobs bash a lit fire until it goes out, a held ring heals and relights,
## all fires out brings the dark, and the next-to-last chapter takes them.
## Mobs walk to the nearest building and bash it, a ruin loses its bonus and
## can be rebuilt, and the Town falls with its last building.

var fails := 0


func _ready() -> void:
	var sim := Sim.new(3, {0: {"cls": "fighter", "name": "A"}, 1: {"cls": "mage", "name": "B"}})
	var a: HeroState = sim.heroes[0]
	var b: HeroState = sim.heroes[1]
	# No waves: the fires are tested alone.
	sim.director.phase = Director.Phase.GAP
	sim.director.t = 1e9
	_check(sim.fires.size() == 4, "two fires per open corridor")
	for f: Dictionary in sim.fires:
		_check(not sim.map.is_open(TownDefs.foot("barracks") + Vector2(0, -30)), "buildings are solid")
		_check(sim.map.is_open(f["pos"]), "fires stand on open ground")
	for id: String in TownDefs.ids():
		_check(sim.map.is_open(TownDefs.door(id)), "%s's door is open ground" % id)

	# Building.
	var hp0 := b.max_hp()
	a.pos = TownDefs.door("barracks")
	a.gold = 10
	sim.build(a, "barracks")
	_check(TownDefs.level(sim.town, "barracks") == 0, "no gold, no building")
	a.gold = 1000
	a.pos = MapData.portal(0)
	sim.build(a, "barracks")
	_check(TownDefs.level(sim.town, "barracks") == 0, "too far from the door, no building")
	a.pos = TownDefs.door("barracks")
	var price := TownDefs.cost(sim.town, "barracks")
	sim.build(a, "barracks")
	_check(TownDefs.level(sim.town, "barracks") == 1 and a.gold == 1000 - price, "built for its price")
	_check(is_equal_approx(b.max_hp(), hp0 * 1.05), "the other hero gets the Barracks' HP")
	a.gold = 99999
	for i in 6:
		sim.build(a, "barracks")
	_check(TownDefs.level(sim.town, "barracks") == TownDefs.MAX, "stops at MAX")
	a.gold = 5000
	var hm := sim.building_max("mint")
	a.pos = TownDefs.door("quarry")
	sim.build(a, "quarry")
	_check(is_equal_approx(sim.building_max("mint"), hm * 1.15), "the Quarry raises every building's HP")
	_check(is_equal_approx(float(sim.bhp["mint"]), sim.building_max("mint")), "and fills what it adds")
	a.pos = TownDefs.door("alchemist")
	sim.build(a, "alchemist")
	_check(TownDefs.potion_price(sim.town, "heal") < int(PotionDefs.get_def("heal")["price"]), "the Alchemist sells cheaper")
	_check(Skills.can_shop(sim, a), "the Alchemist's door is a shop")

	# A lone mob walks up to a lit fire and bashes it out.
	for h: HeroState in sim.heroes.values():
		h.pos = MapData.SQUARE + Vector2(0, 600)
	var f0: Dictionary = sim.fires[0]
	var m := sim.spawn("goblin", f0["pos"] + Vector2(150, 0), 0, 1.0, 50.0)
	var went_out := false
	for i in 30 * 60:
		sim.step()
		sim.take_events()
		if not f0["lit"]:
			went_out = true
			break
	_check(went_out, "a mob puts out a fire it passes")
	sim.step()
	_check(m.state != Mob.State.FIRE, "the mob leaves the fire once it is out")
	m.hp = 0.0
	sim.damage_mob(m, 1e9, "pure", -1)

	# Hold the ring: a hero in it and no mob relights it.
	a.pos = f0["pos"] + Vector2(60, 0)
	var lit := false
	for i in 30 * 8:
		sim.step()
		sim.take_events()
		if f0["lit"]:
			lit = true
			break
	_check(lit, "holding the ring relights the fire")
	a.hp = a.max_hp() * 0.4
	var before := a.hp
	for i in 30:
		sim.step()
	_check(a.hp > before + a.max_hp() * 0.02, "a lit fire heals the hero in its ring")

	# Every fire out: the dark. One back: the light.
	for i in sim.fires.size():
		sim.hit_fire(i, 1e9)
	sim.step()
	_check(sim.dark, "all fires out brings the dark")
	sim.relight_fires()
	sim.step()
	_check(not sim.dark, "a lit fire lifts it")

	# The next-to-last chapter: the dark takes them for good.
	sim.director.chapter = Sim.dark_chapter()
	sim.snuff_fires()
	for i in 30 * 10:
		sim.step()
	_check(sim.dark and sim.fires.all(func(f: Dictionary) -> bool: return f["gone"] and not f["lit"]),
		"the dark takes every fire and none relights")
	sim.relight_fires()
	_check(sim.fires.all(func(f: Dictionary) -> bool: return not f["lit"]), "the campfire can't light a taken fire")

	# A mob that gets past the heroes walks to the nearest building and
	# bashes it. A ruin loses its bonus, and the mobs move on.
	var sim2 := Sim.new(5, {0: {"cls": "fighter", "name": "A"}})
	var c: HeroState = sim2.heroes[0]
	sim2.director.phase = Director.Phase.GAP
	sim2.director.t = 1e9
	for f: Dictionary in sim2.fires:
		f["lit"] = false
	c.pos = MapData.portal(2)
	c.gold = 99999
	var cc := c.pos
	c.pos = TownDefs.door("mint")
	sim2.build(c, "mint")
	c.pos = cc
	_check(sim2.gold_mult() > 1.0, "the Mint pays more")
	var orc := sim2.spawn("orc", MapData.CROSSROADS, 0, 1.0, 40.0)
	var first := ""
	for i in 30 * 40:
		sim2.step()
		sim2.take_events()
		if orc.state == Mob.State.SIEGE and first == "":
			first = orc.bld
		if not sim2.ruins.is_empty():
			break
	_check(first in ["mint", "alchemist"], "a mob from the Crossroads goes for the nearest building (%s)" % first)
	_check(sim2.ruins.has(first), "and bashes it to a ruin")
	if first == "mint":
		_check(is_equal_approx(sim2.gold_mult(), 1.0), "a ruined Mint gives nothing")
		_check(int(sim2.ruins["mint"]) == 1, "the ruin keeps its level for the rebuild")
	for i in 30 * 10:
		sim2.step()
		sim2.take_events()
	_check(orc.bld != first, "the mob moves on to the next building")
	orc.hp = 0.0
	sim2.damage_mob(orc, 1e9, "pure", -1)
	c.pos = TownDefs.door(first)
	var g0 := c.gold
	sim2.build(c, first)
	_check(not sim2.ruins.has(first) and c.gold == g0 - TownDefs.rebuild_cost(first, 1), "a ruin is rebuilt for gold")
	_check(TownDefs.level(sim2.town, first) == 1, "at the level it had")
	_check(is_equal_approx(float(sim2.bhp[first]), sim2.building_max(first) * 0.5), "with half its HP")
	# Every building down: the run is lost.
	for id: String in TownDefs.ids():
		sim2.hit_building(id, 1e9)
	sim2.step()
	_check(sim2.over == "defeat", "the Town falls with its last building")
	print("town test: %d failed" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)
