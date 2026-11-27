extends SceneTree
## The farm windmill as the player's Meshy one: from the yard (<out>), its wheel a moment later (turned: <out>_turn.png),
## and up its ladder on the platform (<out>_top.png). Prints the wheel's turn and where he stands. Windowed.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var H: Homestead = main.homestead; var m: Vector3 = H.mill_at
	print("meshy mill %s, wheel %s" % [H.meshy_mill, H.wheel != null])
	var stand := m + Vector3(-9, 0, 9)
	for i in 60: main.player.pos = Vector3(stand.x, Terrain.get_height(stand.x, stand.z), stand.z); await process_frame
	main.rig.dist = 42.0; main.rig.pitch = 0.22; main.rig.yaw = atan2(stand.x - m.x, stand.z - m.z); main.rig.snap()
	for i in 20: await process_frame
	var b0: Basis = H.wheel.transform.basis if H.wheel else Basis()
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	for i in 40: await process_frame
	print("wheel turned %.2f rad" % (b0.get_euler() - (H.wheel.transform.basis.get_euler() if H.wheel else Vector3.ZERO)).length())
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_turn.png"))
	var L = null
	for st in main.climbs.sets.values(): for l in st.ladders: if l.name == "the windmill": L = l
	for i in 15: main.player.pos = L.foot; await process_frame
	print("at the foot: '%s'" % main.beast_prompt)
	main.input.pressed["KeyE"] = true
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000 and main.player.climbing != null: await process_frame
	for i in 30: await process_frame
	print("on the platform at %.2f m (deck 7.82), standing %s" % [main.player.pos.y - m.y, main.climbs.standing(main.player.pos) != null])
	main.rig.dist = 14.0; main.rig.pitch = 0.4; main.rig.snap()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_top.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
