extends SceneTree
## A look at Mad Jebediah mid-fight at his diggings (a pick in the air, the bar up): <out.png> after --. Windowed.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]
	var close := args.size() > 1 and args[1] == "close" # (up close, walking at you with the pick in hand, nothing in the air)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var B: Boss = main.bosses[2] if args.has("crane") else (main.bosses[1] if args.has("angus") else main.boss); var p: Player = main.player
	var dir: Vector3 = (main.town.at - B.at).normalized()
	if args.has("lair"): # (the camp from above and well back, the boss beaten and gone: just the layout)
		B.beaten = true
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 5000:
			var st: Vector3 = B.at + dir * 2.0
			main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); main.rig.yaw = atan2(dir.x, dir.z); main.rig.pitch = 0.9; main.rig.dist = 42.0
			await process_frame
		main.player.avatar.root.visible = false
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out); quit(); return
	if args.has("spoils"): # (beaten: stand at his mine mouth for the day's go at it)
		B.beaten = true; var mo: Vector3 = B.mouth + (B.at - B.mouth).normalized() * 2.0
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 5000:
			main.player.pos = Vector3(mo.x, Terrain.get_height(mo.x, mo.z), mo.z); main.rig.yaw = atan2(dir.x, dir.z) + 0.3; main.rig.pitch = 0.3; main.rig.dist = 11.0
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out); quit(); return
	var off: Vector3 = B.at + dir * 16.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000:
		p.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); p.health = p.max_health; p.dead = false
		main.rig.yaw = atan2(dir.x, dir.z) + 0.5; main.rig.pitch = (0.2 if args.has("taunt") else 0.32); main.rig.dist = (12.0 if args.has("slam") else 8.0) if close else (26.0 if args.has("taunt") else 15.0)
		if args.has("fall"): # (beaten: catch the dust a moment after he hits the ground)
			if Time.get_ticks_msec() - t0 > 2500 and B.alive(): while B.alive(): B.damage(10, B.hooks)
			if B.dead > 0.45: break
			await process_frame; continue
		if args.has("taunt"): # (as he calls out, the card half a second up)
			if Time.get_ticks_msec() - t0 > 3000 and B.fighting() and B.say_t <= 0.0: B.say("fight", true)
			if B.say_t > 2.0 and B.say_t < 2.5 and Time.get_ticks_msec() - t0 > 3000: break
			await process_frame; continue
		if args.has("special"): # (riled, his third throw due: catch his trick in the air)
			if B.fighting() and B.hp > int(B.spec.hp) / 3: B.hp = int(B.spec.hp) / 3; B.throws = 2; B.cool = 0.0
			if B.picks.any(func(k): return k.landed < 0.0 and k.get("drop", false) and k.t > k.dur * 0.8) and B.picks.size() >= 3: break
			await process_frame; continue
		if args.has("slam"): # (stand in his reach till he winds up, and catch the ring half spread)
			var bp: Vector3 = B.pos(); p.pos = Vector3(bp.x + 3.0, Terrain.get_height(bp.x + 3.0, bp.z), bp.z)
			if B.slam_t > 0.0 and B.slam_t < 0.35: break
			await process_frame; continue
		if close and Time.get_ticks_msec() - t0 > 6000 and B.act_t < -0.3 and B.slam_t < 0.0 and B.speed > 1.0: break
		if not close and Time.get_ticks_msec() - t0 > 6000 and B.picks.any(func(k): return k.landed < 0.0 and k.t > 0.35): break
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
