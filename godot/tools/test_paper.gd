extends SceneTree
## The 18d bits: the kite up on G (out_kite), a leaf pile kicked (out_leaves), snow footprints (out_snow), a fairy
## ring the morning after rain and gathered (out_ring), sunbeams in the woods (out_shafts), the will-o'-the-wisp
## leading to a satchel by night, hoof dust behind a galloping horse.

func _shot(path: String, n := 20) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.35; main.sky.day = 3
	for i in 10: await process_frame
	var p: Player = main.player; var res := {}
	if main.glint != null: main.glint.queue_free(); main.glint = null
	var press := func(key := "KeyE") -> void:
		main.input.pressed[key] = true
		for i in 3: await process_frame
	var stand := func(at: Vector3) -> void:
		p.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z)
		for i in 3: await process_frame
	# the kite
	main.tools["kite"] = true
	await press.call("KeyG")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	res.kite = main.kite.flying and main.kite.pos.y > p.pos.y + 4.0
	main.rig.dist = 16.0; main.rig.pitch = 0.35; main.rig.snap()
	await _shot(out.replace(".png", "_kite.png"))
	await press.call("KeyG"); res.kite_down = not main.kite.flying
	# a leaf pile: run straight through it
	var LP: LeafPiles = main.leaf_piles; var s: Vector3 = LP.spots[1]
	await stand.call(s + Vector3(-0.5, 0, 0)); p.vel = Vector3(4, 0, 0)
	LP.update(0.016, [{"pos": p.pos, "speed": 4.0}])
	for i in 20: await process_frame
	res.leaves = LP.moving > 20
	main.rig.dist = 7.0; main.rig.pitch = 0.5; main.rig.snap()
	await _shot(out.replace(".png", "_leaves.png"), 5)
	# snow: footprints
	main.weather.snow = 1.0
	for k in 12:
		p.pos = Vector3(s.x + 3.0 + k * 0.7, 0, s.z + 3.0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
		for i in 2: await process_frame
	res.prints = main.footprints.mm.visible_instance_count >= 8
	main.rig.dist = 6.0; main.rig.pitch = 0.8; main.rig.snap()
	await _shot(out.replace(".png", "_snow.png"))
	main.weather.snow = 0.0
	# a fairy ring the morning after a wet night
	var FR: FairyRing = main.fairy_ring
	main.ring_rain = true; main.sky.time = 0.3
	for i in 5: await process_frame
	res.ring_up = FR.state == "up"
	if FR.state == "up":
		await stand.call(FR.at + Vector3(4, 0, 3))
		main.rig.dist = 8.0; main.rig.pitch = 0.6; main.rig.snap()
		await _shot(out.replace(".png", "_ring.png"), 60)
		await stand.call(FR.at)
		var m0: int = main.inventory.get("mushrooms", 0)
		await press.call(); res.ring_gathered = main.inventory.mushrooms == m0 + 6 and FR.state == "none"
	# sunbeams in the woods, early morning
	var fp = null
	for r in range(10, 400, 6):
		for k in 16:
			var q: Vector3 = p.pos + Vector3(cos(k * 0.39), 0, sin(k * 0.39)) * r
			if Terrain.region_at(q.x, q.z) == "forest": fp = q; break
		if fp != null: break
	main.sky.time = 0.3
	if fp != null: await stand.call(fp)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000: await process_frame
	res.shafts = main.shafts.mi.visible and main.shafts.strength > 0.05
	main.rig.dist = 22.0; main.rig.pitch = 0.6; main.rig.snap()
	await _shot(out.replace(".png", "_shafts.png"))
	# hoof dust
	main.hoof_dust.update(0.1, p.pos, Vector3(8, 0, 0), true, main.rig.camera)
	main.hoof_dust.update(0.1, p.pos, Vector3(8, 0, 0), true, main.rig.camera)
	res.dust = main.hoof_dust.mm.visible_instance_count > 0
	# the wisp, by night (if a lost satchel lies within four chunks)
	main.sky.time = 0.95; main.wisp.cool = 0.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 and main.wisp.state != "leading": await process_frame
	print("wisp: %s target %s search %s cool %.1f night %.2f at %s" % [main.wisp.state, main.wisp.target, main.wisp.search, main.wisp.cool, main.sky.night, p.pos])
	print("shaft strength %.3f  prints %d  leaves moving %d" % [main.shafts.strength, main.footprints.mm.visible_instance_count, LP.moving])
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("PAPER TEST ", "PASS" if ok else "FAIL")
	quit()
