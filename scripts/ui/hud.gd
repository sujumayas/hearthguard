class_name Hud
extends CanvasLayer
## The screen over the field, in MatchRPG's dusk colors. Drawn by hand on
## one Control; the panels' rects take the clicks they cover, and anything
## else falls through to the field as an order.

const INK := Color("15121c")
const DUSK := Color("1d1828")
const PANEL := Color(0.11, 0.09, 0.15, 0.92)
const EDGE := Color("3a3248")
const BONE := Color("f4efe6")
const DIM := Color("8a8494")
const GOLD := Color("f2c53d")
const HP := Color("e04848")
const XP := Color("9b59d0")

## Ability id to the MatchRPG talent picture that draws it (TalentIcon).
const ICONS := {"whirlwind": "cleave", "charge": "drive", "war_cry": "onslaught", "executioner": "first_blood",
	"fireball": "wildfire", "frost_nova": "stasis", "blink": "time_stop", "meteor": "meteor",
	"fan_of_knives": "flurry", "shadow_step": "outrun", "smoke": "dirty_fighting", "flurry": "unstoppable"}

var game: Node
var root: Control
var heading_font: Font
var body_font: Font
var state := {}
var me := {}
var t := 0.0
var banners: Array = []
var callouts: Array = []
var toasts: Array = []
var card := {}
var talents_open := false
var shop_open := false
var help_open := false
var menu_open := false
var end_screen := {}
var hits: Array = []
var minimap_tex: ImageTexture
var mouse := Vector2.ZERO
var pad: TouchPad
## The pause menu's sliders: key -> track rect, and the one being dragged.
var sliders := {}
var slider_key := ""


func setup(g: Node) -> void:
	game = g
	layer = 10
	# The menu pauses the match, and the HUD has to keep running to close it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	heading_font = load("res://assets/fonts/kanit.tres")
	body_font = load("res://assets/fonts/outfit.tres")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.draw.connect(_draw)
	root.gui_input.connect(_gui_input)
	add_child(root)
	_fit()
	_bake_minimap()
	pad = TouchPad.new(self)
	Touch.changed.connect(func(_on: bool) -> void: pad.reset())
	get_window().focus_exited.connect(func() -> void: pad.reset())
	help_open = true
	get_tree().create_timer(9.0).timeout.connect(func() -> void: help_open = false)


## On a phone the HUD draws bigger: the layer scales up and the Control
## shrinks to match, so everything is laid out in the scaled units.
func _fit() -> void:
	var vs := root.get_viewport_rect().size
	var s := Touch.hud_scale(vs.y)
	scale = Vector2(s, s)
	root.position = Vector2.ZERO
	root.size = vs / s


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		# Esc first cancels an aimed spell, which the hero control handles.
		if menu_open or game.ctrl.targeting < 0 and not game.ctrl.amove_armed:
			_escape()
			get_viewport().set_input_as_handled()
			return
	if slider_key != "" and event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseMotion:
			slider_move((event as InputEventMouse).position / scale.x)
		elif event is InputEventMouseButton and not event.pressed:
			slider_end()
	if Touch.on and pad != null and pad.input(event):
		get_viewport().set_input_as_handled()


func _escape() -> void:
	if menu_open:
		set_menu(false)
	elif talents_open or shop_open or help_open:
		talents_open = false
		shop_open = false
		help_open = false
	else:
		set_menu(true)


## Opens or closes the pause menu. Solo, the match stops while it is open;
## online it can't, so the menu just covers the screen.
func set_menu(v: bool) -> void:
	menu_open = v
	slider_end()
	if pad != null:
		pad.reset()
	if not Net.online:
		get_tree().paused = v


func _process(delta: float) -> void:
	t += delta
	_fit()
	for arr: Array in [banners, callouts, toasts]:
		for b: Dictionary in arr:
			b["t"] = float(b["t"]) + delta
		var keep := arr.filter(func(b: Dictionary) -> bool: return float(b["t"]) < float(b["dur"]))
		arr.clear()
		arr.append_array(keep)
	if not card.is_empty():
		card["t"] = float(card["t"]) + delta
		if float(card["t"]) > float(card["dur"]):
			card = {}
	# No hover on a touch screen: the last tap would light buttons up.
	mouse = Vector2(-1e5, -1e5) if Touch.on else root.get_local_mouse_position()
	root.queue_redraw()


func on_state(st: Dictionary) -> void:
	state = st
	me = (st.get("heroes", {}) as Dictionary).get(game.my_slot, {})


func banner(title: String, sub: String, col: Color) -> void:
	banners = [{"title": title, "sub": sub, "color": col, "t": 0.0, "dur": 3.6}]


func callout(text: String, col: Color, size: float) -> void:
	callouts = [{"text": text, "color": col, "size": size, "t": 0.0, "dur": 1.3}]


func toast(text: String) -> void:
	toasts.append({"text": text, "t": 0.0, "dur": 3.0})
	if toasts.size() > 3:
		toasts.pop_front()


func boss_card(kind: String) -> void:
	var d := MobDefs.get_def(kind)
	card = {"name": d["name"], "lore": d["lore"], "color": d["color"], "kind": kind, "t": 0.0, "dur": 4.5, "boss": true}


func elite_card(kind: String) -> void:
	var d := MobDefs.get_def(kind)
	card = {"name": d["name"], "lore": d["lore"], "color": d["color"], "kind": kind, "t": 0.0, "dur": 3.0, "boss": false}


func open_shop(on: bool) -> void:
	shop_open = on


func show_end(title: String, sub: String) -> void:
	end_screen = {"title": title, "sub": sub}
	talents_open = false
	shop_open = false


func blocks_input() -> bool:
	return not end_screen.is_empty() or menu_open


func unhandled_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_T:
			talents_open = not talents_open
			shop_open = false
		KEY_B:
			shop_open = not shop_open
			talents_open = false
		KEY_F1:
			help_open = not help_open
		KEY_F:
			var id := _building_here()
			if id != "":
				game.send_build(id)
		KEY_ENTER, KEY_KP_ENTER:
			game.send_ready()


# --- Clicks ----------------------------------------------------------------------

func _hit(r: Rect2, action: Callable) -> void:
	hits.append([r, action])


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if Touch.on and mb.device == InputEvent.DEVICE_ID_EMULATION:
		return  # The touch pad already took the finger.
	for i in range(hits.size() - 1, -1, -1):
		var h: Array = hits[i]
		if (h[0] as Rect2).has_point(mb.position):
			if mb.button_index == MOUSE_BUTTON_LEFT and (h[1] as Callable).is_valid():
				mouse = mb.position
				(h[1] as Callable).call()
				Sfx.ui("click", 0.6)
			root.accept_event()
			return


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	hits.clear()
	var size := root.size
	_draw_top(size)
	_draw_boss(size)
	_draw_party()
	_draw_menu_buttons()
	if Touch.on:
		_draw_touch_bottom(size)
	else:
		_draw_bottom(size)
	_draw_minimap(size)
	_draw_building_card(size)
	_draw_banners(size)
	_draw_card(size)
	_draw_toasts(size)
	if Touch.on:
		pad.draw(size)
	if talents_open:
		_draw_talents(size)
	if shop_open:
		_draw_shop(size)
	if help_open:
		_draw_help(size)
	if menu_open:
		_draw_menu(size)
	if not end_screen.is_empty():
		_draw_end(size)


