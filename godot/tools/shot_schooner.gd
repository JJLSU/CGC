extends SceneTree
## The lost schooner (the prairie's set piece), set down beside the farm for a look (<out>): the player's wrecked
## Conestoga where the old broken wagon lay. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var at: Vector3 = main.spawn - (main.town.at - main.spawn).normalized() * 40.0
	at.y = Terrain.get_height(at.x, at.z)
	main.landmarks.spawn({"key": "test:schooner", "mark": "schooner", "x": at.x, "y": at.y, "z": at.z, "rot": 0.6})
	for i in 60: main.player.pos = at + Vector3(10, 0, 10); await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	cam.global_position = at + Vector3(5, 13, 5); cam.look_at(at + Vector3(0, 0.5, 0), Vector3.UP); cam.fov = 45.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
