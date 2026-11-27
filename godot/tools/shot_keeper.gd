extends SceneTree
## A whistle-stop's keeper by his trading post (<out>; the stop's index after it). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]; var i := int(args[1]) if args.size() > 1 else 0
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	if not main.railroad.built: main.railroad.build() # (as when the whole town is mended)
	var t0 := Time.get_ticks_msec(); var s = null
	while Time.get_ticks_msec() - t0 < 9000:
		if s == null and main.railroad.stops.size() > i: s = main.railroad.stops[i]
		if s != null and s.has("keeper"):
			var k: Vector3 = s.keeper.root.position; var st: Vector3 = k + Vector3(sin(s.keeper.root.rotation.y), 0, cos(s.keeper.root.rotation.y)) * 3.0
			main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); main.rig.yaw = s.keeper.root.rotation.y + 0.4; main.rig.pitch = (0.75 if OS.get_cmdline_user_args().has("high") else 0.2); main.rig.dist = (26.0 if OS.get_cmdline_user_args().has("high") else 7.0)
		elif s != null: main.player.pos = s.at
		await process_frame
	if s != null and main.railroad.keeper_card: s.hailed = false; main.railroad.keeper_card.t = 0.0 # (hail afresh for the picture)
	for f in 30: await process_frame
	print("stop %s, keeper %s, says '%s'" % [s.name if s else "-", s.keeper.name if s and s.has("keeper") else "-", main.railroad.keeper_card.text if main.railroad.keeper_card else "-"])
	var kc = main.railroad.keeper_card
	if kc: print("card visible %s t %.2f at %s, on screen %s" % [kc.visible, kc.t, kc.global_position.round(), main.rig.camera.unproject_position(kc.global_position).round()])
	main.player.avatar.root.visible = false
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