func _panel(r: Rect2, col := PANEL) -> void:
	Kept.rect(root, r.grow(2), Color(0, 0, 0, 0.5))
	Kept.rect(root, r, col)
	Kept.rect(root, r, EDGE, false, 2.0)
	_hit(r, Callable())


func _text(at: Vector2, text: String, size: int, col: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT,
		width := -1.0) -> void:
	var f := font if font != null else body_font
	root.draw_string(f, at, text, align, width, size, col)


func _text_c(center_x: float, y: float, text: String, size: int, col: Color, font: Font = null) -> void:
	var f := font if font != null else heading_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	root.draw_string_outline(f, Vector2(center_x - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, col.a * 0.7))
	root.draw_string(f, Vector2(center_x - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(r: Rect2, frac: float, col: Color, back := Color(0, 0, 0, 0.6)) -> void:
	root.draw_rect(r, back)
	root.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	root.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y * 0.35)), Color(1, 1, 1, 0.12))


func _draw_top(size: Vector2) -> void:
	var d: Dictionary = state.get("dir", {})
	if d.is_empty():
		return
	var cx := size.x * 0.5
	var r := Rect2(cx - 220, 8, 440, 74)
	_panel(r)
	var phase: int = d.get("phase", 0)
	var title: String = d.get("title", "")
	var sub := "%s · Chapter %d of 5" % [d.get("world", ""), int(d.get("chapter", 0)) + 1]
	_text_c(cx, 30, sub, 14, DIM, body_font)
	match phase:
		Director.Phase.INTRO:
			_text_c(cx, 56, "Get ready · %d" % ceili(float(d.get("t", 0.0))), 22, BONE)
		Director.Phase.WAVE:
			_text_c(cx, 56, "%s  ·  %d left" % [title, int(d.get("left", 0))], 22, BONE)
		Director.Phase.GAP:
			_text_c(cx, 56, "Next wave in %d" % ceili(float(d.get("t", 0.0))), 22, Color("ffd98a"))
		Director.Phase.CAMP:
			_text_c(cx, 56, "Campfire · %d s" % ceili(float(d.get("t", 0.0))), 22, Color("f0a23c"))
		Director.Phase.VICTORY:
			_text_c(cx, 56, "Victory", 22, GOLD)
	if phase in [Director.Phase.INTRO, Director.Phase.GAP, Director.Phase.CAMP] and float(d.get("t", 0.0)) > 0.5:
		_draw_call(r, d)
	# The Town: every building's HP together, and how many still stand.
	var hf: float = game.town_frac()
	var hb := Rect2(r.position.x + 20, r.end.y - 14, r.size.x - 40, 8)
	_bar(hb, hf, Color("f0a23c") if hf > 0.3 else Color("ff6a3d"))
	var standing := TownDefs.ids().size() - (state.get("ruins", {}) as Dictionary).size()
	_text(Vector2(hb.position.x, hb.position.y - 1), "Town  ·  %d of %d standing" % [standing, TownDefs.ids().size()], 11,
		Color(1, 1, 1, 0.6) if standing > 3 else Color("ff8a6a"))
	_draw_fire_marks(r)


## The road fires under the wave panel: a flame for each, lit, out, or gone
## to the dark, and the word when it is dark.
func _draw_fire_marks(r: Rect2) -> void:
	var fs: Array = state.get("fires", [])
	if fs.is_empty():
		return
	var w := fs.size() * 26.0 + 64.0
	var b := Rect2(r.get_center().x - w * 0.5, r.end.y + 6, w, 30)
	var dark: bool = state.get("dark", false)
	Kept.rect(root, b, Color(0.06, 0.05, 0.1, 0.85))
	_text(b.position + Vector2(8, 20), "Dark" if dark else "Fires", 13, Color("b9a5ff") if dark else Color("ffd27a"), body_font)
	for i in fs.size():
		var f: Array = fs[i]
		var c := b.position + Vector2(58 + i * 26, 22)
		var st: int = f[1]
		var col := Color("f0a23c") if st == 1 else (Color("4a4452") if st == 2 else Color("8a8494"))
		var hgt := 16.0 if st == 1 else 8.0
		if st == 0 and float(f[3]) > 0.0:
			hgt = 8.0 + 8.0 * float(f[3])
			col = Color("8a8494").lerp(Color("ffd27a"), float(f[3]))
		root.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(0, -hgt), c + Vector2(7, 0)]), col)
		if st == 2:
			root.draw_line(c + Vector2(-8, -12), c + Vector2(8, 2), Color("b9a5ff"), 2.0)


## The Town building whose door the hero stands at, or "".
func _building_here() -> String:
	if me.is_empty() or not me.get("alive", false):
		return ""
	return TownDefs.near(game.ctrl.pos)


