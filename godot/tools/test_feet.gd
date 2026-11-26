extends SceneTree
## Feet on the ground (the player: some folks' feet were in the ground): the whole town mended, every townsperson
## out front measured after a few seconds of their clips: the lowest sole (toe bone less the foot's depth) against the
## surface under them (boardwalk or street). Fails if any sinks more than 4 cm. CGC_KEEP to load a copy of a save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp) and OS.get_environment("CGC_KEEP") == "": DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.5
	main._dev_town()
	var T: Town = main.town
	var t0 := Time.get_ticks_msec()
	var worst := {}
	while Time.get_ticks_msec() - t0 < 12000:
		main.player.pos = T.at + T.along * -10.0
		await process_frame
		if Time.get_ticks_msec() - t0 < 3000: continue
		for key in T.folk.keys():
			var f: ModelFigure = T.folk[key].fig
			if f == null or f.skeleton == null or not f.root.is_visible_in_tree(): continue
			if OS.get_environment("NOLIFT") != "": f.ground_feet = false # (to see what it would be without the lift)
			var id: String = String(key).get_slice("_", 0) if not String(key).begins_with("cn_") else "_".join(String(key).split("_").slice(0, 2))
			var low := INF
			for b in ["LeftToeBase", "RightToeBase"]:
				var i := f.skeleton.find_bone(b)
				if i >= 0: low = minf(low, (f.skeleton.global_transform * f.skeleton.get_bone_global_pose(i)).origin.y - 0.035 * f.root.global_transform.basis.get_scale().y)
			if low == INF: continue
			var p := f.root.global_position
			var ground := T.surface_at(p.x, p.z, id)
			var sink := ground - low
			if not worst.has(key) or sink > worst[key][0]: worst[key] = [sink, f.name, f.current]
	var bad := 0
	for key in worst:
		var w: Array = worst[key]
		if w[0] > 0.04: bad += 1; print("SUNK %s (%s, %s): %.2f m below" % [key, w[1], w[2], w[0]])
	print("%d folk measured, %d with feet in the ground" % [worst.size(), bad])
	if FileAccess.file_exists(sp) and OS.get_environment("CGC_KEEP") == "": DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("FEET TEST ", "PASS" if bad == 0 else "FAIL")
	quit(0 if bad == 0 else 1)
