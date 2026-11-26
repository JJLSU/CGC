extends SceneTree
## Walks the farmer: holds W for 2 s, then W+Shift for 2 s, then turns the camera and walks into the nearest water.
## Checks he moves at the web's speeds (6 m/s walking, 11.5 sprinting), spends stamina sprinting, stays on the
## ground, and never walks into deep water.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	var p: Player = main.player
	var inp: GameInput = main.input
	for i in 30: await process_frame
	# a clear line to walk and run (since the hen house and the rest of the yard stand round the porch): the yaw
	# whose 40 m ahead is free of colliders, trees, rocks and water
	var rig: CameraRig = main.rig
	for k in 32:
		rig.yaw = TAU * k / 32.0
		var f := rig.forward(); var clear := true
		for st in range(1, 40):
			var q := p.pos + f * float(st)
			if Terrain.is_water(q.x, q.z): clear = false; break
			for c in main.world.colliders: if Vector2(c.x - q.x, c.z - q.z).length() < c.r + 0.6: clear = false
			for r in main.world.resources_near(q.x, q.z, 1.5): if not r.type in Res.WALK_THROUGH: clear = false
			if not clear: break
		if clear: break
	var start := p.pos
	inp.keys["KeyW"] = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000: await process_frame
	var walked := Vector2(p.pos.x - start.x, p.pos.z - start.z).length()
	var st0 := p.stamina
	inp.keys["ShiftLeft"] = true
	var a := p.pos
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000: await process_frame
	var ran := Vector2(p.pos.x - a.x, p.pos.z - a.z).length()
	print("walked 2s: %.2f m  sprinted 2s: %.2f m  stamina %.1f -> %.1f  ground %.3f vs y %.3f  anim %s" % [walked, ran, st0, p.stamina, p.ground_at(p.pos.x, p.pos.z), p.pos.y, p.avatar.fig.current])
	var grounded := absf(p.pos.y - p.ground_at(p.pos.x, p.pos.z)) < 0.05
	var spent := p.stamina < st0
	inp.keys.erase("ShiftLeft")
	# head for the water: aim the camera so forward points at the nearest deep water within 120 m
	var best := Vector3.ZERO; var bd := INF
	for ang in range(0, 360, 10):
		for r in range(4, 120, 4):
			var x := p.pos.x + cos(deg_to_rad(ang)) * r; var z := p.pos.z + sin(deg_to_rad(ang)) * r
			if Terrain.is_water(x, z) and not Terrain.wadeable(x, z):
				if r < bd: bd = r; best = Vector3(x, 0, z)
				break
	var deep_in := false
	if bd < INF:
		var d := (best - p.pos).normalized()
		p.rig.yaw = atan2(-d.x, -d.z) # (forward = (-sin yaw, -cos yaw))
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < (bd / 6.0 + 3.0) * 1000.0:
			await process_frame
			if Terrain.is_water(p.pos.x, p.pos.z) and not Terrain.wadeable(p.pos.x, p.pos.z): deep_in = true
		print("water %.0f m off; ended %.1f m from it, in deep water at any point: %s" % [bd, Vector2(p.pos.x - best.x, p.pos.z - best.z).length(), deep_in])
	var ok := walked > 10.5 and walked < 12.5 and ran > 19.0 and ran < 23.5 and spent and grounded and not deep_in
	print("PLAYER TEST ", "PASS" if ok else "FAIL")
	quit()