## Standing at a building's door: what it gives, what the next level costs,
## and a button (F) to pay for it. A ruin offers its rebuild instead.
func _draw_building_card(size: Vector2) -> void:
	var id := _building_here()
	if id == "" or talents_open or shop_open:
		return
	var town: Dictionary = state.get("town", {})
	var ruins: Dictionary = state.get("ruins", {})
	var bd := TownDefs.get_def(id)
	var lv := TownDefs.level(town, id)
	var price := TownDefs.cost(town, id)
	var ruined := ruins.has(id)
	if ruined:
		lv = int(ruins[id])
		price = TownDefs.rebuild_cost(id, lv)
	var gold := int(me.get("gold", 0))
	var w := 460.0
	var h := 112.0
	var bottom := pad.strip_rect(size).position.y if Touch.on else size.y - 118.0
	var r := Rect2(size.x * 0.5 - w * 0.5, bottom - h - 10.0, w, h)
	Kept.rect(root, r.grow(2), Color(0, 0, 0, 0.5))
	Kept.rect(root, r, Color(0.08, 0.07, 0.11, 0.95))
	var icon := Rect2(r.position + Vector2(8, 8), Vector2(96, 96))
	BuildingIcon.draw_building(root, id, icon, lv > 0 and not ruined, Color.TRANSPARENT, Color.TRANSPARENT, 0.0,
		lv * TownDefs.ART_STEP)
	var x := r.position.x + 114
	_text(Vector2(x, r.position.y + 28), bd["name"], 20, BONE, heading_font)
	var tag := "Ruin" if ruined else ("Not built" if lv == 0 else "Level %d / %d" % [lv, TownDefs.MAX])
	var hp_frac := float(state.get("bhp", {}).get(id, 1.0))
	if not ruined and hp_frac < 0.999:
		tag += "  ·  %d%% HP" % roundi(hp_frac * 100.0)
	_text(Vector2(r.end.x - 172, r.position.y + 28), tag, 14,
		Color("ff8a6a") if ruined else (GOLD if lv > 0 else DIM), body_font, HORIZONTAL_ALIGNMENT_RIGHT, 160)
	_text(Vector2(x, r.position.y + 50), bd["desc"], 13, Color(1, 1, 1, 0.75), body_font, HORIZONTAL_ALIGNMENT_LEFT, w - 124)
	if ruined:
		_text(Vector2(x, r.position.y + 72), "Rebuild it at level %d, with half its HP." % maxi(1, lv), 13,
			Color("ffd98a"), body_font)
	elif price < 0:
		_text(Vector2(x, r.position.y + 88), "Fully built.", 16, GOLD, heading_font)
		return
	else:
		_text(Vector2(x, r.position.y + 72), ("Activate: " if lv == 0 else "Level %d: " % (lv + 1)) + TownDefs.next_text(town, id),
			13, Color("ffd98a"), body_font)
	var b := Rect2(x, r.position.y + 78, w - 124, 28)
	var afford := gold >= price
	Kept.rect(root, b, (Color("6a5a24") if b.has_point(mouse) else Color("4a3f1c")) if afford else Color(0.18, 0.16, 0.2))
	var key := "" if Touch.on else "  (F)"
	var verb := "Rebuild" if ruined else ("Build" if lv == 0 else "Level up")
	_text_c(b.get_center().x, b.position.y + 20, "%s for %d gold%s" % [verb, price, key], 15,
		BONE if afford else DIM, body_font)
	var bid := id
	_hit(b, func() -> void: game.send_build(bid))


## The "call it early" button beside the wave panel: Space, with the gold
## it pays now and, in co-op, who has called.
func _draw_call(r: Rect2, d: Dictionary) -> void:
	var calls: Array = d.get("calls", [])
	var mine: bool = game.my_slot in calls
	var need: int = maxi(1, game.player_count())
	var b := Rect2(r.end.x + 8, r.position.y + 8, 150, 58)
	var lit: bool = b.has_point(mouse) and not mine
	Kept.rect(root, b, Color("6a5a24") if lit else (Color("2f3a2a") if mine else Color("4a3f1c")))
	var label := "Waiting %d/%d" % [calls.size(), need] if mine else ("Call it" if Touch.on else "Call it  (Space)")
	_text_c(b.get_center().x, b.position.y + 24, label, 16, BONE, body_font)
	var gold: int = roundi(float(d.get("t", 0.0)) * Sim.RUSH_GOLD_PER_S * (1.0 + 0.7 * float(d.get("chapter", 0))))
	_text_c(b.get_center().x, b.position.y + 46, "+%d gold" % gold, 14, GOLD, body_font)
	if not mine:
		_hit(b, func() -> void: game.send_ready())


func _draw_boss(size: Vector2) -> void:
	var b: Dictionary = state.get("boss", {})
	if b.is_empty():
		return
	var d := MobDefs.get_def(b["kind"])
	var cx := size.x * 0.5
	var r := Rect2(cx - 330, 92, 660, 44)
	_panel(r, Color(0.1, 0.06, 0.1, 0.92))
	_bar(Rect2(r.position + Vector2(12, 24), Vector2(r.size.x - 24, 12)), float(b["hp"]), Color("ff6a3d"))
	for p in [0.7, 0.35]:
		var x: float = r.position.x + 12 + (r.size.x - 24) * p
		root.draw_line(Vector2(x, r.position.y + 22), Vector2(x, r.position.y + 38), BONE, 2.0)
	_text(r.position + Vector2(12, 19), "%s  ·  phase %d" % [d["name"], int(b["phase"])], 16, BONE, heading_font)
	var et: float = b.get("enrage", 0.0)
	var txt := "ENRAGED" if b.get("enraged", false) else "enrage in %d s" % ceili(et)
	_text(Vector2(r.end.x - 160, r.position.y + 19), txt, 14, Color("ffbf5e") if b.get("enraged", false) else DIM, body_font,
		HORIZONTAL_ALIGNMENT_RIGHT, 148)


func _draw_party() -> void:
	var hs: Dictionary = state.get("heroes", {})
	var y := 12.0
	var slots: Array = hs.keys()
	slots.sort()
	for s: int in slots:
		var h: Dictionary = hs[s]
		var r := Rect2(12, y, 230, 58)
		_panel(r)
		var cls: String = h["cls"]
		var col: Color = HeroClasses.get_def(cls)["color"]
		HeroLook.draw(root, r.position + Vector2(8, 4), 0.75, col, HeroStats.gear(cls, h["talents"]), {"frame": HeroLook.frame_at(t)})
		root.draw_set_transform(Vector2.ZERO)
		var name_txt := "%s  ·  %s %d" % [h["name"], HeroClasses.get_def(cls)["name"], h["level"]]
		_text(r.position + Vector2(52, 20), name_txt, 14, col.lightened(0.3), heading_font)
		if h["alive"]:
			_bar(Rect2(r.position + Vector2(52, 28), Vector2(166, 10)), float(h["hp"]) / float(h["max_hp"]), Color("5ad06a"))
		else:
			_text(r.position + Vector2(52, 38), "Back in %d" % ceili(float(h["respawn"])), 13, DIM)
		var lane_name: String = MapData.CORRIDORS[s]["name"]
		_text(r.position + Vector2(52, 52), lane_name, 11, DIM)
		y += 64.0


