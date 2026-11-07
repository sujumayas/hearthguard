extends Node
## MatchRPG's sounds and music, played from a pool. A horde dying at once
## would play the same sound a hundred times, so each sound plays at most
## MAX_PER_WINDOW times in WINDOW seconds, a little louder for the crowd.

const DIR := "res://assets/audio/"
const POOL := 24
const WINDOW := 0.06
const MAX_PER_WINDOW := 3

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _recent := {}
var _music: AudioStreamPlayer
var _music_fade: AudioStreamPlayer
var _music_name := ""
var music_on := true
var master := 0.8


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music_fade = AudioStreamPlayer.new()
	add_child(_music)
	add_child(_music_fade)
	master = clampf(Tuning.volume() * 1.6, 0.0, 1.0)


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + sound + ".wav"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


## Plays `sound` (a file name in assets/audio, no extension).
func play(sound: String, volume := 1.0, pitch := 1.0) -> void:
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
	p.volume_db = linear_to_db(maxf(0.001, volume * master))
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


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
