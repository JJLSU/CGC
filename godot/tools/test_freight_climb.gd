extends SceneTree
## Up onto the freight in the open car: walking toward the crates' end you hop up onto the stack a crate at a time and
## stand on top while she runs; with no freight aboard you stay on the floor. Headless; a throwaway save. (<out> if given:
## a picture of him on top, windowed.)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0] if args.size() else ""
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build()
	var TR: Train = main.train
	TR.load_cargo(6)
	TR.passenger = true; TR.state = "run"; TR.leg = 0; TR.dir = 1; TR.s = TR.home_s() + 200.0
	for i in 30: await process_frame
	var car: Node3D = TR.ride_car(); var along: Vector3 = car.global_basis.z.normalized()
	var top := 0.0
	for i in 300: # (toward the crates' end: the car's +z)
		TR.move_rider(along, 1.0 / 60.0); top = maxf(top, TR.ride_y - TR.ride_floor.y)
		if top > 1.5: break # (on top of the stack: stand there)
	var mid := 0.0
	for i in 60:
		await process_frame
		if i == 4: mid = TR.ride_at.y - TR.ride_floor.y # (part way up, not there at once)
	print("part way up after a few frames: %.2f m" % mid)
	var stood: float = TR.ride_at.y - TR.ride_floor.y
	print("climbed onto the freight: highest %.2f m, standing %.2f m above the floor; his feet %.2f m above the car floor" % [top, stood, main.player.pos.y - car.to_global(TR.ride_floor).y])
	if out != "":
		main.set_process(false)
		var cam: Camera3D = main.rig.camera; var fw := along; var sd := fw.cross(Vector3.UP).normalized()
		cam.global_position = car.global_position + sd * 5.0 - fw * 6.0 + Vector3(0, 5.0, 0); cam.look_at(car.global_position + Vector3(0, 2.0, 0), Vector3.UP); cam.fov = 50.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
		main.set_process(true)
	TR.unload()
	for i in 60: TR.move_rider(-along, 1.0 / 60.0)
	var after: float = TR.ride_at.y - TR.ride_floor.y
	print("freight off: %.2f m above the floor" % after)
	var ok: bool = mid > 0.05 and mid < 1.9 and top > 0.9 and stood > 0.9 and after < 0.01
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("FREIGHT CLIMB TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