func _draw_bottom(size: Vector2) -> void:
	if me.is_empty():
		return
	var cls: String = me["cls"]
	var col: Color = HeroClasses.get_def(cls)["color"]
	var w := 760.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - 118, w, 110)
	_panel(r)
	# Portrait.
	var pr := Rect2(r.position + Vector2(10, 10), Vector2(80, 90))
	Kept.rect(root, pr, DUSK)
	HeroLook.draw(root, pr.position + Vector2(18, 10), 1.1, col, HeroStats.gear(cls, me["talents"]), {"frame": HeroLook.frame_at(t)})
	root.draw_set_transform(Vector2.ZERO)
	_text(pr.position + Vector2(4, 86), "Lv %d" % me["level"], 14, GOLD, heading_font)
	# HP and XP.
	var bx := r.position.x + 100
	var hp_r := Rect2(bx, r.position.y + 12, 300, 16)
	_bar(hp_r, float(me["hp"]) / float(me["max_hp"]), Color("5ad06a") if me["alive"] else Color("444"))
	_text(hp_r.position + Vector2(6, 13), "%d / %d" % [me["hp"], me["max_hp"]], 13, BONE)
	var xp_r := Rect2(bx, r.position.y + 32, 300, 6)
	_bar(xp_r, float(me["xp"]) / maxf(1.0, float(me["xp_next"])), XP)
	if not me["alive"]:
		_text(Vector2(bx + 310, r.position.y + 26), "Back in %d" % ceili(float(me["respawn"])), 15, Color("ff8a8a"), heading_font)
	# Abilities.
	var ranks: Array = me["ranks"]
	var cds: Array = game.ctrl.local_cds
	for i in 4:
		var a := HeroClasses.ability(cls, i)
		var ar := Rect2(bx + i * 74, r.position.y + 44, 64, 58)
		var learned := int(ranks[i]) > 0
		Kept.rect(root, ar, col.darkened(0.55) if learned else Color(0.15, 0.13, 0.18))
		_ability_icon(a["id"], ar.get_center() + Vector2(0, -2), learned, col)
		var cd: float = cds[i]
		if learned and cd > 0.05:
			var full := HeroStats.cooldown(cls, i, int(ranks[i]), HeroStats.compute(cls, int(me["level"]), me["talents"]))
			var k := clampf(cd / maxf(0.1, full), 0.0, 1.0)
			root.draw_rect(Rect2(ar.position, Vector2(ar.size.x, ar.size.y * k)), Color(0, 0, 0, 0.6))
			_text_c(ar.get_center().x, ar.get_center().y + 8, "%.0f" % ceilf(cd) if cd >= 1.0 else "%.1f" % cd, 20, BONE)
		Kept.rect(root, ar, BONE if game.ctrl.targeting == i else EDGE, false, 2.0)
		_text(ar.position + Vector2(4, 14), a["key"], 13, BONE, heading_font)
		for k2 in HeroClasses.max_rank(i):
			Kept.disc(root, ar.position + Vector2(8 + k2 * 9, ar.size.y - 6), 3.0, GOLD if k2 < int(ranks[i]) else Color(1, 1, 1, 0.2))
		var can_learn: bool = int(me["points"]) > 0 and int(ranks[i]) < HeroClasses.max_rank(i) \
			and int(me["level"]) >= HeroClasses.rank_level(i, int(ranks[i]))
		if can_learn:
			var lr := Rect2(ar.position + Vector2(ar.size.x - 22, -12), Vector2(24, 24))
			Kept.rect(root, lr, Color("ffd24a") if lr.has_point(mouse) else GOLD.darkened(0.15))
			_text_c(lr.get_center().x, lr.position.y + 19, "+", 20, INK)
			var slot_i := i
			_hit(lr, func() -> void: game.send_learn(slot_i))
		if ar.has_point(mouse):
			_tooltip(ar, "%s (%s)  ·  rank %d/%d" % [a["name"], a["key"], ranks[i], HeroClasses.max_rank(i)], a["desc"],
				"Ctrl+%s to learn" % a["key"] if can_learn else "")
	# Belt.
	var belt: Array = me["belt"]
	for i in 4:
		var br := Rect2(bx + 304 + i * 52, r.position.y + 44, 46, 58)
		Kept.rect(root, br, DUSK)
		var b: Array = belt[i]
		if str(b[0]) != "" and int(b[1]) > 0:
			var pd := PotionDefs.get_def(b[0])
			PotionArt.draw_symbol(root, PotionDefs.symbol(b[0]), br.get_center() + Vector2(0, -2), 14.0, pd["color"])
			if int(b[1]) > 1:
				_text(br.position + Vector2(br.size.x - 12, 14), str(b[1]), 13, BONE, heading_font)
			if br.has_point(mouse):
				_tooltip(br, pd["name"], pd["desc"], "Press %d" % (i + 1))
			var idx := i
			_hit(br, func() -> void: game.send_drink(idx, game.ctrl.pos))
		Kept.rect(root, br, EDGE, false, 2.0)
		_text(br.position + Vector2(4, 14), str(i + 1), 12, DIM, heading_font)
	# Gold, Flow, talents and shop buttons.
	var gx := r.end.x - 120
	Kept.disc(root, Vector2(gx + 10, r.position.y + 20), 8.0, GOLD)
	_text(Vector2(gx + 24, r.position.y + 26), str(me["gold"]), 18, GOLD, heading_font)
	if cls == "flow":
		_text(Vector2(gx - 20, r.position.y + 40), "Flow %d" % me["flow"], 14, Color("f2c53d"), heading_font)
	var open_rows := _open_talent_rows()
	var tb := Rect2(gx, r.position.y + 44, 110, 26)
	var glow := open_rows > 0 and fmod(t, 1.0) < 0.6
	Kept.rect(root, tb, GOLD.darkened(0.2) if glow else DUSK)
	var tl := "Talents (T)" + (" !" if open_rows > 0 else "")
	var tw := body_font.get_string_size(tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	root.draw_string(body_font, Vector2(tb.get_center().x - tw * 0.5, tb.position.y + 19), tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		INK if glow else BONE)
	_hit(tb, func() -> void:
		talents_open = not talents_open
		shop_open = false)
	var sb := Rect2(gx, r.position.y + 76, 110, 26)
	Kept.rect(root, sb, DUSK.lightened(0.1) if sb.has_point(mouse) else DUSK)
	_text_c(sb.get_center().x, sb.position.y + 19, "Alchemist (B)", 14, BONE, body_font)
	_hit(sb, func() -> void:
		shop_open = not shop_open
		talents_open = false)


func _ability_icon(id: String, c: Vector2, on: bool, col: Color) -> void:
	var tint := col if on else Color(0.4, 0.38, 0.45)
	if ICONS.has(id):
		TalentIcon.fallback_branch = "blade"
		TalentIcon.draw(root, ICONS[id], c, 0.5, tint)
		root.draw_set_transform(Vector2.ZERO)
		return
	# The Archer's own: arrows, drawn in the same ink.
	var ink := Color(tint.lerp(TileIcon.INK, TileIcon.INK_MIX), 1.0)
	var lit := Color(tint.lerp(Color.WHITE, 0.6), 1.0)
	match id:
		"volley":
			for k in 3:
				var d := Vector2.from_angle(-PI * 0.25 + (k - 1) * 0.35)
				var a := c - d * 16.0
				root.draw_line(a, a + d * 30.0, ink, 3.0, true)
				root.draw_colored_polygon(PackedVector2Array([a + d * 34.0, a + d * 26.0 + d.orthogonal() * 4.0,
					a + d * 26.0 - d.orthogonal() * 4.0]), ink)
		"power_shot":
			var d := Vector2(1, 0)
			root.draw_line(c - d * 20.0, c + d * 16.0, ink, 5.0, true)
			root.draw_colored_polygon(PackedVector2Array([c + d * 24.0, c + d * 12.0 + Vector2(0, 7), c + d * 12.0 - Vector2(0, 7)]), lit)
			for k in 3:
				root.draw_line(c - d * (18.0 + k * 4.0) + Vector2(0, -8), c - d * (24.0 + k * 4.0) + Vector2(0, -8), ink, 2.0)
		"tumble":
			Kept.arc(root, c, 14.0, -PI * 0.2, PI * 1.5, 20, ink, 4.0, true)
			root.draw_colored_polygon(PackedVector2Array([c + Vector2(14, -10), c + Vector2(20, 2), c + Vector2(6, 0)]), ink)
		"rain":
			for k in 5:
				var x := (k - 2) * 9.0
				root.draw_line(c + Vector2(x - 4, -18), c + Vector2(x + 2, 4), ink, 2.5, true)
				root.draw_colored_polygon(PackedVector2Array([c + Vector2(x + 3, 10), c + Vector2(x - 1, 2), c + Vector2(x + 6, 3)]), lit)
		_:
			Kept.disc(root, c, 12.0, ink)


func _tooltip(anchor: Rect2, title: String, desc: String, hint := "") -> void:
	var w := 300.0
	var lines := _wrap(desc, w - 20, 14)
	var h := 34.0 + lines.size() * 18.0 + (18.0 if hint != "" else 0.0)
	var r := Rect2(anchor.get_center().x - w * 0.5, anchor.position.y - h - 10, w, h)
	r.position.x = clampf(r.position.x, 8, root.size.x - w - 8)
	Kept.rect(root, r, Color(0.06, 0.05, 0.09, 0.96))
	Kept.rect(root, r, EDGE, false, 2.0)
	_text(r.position + Vector2(10, 22), title, 16, BONE, heading_font)
	for i in lines.size():
		_text(r.position + Vector2(10, 42 + i * 18), lines[i], 14, Color(1, 1, 1, 0.8))
	if hint != "":
		_text(r.position + Vector2(10, 42 + lines.size() * 18), hint, 13, GOLD)


func _wrap(text: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if body_font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out


func _open_talent_rows() -> int:
	if me.is_empty():
		return 0
	var n := 0
	for row in HeroClasses.TALENT_LEVELS.size():
		if int(me["level"]) >= HeroClasses.TALENT_LEVELS[row] and str(me["talents"][row]) == "":
			n += 1
	return n


func _draw_talents(size: Vector2) -> void:
	var cls: String = me.get("cls", "fighter")
	var c: Dictionary = HeroClasses.get_def(cls)
	var col: Color = c["color"]
	var w := 820.0
	var h := 560.0
	var r := Rect2(size.x * 0.5 - w * 0.5, maxf(8.0, size.y * 0.5 - h * 0.5 - 30), w, h)
	_panel(r, Color(0.08, 0.07, 0.11, 0.97))
	_text(r.position + Vector2(20, 34), "%s talents" % c["name"], 24, col.lightened(0.3), heading_font)
	_text(r.position + Vector2(20, 56), "One of three at levels 4, 8, 12, 16 and 20. Each one you take shows on your hero.",
		14, DIM)
	var rows: Array = c["talents"]
	TalentIcon.fallback_branch = "blade" if cls == "fighter" else ("arcane" if cls == "mage" else "cunning")
	for row in rows.size():
		var lvl: int = HeroClasses.TALENT_LEVELS[row]
		var taken: String = str(me.get("talents", ["", "", "", "", ""])[row])
		var open: bool = int(me.get("level", 1)) >= lvl and taken == ""
		var y := r.position.y + 72 + row * 94
		_text(Vector2(r.position.x + 20, y + 52), "Lv %d" % lvl, 16, GOLD if open else DIM, heading_font)
		for k in 3:
			var tdef: Dictionary = rows[row][k]
			var cr := Rect2(r.position.x + 80 + k * 244, y, 234, 86)
			var picked: bool = taken == tdef["id"]
			var bg := col.darkened(0.6) if picked else (DUSK.lightened(0.08) if open and cr.has_point(mouse) else DUSK)
			Kept.rect(root, cr, bg)
			Kept.rect(root, cr, GOLD if picked else (col if open else EDGE), false, 2.0)
			var on := col if (picked or open) else Color(0.35, 0.33, 0.4)
			Kept.rect(root, Rect2(cr.position + Vector2(8, 10), Vector2(52, 52)), on.darkened(0.2))
			TalentIcon.draw(root, tdef["id"], cr.position + Vector2(34, 36), 0.55, on)
			root.draw_set_transform(Vector2.ZERO)
			_text(cr.position + Vector2(68, 24), tdef["name"], 16, BONE if (picked or open) else DIM, heading_font)
			var lines := _wrap(tdef["desc"], 156, 13)
			for i in mini(lines.size(), 3):
				_text(cr.position + Vector2(68, 44 + i * 16), lines[i], 13, Color(1, 1, 1, 0.75 if (picked or open) else 0.4))
			if open:
				var rr := row
				var kk := k
				_hit(cr, func() -> void: game.send_talent(rr, kk))
	var close := Rect2(r.end.x - 52, r.position.y + 4, 48, 48)
	_text_c(close.get_center().x, close.position.y + 34, "x", 26, BONE)
	_hit(close, func() -> void: talents_open = false)


func _draw_shop(size: Vector2) -> void:
	var w := 640.0
	var h := 330.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5 - 40, w, h)
	_panel(r, Color(0.08, 0.07, 0.11, 0.97))
	var town: Dictionary = state.get("town", {})
	var near: bool = Skills.near_shop(game.ctrl.pos, town)
	var d: Dictionary = state.get("dir", {})
	var can := near or int(d.get("phase", -1)) == Director.Phase.CAMP
	var where := "at the market well or the Alchemist's door" if TownDefs.level(town, "alchemist") > 0 else "at the market well in the town square"
	_text(r.position + Vector2(20, 34), "The Alchemist", 24, Color("4fd1c5"), heading_font)
	_text(r.position + Vector2(20, 56), ("Open at the campfire, or " + where + ".") if can else "Come back to buy, " + where + ".",
		14, DIM if can else Color("ff8a8a"))
	_text(Vector2(r.end.x - 140, r.position.y + 34), "%d gold" % int(me.get("gold", 0)), 20, GOLD, heading_font)
	for i in PotionDefs.SHOP.size():
		var id: String = PotionDefs.SHOP[i]
		var pd := PotionDefs.get_def(id)
		var cr := Rect2(r.position.x + 20 + (i % 3) * 202, r.position.y + 72 + (i / 3) * 82, 192, 72)
		var price := TownDefs.potion_price(town, id)
		var afford: bool = int(me.get("gold", 0)) >= price and can
		Kept.rect(root, cr, DUSK.lightened(0.08) if afford and cr.has_point(mouse) else DUSK)
		Kept.rect(root, cr, EDGE, false, 2.0)
		PotionArt.draw_symbol(root, PotionDefs.symbol(id), cr.position + Vector2(32, 36), 18.0,
			pd["color"] if afford else Color(pd["color"], 0.35))
		_text(cr.position + Vector2(62, 28), pd["name"], 15, BONE if afford else DIM, heading_font)
		_text(cr.position + Vector2(62, 50), "%d gold" % price, 14, GOLD if afford else DIM)
		if cr.has_point(mouse):
			_tooltip(cr, pd["name"], pd["desc"])
		var pid := id
		_hit(cr, func() -> void: game.send_buy(pid))
	var close := Rect2(r.end.x - 52, r.position.y + 4, 48, 48)
	_text_c(close.get_center().x, close.position.y + 34, "x", 26, BONE)
	_hit(close, func() -> void: shop_open = false)


func _draw_help(size: Vector2) -> void:
	if Touch.on:
		_draw_touch_help(size)
		return
	var r := Rect2(size.x - 392, 150, 380, 420)
	_panel(r, Color(0.08, 0.07, 0.11, 0.9))
	var lines := ["Right-click: move, or attack a mob", "A + click: attack-move   H: hold position",
		"S (hold): stand down, to walk past a fight", "Q W E R: cast (click to aim, F2 quick cast)",
		"Ctrl + Q W E R: learn an ability", "1 2 3 4: drink a potion", "T: talents   B: Alchemist",
		"Space: call the next wave early, for gold", "F: build at a Town building's door",
		"C: camera to you   Y: lock camera", "Wheel: zoom   Arrows/edges: pan",
		"Keep the road fires lit: they heal you.", "Hold an unlit fire's ring to light it.",
		"Hold your corridor. Don't let the Town's buildings fall.", "F1: hide this"]
	_text(r.position + Vector2(16, 30), "How to play", 20, BONE, heading_font)
	for i in lines.size():
		_text(r.position + Vector2(16, 58 + i * 23), lines[i], 14, Color(1, 1, 1, 0.8))


func _draw_menu(size: Vector2) -> void:
	root.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	_hit(Rect2(Vector2.ZERO, size), Callable())
	var w := 460.0
	var h := 452.0
	var r := Rect2(size.x * 0.5 - w * 0.5, maxf(8.0, size.y * 0.5 - h * 0.5), w, h)
	_panel(r, Color(0.08, 0.07, 0.11, 0.97))
	var x := r.position.x + 24
	var inner := w - 48
	var y := r.position.y
	_text_c(r.get_center().x, y + 40, "Paused" if not Net.online else "Menu", 26, BONE)
	var back := Rect2(x, y + 58, inner, 44)
	_menu_button(back, "Back to the fight", false)
	_hit(back, func() -> void: set_menu(false))
	# Sound.
	y += 124
	_text(Vector2(x, y + 20), "Sound", 18, BONE, heading_font)
	var tog := Rect2(r.end.x - 24 - 120, y, 120, 30)
	_menu_button(tog, "On" if Sfx.sound_on else "Off", Sfx.sound_on)
	_hit(tog, func() -> void: Sfx.set_sound_on(not Sfx.sound_on))
	y += 38
	for row: Array in [["music", "Music"], ["sfx", "Effects"], ["ui", "Buttons"]]:
		_slider(row[0], row[1], Rect2(x, y, inner, 38))
		y += 40
	# Layout.
	y += 10
	_text(Vector2(x, y + 20), "Controls", 18, BONE, heading_font)
	_text(Vector2(x + 96, y + 20), "Auto picks touch on phones and tablets", 13, DIM)
	y += 30
	var bw := (inner - 16) / 3.0
	for i in 3:
		var m: String = Touch.MODES[i]
		var b := Rect2(x + i * (bw + 8), y, bw, 40)
		_menu_button(b, ["Auto", "Touch", "Mouse"][i], Touch.mode == m)
		_hit(b, func() -> void: Touch.set_mode(m))
	y += 58
	var leave := Rect2(x, y, inner, 40)
	Kept.rect(root, leave, Color("5a2a2a") if leave.has_point(mouse) else Color("3a2228"))
	_text_c(leave.get_center().x, leave.position.y + 27, "Leave the game", 17, BONE, body_font)
	_hit(leave, func() -> void:
		get_tree().paused = false
		Net.back_to_menu())


func _menu_button(b: Rect2, label: String, lit: bool) -> void:
	var bg := GOLD.darkened(0.35) if lit else DUSK
	Kept.rect(root, b, bg.lightened(0.1) if b.has_point(mouse) else bg)
	Kept.rect(root, b, GOLD if lit else EDGE, false, 2.0)
	_text_c(b.get_center().x, b.position.y + b.size.y * 0.5 + 6, label, 17, BONE, body_font)


## One volume row: the name, a track to tap or drag, and the percent.
func _slider(key: String, label: String, row: Rect2) -> void:
	var on: bool = Sfx.sound_on
	_text(row.position + Vector2(0, 25), label, 15, BONE if on else DIM)
	var track := Rect2(row.position.x + 96, row.position.y + 15, row.size.x - 96 - 56, 8)
	sliders[key] = track
	var v: float = Sfx.levels[key]
	root.draw_rect(track, Color(0, 0, 0, 0.6))
	root.draw_rect(Rect2(track.position, Vector2(track.size.x * v, track.size.y)), GOLD if on else DIM)
	var knob := Vector2(track.position.x + track.size.x * v, track.get_center().y)
	Kept.disc(root, knob, 13.0 if Touch.on else 10.0, BONE if slider_key == key or knob.distance_to(mouse) < 14.0 else Color("d8d2c8"))
	_text(Vector2(row.end.x - 46, row.position.y + 25), "%d%%" % roundi(v * 100.0), 14, DIM, body_font,
		HORIZONTAL_ALIGNMENT_RIGHT, 46)
	# A tall hit area, so a thumb can grab the thin track.
	var area := Rect2(track.position.x - 14, row.position.y, track.size.x + 28, row.size.y)
	_hit(area, func() -> void:
		slider_key = key
		slider_move(mouse))


## Moves the slider being dragged to `p` (HUD units).
func slider_move(p: Vector2) -> void:
	if slider_key == "" or not sliders.has(slider_key):
		return
	var track: Rect2 = sliders[slider_key]
	Sfx.set_level(slider_key, (p.x - track.position.x) / track.size.x)


func slider_end() -> void:
	if slider_key == "":
		return
	# A sample at the new level, then keep it.
	if slider_key == "sfx":
		Sfx.play("kill", 0.6)
	elif slider_key == "ui":
		Sfx.ui("click", 0.6)
	slider_key = ""
	Sfx.save_settings()


func _draw_end(size: Vector2) -> void:
	root.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	var r := Rect2(size.x * 0.5 - 300, size.y * 0.5 - 200, 600, 400)
	_panel(r, Color(0.08, 0.07, 0.11, 0.97))
	_text_c(r.get_center().x, r.position.y + 60, end_screen["title"], 40, GOLD)
	_text_c(r.get_center().x, r.position.y + 92, end_screen["sub"], 16, DIM, body_font)
	var hs: Dictionary = state.get("heroes", {})
	var y := r.position.y + 140
	for s: int in hs:
		var h: Dictionary = hs[s]
		var txt := "%s (%s, level %d)   %d kills · %d damage · %d deaths" % [h["name"], HeroClasses.get_def(h["cls"])["name"],
			h["level"], h["kills"], h["dmg"], h["deaths"]]
		_text_c(r.get_center().x, y, txt, 16, HeroClasses.get_def(h["cls"])["color"].lightened(0.3), body_font)
		y += 30
	var d: Dictionary = state.get("dir", {})
	_text_c(r.get_center().x, y + 10, "Reached chapter %d, wave %d" % [int(d.get("chapter", 0)) + 1, int(d.get("wave", 0)) + 1], 15, DIM, body_font)
	var b := Rect2(r.get_center().x - 110, r.end.y - 70, 220, 44)
	Kept.rect(root, b, DUSK.lightened(0.12) if b.has_point(mouse) else DUSK)
	_text_c(b.get_center().x, b.position.y + 29, "Back to the Town", 18, BONE, body_font)
	_hit(Rect2(Vector2.ZERO, size), Callable())
	_hit(b, func() -> void: Net.back_to_menu())


func _draw_banners(size: Vector2) -> void:
	for b: Dictionary in banners:
		var k := float(b["t"]) / float(b["dur"])
		var a := clampf(minf(float(b["t"]) / 0.3, (float(b["dur"]) - float(b["t"])) / 0.6), 0.0, 1.0)
		var y := size.y * 0.3 - (1.0 - minf(1.0, float(b["t"]) * 4.0)) * 20.0
		var col: Color = b["color"]
		root.draw_rect(Rect2(0, y - 52, size.x, 84), Color(0, 0, 0, 0.35 * a))
		_text_c(size.x * 0.5, y, b["title"], 44, Color(col.lightened(0.2), a))
		_text_c(size.x * 0.5, y + 26, b["sub"], 17, Color(1, 1, 1, 0.8 * a), body_font)
		k = k
	for c: Dictionary in callouts:
		var a := clampf((float(c["dur"]) - float(c["t"])) / 0.4, 0.0, 1.0)
		var pop := 1.0 + maxf(0.0, 0.25 - float(c["t"])) * 1.6
		_text_c(size.x * 0.5, size.y * 0.42, c["text"], int(float(c["size"]) * pop), Color(c["color"], a))


func _draw_card(size: Vector2) -> void:
	if card.is_empty():
		return
	var a := clampf(minf(float(card["t"]) / 0.3, (float(card["dur"]) - float(card["t"])) / 0.5), 0.0, 1.0)
	var big: bool = card["boss"]
	var w := 520.0 if big else 380.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.52, w, 120 if big else 88)
	Kept.rect(root, r, Color(0.05, 0.04, 0.07, 0.9 * a))
	Kept.rect(root, r, Color(card["color"].lightened(0.3), a), false, 3.0)
	var look_r := Rect2(r.position + Vector2(10, 8), Vector2(r.size.y - 16, r.size.y - 16))
	EnemyLook.draw(root, card["kind"], look_r, Color(card["color"], a), t)
	root.draw_set_transform(Vector2.ZERO)
	_text(r.position + Vector2(r.size.y + 6, 40), card["name"], 30 if big else 22, Color(card["color"].lightened(0.45), a), heading_font)
	var lines := _wrap(card["lore"], w - r.size.y - 20, 15)
	for i in lines.size():
		_text(r.position + Vector2(r.size.y + 6, 64 + i * 19), lines[i], 15, Color(1, 1, 1, 0.8 * a))


