extends SceneTree
## The town seen from the farm, low across the fields (<out>): its far streets lie past the built ground; do they sit on
## the land or hang over the flat sheet? Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	main._dev_town()
	var T: Town = main.town; var h: Vector3 = main.spawn
	var dir: Vector3 = (T.at - h).normalized()
	for i in 120: main.player.pos = Vector3(h.x, Terrain.get_height(h.x, h.z), h.z); await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	cam.global_position = h + dir * 20.0 + Vector3(0, 4.0, 0); cam.look_at(T.at + Vector3(0, 1.5, 0), Vector3.UP); cam.fov = 30.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("town %.0f m from the farm" % h.distance_to(T.at))
	quit()
