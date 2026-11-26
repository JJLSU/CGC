extends SceneTree
## Squatters' Row and its people (<out>_row.png), and the church with its preacher and his wife (<out>_church.png),
## the whole town mended. Prints who stands on the Row. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main._dev_town()
	var T: Town = main.town
	var row := []
	for k in T.folk: if String(k).begins_with("row_"): row.append(T.folk[k].fig.name)
	print("on the Row: %s; at the church: %s" % [row, T.folk.church.fig.name if T.folk.has("church") else "-"])
	var rc: Vector3 = T.at + T.along * -47.0
	for i in 90: main.player.pos = rc + T.along * 14.0; await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	cam.global_position = rc + T.along * 12.0 + T.toward * 6.0 + Vector3(0, T.y0 + 5.0 - rc.y, 0); cam.look_at(rc + Vector3(0, T.y0 + 0.8 - rc.y, 0), Vector3.UP); cam.fov = 55.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_row.png"))
	var d: Vector3 = T.doors.church
	main.set_process(true)
	for i in 60: main.player.pos = d - T.along * 9.0; await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	cam.global_position = d - T.along * 8.0 + Vector3(0, T.y0 + 3.0 - d.y, 0); cam.look_at(d + Vector3(0, T.y0 + 1.5 - d.y, 0), Vector3.UP); cam.fov = 55.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_church.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
