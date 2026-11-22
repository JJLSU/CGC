extends SceneTree
## Settlers: a storehouse brings folk to camp at the farm's edge; Silas is hired for apples and berries, walks to the
## woodlot, works, fills his crate and carries it to the storehouse; E there takes the wood; R stocks the larder;
## Big Jim is beaten at arm-wrestling. Screenshot of the camp.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4
	for i in 10: await process_frame
	var p: Player = main.player; var st: Settlers = main.settlers; var C: Vector3 = main.spawn
	var sx := C.x + 4.0; var sz := C.z + 22.0
	main.build.add({"type": "storehouse", "x": sx, "y": Terrain.get_height(sx, sz), "z": sz, "rot": 0.0})
	var wx := C.x - 26.0; var wz := C.z + 26.0
	main.build.add({"type": "woodlot", "x": wx, "y": Terrain.get_height(wx, wz), "z": wz, "rot": 0.0})
	var tw := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tw < 2500: await process_frame
	var camped := st.list.filter(func(q): return q.state == "camp").size()
	var silas: Dictionary = st.list[0]
	# the camp, from above
	var sp := Settlers.spos(silas)
	p.pos = Vector3(sp.x + 3.0, Terrain.get_height(sp.x + 3.0, sp.z + 3.0), sp.z + 3.0)
	main.rig.dist = 11.0; main.rig.pitch = 0.6; main.rig.yaw = 0.4; main.rig.snap()
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# hire Silas
	main.inventory.apples = 10; main.inventory.berries = 10
	p.pos = Vector3(sp.x + 1.0, Terrain.get_height(sp.x + 1.0, sp.z), sp.z)
	for i in 3: await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var hired: bool = silas.state == "hired"
	# off to the woodlot: a little work, a crateful, the haul
	p.pos = Vector3(C.x, Terrain.get_height(C.x, C.z), C.z)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and Vector2(Settlers.spos(silas).x - wx - 1.3, Settlers.spos(silas).z - wz - 0.9).length() > 0.9: await process_frame
	var at_work: bool = Vector2(Settlers.spos(silas).x - wx - 1.3, Settlers.spos(silas).z - wz - 0.9).length() <= 0.9
	silas.made = 44.9; silas.load = 2
	for i in 30: await process_frame
	var hauling: bool = silas.hauling
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000 and st.stock.get("wood", 0) == 0: await process_frame
	var stocked: int = st.stock.get("wood", 0)
	# the storehouse: E takes it, R stocks the larder
	p.pos = Vector3(sx + 1.5, Terrain.get_height(sx + 1.5, sz), sz)
	for i in 3: await process_frame
	var w0: int = main.inventory.get("wood", 0)
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var took: int = main.inventory.get("wood", 0) - w0
	main.inventory.fish = 4
	main.input.pressed["KeyR"] = true
	for i in 3: await process_frame
	print("camped %d  prompt [%s]  hired %s  at the woodlot %s  hauling %s  stocked %d  took %d  larder %d" % [camped, prompt, hired, at_work, hauling, stocked, took, st.larder])
	# Big Jim, arm-wrestled
	var jim: Dictionary = st.list[3]
	var jp := Settlers.spos(jim)
	p.pos = Vector3(jp.x + 1.0, Terrain.get_height(jp.x + 1.0, jp.z), jp.z)
	for i in 3: await process_frame
	for i in 200:
		main.input.pressed["KeyE"] = true
		await process_frame
		if jim.state == "hired": break
	print("Big Jim hired %s" % [jim.state == "hired"])
	var ok: bool = camped >= 10 and hired and at_work and stocked >= 3 and took >= 3 and st.larder >= 4 and jim.state == "hired"
	print("SETTLERS TEST ", "PASS" if ok else "FAIL")
	quit()
