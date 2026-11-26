extends SceneTree
## A look at Mad Jebediah mid-fight at his diggings (a pick in the air, the bar up): <out.png> after --. Windowed.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]
	var close := args.size() > 1 and args[1] == "close" # (up close, walking at you with the pick in hand, nothing in the air)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var B: Boss = main.boss; var p: Player = main.player
	var dir: Vector3 = (main.town.at - B.at).normalized()
	var off: Vector3 = B.at + dir * 16.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000:
		p.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); p.health = p.max_health; p.dead = false
		main.rig.yaw = atan2(dir.x, dir.z) + 0.5; main.rig.pitch = 0.32; main.rig.dist = 8.0 if close else 15.0
		if close and Time.get_ticks_msec() - t0 > 6000 and B.act_t < -0.3 and B.slam_t < 0.0 and B.speed > 1.0: break
		if not close and Time.get_ticks_msec() - t0 > 6000 and B.picks.any(func(k): return k.landed < 0.0 and k.t > 0.35): break
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