func _draw_toasts(size: Vector2) -> void:
	for i in toasts.size():
		var tt: Dictionary = toasts[i]
		var a := clampf((float(tt["dur"]) - float(tt["t"])) / 0.5, 0.0, 1.0)
		_text_c(size.x * 0.5, size.y - 140 - i * 22, tt["text"], 16, Color(1, 1, 1, a), body_font)


# --- Minimap ----------------------------------------------------------------------

func _bake_minimap() -> void:
	var m: MapData = game.map
	var img := Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	for y in m.h:
		for x in m.w:
			img.set_pixel(x, y, Color(0.32, 0.3, 0.36, 0.95) if m.walk[y * m.w + x] == 1 else Color(0.06, 0.05, 0.08, 0.85))
	minimap_tex = ImageTexture.create_from_image(img)


func _draw_minimap(size: Vector2) -> void:
	var m: MapData = game.map
	var s := (150.0 if Touch.on else 200.0) / MapData.SIZE.x
	var r := Rect2(size.x - 212, size.y - 182, MapData.SIZE.x * s, MapData.SIZE.y * s)
	if Touch.on:
		# Top right, under the page's full screen button: the thumbs own the bottom.
		r.position = Vector2(size.x - r.size.x - 12, 84)
	Kept.rect(root, r.grow(4), Color(0, 0, 0, 0.6))
	root.draw_texture_rect(minimap_tex, r, false)
	for lane in 3:
		var p := r.position + MapData.portal(lane) * s
		Kept.disc(root, p, 4.0, Color("8a7dff") if lane in game.active_lanes() else Color(0.3, 0.3, 0.3))
	var town: Dictionary = state.get("town", {})
	var ruins: Dictionary = state.get("ruins", {})
	for id: String in TownDefs.ids():
		var built := TownDefs.level(town, id) > 0
		var bp := r.position + (TownDefs.foot(id) + Vector2(0, -60)) * s
		var col := Color("ff5a3d") if ruins.has(id) else (Color("ffd98a") if built else Color(0.45, 0.42, 0.5))
		root.draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), col)
	for f: Array in state.get("fires", []):
		var st: int = f[1]
		Kept.disc(root, r.position + (f[0] as Vector2) * s, 4.0,
			Color("f0a23c") if st == 1 else (Color(0.25, 0.22, 0.3) if st == 2 else Color(0.6, 0.58, 0.66)))
	for mob: Dictionary in game.view.mobs.values():
		var col := Color("e04848")
		var rad := 1.5
		if mob["rank"] == "elite":
			col = Color("ffb347")
			rad = 3.0
		elif mob["rank"] == "boss":
			col = Color("ff6a3d")
			rad = 5.0
		root.draw_rect(Rect2(r.position + (mob["pos"] as Vector2) * s - Vector2(rad, rad) * 0.5, Vector2(rad, rad)), col)
	for hp: Dictionary in game.view.heroes.values():
		Kept.disc(root, r.position + (hp["pos"] as Vector2) * s, 4.0, HeroClasses.get_def(hp["cls"])["color"])
	var cam: Camera2D = game.cam
	var vs := root.get_viewport_rect().size / cam.zoom
	var vr := Rect2((cam.position - vs * 0.5) * s + r.position, vs * s)
	Kept.rect(root, vr, Color(1, 1, 1, 0.6), false, 1.0, 0)
	_hit(r, func() -> void:
		game.cam_pos = (mouse - r.position) / s)


