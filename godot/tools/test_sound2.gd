extends SceneTree
## Sound (step 19b) and what came with it: striking a built piece (a knock each blow; broken: a tear, "Broke ..."
## and its cost back), tapping a maple (a plop), the kite (a tear), the bed (the lullaby).

func _playing(snd: Sound, base: String) -> bool:
	var list: Array = snd.bank.get(base, [])
	for p in snd.pool: if p.playing and list.has(p.stream): return true
	return false

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4; main.sky.day = 3
	for i in 10: await process_frame
	if main.glint != null: main.glint.queue_free(); main.glint = null
	var p: Player = main.player; var S: Sound = main.sound; var inv: Dictionary = main.inventory; var res := {}
	var press := func(key := "KeyE") -> void:
		main.input.pressed[key] = true
		for i in 3: await process_frame
	# a workbench a step ahead, struck till it breaks
	var f := p.forward(); var bx := p.pos.x + f.x * 1.6; var bz := p.pos.z + f.z * 1.6
	var bench: Dictionary = main.build.add({"type": "workbench", "x": bx, "y": Terrain.get_height(bx, bz), "z": bz, "rot": 0}, true)
	for i in 5: await process_frame
	main.pick_tool("axe")
	var w0: int = inv.get("wood", 0); var knocked := false; var tore := false; var hint := ""
	for k in 12:
		if not main.build.pieces.has(bench): break
		main.input.clicked = true
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 650:
			await process_frame
			knocked = knocked or _playing(S, "knock"); tore = tore or _playing(S, "tear")
			if hint == "" and main.piece_t != null: hint = "aimed"
	res.piece = hint == "aimed" and knocked and tore and not main.build.pieces.has(bench) and inv.get("wood", 0) > w0
	# a maple: E taps it
	var maple = null; var md := INF
	for r in main.world.resources_near(p.pos.x, p.pos.z, 60.0):
		if r.type == "maple" and r.alive:
			var d := Vector2(r.x - p.pos.x, r.z - p.pos.z).length()
			if d < md: md = d; maple = r
	if maple != null:
		var dir := Vector3(1, 0, 0)
		p.pos = Vector3(maple.x - dir.x * 1.2, Terrain.get_height(maple.x - dir.x * 1.2, maple.z), maple.z)
		main.rig.yaw = atan2(-dir.x, -dir.z); main.rig.snap()
		for i in 5: await process_frame
		var s0: int = inv.get("sap", 0)
		await press.call()
		res.sap = inv.get("sap", 0) == s0 + 1 and _playing(S, "plop")
	# the kite; the bed
	main.tools["kite"] = true
	await press.call("KeyG"); res.kite = main.kite.flying and _playing(S, "tear")
	await press.call("KeyG")
	print("maple %s  wood %d -> %d" % [maple != null, w0, inv.get("wood", 0)])
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("SOUND2 TEST ", "PASS" if ok else "FAIL")
	quit()
