class_name Mob
extends RefCounted
## One mob on the host. Plain fields: there can be hundreds, and MobSim
## steps them all in one loop.

enum State { MARCH, CHASE, HEARTH, CHARGE_WIND, CHARGING, BURROWED, FIRE, DEAD }

var id := 0
var kind := ""
var kidx := 0
var rank := "mob"
var def: Dictionary
var lane := 0

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var knock := Vector2.ZERO
var radius := 16.0
var speed := 150.0
var flip := false

var hp := 1.0
var max_hp := 1.0
var atk := 1.0
var interval := 2.0
var phys := 1.0
var mag := 1.0
var xp := 1.0
var gold := 1

var state := State.MARCH
var target := -1
## The road fire it is bashing (an index into Sim.fires), in State.FIRE.
var fire := -1
var token := false
var atk_cd := 0.0
## Seconds left in the current attack's wind-up (0 when not attacking), and
## its length, so the view can show the swing.
var wind := 0.0
var wind_len := 0.35
var think_t := 0.0
var chase_t := 0.0
var orbit := 1.0
var var_speed := 1.0
var trait_cd := 0.0
var charge_dir := Vector2.ZERO
var charge_t := 0.0
var charge_hit := {}

# Statuses, in seconds left.
var slow_t := 0.0
var slow := 0.0
var stun_t := 0.0
var freeze_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var burn_src := -1
var poison_t := 0.0
var poison_dps := 0.0
var poison_src := -1
var sunder_t := 0.0
var sunder := 0.0
var mark_t := 0.0
var mark := 0.0
var blind_t := 0.0
var flash_t := 0.0
var untargetable := false
var hidden := false
var enraged := false
## Hit on its first damage (First Blood reads this).
var full := true
## Amdusias' song: "phys" or "mag" it shrugs off, or "".
var immune := ""
## Elite and boss brain state.
var brain: Dictionary = {}
## Who has hurt it, for the boss's threat table: slot to damage.
var threat := {}
## Seconds a hit keeps this mob on the hero who hit it, at any distance.
var provoke_t := 0.0


func alive() -> bool:
	return state != State.DEAD


func hp_frac() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func slow_mult() -> float:
	var m := 1.0
	if slow_t > 0.0:
		m *= 1.0 - slow
	if blind_t > 0.0:
		m *= 0.6
	return m


func disabled() -> bool:
	return stun_t > 0.0 or freeze_t > 0.0
