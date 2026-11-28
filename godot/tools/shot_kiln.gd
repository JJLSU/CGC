extends SceneTree
## The brick kiln piece, built beside the farm (<out>): the player's Meshy kiln in the paper one's place. Windowed;
## a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var at: Vector3 = main.spawn + Vector3(7, 0, 12)
	var pc: Dictionary = main.build.add({"type": "kiln", "x": at.x, "y": Terrain.get_height(at.x, at.z), "z": at.z, "rot": 0}, true)
	var bb := PaperMats._aabb(pc.mesh, Transform3D.IDENTITY)
	print("kiln built: %s, %.1f x %.1f x %.1f m" % [pc.mesh.get_child_count() > 0, bb.size.x, bb.size.y, bb.size.z])
	for i in 60: main.player.pos = at + Vector3(3, 0, 4); await process_frame
	main.set_process(false)
	var cam: Camera3D = main.rig.camera; var y := Terrain.get_height(at.x, at.z)
	cam.global_position = Vector3(at.x + 9.5, y + 3.0, at.z - 2.0); cam.look_at(Vector3(at.x, y + 0.5, at.z), Vector3.UP); cam.fov = 50.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
