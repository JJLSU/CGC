extends SceneTree
## The whole town from above (<out>), every street up and mended (the Whole town dev button), the railroad and all;
## with "low" a second, lower picture down the length of the town (<out>_low.png). Prints where the streets and the
## nearest track lie. Windowed; a throwaway save.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp) and OS.get_environment("CGC_KEEP") == "": DirAccess.remove_absolute(ProjectSettings.globalize_path(sp)) # (CGC_KEEP: start from that save, a copy of one)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.5; main.weather.rain = 0.0
	main._dev_town()
	var T: Town = main.town
	var c: Vector3 = T.at + T.toward * (T.street_offs.reduce(func(a, b): return a + b, 0.0) / (T.street_offs.size() + 1))
	print("town at %s, along %s; street offsets %s" % [T.at.round(), T.along, T.street_offs])
	var near := 1e9
	if main.get("railroad") != null and main.railroad.get("pts") != null:
		for p in main.railroad.pts: near = minf(near, Vector2(p.x - c.x, p.z - c.z).length())
	print("nearest track to the town's middle: %.0f m" % near)
	for i in 120: main.player.pos = c + T.along * 40.0; await process_frame
	main.set_process(false)
	var cam: Camera3D = main.rig.camera
	cam.global_position = c + Vector3(0, 150, 0) + T.toward * 0.01; cam.look_at(c, T.along); cam.fov = 60.0
	main.player.avatar.root.visible = false
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	if args.has("low"):
		cam.global_position = c - T.along * 70.0 + Vector3(0, T.y0 + 30.0 - c.y, 0); cam.look_at(c + Vector3(0, T.y0 - c.y, 0), Vector3.UP); cam.fov = 55.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_low.png"))
	if args.has("county"): # (the whole line from high up)
		cam.global_position = c + Vector3(0, 900, 0) + T.toward * 0.01; cam.look_at(c, T.along); cam.fov = 70.0; cam.far = 3000.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_county.png"))
	if args.has("road"): # (a crossing up close: Main Street's north end)
		var q: Vector3 = T.at + T.along * Town.CROSS_N
		cam.global_position = q + T.toward * 9.0 - T.along * 10.0 + Vector3(0, T.y0 + 9.0 - q.y, 0); cam.look_at(q + Vector3(0, T.y0 - q.y, 0), Vector3.UP); cam.fov = 60.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_road.png"))
	if args.has("depot"): # (the depot and the yard across the track, from the town side and from above the yard)
		var rr: Railroad = main.railroad; var dp: Vector3 = rr.depot; var yd: Vector3 = rr.yard
		var tw := (yd - dp).normalized()
		main.set_process(true)
		for i in 60: main.player.pos = dp - tw * 14.0; await process_frame
		main.set_process(false); main.player.avatar.root.visible = false
		cam.global_position = dp - tw * 26.0 + T.along * -14.0 + Vector3(0, T.y0 + 12.0 - dp.y, 0); cam.look_at(dp.lerp(yd, 0.4) + Vector3(0, T.y0 - dp.y, 0), Vector3.UP); cam.fov = 60.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_depot.png"))
		cam.global_position = yd + Vector3(0, T.y0 + 16.0 - yd.y, 0) + tw * 14.0; cam.look_at(yd + Vector3(0, T.y0 - yd.y, 0), Vector3.UP); cam.fov = 60.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_yard.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