# --- Touch layout -------------------------------------------------------------------

## The phone version of the bottom bar: HP, XP, gold, the potion belt and the
## talent and Alchemist buttons, in a strip between the thumbs.
func _draw_touch_bottom(size: Vector2) -> void:
	if me.is_empty():
		return
	var r := pad.strip_rect(size)
	_panel(r)
	var hp_r := Rect2(r.position + Vector2(12, 8), Vector2(262, 16))
	_bar(hp_r, float(me["hp"]) / float(me["max_hp"]), Color("5ad06a") if me["alive"] else Color("444"))
	_text(hp_r.position + Vector2(6, 13), "%d / %d" % [me["hp"], me["max_hp"]], 13, BONE)
	_bar(Rect2(r.position + Vector2(12, 26), Vector2(262, 5)), float(me["xp"]) / maxf(1.0, float(me["xp_next"])), XP)
	_text(r.position + Vector2(284, 24), "Lv %d" % me["level"], 17, GOLD, heading_font)
	Kept.disc(root, r.position + Vector2(352, 17), 7.0, GOLD)
	_text(r.position + Vector2(364, 24), str(me["gold"]), 17, GOLD, heading_font)
	if not me["alive"]:
		_text_c(r.get_center().x, r.position.y - 14, "Back in %d" % ceili(float(me["respawn"])), 20, Color("ff8a8a"))
	if str(me["cls"]) == "flow":
		_text(r.position + Vector2(284, -8), "Flow %d" % me["flow"], 15, GOLD, heading_font)
	var belt: Array = me["belt"]
	for i in 4:
		var br := pad.potion_rect(size, i)
		var down := ("potion%d" % i) in pad.pressed_fx.values()
		Kept.rect(root, br, DUSK.lightened(0.15) if down else DUSK)
		var b: Array = belt[i]
		if str(b[0]) != "" and int(b[1]) > 0:
			var pd := PotionDefs.get_def(b[0])
			PotionArt.draw_symbol(root, PotionDefs.symbol(b[0]), br.get_center(), 13.0, pd["color"])
			if int(b[1]) > 1:
				_text(br.position + Vector2(br.size.x - 12, 14), str(b[1]), 13, BONE, heading_font)
		Kept.rect(root, br, EDGE, false, 2.0)
	var open_rows := _open_talent_rows()
	var tb := Rect2(r.position.x + 224, r.position.y + 34, 100, 44)
	var glow := open_rows > 0 and fmod(t, 1.0) < 0.6
	Kept.rect(root, tb, GOLD.darkened(0.2) if glow else DUSK)
	Kept.rect(root, tb, EDGE, false, 2.0)
	_text_c(tb.get_center().x, tb.position.y + 28, "Talents" + (" !" if open_rows > 0 else ""), 16, INK if glow else BONE, body_font)
	_hit(tb, func() -> void:
		talents_open = not talents_open
		shop_open = false)
	var sb := Rect2(r.position.x + 330, r.position.y + 34, 100, 44)
	Kept.rect(root, sb, DUSK)
	Kept.rect(root, sb, EDGE, false, 2.0)
	_text_c(sb.get_center().x, sb.position.y + 28, "Alchemist", 16, BONE, body_font)
	_hit(sb, func() -> void:
		shop_open = not shop_open
		talents_open = false)


