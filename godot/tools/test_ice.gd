extends SceneTree
## 23b: the ponds' ice. Thick snow freezes the nearest pond ("The ponds have frozen over!"), the farmer skates across
## it (the skate journal event after a second's glide over 2.2 m/s, the blade scratches in pairs behind him), the
## ice holds under his boots after the snow has gone, and the scratches clear once it thaws. Screenshot: <out>.

func _wait(sec: float, main: Node = null, snow := -1.0) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0:
		if main and snow >= 0.0: main.weather.snow = snow
		await process_frame

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.45
	var p: Player = main.player
	var c := p.pos; var pond := Vector3.INF; var r := 10.0
	while r < 400.0 and pond == Vector3.INF:
		for k in 48:
			var a := TAU * k / 48.0; var x := c.x + cos(a) * r; var z := c.z + sin(a) * r
			if not Terrain.is_water(x, z): continue
			var open := true
			for j in 8: if not Terrain.is_water(x + cos(j * 0.785) * 5.0, z + sin(j * 0.785) * 5.0): open = false; break
			if open: pond = Vector3(x, 0, z); break
		r += 4.0
	await _wait(2.0)
	# a hard snow: the ice comes (sped up: the page takes ~40 s)
	main.weather.kind = "snow"; main.weather.snow = 1.0; main.ice = 0.79
	await _wait(1.5, main, 1.0)
	var toasted: bool = main.hud.live.any(func(n): return "frozen over" in n.text) or main.hud.queue.any(func(t): return "frozen over" in t)
	print("ice %.2f  ice_on %s  toast %s" % [main.ice, p.ice_on, toasted])
	var ok: bool = p.ice_on and toasted
	# out onto the pond, gliding
	p.pos = Vector3(pond.x - 3.0, Terrain.get_height(pond.x, pond.z), pond.z); p.vel = Vector3.ZERO
	main.rig.yaw = 0.6; main.rig.pitch = 0.5; main.rig.dist = 9.0; main.rig.snap()
	await process_frame
	main.input.keys["KeyD"] = true
	await _wait(2.5, main, 1.0)
	main.input.keys.erase("KeyD")
	var placed := 0
	for i in main.TRACKS: if main.tracks.multimesh.get_instance_transform(i).basis.get_scale().x > 0.5: placed += 1
	print("on_ice %s  speed %.1f  skate %s  scratches %d" % [p.on_ice, Vector2(p.vel.x, p.vel.z).length(), main.journal.day_log.get("skate", 0), placed])
	ok = ok and main.journal.day_log.get("skate", 0) >= 1 and placed >= 4 and main.tracks.visible
	await _wait(0.6, main, 1.0)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# the snow goes: the ice stays under his boots while he's on the pond
	main.weather.snow = 0.0; main.ice = 0.75
	await _wait(0.5, main, 0.0)
	print("thawing, on the pond: ice_on %s" % p.ice_on)
	ok = ok and p.ice_on
	# off the pond and thawed: the scratches go
	p.pos = Vector3(c.x, Terrain.get_height(c.x, c.z), c.z); main.ice = 0.2
	await _wait(0.5, main, 0.0)
	print("thawed: ice_on %s  tracks visible %s" % [p.ice_on, main.tracks.visible])
	ok = ok and not p.ice_on and not main.tracks.visible
	print("ICE TEST ", "PASS" if ok else "FAIL")
	quit()
