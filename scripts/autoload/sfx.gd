extends Node
## MatchRPG's sounds and music, played from a pool. A horde dying at once
## would play the same sound a hundred times, so each sound plays at most
## MAX_PER_WINDOW times in WINDOW seconds, a little louder for the crowd.
##
## Music, sounds and UI clicks each go through their own audio bus, so the
## pause menu can turn each one up or down. The choice is kept in
## user://settings.cfg.

const DIR := "res://assets/audio/"
const POOL := 24
const WINDOW := 0.06
const MAX_PER_WINDOW := 3
const SETTINGS := "user://settings.cfg"
const BUSES := {"music": "Music", "sfx": "SFX", "ui": "UI"}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _recent := {}
var _music: AudioStreamPlayer
var _music_fade: AudioStreamPlayer
var _music_name := ""
var music_on := true
var master := 0.8
var sound_on := true
var levels := {"music": 1.0, "sfx": 1.0, "ui": 1.0}


func _ready() -> void:
	# Keeps playing under the pause menu, so its sliders can be heard.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key: String in BUSES:
		if AudioServer.get_bus_index(BUSES[key]) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, BUSES[key])
			AudioServer.set_bus_send(i, "Master")
	_music = AudioStreamPlayer.new()
	_music_fade = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music_fade.bus = "Music"
	add_child(_music)
	add_child(_music_fade)
	master = clampf(Tuning.volume() * 1.6, 0.0, 1.0)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		sound_on = bool(cfg.get_value("sound", "on", true))
		for key: String in levels:
			levels[key] = clampf(float(cfg.get_value("sound", key, 1.0)), 0.0, 1.0)
	_apply()


## Sound on or off for everything.
func set_sound_on(v: bool) -> void:
	sound_on = v
	_apply()
	_save()


## `key` is "music", "sfx" or "ui"; `v` runs from 0 to 1.
func set_level(key: String, v: float) -> void:
	levels[key] = clampf(v, 0.0, 1.0)
	_apply()


## Writes the sound settings. The menu calls it when a slider is let go.
func save_settings() -> void:
	_save()


func _apply() -> void:
	AudioServer.set_bus_mute(0, not sound_on)
	for key: String in BUSES:
		var i := AudioServer.get_bus_index(BUSES[key])
		var v: float = levels[key]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("sound", "on", sound_on)
	for key: String in levels:
		cfg.set_value("sound", key, levels[key])
	cfg.save(SETTINGS)


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + sound + ".wav"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


## Plays `sound` (a file name in assets/audio, no extension).
func play(sound: String, volume := 1.0, pitch := 1.0, bus := "SFX") -> void:
	var s := _stream(sound)
	if s == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var r: Array = _recent.get(sound, [])
	while not r.is_empty() and now - float(r[0]) > WINDOW:
		r.pop_front()
	if r.size() >= MAX_PER_WINDOW:
		return
	r.append(now)
	_recent[sound] = r
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.bus = bus
	p.volume_db = linear_to_db(maxf(0.001, volume * master))
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


## A button click or a "can't do that", on the UI bus.
func ui(sound: String, volume := 1.0) -> void:
	play(sound, volume, 1.0, "UI")


## Crossfades to music track `track` ("music_forest", "music_forest_boss").
func music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	var s := _stream(track)
	var old := _music
	_music = _music_fade
	_music_fade = old
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.tween_callback(old.stop)
	if s == null or not music_on:
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", linear_to_db(0.45 * master), 1.2)


func stop_music() -> void:
	_music_name = ""
	_music.stop()
	_music_fade.stop()
