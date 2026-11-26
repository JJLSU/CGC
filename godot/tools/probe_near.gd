extends SceneTree
## Probe: what stands near a point of the town (s along, o across: args), the whole town mended. Prints each node
## within r of it with its path. CGC_KEEP to load a copy of a save. Headless.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var s0 := float(args[0]); var o0 := float(args[1]); var r := float(args[2]) if args.size() > 2 else 6.0
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main._dev_town()
	for i in 30: await process_frame
	var T: Town = main.town
	var p: Vector3 = T.at + T.along * s0 + T.toward * o0
	var seen := {}
	for n in main.find_children("*", "Node3D", true, false):
		var q: Vector3 = (n as Node3D).global_position
		if Vector2(q.x - p.x, q.z - p.z).length() < r and n.get_child_count() > 0:
			var path := String(main.get_path_to(n)); var top := path.get_slice("/", 0)
			if seen.has(path.get_base_dir()): continue
			seen[path] = true
			print("%s  (%s)" % [path.left(140), n.get_class()])
	quit()
