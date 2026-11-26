extends SceneTree
## Any prop model set down beside the farm for a look (<out>; args: <out.png> <model> [size m]). Windowed; a throwaway save.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]; var nm: String = args[1]; var size := float(args[2]) if args.size() > 2 else 10.0
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var at: Vector3 = main.spawn - (main.town.at - main.spawn).normalized() * 30.0
	at.y = Terrain.get_height(at.x, at.z)
	var m := PaperMats.seated(load("res://assets/models/props/%s.glb" % nm), size)
	m.position = at; main.add_child(m)
	var bb := PaperMats._aabb(m, Transform3D.IDENTITY)
	print("%s: %.1f x %.1f x %.1f m" % [nm, bb.size.x, bb.size.y, bb.size.z])
	for i in 60: main.player.pos = at + Vector3(size, 0, size); await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	cam.global_position = at + Vector3(-size * 0.7, size * 0.75, -size * 0.9); cam.look_at(at + Vector3(0, size * 0.15, 0), Vector3.UP); cam.fov = 50.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
