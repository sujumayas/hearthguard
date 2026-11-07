extends Node
## The feel of the game, read from the rts-playtest-lab preset this game is
## built on (Dota_2.json, the "dota" base with its diff). The lab measures in
## its own units; WORLD turns its distances and speeds into this map's
## pixels, so the timings stay exactly as exported and only the space grows.

const PRESET := "res://Dota_2.json"
## Lab units to pixels. The lab's hero walks 100 a second; ours 250.
const WORLD := 2.5

var config := {}


func _ready() -> void:
	var f := FileAccess.open(PRESET, FileAccess.READ)
	if f != null:
		var data: Variant = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			config = data.get("config", {})
	if config.is_empty():
		push_warning("Tuning: %s missing, using built-in defaults" % PRESET)


## A value at `path` ("combat.cooldownMs"), or `fallback`.
func get_v(path: String, fallback: Variant) -> Variant:
	var parts := path.split(".")
	var node: Variant = config
	for p in parts:
		if not (node is Dictionary) or not (node as Dictionary).has(p):
			return fallback
		node = node[p]
	return node


func sec(path: String, fallback_ms: float) -> float:
	return float(get_v(path, fallback_ms)) / 1000.0


func dist(path: String, fallback: float) -> float:
	return float(get_v(path, fallback)) * WORLD


# The values the game reads, by name.
func tick_rate() -> int: return int(get_v("sim.tickRate", 30))
func hero_speed() -> float: return dist("movement.speed", 100)
func turn_180() -> float: return sec("movement.turn180Ms", 160)
func move_turn_limit() -> float: return deg_to_rad(float(get_v("movement.moveTurnLimitDeg", 12)))
func attack_cooldown() -> float: return sec("combat.cooldownMs", 630)
func windup() -> float: return sec("combat.windupMs", 0)
func backswing() -> float: return sec("combat.backswingMs", 400)
func backswing_cancel() -> bool: return bool(get_v("combat.backswingCancel", true))
func ranged_range() -> float: return dist("combat.range", 200)
func projectile_speed() -> float: return dist("combat.projectileSpeed", 330)
func cleave_arc() -> float: return deg_to_rad(float(get_v("combat.cleaveArcDeg", 120)))
func face_tolerance() -> float: return deg_to_rad(float(get_v("combat.faceToleranceDeg", 11)))
func base_damage() -> float: return float(get_v("combat.damage", 30))
func cast_point() -> float: return sec("abilities.castPointMs", 350)
func cast_backswing() -> float: return sec("abilities.castBackswingMs", 500)
func dash_distance() -> float: return dist("abilities.dashDistance", 180)
func aoe_delay() -> float: return sec("abilities.aoeDelayMs", 600)
func hit_stop() -> float: return sec("juice.hitStopMs", 10)
func shake() -> float: return float(get_v("juice.shake", 0.25))
func flash() -> float: return sec("juice.flashMs", 50)
func damage_numbers() -> bool: return bool(get_v("juice.damageNumbers", true))
func particles() -> float: return float(get_v("juice.particles", 0.45))
func volume() -> float: return float(get_v("juice.volume", 0.5))
func aggro_radius() -> float: return dist("scenario.aggroRadius", 200)
func wave_gap() -> float: return float(get_v("scenario.waveGapS", 12))
func hero_hp() -> float: return float(get_v("scenario.heroHp", 700))
func hero_respawn() -> float: return float(get_v("scenario.heroRespawnS", 6))
func acquire_range() -> float: return dist("input.acquireRange", 220)
func auto_acquire() -> bool: return bool(get_v("input.autoAcquire", true))
func edge_pan() -> bool: return bool(get_v("camera.edgePan", true))
