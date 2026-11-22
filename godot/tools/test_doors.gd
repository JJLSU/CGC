extends SceneTree
## The town's trade doors: the assayer buys gold (fortune grows), the store opens its shelves, the sheriff posts a
## bounty (the WANTED poster) and pays it once the den is beaten, the barber, the telegraph's wire, the church's
## blessing, the saloon's supper and tip, the livery's horse, the Grand Hotel's feather bed, the stage line to a found
## landmark and back, panning in the shallows. Screenshot: the WANTED poster by the jail.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.45; main.sky.day = 2
	for i in 10: await process_frame
	var p: Player = main.player; var T: Town = main.town; var inv: Dictionary = main.inventory
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	var res := {}
	var at_door := func(id: String) -> void:
		var d: Vector3 = T.doors[id]; p.pos = Vector3(d.x, T.y0, d.z)
		for i in 3: await process_frame
	var press := func() -> void:
		main.input.pressed["KeyE"] = true
		for i in 3: await process_frame
	inv.dollars = 200
	# the assayer
	inv.gold = 5; p.pos = T.doors.assay; p.pos.y = T.y0
	for i in 3: await process_frame
	await press.call(); res.assay = main.fortune == 20 and inv.gold == 0
	# the store's shelves
	await at_door.call("store"); await press.call(); res.store = main.panel.open; main._close_craft()
	# the sheriff
	await at_door.call("jail"); await press.call()
	res.bounty_posted = main.bounty != null and main.poster != null
	if main.bounty != null:
		var b: Dictionary = main.bounty
		var jp: Vector3 = main.poster.position
		var fr: Vector3 = main.poster.global_transform.basis.z; fr.y = 0; fr = fr.normalized()
		p.pos = jp + fr * 2.5 + fr.cross(Vector3.UP) * 1.2; p.pos.y = T.y0
		main.rig.dist = 4.5; main.rig.pitch = 0.15; main.rig.yaw = atan2(fr.x, fr.z); main.rig.snap()
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
		for i in int(b.guards): main.world.destroyed["%s:g%d" % [b.key, i]] = true
		var d0: int = inv.dollars
		await at_door.call("jail"); await press.call()
		res.bounty_paid = inv.dollars == d0 + b.pay and main.bounty == null
	# the barber, the wire, the church, the saloon, the livery
	await at_door.call("barber"); await press.call(); res.barber = inv.get("groomedDay", -1) == main.sky.day
	var wire: Array = main.MARKET[(main.sky.day * 5 + 3) % main.MARKET.size()]; inv[wire[0]] = 3
	await at_door.call("telegraph"); var d1: int = inv.dollars; await press.call(); res.wire = inv.dollars == d1 + 3 * wire[1]
	p.health = 50.0
	await at_door.call("church"); await press.call(); res.church = main.blessed_day == main.sky.day and p.health == p.max_health
	p.fullness = 20.0
	await at_door.call("saloon"); print("saloon prompt [%s] dollars %d" % [main.beast_prompt, inv.dollars]); await press.call(); res.saloon = p.fullness > 99.0; print("fullness %.1f" % p.fullness)
	await at_door.call("livery"); await press.call(); res.livery = main.horse != null
	# the stage line to a found landmark, and home
	var lm_key := ""
	for u in Props.unique_encounters():
		lm_key = "%d,%d,landmark" % [floori(u.x / Terrain.CHUNK), floori(u.z / Terrain.CHUNK)]
		if u.mark == "arch": break
	main.landmarks.found[lm_key] = true
	await at_door.call("stable2"); await press.call()
	res.stage_out = main.stage_from != null and p.pos.distance_to(T.at) > 60.0
	await press.call()
	res.stage_home = main.stage_from == null and p.pos.distance_to(T.doors.stable2) < 4.0
	# the Grand Hotel at night
	main.sky.time = 0.85; p.fullness = 20.0
	await at_door.call("hotel2"); await press.call()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and main.sleep_timer > 0.0: await process_frame
	res.hotel = p.fullness >= 60.0 and main.sky.time < 0.3
	# panning in the shallows
	var w = null
	for r in range(5, 200, 3):
		for k in 24:
			var q := p.pos + Vector3(cos(k * 0.26), 0, sin(k * 0.26)) * r
			if Terrain.is_water(q.x, q.z) and Terrain.wadeable(q.x, q.z): w = q; break
		if w != null: break
	if w != null:
		p.pos = Vector3(w.x, Terrain.get_height(w.x, w.z), w.z)
		for i in 5: await process_frame
		await press.call()
		res.pan = main.pan_t > 0.0 or main.pan_mesh.visible
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("DOORS TEST ", "PASS" if ok else "FAIL")
	quit()
