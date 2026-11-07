extends Node
## Two (or three) copies of the game on one machine: one hosts, the others
## join over WebSocket, and each prints what it sees. Checks the lobby,
## the start, snapshots, events and commands.
##   godot --headless --path . res://tests/net_test.tscn -- --role=host --players=2
##   godot --headless --path . res://tests/net_test.tscn -- --role=client --cls=mage

var role := "host"
var want := 2
var t := 0.0
var started := false
var printed := 0.0


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	role = args.get("role", "host")
	want = int(args.get("players", "2"))
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	Net.set_identity(role.capitalize(), args.get("cls", "archer" if role == "host" else "mage"))
	if role == "host":
		print("host: ", Net.host())
	else:
		await get_tree().create_timer(1.0).timeout
		print("client: ", Net.join("127.0.0.1"))


func _process(delta: float) -> void:
	t += delta
	if role == "host" and not started and Net.players.size() >= want:
		started = true
		print("host: starting with ", Net.players.size(), " players")
		Net.start_game()
	var g := get_tree().current_scene
	if g != null and g.has_method("send_attack") and t - printed > 5.0:
		printed = t
		var hs: Dictionary = g.state.get("heroes", {})
		var desc := []
		for s: int in hs:
			desc.append("%s L%d k%d" % [hs[s]["name"], hs[s]["level"], hs[s]["kills"]])
		print("%s t=%.0f slot=%d mobs_seen=%d lanes=%s heroes=%s ctrl=%s" % [role, t, g.my_slot, g.view.mobs.size(),
			g.active_lanes(), ", ".join(desc), g.ctrl.pos.round()])
	if t > float(OS.get_environment("NET_TEST_SECS") if OS.get_environment("NET_TEST_SECS") != "" else "45"):
		get_tree().quit()
