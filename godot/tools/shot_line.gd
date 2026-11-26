extends SceneTree
## A stretch of the line out past the town (<out>): ties, rails, the telegraph poles and their wires. Windowed; a
## throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.62; main.weather.rain = 0.0
	main._dev_town()
	var R: Railroad = main.railroad
	for i in 10: await process_frame
	R.build()
	var i0: int = mini(R.path.size() - 10, R.depot_i + 260)
	var a: Vector3 = R.path[i0]; var b: Vector3 = R.path[i0 + 8]; var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized(); var side := Vector3(-dir.z, 0, dir.x)
	for i in 60: main.player.pos = a + side * 8.0; await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera; var y := Terrain.get_height(a.x, a.z)
	cam.global_position = a - side * 9.0 - dir * 6.0 + Vector3(0, y + 4.5 - a.y, 0); cam.look_at(a + dir * 14.0 + Vector3(0, y + 2.5 - a.y, 0), Vector3.UP); cam.fov = 55.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
