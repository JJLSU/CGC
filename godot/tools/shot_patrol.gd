extends SceneTree
## A fort's patrol on the road at mid-morning (<out>). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	var F: ArmyForts = main.forts; var pt: Dictionary = F.patrols[0]
	main.sky.time = 0.38
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		main.sky.time = 0.38 + (Time.get_ticks_msec() - t0) / 6000.0 * 0.004
		var at: Vector3 = F.patrol_pos(pt, main.sky.time) + Vector3(7, 0, 7)
		main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); main.rig.yaw = 0.8; main.rig.pitch = 0.25; main.rig.dist = 12.0
		await process_frame
	print("patrol built %s, %d riders" % [pt.built, pt.riders.size()])
	main.player.avatar.root.visible = false
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
