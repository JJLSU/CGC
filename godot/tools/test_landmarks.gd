extends SceneTree
## The landmarks: each of the world's one-of-a-kind sites spawns with its chunk; reaching one for the first time
## gives its find; the fire lookout is climbed by its ladder and its view counts only from the top; the windmill's
## ladder works. Screenshots of each set piece (out/<mark>.png).

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4
	for i in 10: await process_frame
	var p: Player = main.player; var lm: Landmarks = main.landmarks
	var U := Props.unique_encounters()
	print("uniques: %s" % [U.map(func(u): return "%s@%d,%d" % [u.mark, roundi(u.x), roundi(u.z)])])
	var spawned := 0; var found := 0; var climbed := false
	main.inventory.apples = 5
	for u in U:
		# arrive a little way off and let the chunks come in
		var a: float = u.rot + 1.0
		var o := Vector3(u.x + cos(a) * 14.0, 0, u.z + sin(a) * 14.0)
		p.pos = Vector3(o.x, Terrain.get_height(o.x, o.z), o.z)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000 and not lm.live.values().any(func(l): return l.site.mark == u.mark): await process_frame
		var here = null
		for l in lm.live.values(): if l.site.mark == u.mark: here = l
		if here == null: print("  %s did not spawn" % u.mark); continue
		spawned += 1
		main.rig.dist = 26.0 if u.mark in ["lookout", "steamboat", "arch"] else 16.0; main.rig.pitch = 0.45; main.rig.yaw = atan2(o.x - u.x, o.z - u.z); main.rig.snap()
		for i in 40: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.get_base_dir() + "/lm_" + u.mark + ".png")
		var f0: int = lm.found.size()
		if u.mark == "lookout":
			# up the ladder: from its foot, E, carried up; the view (the find) only from the top
			var L = null
			for st in main.climbs.sets.values(): for l in st.ladders: if l.name == "the fire lookout": L = l
			p.pos = L.foot
			for i in 3: await process_frame
			var before: int = lm.found.size()
			main.input.pressed["KeyE"] = true
			t0 = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 9000 and (p.climbing != null or p.pos.y < here.site.y + 8.0): await process_frame
			for i in 10: await process_frame
			climbed = p.pos.y > here.site.y + 8.5 and lm.found.size() > before
			print("  lookout: on the deck at %.1f m (site %.1f)  found %s" % [p.pos.y, here.site.y, lm.found.size() > before])
		else:
			p.pos = Vector3(u.x + cos(a) * 5.0, 0, u.z + sin(a) * 5.0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
			for i in 5: await process_frame
		if lm.found.size() > f0: found += 1
	# the windmill
	var mill = null
	for st in main.climbs.sets.values(): for l in st.ladders: if l.name == "the windmill": mill = l
	p.pos = mill.foot
	for i in 3: await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 8000 and (p.climbing != null or p.pos.y < 7.0): await process_frame
	var mill_up: bool = p.pos.y > main.homestead.mill_at.y + 7.0
	print("landmarks spawned %d/%d  found %d  lookout climbed %s  windmill [%s] up %s  blessed %s" % [spawned, U.size(), found, climbed, prompt, mill_up, lm.blessed])
	var ok: bool = spawned == U.size() and found == U.size() and climbed and mill_up
	print("LANDMARKS TEST ", "PASS" if ok else "FAIL")
	quit()
