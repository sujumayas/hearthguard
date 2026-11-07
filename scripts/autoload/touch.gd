extends Node
## Touch mode: on for phones and tablets, and as soon as a finger touches
## the screen; off again when a real mouse clicks. The HUD reads it to swap
## the desktop bar for the joystick and the thumb buttons.
##
## `?touch=1` in the page address forces it on (testing on a desktop).

signal changed(on: bool)

var on := false
var forced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		var search := str(JavaScriptBridge.eval("window.location.search", true))
		forced = search.contains("touch=1")
		var coarse := bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches", true))
		on = forced or coarse or OS.has_feature("web_android") or OS.has_feature("web_ios")
	else:
		on = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
		forced = "--touch" in OS.get_cmdline_user_args()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not on:
		_switch(true)
	elif event is InputEventMouseButton and event.pressed and on and not forced \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		_switch(false)


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
