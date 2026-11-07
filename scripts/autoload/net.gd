extends Node
## The lobby and the connection. One player hosts (the desktop build: a
## browser can't listen for connections), up to two more join by address,
## from the desktop build or the browser. WebSocket for both, so a web
## client reaches a desktop host. The host runs the game (Sim); clients
## draw it and send what their own hero does.
##
## Solo is the same game with no one else: Godot's offline peer, where this
## machine is the host.

signal lobby_changed
signal failed(message: String)
signal closed

const PORT := 7350
const MAX_PLAYERS := 3

## Peer id to {name, cls, slot, ready}.
var players := {}
var my_name := "Hero"
var my_cls := "fighter"
var online := false
var seed_value := 0
var in_game := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: failed.emit("Couldn't reach the host."))
	multiplayer.server_disconnected.connect(_on_server_gone)
	var saved := _load_prefs()
	my_name = saved.get("name", "Hero%d" % (randi() % 90 + 10))
	my_cls = saved.get("cls", "fighter")


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func solo() -> void:
	leave()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	players = {1: {"name": my_name, "cls": my_cls, "slot": 0, "ready": true}}
	lobby_changed.emit()


func host(port := PORT) -> String:
	leave()
	if OS.has_feature("web"):
		return "A browser can't host. Host from the desktop build, and join it from here."
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		return "Couldn't open port %d (%s)." % [port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	online = true
	players = {1: {"name": my_name, "cls": my_cls, "slot": 0, "ready": true}}
	lobby_changed.emit()
	return ""


func join(address: String) -> String:
	leave()
	var url := address.strip_edges()
	if url == "":
		url = "127.0.0.1"
	# A bare address ("192.168.1.20") gets ws:// and the game's port. A full
	# URL ("wss://name.trycloudflare.com") is used as typed: a tunnel or a
	# TLS proxy picks its own port.
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		url = "ws://" + url
		if url.count(":") < 2:
			url += ":%d" % PORT
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		return "Couldn't connect to %s (%s)." % [url, error_string(err)]
	multiplayer.multiplayer_peer = peer
	online = true
	players = {}
	return ""


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	online = false
	in_game = false


func set_identity(name_: String, cls: String) -> void:
	my_name = name_.strip_edges().substr(0, 16)
	if my_name == "":
		my_name = "Hero"
	my_cls = cls
	_save_prefs()
	if players.is_empty():
		return
	if is_host():
		_set_player(1, my_name, my_cls)
	else:
		_rpc_set.rpc_id(1, my_name, my_cls)


func _on_connected() -> void:
	_rpc_register.rpc_id(1, my_name, my_cls)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	players.erase(id)
	_broadcast()
	if in_game:
		var g := get_tree().current_scene
		if g != null and g.has_method("peer_left"):
			g.peer_left(id)


func _on_server_gone() -> void:
	players = {}
	online = false
	closed.emit()


@rpc("any_peer", "reliable")
func _rpc_register(name_: String, cls: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game:
		_rpc_rejected.rpc_id(id, "The game has already started.")
		return
	var used := []
	for p: Dictionary in players.values():
		used.append(p["slot"])
	var slot := -1
	for s in MAX_PLAYERS:
		if s not in used:
			slot = s
			break
	if slot < 0:
		_rpc_rejected.rpc_id(id, "The game is full (3 players).")
		return
	players[id] = {"name": name_.substr(0, 16), "cls": cls, "slot": slot, "ready": true}
	_broadcast()


@rpc("authority", "reliable")
func _rpc_rejected(message: String) -> void:
	failed.emit(message)
	leave()


@rpc("any_peer", "reliable")
func _rpc_set(name_: String, cls: String) -> void:
	if is_host():
		_set_player(multiplayer.get_remote_sender_id(), name_, cls)


func _set_player(id: int, name_: String, cls: String) -> void:
	if not players.has(id):
		return
	players[id]["name"] = name_.substr(0, 16)
	if HeroClasses.CLASSES.has(cls):
		players[id]["cls"] = cls
	_broadcast()


func _broadcast() -> void:
	if online:
		_rpc_lobby.rpc(players)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _rpc_lobby(p: Dictionary) -> void:
	players = p
	lobby_changed.emit()


## Slot to {name, cls, peer}: who plays which corridor.
func slots() -> Dictionary:
	var out := {}
	for id: int in players:
		var p: Dictionary = players[id]
		out[int(p["slot"])] = {"name": p["name"], "cls": p["cls"], "peer": id}
	return out


func my_slot() -> int:
	var p: Dictionary = players.get(my_id(), {})
	return int(p.get("slot", 0))


func start_game() -> void:
	if not is_host():
		return
	seed_value = randi()
	in_game = true
	if online:
		_rpc_start.rpc(seed_value, players)
	_rpc_start(seed_value, players)


@rpc("authority", "reliable")
func _rpc_start(s: int, p: Dictionary) -> void:
	seed_value = s
	players = p
	in_game = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func back_to_menu() -> void:
	leave()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _save_prefs() -> void:
	var f := FileAccess.open("user://prefs.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": my_name, "cls": my_cls}))


func _load_prefs() -> Dictionary:
	var f := FileAccess.open("user://prefs.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
