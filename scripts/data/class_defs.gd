class_name HeroClasses
extends RefCounted
## The four heroes. Three are MatchRPG's classes, drawn with its HeroArt
## branches (Fighter = Blade, Mage = Arcane, Flow = MatchRPG's Rogue, whose
## passive is Flow); the Archer is new, drawn in the same hand ("hunt").
##
## Growth is Warcraft III's: every level gives a point to put in Q, W or E
## (ranks 1-4, at hero levels 1/3/5/7) or R (ranks 1-3, at 6/11/16).
## On top sit MatchRPG's talent rows: at each of TALENT_LEVELS one talent of
## three. Each talent taken also dresses the hero one rank further, as in
## MatchRPG (HeroArt.resolve), so a build can be read on the field.

const MAX_LEVEL := 30
const TALENT_LEVELS := [4, 8, 12, 16, 20]
const R_LEVELS := [6, 11, 16]


static func xp_to_next(level: int) -> int:
	return 80 + level * 70 + level * level * 6


## `effects` is what each talent sets in the hero's mods (see HeroStats).
const CLASSES := {
	"fighter": {
		"name": "Fighter", "branch": "blade", "color": Color("e8743b"), "dmg_kind": "phys",
		"desc": "Wades into the corridor and cuts through whole lines. Cleaves everything in front.",
		"hp": 820.0, "hp_lv": 68.0, "dmg": 32.0, "dmg_lv": 4.8, "armor": 3.0, "range": 92.0, "speed": 255.0,
		"aspd": 1.0, "regen": 3.5, "melee": true, "cleave": 0.45,
		"abilities": [
			{"key": "Q", "id": "whirlwind", "name": "Whirlwind", "cd": [7.0, 6.5, 6.0, 5.5], "power": [1.3, 1.7, 2.1, 2.5],
				"radius": 170.0, "desc": "Spin once: hits everything around you and throws it back."},
			{"key": "W", "id": "charge", "name": "Charge", "cd": [10.0, 9.0, 8.0, 7.0], "power": [1.0, 1.4, 1.8, 2.2],
				"desc": "Dash to a point, carving through everything in the way. You can't be hit while charging."},
			{"key": "E", "id": "war_cry", "name": "Bloodlust", "cd": [18.0, 17.0, 16.0, 15.0], "power": [0.35, 0.5, 0.65, 0.8],
				"dur": 6.0, "desc": "Faster attacks and lifesteal for 6 seconds. Nearby mobs flinch."},
			{"key": "R", "id": "executioner", "name": "Headsman's Leap", "cd": [70.0, 60.0, 50.0], "power": [5.0, 7.0, 9.0],
				"radius": 260.0, "dur": 8.0, "desc": "Leap and slam the ground. For 8 seconds your hits execute anything under 30% HP."},
		],
		"talents": [
			[{"id": "first_blood", "name": "First Blood", "desc": "+75% damage to enemies at full HP.", "fx": {"first_blood": 0.75}},
				{"id": "thorns", "name": "Thorns", "desc": "Melee attackers take 40% of the damage back.", "fx": {"thorns": 0.4}},
				{"id": "cleave", "name": "Cleave", "desc": "Your cleave is a full circle and hits for 80%.", "fx": {"cleave_full": 1.0, "cleave": 0.25}}],
			[{"id": "executioner", "name": "Executioner", "desc": "Hits kill mobs under 20% HP outright. Elites under 6%.", "fx": {"execute": 0.2}},
				{"id": "second_wind", "name": "Second Wind", "desc": "Falling under 30% HP heals 40% over 3 s (every 40 s).", "fx": {"second_wind": 0.4}},
				{"id": "momentum", "name": "Momentum", "desc": "Each kill takes 0.4 s off Charge and Whirlwind.", "fx": {"momentum": 0.4}}],
			[{"id": "bloodlust", "name": "Bloodlust", "desc": "15% lifesteal on everything.", "fx": {"lifesteal": 0.15}},
				{"id": "sunder", "name": "Sunder", "desc": "Hits make the target take 25% more from everyone for 4 s.", "fx": {"sunder": 0.25}},
				{"id": "earthsplitter", "name": "Earthsplitter", "desc": "Whirlwind is 60% wider and stuns for 1 s.", "fx": {"whirl_wide": 0.6, "whirl_stun": 1.0}}],
			[{"id": "follow_through", "name": "Follow-through", "desc": "Every 4th attack is a sweeping crit for 250%.", "fx": {"follow_through": 2.5}},
				{"id": "hold_the_line", "name": "Hold the Line", "desc": "Take 30% less damage with 5+ enemies close.", "fx": {"hold_line": 0.3}},
				{"id": "rampage", "name": "Rampage", "desc": "Kills give +5% attack speed for 5 s, stacking to 20.", "fx": {"rampage": 0.05}}],
			[{"id": "avatar", "name": "Avatar of Blades", "desc": "During Headsman's Leap, Whirlwind casts itself every 1.5 s.", "fx": {"avatar": 1.0}},
				{"id": "headsman", "name": "Headsman", "desc": "Executions burst, hitting everything near for 120%.", "fx": {"exec_burst": 1.2}},
				{"id": "unbroken", "name": "Unbroken", "desc": "+30% max HP and +4 armor.", "fx": {"hp_pct": 0.3, "armor": 4.0}}],
		],
	},
	"mage": {
		"name": "Mage", "branch": "arcane", "color": Color("9b59d0"), "dmg_kind": "mag",
		"desc": "Fragile, but magic melts what swords can't touch. Bolts splash; spells clear corridors.",
		"hp": 680.0, "hp_lv": 54.0, "dmg": 30.0, "dmg_lv": 5.0, "armor": 1.0, "range": 430.0, "speed": 245.0,
		"aspd": 1.0, "regen": 3.0, "melee": false, "missile": "arcane", "splash": 70.0, "splash_pct": 0.4,
		"abilities": [
			{"key": "Q", "id": "fireball", "name": "Ignite", "cd": [4.0, 3.6, 3.2, 2.8], "power": [1.8, 2.4, 3.0, 3.6],
				"radius": 150.0, "desc": "A fireball that bursts where it lands and sets the crowd burning."},
			{"key": "W", "id": "frost_nova", "name": "Chill", "cd": [10.0, 9.0, 8.0, 7.0], "power": [1.2, 1.6, 2.0, 2.4],
				"radius": 240.0, "dur": 3.0, "desc": "Frost bursts out of you: damage, and everything is slowed by half."},
			{"key": "E", "id": "blink", "name": "Blink", "cd": [8.0, 7.0, 6.0, 5.0], "power": [0.0, 0.0, 0.0, 0.0],
				"range": 420.0, "desc": "Step through the arcane to a point."},
			{"key": "R", "id": "meteor", "name": "Meteor Storm", "cd": [75.0, 65.0, 55.0], "power": [4.0, 5.5, 7.0],
				"radius": 300.0, "desc": "Meteors fall on an area for 3 seconds. Each one burns what it lands on."},
		],
		"talents": [
			[{"id": "ignite", "name": "Ignite", "desc": "Bolts set targets burning for 60% over 3 s.", "fx": {"bolt_burn": 0.6}},
				{"id": "arcane_ward", "name": "Arcane Ward", "desc": "A ward absorbs 20% of max HP; refills after 8 s unhit.", "fx": {"ward": 0.2}},
				{"id": "attunement", "name": "Attunement", "desc": "+25% attack speed, +80 range.", "fx": {"aspd": 0.25, "range": 80.0}}],
			[{"id": "chill", "name": "Chill", "desc": "Bolts slow by 30%. Chill lasts twice as long.", "fx": {"bolt_slow": 0.3, "nova_long": 1.0}},
				{"id": "transmute", "name": "Transmute", "desc": "Kills refund 0.25 s of every cooldown.", "fx": {"refund": 0.25}},
				{"id": "spellblade", "name": "Spellblade", "desc": "Each spell cast makes the next 3 bolts deal 200%.", "fx": {"spellblade": 2.0}}],
			[{"id": "wildfire", "name": "Wildfire", "desc": "Burning mobs that die spread their fire to all near them.", "fx": {"wildfire": 1.0}},
				{"id": "deep_freeze", "name": "Deep Freeze", "desc": "Chill freezes solid for 1.5 s, and frozen mobs take +50%.", "fx": {"deep_freeze": 1.5}},
				{"id": "overcharge", "name": "Overcharge", "desc": "Every 4th spell is cast twice.", "fx": {"overcharge": 4.0}}],
			[{"id": "pyroclasm", "name": "Pyroclasm", "desc": "Ignite leaves a fire pool for 3 s. 35% wider.", "fx": {"fire_pool": 1.0, "fireball_wide": 0.35}},
				{"id": "chain_lightning", "name": "Storm Bolts", "desc": "Bolts arc to 3 more targets for 60%.", "fx": {"chain": 3.0}},
				{"id": "time_stop", "name": "Time Stop", "desc": "Blink freezes everything near where you left for 2 s.", "fx": {"time_stop": 2.0}}],
			[{"id": "cataclysm", "name": "Cataclysm", "desc": "Meteor Storm drops twice as many meteors.", "fx": {"meteor_double": 1.0}},
				{"id": "archmage", "name": "Archmage", "desc": "All spell damage +40%, cooldowns -15%.", "fx": {"spell_pct": 0.4, "cdr": 0.15}},
				{"id": "frost_orb", "name": "Frost Orb", "desc": "Chill also fires 12 frost shards outward.", "fx": {"nova_shards": 12.0}}],
		],
	},
	"flow": {
		"name": "Flow", "branch": "cunning", "color": Color("f2c53d"), "dmg_kind": "phys",
		"desc": "MatchRPG's Rogue. Keeps the chain alive: every hit in a row builds Flow, and Flow hits harder and faster.",
		"hp": 760.0, "hp_lv": 60.0, "dmg": 26.0, "dmg_lv": 4.4, "armor": 3.0, "range": 84.0, "speed": 290.0,
		"aspd": 1.3, "regen": 3.5, "melee": true, "cleave": 0.0, "lifesteal": 0.06, "dodge": 0.1,
		"abilities": [
			{"key": "Q", "id": "fan_of_knives", "name": "Fan of Knives", "cd": [5.0, 4.5, 4.0, 3.5], "power": [1.1, 1.5, 1.9, 2.3],
				"count": 14, "desc": "Knives in every direction. Each one hits the first thing it meets."},
			{"key": "W", "id": "shadow_step", "name": "Ambush", "cd": [8.0, 7.0, 6.0, 5.0], "power": [2.5, 3.0, 3.5, 4.0],
				"desc": "Step behind an enemy and stab: a guaranteed crit."},
			{"key": "E", "id": "smoke", "name": "Dirty Fighting", "cd": [16.0, 15.0, 14.0, 13.0], "power": [0.5, 0.6, 0.7, 0.8],
				"radius": 220.0, "dur": 5.0, "desc": "A smoke bomb: mobs inside are blinded and slowed, and miss you."},
			{"key": "R", "id": "flurry", "name": "Flurry", "cd": [60.0, 50.0, 40.0], "power": [1.6, 2.0, 2.4],
				"radius": 420.0, "count": 14, "desc": "Become a blade: strike up to 14 enemies near, one after another. Untouchable."},
		],
		"talents": [
			[{"id": "flow", "name": "Deep Flow", "desc": "Flow stacks to 30 and lasts 1 s longer.", "fx": {"flow_max": 10.0, "flow_time": 1.0}},
				{"id": "steady_hands", "name": "Steady Hands", "desc": "+20% crit chance.", "fx": {"crit": 0.2}},
				{"id": "outrun", "name": "Outrun", "desc": "+15% move speed. Dodge 15% of hits.", "fx": {"speed_pct": 0.15, "dodge": 0.15}}],
			[{"id": "flurry_t", "name": "Twin Blades", "desc": "Attacks hit a second nearby enemy.", "fx": {"twin": 1.0}},
				{"id": "ambush", "name": "Ambush", "desc": "Ambush resets when its target dies.", "fx": {"ambush_reset": 1.0}},
				{"id": "medley", "name": "Medley", "desc": "Fan of Knives throws twice as many knives.", "fx": {"fan_double": 1.0}}],
			[{"id": "crescendo", "name": "Crescendo", "desc": "At full Flow, crits deal 300% instead of 200%.", "fx": {"crescendo": 1.0}},
				{"id": "bullet_time", "name": "Bullet Time", "desc": "Dodge 25% of hits. A dodge gives 3 Flow.", "fx": {"dodge": 0.25, "dodge_flow": 3.0}},
				{"id": "poison_blades", "name": "Poisoned Blades", "desc": "Hits poison for 40% over 4 s, stacking.", "fx": {"poison": 0.4}}],
			[{"id": "dirty_fighting", "name": "Dirty Fighting", "desc": "Mobs in your smoke take +40% damage.", "fx": {"smoke_amp": 0.4}},
				{"id": "lethal", "name": "Lethal", "desc": "Crits under 25% HP execute mobs.", "fx": {"crit_execute": 0.25}},
				{"id": "shadow_dance", "name": "Shadow Dance", "desc": "Kills take 1 s off Ambush and Fan of Knives.", "fx": {"shadow_dance": 1.0}}],
			[{"id": "thousand_cuts", "name": "Thousand Cuts", "desc": "Flurry strikes 28 times and fans knives at each.", "fx": {"flurry_double": 1.0}},
				{"id": "eternal_flow", "name": "Eternal Flow", "desc": "Flow never falls while you keep moving.", "fx": {"eternal_flow": 1.0}},
				{"id": "jackpot", "name": "Jackpot", "desc": "Kills drop 50% more gold, and potions twice as often.", "fx": {"gold_pct": 0.5, "potion_luck": 1.0}}],
		],
	},
	"archer": {
		"name": "Archer", "branch": "hunt", "color": Color("6fbf73"), "dmg_kind": "phys",
		"desc": "The longest reach in the Town. Bows are a joy to fire; arrows pierce, split and rain.",
		"hp": 680.0, "hp_lv": 54.0, "dmg": 31.0, "dmg_lv": 5.0, "armor": 1.5, "range": 520.0, "speed": 262.0,
		"aspd": 1.05, "regen": 3.0, "melee": false, "missile": "arrow",
		"abilities": [
			{"key": "Q", "id": "volley", "name": "Volley", "cd": [4.0, 3.6, 3.2, 2.8], "power": [1.0, 1.25, 1.5, 1.75],
				"count": 7, "desc": "Seven arrows in a cone. Each one pierces the first two it meets."},
			{"key": "W", "id": "power_shot", "name": "Power Shot", "cd": [9.0, 8.0, 7.0, 6.0], "power": [3.0, 4.0, 5.0, 6.0],
				"desc": "Draw for a breath, then loose an arrow that goes through everything in a line."},
			{"key": "E", "id": "tumble", "name": "Tumble", "cd": [9.0, 8.0, 7.0, 6.0], "power": [3.0, 3.0, 4.0, 5.0],
				"desc": "Roll toward the cursor. Your next shots split into three."},
			{"key": "R", "id": "rain", "name": "Rain of Arrows", "cd": [55.0, 48.0, 40.0], "power": [0.55, 0.75, 0.95],
				"radius": 300.0, "dur": 4.0, "desc": "Arrows rain on an area for 4 s, slowing all inside."},
		],
		"talents": [
			[{"id": "split_shot", "name": "Split Shot", "desc": "Every shot also hits 2 more enemies for 50%.", "fx": {"split": 2.0}},
				{"id": "quickdraw", "name": "Quickdraw", "desc": "+30% attack speed.", "fx": {"aspd": 0.3}},
				{"id": "longbow", "name": "Longbow", "desc": "+140 range, +15% damage.", "fx": {"range": 140.0, "dmg_pct": 0.15}}],
			[{"id": "pierce", "name": "Pierce", "desc": "Shots go through 2 enemies.", "fx": {"pierce": 2.0}},
				{"id": "hunters_mark", "name": "Hunter's Mark", "desc": "Hits mark: marked enemies take +30% from all heroes.", "fx": {"mark": 0.3}},
				{"id": "fleetfoot", "name": "Fleetfoot", "desc": "Tumble has 2 charges and goes 50% farther.", "fx": {"tumble_far": 0.5}}],
			[{"id": "headshot", "name": "Headshot", "desc": "15% chance: 300% damage. Executes mobs under 30%.", "fx": {"headshot": 0.15}},
				{"id": "barrage", "name": "Barrage", "desc": "Volley fires 13 arrows.", "fx": {"volley_more": 6.0}},
				{"id": "trueshot", "name": "Trueshot Aura", "desc": "All heroes deal +15% damage.", "fx": {"aura": 0.15}}],
			[{"id": "explosive", "name": "Blast Arrows", "desc": "Shots burst for 35% around the target.", "fx": {"blast": 0.35}},
				{"id": "focus", "name": "Focus", "desc": "Each shot at the same target hits 8% harder, up to 80%.", "fx": {"focus": 0.08}},
				{"id": "wind_runner", "name": "Wind Runner", "desc": "Power Shot fires three arrows in a fan.", "fx": {"power_triple": 1.0}}],
			[{"id": "storm", "name": "Arrowstorm", "desc": "Rain of Arrows is twice as wide and lasts 6 s.", "fx": {"rain_big": 1.0}},
				{"id": "hailfire", "name": "Hailfire", "desc": "Every 5th shot is a Volley.", "fx": {"hailfire": 5.0}},
				{"id": "deadeye", "name": "Deadeye", "desc": "+25% crit chance; crits deal 250%.", "fx": {"crit": 0.25, "crit_dmg": 0.5}}],
		],
	},
}

const ORDER := ["fighter", "mage", "flow", "archer"]


static func get_def(id: String) -> Dictionary:
	return CLASSES[id]


static func ability(cls: String, slot: int) -> Dictionary:
	return CLASSES[cls]["abilities"][slot]


## The level a rank needs: Q/W/E rank n at 2n-1, R at R_LEVELS.
static func rank_level(slot: int, rank: int) -> int:
	if slot == 3:
		return R_LEVELS[rank]
	return rank * 2 + 1


static func max_rank(slot: int) -> int:
	return 3 if slot == 3 else 4
