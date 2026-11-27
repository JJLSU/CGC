extends SceneTree
## Your gold claim's adit (<out>_rich.png before you dig, <out>_worked.png after): the player's gold-vein wall in the
## mouth. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build(); main.claim.build()
	var C: Claim = main.claim; var d: Vector3 = C.dig_at; var g: Node3D = C.group
	var out_dir: Vector3 = g.global_basis.z.normalized()
	for k in ["rich", "worked"]:
		if k == "worked": C.dig(main.sky.day, main.tools)
		main.set_process(true)
		for i in 60: main.player.pos = d + out_dir * 9.0; await process_frame
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera
		cam.global_position = d + out_dir * 4.5 + Vector3(0, 1.6, 0); cam.look_at(d - out_dir * 1.0 + Vector3(0, 0.8, 0), Vector3.UP); cam.fov = 50.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % k))
	print("rich shown %s, worked shown %s" % [C.vein_rich.visible if C.vein_rich else null, C.vein_worked.visible if C.vein_worked else null])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
