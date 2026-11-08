extends Node
## Starts a solo game and saves screenshots, to look at the game without
## playing it.
##   godot --path . res://tests/shot.tscn -- --cls=archer --times=4,12,30 --speed=2 --chapter=0
## --town=N builds every Town building to level N (0 leaves some unbuilt to
## compare), --at=x,y puts the hero there, --zoom=z sets the camera's zoom,
## --out=a,b puts out road fires a and b, --kindle=a holds fire a half lit.

var times: Array = [4.0, 12.0, 30.0]
var taken := 0
var t := 0.0
var cls := "archer"
var speed := 1.0
var chapter := 0
var wave := 0
var learn := true


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	cls = args.get("cls", cls)
	speed = float(args.get("speed", "1"))
	chapter = int(args.get("chapter", "0"))
	wave = int(args.get("wave", "0"))
	if args.has("times"):
		times = Array(str(args["times"]).split(",")).map(func(s: String) -> float: return float(s))
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	Net.set_identity("Tester", cls)
	Net.solo()
	Net.start_game.call_deferred()
	Engine.time_scale = speed


func _process(delta: float) -> void:
	t += delta / maxf(0.01, Engine.time_scale)
	var g := get_tree().current_scene
	if g == null or not g.has_method("send_attack"):
		return
	if g.sim != null and t < 1.0 and (chapter > 0 or wave > 0):
		var d: Director = g.sim.director
		d.chapter = chapter
		d.wave = wave
		g.map_view.set_chapter(chapter)
		g.view.chapter = chapter
		for h: HeroState in g.sim.heroes.values():
			h.level = 1 + chapter * 5 + wave
			h.points = h.level
			h.recompute()
			h.hp = h.max_hp()
	if g.sim != null and learn:
		for h: HeroState in g.sim.heroes.values():
			for s in [3, 0, 1, 2, 0, 1, 2]:
				Skills.learn(g.sim, h, s)
			if t > 0.5 and g.ctrl.casting.is_empty() and g.ctrl.alive and fmod(t, 1.5) < 0.05:
				var m: Mob = g.sim.nearest_mob(h.pos, 400.0)
				if m != null:
					for s in 4:
						if h.cds[s] <= 0.0 and h.ranks[s] > 0:
							g.ctrl._confirm_cast(s, m.pos)
							break
	if OS.get_cmdline_user_args().has("--talents") and t > 2.0:
		g.hud.talents_open = true
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if g.sim != null and t < 1.0:
		if args.has("town"):
			var n := int(args["town"])
			var ids := TownDefs.ids()
			for i in ids.size():
				g.sim.town[ids[i]] = n if n > 0 else [0, 1, 2, 3, 4, 5, 0, 2, 5][i]
			for h: HeroState in g.sim.heroes.values():
				h.recompute()
				h.gold = 900
		if args.has("at"):
			var xy: PackedStringArray = str(args["at"]).split(",")
			g.ctrl.teleport(Vector2(float(xy[0]), float(xy[1])))
			g.cam_pos = g.ctrl.pos
		if args.has("zoom"):
			g.zoom = float(args["zoom"])
	if g.sim != null and args.has("out"):
		for a: String in str(args["out"]).split(","):
			var f: Dictionary = g.sim.fires[int(a)]
			if f["lit"]:
				g.sim.hit_fire(int(a), 1e9)
	if g.sim != null and args.has("kindle"):
		g.sim.fires[int(args["kindle"])]["kindle"] = 0.55
	if taken < times.size() and t >= float(times[taken]):
		var img := get_viewport().get_texture().get_image()
		var path := "res://tests/shots/%s_%d.png" % [cls, taken]
		img.save_png(ProjectSettings.globalize_path(path))
		print("shot ", path, " t=", t)
		taken += 1
		if taken >= times.size():
			get_tree().quit()
