extends SceneTree
## The town's sign at the head of Main Street (<out>), close up. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var T: Town = main.town; var s: Vector3 = T.sign_at
	var f: Vector3 = (T.sign as Node3D).global_basis.z.normalized()
	for i in 60: main.player.pos = s + f * 8.0; await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera; var y := Terrain.get_height(s.x, s.z)
	for k in [["front", 1.0], ["back", -1.0]]:
		cam.global_position = Vector3(s.x, y + 2.4, s.z) + f * 6.0 * k[1]; cam.look_at(Vector3(s.x, y + 1.7, s.z), Vector3.UP); cam.fov = 45.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % k[0]))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