## Menu and help buttons under the party list, for a mouse or a thumb. A
## keyboard also gets them from Esc and F1.
func _draw_menu_buttons() -> void:
	var n := maxi(1, (state.get("heroes", {}) as Dictionary).size())
	var y := 12.0 + 64.0 * n
	var mb := Rect2(12, y, 48 if Touch.on else 122, 44)
	_panel(mb, PANEL.lightened(0.08) if mb.has_point(mouse) else PANEL)
	if Touch.on:
		root.draw_rect(Rect2(mb.position + Vector2(16, 12), Vector2(5, 20)), BONE)
		root.draw_rect(Rect2(mb.position + Vector2(27, 12), Vector2(5, 20)), BONE)
	else:
		_text_c(mb.get_center().x, mb.position.y + 28, "Menu  (Esc)", 15, BONE, body_font)
	_hit(mb, func() -> void: set_menu(not menu_open))
	var hb := Rect2(mb.end.x + 8, y, 48, 44)
	_panel(hb, Color(0.2, 0.17, 0.27, 0.92) if help_open or hb.has_point(mouse) else PANEL)
	_text_c(hb.get_center().x, hb.position.y + 32, "?", 24, BONE)
	_hit(hb, func() -> void: help_open = not help_open)


func _draw_touch_help(_size: Vector2) -> void:
	var n := maxi(1, (state.get("heroes", {}) as Dictionary).size())
	var lines := ["Left thumb: drag anywhere on the left to move", "Tap the field: walk there, or attack a mob",
		"Attack: hit the nearest mob", "Q W E R: tap to cast at the nearest mob,", "    or drag off the button to aim, then let go",
		"Drag back onto the button to cancel", "Gold +: learn or rank up an ability", "Potions, Talents, Alchemist: tap",
		"Call it: the next wave early, for gold", "Town buildings: walk to the door, tap Build",
		"Road fires heal you. Stand in an unlit one's ring to light it", "Two fingers: pinch to zoom",
		"Hold your corridor. Don't let the Town's buildings fall."]
	var r := Rect2(12, 12.0 + 64.0 * n + 54.0, 400, 50 + lines.size() * 22)
	_panel(r, Color(0.08, 0.07, 0.11, 0.9))
	_text(r.position + Vector2(16, 30), "How to play", 20, BONE, heading_font)
	for i in lines.size():
		_text(r.position + Vector2(16, 56 + i * 22), lines[i], 14, Color(1, 1, 1, 0.82))
	_hit(r, func() -> void: help_open = false)
