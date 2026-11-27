extends SceneTree
## The train robbers riding alongside the open car while you ride it, from up behind the car (<out>), and one shot
## down beside the line (<out>_down.png). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build()
	var TR: Train = main.train; var RB: TrainRobbers = main.robbers
	main.tools["shotgun"] = true; main.held = "shotgun"
	main.rob_hooks.on_hit = func(_d: int) -> void: pass
	TR.passenger = true; TR.state = "run"; TR.leg = 0; TR.dir = 1; TR.s = TR.home_s() + 200.0
	for i in 30: await process_frame
	RB.start(TR, 3)
	for i in 420:
		await process_frame
		if i == 395: RB._call("come") # (his call as they come alongside, for the look)
	var cam: Camera3D = main.rig.camera
	var rc: Node3D = TR.ride_car(); var fw: Vector3 = TrainRobbers._fwd(rc); var sd := fw.cross(Vector3.UP).normalized()
	for k in 2:
		main.set_process(false)
		cam.global_position = rc.global_position - fw * 13.0 + sd * 2.0 + Vector3(0, 7.5, 0); cam.look_at(rc.global_position + fw * 2.0 + Vector3(0, 1.5, 0), Vector3.UP); cam.fov = 60.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out if k == 0 else out.replace(".png", "_down.png"))
		main.set_process(true)
		if k == 0:
			var t: Array = RB.targets(); main.hunting.on_target.call(t[0], {"dmg": 20})
			for i in 60: await process_frame
	print("card: '%s'" % (RB.card.text if RB.card else "-"))
	for m in RB.men: print("rider %s at %.1f m from the car, dead %s" % [m.fig.name, Vector2(m.pos.x - rc.global_position.x, m.pos.z - rc.global_position.z).length(), m.dead > 0.0])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
