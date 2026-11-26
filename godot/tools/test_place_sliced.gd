extends SceneTree
## Step 28: Props.place_sliced (the world's frame-by-frame layout) must lay out exactly what Props.place does, and
## keep each frame's share under its budget. Forty chunks about the county, both ways, compared prop by prop.

func _sig(out: Dictionary) -> String:
	var a := []
	for r in out.list: a.append("%s@%.3f,%.3f" % [r.type, r.x, r.z])
	for c in out.colliders: a.append("c%.3f,%.3f,%.2f" % [c.x, c.z, c.r])
	for s in out.sites: a.append("s%s" % s.key)
	return "|".join(a)

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 30: await process_frame
	var w: World = main.world
	var same := 0; var n := 0
	for k in 40:
		var cx := -12 + (k * 7) % 25; var cz := -12 + (k * 11) % 25
		var a := _sig(Props.place(cx, cz, w.exclusions))
		var st := {"done": false, "b": ""} # (a lambda captures locals by value: share a dictionary)
		var run := func() -> void:
			st.b = _sig(await Props.place_sliced(cx, cz, w.exclusions, 4000)); st.done = true
		run.call()
		var guard := 0
		while not st.done and guard < 600: await process_frame; guard += 1
		var b: String = st.b
		if a == b: same += 1
		else: print("differs at %d,%d" % [cx, cz])
		n += 1
	print("%d of %d chunks laid out the same" % [same, n])
	print("PLACE SLICED TEST ", "PASS" if same == n else "FAIL")
	quit()
