extends SceneTree
## The guardians: the nearest guarded site's keepers spawn with its chunk; walk in and they chase, wind up ("!") and
## lunge (the farmer is hurt); blows beat one (it folds flat, pelts); a peace offering puts the rest to sleep ("z z").
## Screenshot of a guardian winding up at the farmer.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4
	for i in 10: await process_frame
	var p: Player = main.player; var en: Enemies = main.enemies; var w: World = main.world
	# the nearest guarded site to the farm (a vein, grove or thicket: guards, not a landmark)
	var C := Terrain.CHUNK
	var pcx := floori(p.pos.x / C); var pcz := floori(p.pos.z / C)
	var site = null
	for r in range(0, 14):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r or site != null: continue
				var pl: Dictionary = Props.place(pcx + dx, pcz + dz, w.exclusions)
				for s in pl.sites: if s.kind != "landmark" and int(s.get("guards", 0)) > 0 and not s.has("guard"): site = s
		if site != null: break
	print("site %s" % [site])
	if site == null: print("ENEMIES TEST FAIL"); quit(); return
	p.pos = Vector3(site.x + 16.0, Terrain.get_height(site.x + 16.0, site.z), site.z)
	var t0 := Time.get_ticks_msec()
	var mine := []
	while Time.get_ticks_msec() - t0 < 8000 and mine.is_empty():
		await process_frame
		mine = en.list.filter(func(e): return e.site.key == site.key)
	print("guardians at the site: %d (%s)" % [mine.size(), mine[0].kind if mine.size() else "-"])
	# walk in: chase, wind-up, lunge
	var h0 := p.health
	var e0: Dictionary = mine[0] if mine.size() else {}
	var wound := false; var shot := false
	var states := {}
	if mine.size():
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 8000 and p.health >= h0:
			var ep := Enemies.pos(e0)
			p.pos = Vector3(ep.x + 1.2, Terrain.get_height(ep.x + 1.2, ep.z), ep.z)
			await process_frame
			states[e0.state] = true
			if e0.warn.visible and not shot:
				shot = true
				main.rig.dist = 7.0; main.rig.pitch = 0.45; main.rig.yaw = 0.2; main.rig.snap()
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(out)
		wound = p.health < h0
	print("states %s  farmer hurt %s (%.0f -> %.0f)" % [states.keys(), wound, h0, p.health])
	p.health = p.max_health
	# a peace offering: it dozes ("z z"); then wake it again for the fight
	var calm := false
	if mine.size():
		main.inventory.fish = 5; main.inventory.apples = 5; main.inventory.berries = 5; main.inventory.milk = 5; main.inventory.honey = 5
		var ep := Enemies.pos(e0)
		p.pos = Vector3(ep.x + 2.0, Terrain.get_height(ep.x + 2.0, ep.z), ep.z)
		for i in 2: await process_frame
		main.input.pressed["KeyE"] = true
		for i in 10: await process_frame
		calm = en.is_calm(e0, main.sky.day + main.sky.time) and e0.zz.visible
		en.calm_by_site.erase(site.key); e0.calmUntil = 0.0
	# beat it: blows until it folds
	var beaten := false
	if mine.size():
		var blows := 0
		while blows < 20 and not e0.dying:
			main.guardian_hit(e0, 4); blows += 1
			await process_frame
		beaten = e0.dying > 0.0 and w.destroyed.has(e0.key)
	print("dozing after the offering %s  beaten %s  pelts %d" % [calm, beaten, main.inventory.get("pelt", 0)])
	var ok: bool = mine.size() > 0 and (states.has("chase") or states.has("attack")) and wound and calm and beaten
	print("ENEMIES TEST ", "PASS" if ok else "FAIL")
	quit()
