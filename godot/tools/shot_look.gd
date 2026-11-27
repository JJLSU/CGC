extends SceneTree
## The look, the same five frames every run, for before/after comparisons of the ground, lighting and render:
## <out>_farm (the farmyard, mid-morning), _street (Main Street, noon), _wide (the county from up high), _golden (the
## farm at golden hour), _night (the town at night). Windowed; a throwaway save; the whole town mended.
func _shot(p: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(p)
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	seed(20261127) # (the same county every run: a fair before and after)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.snow = 0.0
	main._dev_town()
	var T: Town = main.town; var h: Vector3 = main.spawn
	var views := [["farm", h + Vector3(4, 0, 6), 0.36, 0.55, 15.0, 0.7], ["street", T.at - T.along * 20.0, 0.5, 0.3, 14.0, atan2(T.along.x, T.along.z) + PI],
		["wide", h, 0.45, 1.0, 42.0, 0.9], ["golden", h + Vector3(4, 0, 6), 0.71, 0.4, 18.0, 2.4], ["night", T.at - T.along * 15.0, 0.93, 0.35, 16.0, atan2(T.along.x, T.along.z) + PI]]
	for v in views:
		var at: Vector3 = v[1]
		main.sky.time = v[2]
		for i in 90:
			main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); main.sky.time = v[2]
			main.rig.pitch = v[3]; main.rig.dist = v[4]; main.rig.yaw = v[5]
			await process_frame
		await _shot(out.replace(".png", "_%s.png" % v[0]))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
