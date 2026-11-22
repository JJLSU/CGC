extends SceneTree
## Sound (step 19a): the baked bank loads; walking plays paper footsteps; a swing at a tree chops; the banjo tune for
## the hour starts; rain swells the rain bed; N mutes; crossing into a wild land names it (and its wind changes);
## the master bus carries real audio (recorded RMS).

func _rms(w: AudioStreamWAV) -> float:
	var d := w.data; var n := d.size() / 4; var s := 0.0
	for i in n: var x := d.decode_s16(i * 4) / 32768.0; s += x * x
	return sqrt(s / maxf(1, n))

func _playing(snd: Sound, base: String) -> bool:
	var list: Array = snd.bank.get(base, [])
	for p in snd.pool: if p.playing and list.has(p.stream): return true
	return false

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.35; main.sky.day = 3
	for i in 10: await process_frame
	var p: Player = main.player; var S: Sound = main.sound; var res := {}
	var rec := AudioEffectRecord.new(); AudioServer.add_bus_effect(0, rec); rec.set_recording_active(true)
	res.bank = S.bank.size() > 150
	# footsteps: walk forward a second
	var stepped := false
	main.input.keys["KeyW"] = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await process_frame
		stepped = stepped or _playing(S, "step_grass") or _playing(S, "step_wood")
	main.input.keys.erase("KeyW")
	res.steps = stepped
	# a chop at the nearest tree
	var tree = null; var td := INF
	for r in main.world.resources_near(p.pos.x, p.pos.z, 30.0):
		if r.type in ["pine", "maple", "goldtree", "birch"] and r.alive:
			var d := Vector2(r.x - p.pos.x, r.z - p.pos.z).length()
			if d < td: td = d; tree = r
	if tree != null:
		p.pos = Vector3(tree.x + 1.0, Terrain.get_height(tree.x + 1.0, tree.z), tree.z); p.facing = atan2(-1.0, 0.0)
		main.rig.yaw = p.facing + PI; main.rig.snap()
		for i in 3: await process_frame
		main.pick_tool("axe")
		var chopped := false
		for k in 3:
			main.input.clicked = true
			t0 = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 700:
				await process_frame
				chopped = chopped or _playing(S, "chop")
		res.chop = chopped
	# the banjo
	S.note_t = 0.0
	for i in 3: await process_frame
	res.music = S.music.playing and String(S.music.stream.resource_path).contains("tune_sunup")
	# rain
	main.weather.rain = 1.0; main.weather.kind = "rain"
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500: await process_frame
	res.rain_bed = S.beds.rain.player.volume_db > -40.0 # (from silent: -80 dB)
	rec.set_recording_active(false)
	var rms := _rms(rec.get_recording())
	res.audible = rms > 0.003
	# N mutes
	main.input.pressed["KeyN"] = true
	for i in 3: await process_frame
	res.mute = AudioServer.is_bus_mute(0)
	main.input.pressed["KeyN"] = true
	for i in 3: await process_frame
	# into a wild land
	var wild = null
	for r in range(150, 600, 20):
		for k in 24:
			var q := Vector3(cos(k * 0.26) * r, 0, sin(k * 0.26) * r)
			Terrain.land_at(q.x, q.z)
			if Terrain.L_wild > 0.8 and not Terrain.is_water(q.x, q.z): wild = q; break
		if wild != null: break
	if wild != null:
		p.pos = Vector3(wild.x, Terrain.get_height(wild.x, wild.z), wild.z)
		for i in 5: await process_frame
		res.land = main.land_here != "home" and main.lands_found.has(main.land_here)
	print("bank %d sounds  recorded master rms %.4f  rain bed %.1f dB  land %s  music %s" % [S.bank.size(), rms, S.beds.rain.player.volume_db, main.land_here, S.music.stream.resource_path if S.music.stream else "-"])
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("SOUND TEST ", "PASS" if ok else "FAIL")
	quit()
