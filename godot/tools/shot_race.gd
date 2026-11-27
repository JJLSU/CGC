extends SceneTree
## The horse race: the course from above (<out>), Dusty Jake at the post (<out>_post.png), and the two of them racing
## for the second flag (<out>_run.png). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var R: HorseRace = main.race
	main.inventory.dollars = 20
	var c := R.start
	for f in R.flags: c += f
	c /= R.flags.size() + 1
	main.make_horse(R.start.x + 2, R.start.z + 3)
	for i in 90: main.player.pos = R.start + Vector3(4, 0, 4); await process_frame
	var cam: Camera3D = main.rig.camera
	main.set_process(false)
	cam.global_position = c + Vector3(0, 75, 0.01); cam.look_at(c, Vector3.FORWARD); cam.fov = 75.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	main.set_process(true)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_post.png"))
	main.riding = true; main.player.riding = true; main.player.avatar.riding = true
	R.begin()
	var p := R.start; var course: Array = R.flags + [R.start]; var k := 0
	while R.state != "run": main.player.pos = p; await process_frame
	while R.jake_next < 2 and R.state == "run":
		var tgt: Vector3 = course[k]; var d := Vector3(tgt.x - p.x, 0, tgt.z - p.z)
		p += d.normalized() * minf(d.length(), 15.0 * main.get_process_delta_time()); if d.length() < 1.0: k += 1
		p.y = Terrain.get_height(p.x, p.z); main.player.pos = p
		await process_frame
	for i in 3: main.player.pos = p; await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_run.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
