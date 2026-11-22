extends SceneTree
## Paydirt Hollow: the town stands where the web puts it (at -70.11, 24.64 for the default seed); Main Street run-down;
## E at the store's door mends it (dollars, keeper, sign); mend all of Main Street and Second Street goes up; the
## settlers live on Squatters' Row. Screenshots: Main Street run-down (out), and mended (out_mended), at dusk.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.42
	for i in 10: await process_frame
	var p: Player = main.player; var T: Town = main.town
	print("town at %s along %s  offs %s  (web: -70.11, 24.64; along -0.766, 0.643; offs [32, -32])" % [T.at, T.along, T.street_offs])
	var look := func(path: String) -> void:
		var v: Vector3 = T.at - T.along * 26.0
		p.pos = Vector3(v.x, Terrain.get_height(v.x, v.z), v.z)
		main.rig.dist = 30.0; main.rig.pitch = 0.5; main.rig.yaw = atan2(-T.along.x, -T.along.z); main.rig.snap()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(path)
	await look.call(out)
	# mend the store at its door
	main.inventory.dollars = 500
	var d: Vector3 = T.doors.store
	p.pos = Vector3(d.x, T.y0, d.z)
	for i in 3: await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var store_mended: bool = T.tiers.get("store", 0) == 1 and main.inventory.dollars == 475 and T.folk.has("store")
	# all of Main Street: Second Street goes up
	for id in ["assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	var second := 0 in T.opened
	main.sky.time = 0.78
	await look.call(out.replace(".png", "_mended.png"))
	var homes: Array = main.settlers.list.slice(0, 3).map(func(s): return main.settlers.camp_at(s).distance_to(T.at) < 60.0)
	print("prompt [%s]  store mended %s  second street %s  settlers' homes in town %s  lamps %d  chimneys %d" % [prompt, store_mended, second, homes, T.street_lamps.size(), T.chimneys.size()])
	var ok: bool = absf(T.at.x + 70.114) < 0.05 and absf(T.at.z - 24.637) < 0.05 and store_mended and second and homes.all(func(h): return h)
	print("TOWN TEST ", "PASS" if ok else "FAIL")
	quit()
