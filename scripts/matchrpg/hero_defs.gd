class_name HeroDefs
extends RefCounted
## The part of MatchRPG's HeroDefs that HeroLook reads: each talent branch's
## color. Copied from matchRPG/scripts/data/hero_defs.gd, plus Hearthguard's
## "hunt" (the Archer).

const REGIONS := {
	"blade": {"name": "Blade", "color": Color("e8743b"),
		"style": "Cuts through whole lines and charges ahead"},
	"cunning": {"name": "Trickster", "color": Color("f2c53d"),
		"style": "Bends the board's rules with tricks and potions"},
	"bulwark": {"name": "Bulwark", "color": Color("4a90d9"), "style": "Holds the dark back with armor"},
	"arcane": {"name": "Arcane", "color": Color("9b59d0"), "style": "Turns the board to magic and slows time"},
	"scavenger": {"name": "Scavenger", "color": Color("6fbf73"),
		"style": "Makes every resource fight, and bribes the dark"},
	"hunt": {"name": "Hunt", "color": Color("6fbf73"), "style": "Arrows from farther than anyone"},
}

const COLOR := Color("c8c2b0")
