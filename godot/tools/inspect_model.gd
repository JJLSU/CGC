extends SceneTree
## Prints a model's node tree (meshes, skeletons, bones of note) and its animation names.
## godot --headless --path godot --script res://tools/inspect_model.gd -- res://assets/models/folk/folk_jim.glb

func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var n: Node = (load(path) as PackedScene).instantiate()
	_walk(n, 0)
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		print("ANIMS ", (ap as AnimationPlayer).get_animation_list())
	for sk in n.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		var names := []
		for i in s.get_bone_count(): names.append(s.get_bone_name(i))
		print("BONES ", names)
	n.free()
	quit()

func _walk(n: Node, d: int) -> void:
	if d < 4: print("  ".repeat(d), n.name, " [", n.get_class(), "]")
	for c in n.get_children(): _walk(c, d + 1)
