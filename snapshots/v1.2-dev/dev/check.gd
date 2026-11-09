extends Node
func _ready() -> void:
	var d := DirAccess.open("res://scripts")
	for f in d.get_files():
		if f.ends_with(".gd"):
			var s = load("res://scripts/" + f)
			if s == null or not (s as GDScript).can_instantiate():
				print("BAD ", f)
	print("CHECK DONE")
	get_tree().quit()
