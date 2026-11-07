extends Node
## Touch mode: on for phones and tablets, and as soon as a finger touches
## the screen; off again when a real mouse clicks. The HUD reads it to swap
## the desktop bar for the joystick and the thumb buttons.
##
## The pause menu can force one layout ("touch" or "desktop") instead of
## "auto"; the choice is kept in user://settings.cfg. `?touch=1` in the page
## address forces touch for that visit (testing on a desktop).

signal changed(on: bool)

const SETTINGS := "user://settings.cfg"
const MODES := ["auto", "touch", "desktop"]

var on := false
## "auto", "touch" or "desktop".
var mode := "auto"
var forced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		var m := str(cfg.get_value("display", "layout", "auto"))
		mode = m if m in MODES else "auto"
	if OS.has_feature("web"):
		var search := str(JavaScriptBridge.eval("window.location.search", true))
		if search.contains("touch=1"):
			mode = "touch"
	elif "--touch" in OS.get_cmdline_user_args():
		mode = "touch"
	forced = mode != "auto"
	on = _detect() if mode == "auto" else mode == "touch"


## What "auto" picks before anyone touches anything.
func _detect() -> bool:
	if OS.has_feature("web"):
		var coarse := bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches", true))
		return coarse or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return OS.has_feature("mobile")


func _input(event: InputEvent) -> void:
	if forced:
		return
	if event is InputEventScreenTouch and not on:
		_switch(true)
	elif event is InputEventMouseButton and event.pressed and on \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		_switch(false)


## Sets the layout from the pause menu and remembers it.
func set_mode(m: String) -> void:
	if not m in MODES:
		return
	mode = m
	forced = m != "auto"
	_switch(_detect() if m == "auto" else m == "touch")
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("display", "layout", m)
	cfg.save(SETTINGS)


func _switch(v: bool) -> void:
	on = v
	changed.emit(v)


## How much bigger the HUD draws on a small screen. A phone held sideways is
## about 390 CSS pixels tall, so the 720-pixel layout would come out with
## 7-pixel text; this scales it up to fit a 600-unit-tall layout instead.
func hud_scale(view_h: float) -> float:
	if not on:
		return 1.0
	var dpr := maxf(1.0, DisplayServer.screen_get_scale())
	var css_h := float(get_window().size.y) / dpr
	return clampf(view_h / maxf(600.0, css_h * 1.5), 1.0, 1.2)


## A vibration tick on phones that have one. Browsers ignore it elsewhere.
func buzz(ms := 12) -> void:
	if on:
		Input.vibrate_handheld(ms)
