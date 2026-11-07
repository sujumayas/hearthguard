class_name PotionDefs
extends RefCounted
## MatchRPG's potions on a 4-slot belt (keys 1-4), their names, colors and
## symbols (PotionArt) kept; what they do is moved from the board to the
## field. Elites always drop one, bosses three, and the campfire's
## Alchemist sells them between chapters.

const POTIONS := {
	"heal": {"name": "Health Potion", "group": "health", "color": Color("ff7fa0"), "stack": 3, "price": 40,
		"desc": "Heal half your max HP.", "sound": "heal", "weight": 30},
	"stun": {"name": "Stun Potion", "color": Color("9da3ff"), "stack": 2, "price": 60,
		"desc": "Everything around you is stunned for 2.5 seconds.", "sound": "stun", "weight": 12},
	"freeze": {"name": "Freeze Potion", "color": Color("a8e4ff"), "stack": 2, "price": 90,
		"desc": "Every mob on the map stops for 4 seconds.", "sound": "freeze", "weight": 8},
	"surge": {"name": "Surge Potion", "color": Color("e59bff"), "stack": 2, "price": 80,
		"desc": "For 10 seconds, everything you do hits twice as hard.", "sound": "surge", "weight": 10},
	"meteor": {"name": "Meteor Potion", "color": Color("ffbf5e"), "stack": 2, "price": 150,
		"desc": "A meteor falls where you point.", "sound": "meteor", "weight": 10, "aim": true},
	"cataclysm": {"name": "Cataclysm Potion", "color": Color("ff9a5a"), "stack": 1, "price": 320,
		"desc": "Every mob near you dies. Elites lose half their HP, bosses a tenth.", "sound": "blast", "weight": 4},
	"aegis": {"name": "Aegis Potion", "color": Color("8fd0ff"), "stack": 1, "price": 240,
		"desc": "For 6 seconds nothing hurts you.", "sound": "shield", "weight": 5},
	"cleanse": {"name": "Cleanse Potion", "color": Color("e8f4ff"), "stack": 2, "price": 50,
		"desc": "Clears what's on you and puts out the hazards near you.", "sound": "cleanse", "weight": 8},
	"echo": {"name": "Clone Potion", "color": Color("b9a5ff"), "stack": 1, "price": 160,
		"desc": "The next potion you drink in 30 seconds isn't spent.", "sound": "potion", "weight": 3},
}

const SHOP := ["heal", "stun", "meteor", "surge", "freeze", "cleanse", "aegis", "cataclysm", "echo"]


static func get_def(id: String) -> Dictionary:
	return POTIONS[id]


static func roll(rng: RandomNumberGenerator, rank: String) -> String:
	var total := 0
	for id: String in POTIONS:
		total += int(POTIONS[id]["weight"]) * (2 if rank == "boss" and id != "heal" else 1)
	var r := rng.randi() % total
	for id: String in POTIONS:
		r -= int(POTIONS[id]["weight"]) * (2 if rank == "boss" and id != "heal" else 1)
		if r < 0:
			return id
	return "heal"


static func symbol(id: String) -> String:
	return POTIONS[id].get("group", id)


static func short_name(id: String) -> String:
	return String(POTIONS[id]["name"]).trim_suffix(" Potion")
