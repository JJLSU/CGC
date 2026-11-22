extends SceneTree
## The pond life: the duck family turns up on a pond near the farmer and takes corn; frogs settle on lily pads and
## leap off when he comes close; a tumbleweed bowls along; the beaver finds its lodge if one is near. Screenshot of
## the ducks on the water.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4
	var p: Player = main.player
	# the nearest open pond to the farm (water with open water 3.5 m all round)
	var c := p.pos; var pond := Vector3.INF
	var r := 10.0
	while r < 400.0 and pond == Vector3.INF:
		for k in 48:
			var a := TAU * k / 48.0; var x := c.x + cos(a) * r; var z := c.z + sin(a) * r
			if not Terrain.is_water(x, z): continue
			var open := true
			for j in 8: if not Terrain.is_water(x + cos(j * 0.785) * 3.5, z + sin(j * 0.785) * 3.5): open = false; break
			if open: pond = Vector3(x, 0, z); break
		r += 4.0
	# stand on the bank 16 m off
	var stand := pond
	for k in 64:
		var a := TAU * k / 64.0; var x := pond.x + cos(a) * 16.0; var z := pond.z + sin(a) * 16.0
		if not Terrain.is_water(x, z): stand = Vector3(x, Terrain.get_height(x, z), z); break
	p.pos = stand
	main.dog.pos = stand + Vector3(30, 0, 30)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000 and main.ducks.fam == null: await process_frame
	var fam: bool = main.ducks.fam != null
	var n_ducks: int = main.ducks.fam.ducks.size() if fam else 0
	# corn: walk to the water's edge by the mother
	var fed := false
	if fam:
		var m: Vector3 = main.ducks.fam.ducks[0].p.group.position
		var best := Vector3.INF
		for k in 32: # the nearest bank to her: out from the mother along 32 rays to the first dry ground
			var a := TAU * k / 32.0
			for st in 200:
				var q := m + Vector3(cos(a), 0, sin(a)) * (st * 0.25)
				if not Terrain.is_water(q.x, q.z):
					if best == Vector3.INF or m.distance_to(q) < m.distance_to(best): best = q
					break
		if m.distance_to(best) > 6.0: best = m + (best - m).normalized() * 6.0 # (a big pond: he wades out toward her, as he can)
		p.pos = Vector3(best.x, Terrain.get_height(best.x, best.z), best.z)
		main.inventory.corn = 2
		for i in 3: await process_frame
		print("bank %.1f m from her  spot %s  prompt [%s]" % [p.pos.distance_to(m), main.ducks.toss_spot(p.pos.x, p.pos.z), main.beast_prompt])
		main.input.pressed["KeyE"] = true
		for i in 3: await process_frame
		fed = main.ducks.fam != null and main.ducks.fam.come != null
	print("pond at %s  family %s (%d)  fed %s" % [pond, fam, n_ducks, fed])
	if main.ducks.fam != null:
		var m: Vector3 = main.ducks.fam.ducks[0].p.group.position
		main.rig.dist = 9.0; main.rig.pitch = 0.6
		main.rig.yaw = atan2(p.pos.x - m.x, p.pos.z - m.z)
		main.rig.snap()
		for i in 90: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
	# frogs: the pads round here
	var pads: Array = main.frogs.pads(main.world, p.pos)
	var on_pads := 0
	var leapt := false
	if pads.size():
		var pad = pads[0]
		p.pos = Vector3(pad.x + 8.0, Terrain.get_height(pad.x + 8.0, pad.z), pad.z)
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000: await process_frame
		on_pads = main.frogs.mm.visible_instance_count
		var f0 = null
		for f in main.frogs.frogs: if f.pad != null and f.state == "sit": f0 = f; break
		if f0 != null:
			p.pos = Vector3(f0.pad.x + 1.5, p.pos.y, f0.pad.z)
			for i in 60: await process_frame
			leapt = f0.state in ["leap", "under"]
	print("pads %d  frogs on pads %d  leapt %s" % [pads.size(), on_pads, leapt])
	# a tumbleweed
	var tw: Tumbleweeds = main.tumbleweeds
	tw.wait = 0.0
	tw.update(0.016, p, true, [])
	var x0: float = tw.list[0].x if tw.list.size() else 0.0
	for i in 30: await process_frame
	tw.update(0.5, p, false, [])
	var rolled: bool = tw.list.size() > 0 and tw.list[0].x > x0
	print("tumbleweed rolled %s  beaver lodge %s" % [rolled, main.beaver.lodge != null])
	var ok: bool = fam and n_ducks >= 4 and fed and rolled and (pads.is_empty() or (on_pads > 0 and leapt))
	print("POND TEST ", "PASS" if ok else "FAIL")
	quit()
