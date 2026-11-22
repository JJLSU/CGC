extends SceneTree
## The native camps: three camps found; cross the poles and a warrior comes out and warns (an arrow at your feet);
## stay and it's a fight (bowmen mount, arrows, the farmer hurt); a warrior struck down falls; back over the poles
## and they let you go; a gift at the poles buys peace and the fire offers trade. Screenshots: the camp; the fight.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4
	for i in 10: await process_frame
	var p: Player = main.player; var nc: NativeCamps = main.camp
	print("camps %d at %s" % [nc.list.size(), nc.list.map(func(c): return Vector2(c.at.x, c.at.z).round())])
	var c = nc.list[0]; var at: Vector3 = c.at
	# a look at the camp from outside the poles
	var dir: Vector3 = (main.spawn - at); dir.y = 0; dir = dir.normalized()
	var o: Vector3 = at + dir * (NativeCamps.R + 8.0)
	p.pos = Vector3(o.x, Terrain.get_height(o.x, o.z), o.z)
	main.rig.dist = 30.0; main.rig.pitch = 0.7; main.rig.yaw = atan2(dir.x, dir.z); main.rig.snap()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500: await process_frame
	main.rig.dist = 34.0; main.rig.pitch = 0.75; main.rig.yaw = atan2(-dir.x, -dir.z) + PI; main.rig.snap()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# cross the poles: warned
	var w_in: Vector3 = at + dir * (NativeCamps.R - 4.0)
	for w in c.warriors: w.fig.root.position = Vector3(w.home.x, Terrain.get_height(w.home.x, w.home.z), w.home.z); w.goal = w.home # (each at his post)
	p.pos = Vector3(w_in.x, Terrain.get_height(w_in.x, w_in.z), w_in.z)
	t0 = Time.get_ticks_msec()
	var warned := false; var shot_arrow := false
	while Time.get_ticks_msec() - t0 < 7500 and c.alarm != "fight":
		await process_frame
		if c.alarm == "warn": warned = true
		if c.warn_shot: shot_arrow = true
	# stay: a fight
	var h0 := p.health
	t0 = Time.get_ticks_msec()
	var mounted := false
	while Time.get_ticks_msec() - t0 < 12000:
		p.pos = Vector3(w_in.x, Terrain.get_height(w_in.x, w_in.z), w_in.z)
		await process_frame
		for w in c.warriors: if w.horse != null: mounted = true
		if mounted and p.health < h0: break
	var fought: bool = c.alarm == "fight"; var hurt := p.health < h0
	main.rig.dist = 16.0; main.rig.snap()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_fight.png"))
	p.health = p.max_health
	# strike one down
	var fell := false
	var w0: Dictionary = c.warriors[0]
	for i in 6: c.damage(w0, 3, main.camp_hooks)
	fell = w0.dead > 0.0
	# back over the poles
	var back: Vector3 = at + dir * (NativeCamps.R + 45.0)
	p.pos = Vector3(back.x, Terrain.get_height(back.x, back.z), back.z)
	for i in 5: await process_frame
	var let_go: bool = c.alarm == "none"
	# a gift at the poles, and trade at the fire
	main.inventory.honey = 2
	var pp: Vector3 = at + dir * NativeCamps.R
	p.pos = Vector3(pp.x, Terrain.get_height(pp.x, pp.z), pp.z)
	for i in 3: await process_frame
	var gift_prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var at_peace: bool = c.peace_until > main.sky.day
	p.pos = Vector3(at.x + 2.0, Terrain.get_height(at.x + 2.0, at.z), at.z)
	for i in 10: await process_frame
	var trade_prompt: String = main.beast_prompt
	# the camp at peace, from above (folk about the fire, lodges, the picket)
	p.pos = Vector3(at.x + dir.x * 14.0, 0, at.z + dir.z * 14.0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.rig.dist = 30.0; main.rig.pitch = 0.8; main.rig.yaw = atan2(dir.x, dir.z); main.rig.snap()
	var tp := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tp < 2000: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("warned %s (arrow at the feet %s)  fight %s  mounted %s  hurt %s  a warrior fell %s  let go %s" % [warned, shot_arrow, fought, mounted, hurt, fell, let_go])
	print("gift prompt [%s]  at peace %s  at the fire [%s]  alarm %s" % [gift_prompt, at_peace, trade_prompt, c.alarm])
	var ok: bool = nc.list.size() == 3 and warned and shot_arrow and fought and hurt and fell and let_go and at_peace and trade_prompt.begins_with("[E] Sit at their fire")
	print("CAMPS TEST ", "PASS" if ok else "FAIL")
	quit()
