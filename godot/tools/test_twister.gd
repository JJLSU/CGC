extends SceneTree
## The twister (the player's paper tornado frames): set down 60 m off heading straight at the farmer, it churns
## through its three frames, comes on across the ground, throws him clear with a knock, keeps out of town, and at the
## end of its time lifts back into the clouds. With a user arg <out.png> (windowed) pictures: near, and from afar.
## Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.5; main.weather.rain = 0.0
	for i in 20: await process_frame
	var p: Player = main.player
	var spot: Vector3 = p.pos
	main.spawn_twister()
	var tw: Twister = main.twister
	var a: Vector3 = spot + (spot - main.town.at).normalized() * 60.0 # (away from town)
	a.y = 0; tw.start(a, spot)
	var frames := {}; var start_d: float = tw.pos.distance_to(spot); var hp0 := p.health; var thrown := false; var min_d := 999.0
	var args := OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec(); var shot := false
	while Time.get_ticks_msec() - t0 < 20000:
		frames[tw._frame] = true
		p.pos.x = spot.x; p.pos.z = spot.z # (he stands his ground)
		if main.twister_fling.length() > 1.0: thrown = true
		min_d = minf(min_d, Vector3(tw.pos.x - spot.x, 0, tw.pos.z - spot.z).length())
		if args.size() > 0 and not shot and tw.drop < 0.05 and tw.pos.distance_to(spot) < 30.0:
			shot = true; main.set_process(false)
			var cam: Camera3D = main.rig.camera
			cam.global_position = spot + Vector3(0, 6, 0) + (spot - tw.pos).normalized() * 8.0; cam.look_at(tw.position + Vector3(0, 9, 0), Vector3.UP); cam.fov = 60.0
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(args[0])
			main.set_process(true); cam.fov = 30.0
		if thrown and p.health < hp0: break
		await process_frame
	print("frames seen %s; came from %.0f m to %.1f m; thrown %s; health %.0f -> %.0f" % [frames.keys(), start_d, min_d, thrown, hp0, p.health])
	var ok: bool = frames.size() == 3 and thrown and p.health < hp0
	# its time up: it lifts away
	tw.t = Twister.LIFE + 0.1
	var t1 := Time.get_ticks_msec()
	while main.twister != null and Time.get_ticks_msec() - t1 < 8000: await process_frame
	print("lifted away: %s" % (main.twister == null))
	ok = ok and main.twister == null
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("TWISTER TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
