extends SceneTree
## 21d: frame times at the farm at night (standing, the camera slowly turning), with the night's suspects switched off
## one at a time: the yard lamps, every OmniLight, the fireflies, the stars, bloom, SSAO, shadows of the moon.

func _measure(n: int) -> Array:
	var f := []
	for i in n:
		var t0 := Time.get_ticks_usec(); await process_frame; f.append((Time.get_ticks_usec() - t0) / 1000.0)
	f.sort()
	return [f.reduce(func(s, x): return s + x, 0.0) / f.size(), f[int(f.size() * 0.95)], f[-1]]

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	var p: Player = main.player
	p.pos = Vector3(2, Terrain.get_height(2, -18), -18); main.sky.time = float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() else 0.92
	main.rig.yaw = 0.35; main.rig.pitch = 0.46; main.rig.dist = 15.0; main.rig.snap()
	var ts := Time.get_ticks_msec()
	while Time.get_ticks_msec() - ts < 8000: await process_frame
	var env: Environment = main.env.environment
	var omnis: Array = root.find_children("*", "OmniLight3D", true, false)
	var lit := omnis.filter(func(o): return o.light_energy > 0.01)
	print("time %.2f  omni lights %d (lit %d)  objects %d  draw calls %d" % [main.sky.time, omnis.size(), lit.size(), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var wf := []
	var a := Vector3(-3, 0, -23.5); var b := Vector3(15, 0, 5); var dist := a.distance_to(b); var tt := 0.0
	while tt * 6.0 < dist:
		var t1 := Time.get_ticks_usec(); await process_frame; var dt := (Time.get_ticks_usec() - t1) / 1000.0; wf.append(dt); tt += dt / 1000.0
		var q := a.lerp(b, minf(1.0, tt * 6.0 / dist)); p.pos = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z)
	wf.sort(); print("walking the farm   avg %.1f  p95 %.1f  worst %.1f" % [wf.reduce(func(s, x): return s + x, 0.0) / wf.size(), wf[int(wf.size() * 0.95)], wf[-1]])
	var r: Array = await _measure(300); print("as it is           avg %.1f  p95 %.1f  worst %.1f" % r)
	for o in lit: o.visible = false
	r = await _measure(300); print("no point lights    avg %.1f  p95 %.1f  worst %.1f" % r)
	for o in lit: o.visible = true
	main.ambient.visible = false
	r = await _measure(300); print("no fireflies/amb   avg %.1f  p95 %.1f  worst %.1f" % r)
	main.ambient.visible = true
	main.night_sky.visible = false
	r = await _measure(300); print("no night sky       avg %.1f  p95 %.1f  worst %.1f" % r)
	main.night_sky.visible = true
	env.glow_enabled = false
	r = await _measure(300); print("no bloom           avg %.1f  p95 %.1f  worst %.1f" % r)
	env.glow_enabled = true; env.ssao_enabled = false
	r = await _measure(300); print("no SSAO            avg %.1f  p95 %.1f  worst %.1f" % r)
	env.ssao_enabled = true; main.sky.sun.shadow_enabled = false
	r = await _measure(300); print("no moon shadows    avg %.1f  p95 %.1f  worst %.1f" % r)
	main.sky.sun.shadow_enabled = true
	r = await _measure(300); print("as it is (again)   avg %.1f  p95 %.1f  worst %.1f" % r)
	quit()
