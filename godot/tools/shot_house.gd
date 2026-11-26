extends SceneTree
## The farmhouse from above and to the front (<out>), in the state the save's fortune affords. With CGC_KEEP a copy of
## a save can be loaded as it is. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp) and OS.get_environment("CGC_KEEP") == "": DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main.homestead.set_fortune(500.0)
	var d: Vector3 = main.homestead.front_door
	for i in 60: main.player.pos = d + Vector3(0, 0, 8); await process_frame
	main.set_process(false)
	var cam: Camera3D = main.rig.camera
	cam.global_position = d + Vector3(9, 13, 14); cam.look_at(d + Vector3(0, 1.5, -3), Vector3.UP); cam.fov = 45.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
