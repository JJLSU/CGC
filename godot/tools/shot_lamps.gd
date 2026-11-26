extends SceneTree
## Main Street's lamps (<out>): by day (<out>_day.png) and lit after dark. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	main._dev_town()
	var T: Town = main.town
	for t in [[0.5, "_day"], [0.9, ""]]:
		main.sky.time = t[0]
		main.set_process(true)
		for i in 150: main.player.pos = T.at + T.along * -18.0; await process_frame
		for S in T.street_lamps: T._light(S, t[0] > 0.8)
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera
		cam.global_position = T.at - T.along * 22.0 + T.toward * 3.0 + Vector3(0, T.y0 + 4.0 - T.at.y, 0); cam.look_at(T.at + T.along * 4.0 + Vector3(0, T.y0 + 2.0 - T.at.y, 0), Vector3.UP); cam.fov = 50.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", t[1] + ".png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
