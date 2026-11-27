extends SceneTree
## The full-size train: standing at the depot beside the platform (<out>_depot.png), and you riding in the gondola out
## on the line (<out>_ride.png). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build()
	var TR: Train = main.train; var R: Railroad = main.railroad
	var plat: Vector3 = R.depot_group.to_global(Vector3(-2, 0.3, 3.4))
	for i in 90: main.player.pos = plat; await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera; var c: Vector3 = TR.cars[1].global_position
	cam.global_position = c + (plat - c).normalized() * 14.0 + Vector3(0, 6, 0); cam.look_at(c + Vector3(0, 1.5, 0), Vector3.UP); cam.fov = 55.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_depot.png"))
	main.set_process(true); main.player.avatar.root.visible = true
	TR.load_cargo(6); TR.board_riders()
	TR.passenger = true; TR.state = "run"; TR.leg = 0; TR.dir = 1; TR.s = TR.home_s() + 200.0
	TR.rider_t = 0.3
	for i in 60: await process_frame
	main.input.keys["KeyD"] = true # (a few steps across the car)
	for i in 30: await process_frame
	main.input.keys.erase("KeyD")
	for i in 30: await process_frame
	main.set_process(false)
	var feet: float = main.player.avatar.root.global_position.y; var floor_y: float = TR.ride_car().to_global(TR.ride_floor).y
	print("feet %.2f vs the car floor %.2f; rider moved off the middle %.2f m" % [feet, floor_y, Vector2(TR.ride_at.x - TR.ride_floor.x, TR.ride_at.z - TR.ride_floor.z).length()])
	var rc: Node3D = TR.ride_car(); var fw: Vector3 = rc.global_basis.z.normalized(); var sd := Vector3(fw.z, 0, -fw.x)
	cam.global_position = rc.global_position + sd * 3.5 - fw * 4.0 + Vector3(0, 7.0, 0); cam.look_at(rc.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_ride.png"))
	print("traveller says: '%s' visible %s" % [TR.rider_card.text if TR.rider_card else "-", TR.rider_card.visible if TR.rider_card else false])
	print("rider at %.1f above the track; train visible %s, car %s at %s, player at %s, head %s, cam %s" % [main.player.pos.y - R.grade_d(TR.s), TR.visible, rc.visible, rc.global_position.round(), main.player.pos.round(), TR.at(TR.s).pos.round(), cam.global_position.round()])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
