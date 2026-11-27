extends SceneTree
## Your claim's mine (the player's mine kit): from above (<out>_top.png), from the portal's side (<out>_side.png), and
## at the face (<out>_face.png). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build(); main.claim.build(); main.claim.hire(main.sky.day)
	var C: Claim = main.claim; var g: Node3D = C.group
	var w := func(q: Vector3) -> Vector3: return g.global_transform * q
	print("mine cols %d; vein at %s (local), shown %s" % [C.mine_cols.size(), C.vein_rich.position if C.vein_rich else null, C.vein_rich.visible if C.vein_rich else null])
	var mid: Vector3 = w.call(Vector3(-15.0, 0, 0))
	for v in [["top", w.call(Vector3(-13, 34, 8)), mid], ["side", w.call(Vector3(-8, 9, 14)), w.call(Vector3(-15, 0, 0))], ["face", w.call(Vector3(-19, 3.2, 3.0)), w.call(Vector3(-23.5, 0.9, 0))], ["over", w.call(Vector3(-16, 14, 6)), w.call(Vector3(-16, 0, 0))]]:
		main.set_process(true)
		for i in 60: main.player.pos = w.call(Vector3(-5, 0, 3)); await process_frame
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera
		cam.global_position = v[1]; cam.look_at(v[2], Vector3.UP); cam.fov = 55.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % v[0]))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
