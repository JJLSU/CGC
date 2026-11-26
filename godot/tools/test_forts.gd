extends SceneTree
## The army's forts (the player's ask): two or three placed for the county, clear of the town and each other; built
## as you come near with their troopers; they leave you be (standing among them a while costs nothing); strike one
## and the fort turns out and fires; a trooper beaten drops his haversack; walk far off and they go back to their
## posts; by the next day it's forgotten; the stockade stops you; saved. Headless; CGC_SAVE_PATH a throwaway.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	await _wait(1.0)
	var F: ArmyForts = main.forts; var p: Player = main.player; var T: Town = main.town
	var apart := INF
	for i in F.forts.size(): for j in range(i + 1, F.forts.size()): apart = minf(apart, Vector2(F.forts[i].at.x - F.forts[j].at.x, F.forts[i].at.z - F.forts[j].at.z).length())
	var from_town: float = F.forts.map(func(f): return Vector2(f.at.x - T.at.x, f.at.z - T.at.z).length()).min()
	print("forts %d, apart %.0f m, nearest town %.0f m" % [F.forts.size(), apart, from_town])
	var ok: bool = F.forts.size() >= 2 and F.forts.size() <= 3 and apart > 200.0 and from_town > 150.0
	var f: Dictionary = F.forts[0]
	var fz := Vector3(sin(f.face), 0, cos(f.face))
	# inside the gate among them: they let you be
	var inside: Vector3 = f.at + fz * 8.0
	p.pos = Vector3(inside.x, Terrain.get_height(inside.x, inside.z), inside.z); p.health = p.max_health
	await _wait(0.5)
	var h0 := p.health
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: p.pos = Vector3(inside.x, Terrain.get_height(inside.x, inside.z), inside.z); await process_frame
	print("built %s, %d men, %d pieces; 4 s among them: health %.0f -> %.0f, angry %s" % [f.built, f.men.size(), f.nodes.size(), h0, p.health, f.angry])
	ok = ok and f.built and f.men.size() >= 5 and f.nodes.size() >= 12 and p.health == h0 and not f.angry
	# the stockade stops you (a wall post pushes you out); the gate doesn't
	var wallq: Vector3 = ArmyForts._wall_point(f.at, Vector3(cos(f.face), 0, -sin(f.face)), fz, 2, 0.0)
	var on_wall: bool = main.world.colliders.any(func(c): return Vector2(c.x - wallq.x, c.z - wallq.z).length() < 1.0)
	var gq: Vector3 = f.at + fz * (ArmyForts.SIDE / 2.0)
	var on_gate: bool = main.world.colliders.any(func(c): return Vector2(c.x - gq.x, c.z - gq.z).length() < 1.5)
	print("a wall post at the side: %s; the gate open: %s" % [on_wall, not on_gate])
	ok = ok and on_wall and not on_gate
	# strike one: the fort turns out and fires
	var m: Dictionary = f.men[3]
	F.damage(m, 2, main.fort_hooks)
	t0 = Time.get_ticks_msec(); var fired := false
	h0 = p.health
	while Time.get_ticks_msec() - t0 < 6000:
		p.pos = Vector3(inside.x, Terrain.get_height(inside.x, inside.z), inside.z)
		if p.health < h0: fired = true
		p.health = maxf(p.health, 80.0); p.dead = false; main.death_timer = 0.0; h0 = p.health
		await process_frame
	var fighting: int = f.men.filter(func(q): return q.state == "fight").size()
	print("struck one: angry %s, fighting %d, hurt by fire %s" % [f.angry, fighting, fired])
	ok = ok and f.angry and fired and fighting >= 4
	# beat him: his haversack
	var n0: int = main.drops.size()
	while not m.dead: F.damage(m, 4, main.fort_hooks)
	await _wait(0.2)
	print("haversack dropped %s" % (main.drops.size() == n0 + 1))
	ok = ok and main.drops.size() == n0 + 1
	# walk far off: back to their posts; the next day, forgotten
	var far: Vector3 = f.at + fz * 140.0
	p.pos = Vector3(far.x, Terrain.get_height(far.x, far.z), far.z); await _wait(0.5)
	var settled: bool = f.men.filter(func(q): return not q.dead).all(func(q): return q.state != "fight")
	main.sky.day += 1; await _wait(0.3)
	print("far off, all stood down %s; next day still angry %s" % [settled, f.angry])
	ok = ok and settled and not f.angry
	# the officer's job: the nearest jumpers' camp; cleared, $30 at the fort
	var f2: Dictionary = F.forts[1]; var fz2 := Vector3(sin(f2.face), 0, cos(f2.face))
	var ins2: Vector3 = f2.at + fz2 * 8.0; p.pos = Vector3(ins2.x, Terrain.get_height(ins2.x, ins2.z), ins2.z); p.health = p.max_health; p.dead = false; main.death_timer = 0.0
	await _wait(0.6)
	var off = f2.men.filter(func(q): return q.role == "officer")[0]
	var op: Vector3 = off.fig.root.position; p.pos = Vector3(op.x + 1.0, Terrain.get_height(op.x + 1.0, op.z), op.z)
	await _wait(0.3); var prompt1: String = main.beast_prompt
	main.input.pressed["KeyE"] = true; await _wait(0.2)
	print("officer: '%s' -> job camp %d" % [prompt1, f2.job])
	ok = ok and f2.job >= 0
	if f2.job >= 0:
		main.jumpers.camps[f2.job].cleared_day = main.sky.day # (as though you'd beaten them all)
		var c0: int = main.inventory.get("dollars", 0)
		await _wait(0.2); main.input.pressed["KeyE"] = true; await _wait(0.2)
		print("reported: +$%d, job now %d" % [main.inventory.get("dollars", 0) - c0, f2.job])
		ok = ok and main.inventory.get("dollars", 0) - c0 == 30 and f2.job == -1
	# hire an escort ($20, R at the officer); into a claim jumpers' camp, they fire on the men chasing you
	main.inventory.dollars = 40; main.sky.time = 0.45
	var op2: Vector3 = off.fig.root.position; p.pos = Vector3(op2.x + 1.0, Terrain.get_height(op2.x + 1.0, op2.z), op2.z)
	await _wait(0.3); main.input.pressed["KeyR"] = true; await _wait(0.3)
	print("escort hired: %d troopers, $%d left" % [main.escort.size(), main.inventory.dollars])
	ok = ok and main.escort.size() == 2 and main.inventory.dollars == 20
	var jc: Dictionary = main.jumpers.camps[0]; jc.cleared_day = -999
	var jst: Vector3 = jc.at + Vector3(22, 0, 0)
	var hp0 := 0; var hit_by_escort := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000:
		p.pos = Vector3(jst.x, Terrain.get_height(jst.x, jst.z), jst.z); p.health = maxf(p.health, 60.0); p.dead = false; main.death_timer = 0.0
		if jc.built and hp0 == 0: for m2 in jc.men: hp0 += m2.hp
		if jc.built and hp0 > 0:
			var now := 0
			for m2 in jc.men: now += maxi(0, m2.hp)
			if now < hp0: hit_by_escort = true
		await process_frame
	print("escort followed (nearest %.1f m), jumpers hurt by their fire %s" % [main.escort.map(func(e2): return e2.fig.root.position.distance_to(p.pos)).min(), hit_by_escort])
	ok = ok and hit_by_escort and main.escort.map(func(e2): return e2.fig.root.position.distance_to(p.pos)).min() < 8.0
	main.sky.time = 0.85; await _wait(0.2)
	print("at sundown the escort's gone: %s" % main.escort.is_empty())
	ok = ok and main.escort.is_empty()
	var sv: Array = F.save()
	ok = ok and sv.size() == F.forts.size()
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("FORTS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
