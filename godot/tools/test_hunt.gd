extends SceneTree
## The bow: hold to draw (the reticle tightens and goes gold on a deer under it), let go, the deer folds down; a miss
## sticks in the turf. The six-shooter: a shot and its powder smoke, the cylinder one down. Fishing: cast from the
## bank, a bite, reel in a fish. Screenshots: drawing on the deer; the line out on the pond.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4
	for i in 30: await process_frame
	var p: Player = main.player; var cr: Critters = main.critters; var hu: Hunting = main.hunting
	main.tools["bow"] = true; main.held = "bow"
	main.rig.dist = 12.0; main.rig.pitch = 0.35; main.rig.yaw = 0.0
	main.rig.snap()
	# a deer, put down where the reticle meets the ground
	var deer = null
	for i in 600:
		for c in cr.list: if c.type == "deer": deer = c; break
		if deer != null: break
		await process_frame
	main.input.mouse_down = true
	for i in 20: await process_frame
	var g: Vector3 = hu.ground_at if hu.ground_at != null else p.pos + main.rig.forward() * 10.0
	var on_deer := false
	if deer != null:
		for i in 40:
			deer.puppet.group.position = Vector3(g.x, Terrain.get_height(g.x, g.z), g.z); deer.state = "idle"; deer.timer = 30.0; deer.speed = 0.0
			await process_frame
		on_deer = hu.target == deer
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
	main.input.mouse_down = false
	for i in 3: await process_frame
	var flying: int = hu.arrows.size()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and deer != null and deer.state != "down": await process_frame
	var downed: bool = deer != null and deer.state == "down"
	# a miss into the sky-ward ground far off: it sticks in the turf
	main.rig.yaw = PI; main.rig.snap()
	main.input.mouse_down = true
	for i in 40: await process_frame
	main.input.mouse_down = false
	t0 = Time.get_ticks_msec()
	var stuck := false
	while Time.get_ticks_msec() - t0 < 3000 and not stuck:
		await process_frame
		for a in hu.arrows: if a.stuck: stuck = true
	print("deer %s  on the reticle %s  arrow loosed %d  down %s  miss stuck %s" % [deer != null, on_deer, flying, downed, stuck])
	# the six-shooter
	main.tools["revolver"] = true; main.held = "revolver"; main.inventory.cartridges = 12
	main.input.mouse_down = true
	for i in 30: await process_frame
	main.input.mouse_down = false
	for i in 3: await process_frame
	var smoke := 0
	for q in hu.puffs: if q.mesh.visible: smoke += 1
	print("revolver loaded %d  smoke puffs %d" % [main.guns.revolver.loaded, smoke])
	# fishing from a bank: stand on the dry ground nearest the farm's pond, face the water
	main.tools["rod"] = true; main.held = "rod"
	var bank = null
	var c0 := p.pos
	for r in range(8, 200, 2):
		for k in 32:
			var a := TAU * k / 32.0
			var q := c0 + Vector3(cos(a), 0, sin(a)) * r
			if Terrain.is_water(q.x, q.z): continue
			for yk in 16:
				var yaw := TAU * yk / 16.0
				var f := Vector3(-sin(yaw), 0, -cos(yaw))
				var w := q + f * 5.0
				if Terrain.is_water(w.x, w.z) and Terrain.is_water(w.x + f.x * 2.0, w.z + f.z * 2.0) and Terrain.is_water(q.x + f.x * 3.5, q.z + f.z * 3.5): bank = [q, yaw]; break
			if bank != null: break
		if bank != null: break
	var caught := false
	if bank != null:
		p.pos = Vector3(bank[0].x, Terrain.get_height(bank[0].x, bank[0].z), bank[0].z); main.rig.yaw = bank[1]; main.rig.snap()
		for i in 3: await process_frame
		var hint: String = main.fish_r.hint
		main.input.clicked = true
		var tc := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tc < 1500: await process_frame
		var st: String = main.fishing.state
		main.fishing.timer = 0.0
		for i in 2: await process_frame
		var bite: bool = main.fishing.state == "bite"
		main.rig.dist = 9.0; main.rig.pitch = 0.5; main.rig.yaw = bank[1] + 0.9; main.rig.snap()
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_fish.png"))
		main.rig.yaw = bank[1]
		var fish0: int = main.inventory.get("fish", 0)
		main.input.clicked = true
		for i in 3: await process_frame
		caught = main.inventory.get("fish", 0) == fish0 + 1
		print("fishing hint [%s]  after the cast %s  bite %s  caught %s" % [hint, st, bite, caught])
	var ok: bool = on_deer and downed and stuck and main.guns.revolver.loaded == 5 and smoke > 0 and caught
	print("HUNT TEST ", "PASS" if ok else "FAIL")
	quit()
