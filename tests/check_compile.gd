extends Node
## Loads every script, so a parse error fails loudly.
##   godot --headless --path . res://tests/check_compile.tscn


func _ready() -> void:
	var bad := 0
	for dir in ["res://scripts/matchrpg", "res://scripts/data", "res://scripts/autoload", "res://scripts/game",
			"res://scripts/net", "res://scripts/ui", "res://tests"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".gd"):
				var s: Script = load(dir + "/" + f)
				if s == null or not s.can_instantiate():
					print("BAD ", dir, "/", f)
					bad += 1
	print("compile check: ", bad, " bad")
	get_tree().quit(1 if bad > 0 else 0)
