extends SceneTree
## The new Homestead shelf and the palisade (the player's ask: more to build). Each piece placed; two mornings pass;
## E gathers what the coop, hay barn and shaft made; the well's drink fills stamina; the lean-to sleeps you at night;
## a palisade stops the farmer and a claim jumper. Headless.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame
func _e(main: Node) -> void:
	main.dog.pos = main.player.pos + Vector3(40, 0, 40) # (Old Blue sent off: at your heel his scratch takes the E)
	main.input.pressed["KeyE"] = true
	await process_frame; await process_frame
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run: an old one would load the pieces already built)
	if sp != "" and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.4; main.weather.rain = 0.0
	await _wait(2.0)
	var B: BuildSystem = main.build; var p: Player = main.player
	var shelf: Array = BuildSystem.DATA.PIECE_GROUPS.filter(func(g): return g[0] == "Homestead")
	print("Homestead shelf: %s; palisade on Yard: %s" % [shelf[0][1] if shelf.size() else "missing", BuildSystem.DATA.PIECE_GROUPS.any(func(g): return g[0] == "Yard" and g[1].has("palisade"))])
	var ok: bool = shelf.size() == 1
	var h: Vector3 = main.spawn + Vector3(-30, 0, 46)
	var placed := {}
	var i := 0
	for t in ["henhouse", "haybarn", "shaft", "well", "leanto"]:
		var x := h.x + i * 14.0; var z := h.z
		while Terrain.is_water(x, z) or Terrain.is_water(x, z + 4.0) or Terrain.is_water(x + 3.0, z): z += 6.0 # (on dry ground)
		var mesh := B.make_mesh(t, true); mesh.free() # (as the ghost is made first: the real box measured)
		placed[t] = B.add({"type": t, "x": x, "y": Terrain.get_height(x, z), "z": z, "rot": 0}, true)
		i += 1
	print("solid boxes: %s" % [["henhouse", "haybarn", "shaft", "well", "leanto"].map(func(t): return BuildSystem.PIECES[t].get("solid"))])
	await _wait(0.3) # (built: the count starts today)
	# two mornings
	for d in 2:
		main.sky.day += 1; main.sky.time = 0.3
		await _wait(0.3)
	for t in ["henhouse", "haybarn", "shaft"]:
		var q: Dictionary = placed[t]
		var before: Dictionary = main.inventory.duplicate()
		var f: Array = BuildSystem.DATA.FOOT[t]
		p.pos = Vector3(q.x, Terrain.get_height(q.x, q.z + f[1] + 0.9), q.z + f[1] + 0.9)
		await _wait(0.2)
		print("  at %s: beast '%s' yard '%s' stock %s near %s" % [t, main.beast_prompt, main.yard_prompt, q.stock, B.extra_near(p.pos) == q])
		await _e(main)
		var got := {}
		for k in BuildSystem.EXTRA[t].makes: got[k] = main.inventory.get(k, 0) - before.get(k, 0)
		print("%s: stock was 2 mornings, got %s" % [t, got])
		for k in BuildSystem.EXTRA[t].makes: ok = ok and got[k] == 2 * int(BuildSystem.EXTRA[t].makes[k])
	# the well
	var w: Dictionary = placed.well; var wf: Array = BuildSystem.DATA.FOOT.well
	p.pos = Vector3(w.x, Terrain.get_height(w.x, w.z + wf[1] + 0.9), w.z + wf[1] + 0.9); p.stamina = 10.0
	await _wait(0.2); await _e(main)
	print("well: stamina %.0f of %.0f" % [p.stamina, p.max_stamina])
	ok = ok and p.stamina > p.max_stamina * 0.9
	# and with Old Blue right at your heel, the well still gets the E (not a scratch for the dog)
	p.stamina = 10.0; main.dog.pos = p.pos + Vector3(0.5, 0, 0.3); await _wait(0.05)
	main.input.pressed["KeyE"] = true; await process_frame; await process_frame
	print("well with the dog at heel: stamina %.0f, prompt '%s'" % [p.stamina, main.beast_prompt])
	ok = ok and p.stamina > p.max_stamina * 0.9
	# the lean-to, at night
	var l: Dictionary = placed.leanto; var lf: Array = BuildSystem.DATA.FOOT.leanto
	main.sky.time = 0.9; var day0: int = main.sky.day
	p.pos = Vector3(l.x, Terrain.get_height(l.x, l.z + lf[1] + 0.9), l.z + lf[1] + 0.9)
	await _wait(0.2); await _e(main)
	await _wait(3.5)
	print("lean-to: slept through (day %d -> %d, clock %.2f)" % [day0, main.sky.day, main.sky.time])
	ok = ok and main.sky.day == day0 + 1
	# a palisade between the farmer and the far side
	var px := h.x; var pz := h.z + 30.0
	B.add({"type": "palisade", "x": px, "y": Terrain.get_height(px, pz), "z": pz, "rot": 0}, true)
	var into: Vector3 = B.collide(Vector3(px, Terrain.get_height(px, pz), pz + 0.05), 0.35)
	print("palisade pushes a body out: %.2f m" % Vector2(into.x - px, into.z - (pz + 0.05)).length())
	ok = ok and Vector2(into.x - px, into.z - (pz + 0.05)).length() > 0.3
	print("HOMESTEAD BUILD TEST ", "PASS" if ok else "FAIL")
	quit()
