extends Node
## Opens the menu and saves one screenshot to tests/shots/menu.png.
##   godot --path . res://tests/menu_shot.tscn

var t := 0.0


func _ready() -> void:
	Net.set_identity("Tester", "archer")
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")


func _process(delta: float) -> void:
	t += delta
	if t > 2.0:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
		get_viewport().get_texture().get_image().save_png("res://tests/shots/menu.png")
		get_tree().quit()
