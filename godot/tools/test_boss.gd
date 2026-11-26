extends SceneTree
## The boss battles (the player's ask): Mad Jebediah's diggings placed 300-450 m from town on dry ground; Main Street
## mended does NOT put up Second Street while the deed is stolen; near him he fights (thrown picks land and hurt; up
## close a slam); beaten, he drops the deed, which keeps; E picks it up; E at the assay office hands it in and Second
## Street goes up; the beaten/delivered flags save. Run with CGC_SAVE_PATH set to a throwaway. Headless.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run: an old one would load the bosses beaten)
	if sp != "" and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	await _wait(1.5)
	var B: Boss = main.boss; var p: Player = main.player; var T: Town = main.town
	var dist := Vector2(B.at.x - T.at.x, B.at.z - T.at.z).length()
	print("lair %.0f m from town, water %s" % [dist, Terrain.is_water(B.at.x, B.at.z)])
	var ok := dist > 250.0 and dist < 520.0 and not Terrain.is_water(B.at.x, B.at.z)
	# the gate: Main Street all mended, Second Street held back
	var gated := []
	T.on_gate = func(n: int) -> void: gated.append(n)
	for b in Town.BUILDINGS: T.mend(b.id)
	T.mend("church")
	print("Main done %s; Second opened %s; gate told %s" % [T.street_done(-1), 0 in T.opened, gated])
	ok = ok and T.street_done(-1) and not 0 in T.opened and gated == [0]
	var rm = main._boss_rumour(); print("rumour: %s, %d paces" % [rm.text if rm else "none", rm.paces if rm else 0])
	ok = ok and rm != null and String(rm.text).contains("Jebediah") and rm.paces > 100
	# go to him
	var off: Vector3 = B.at + (B.at - T.at).normalized() * -20.0
	p.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); p.health = p.max_health
	await _wait(0.6)
	print("built %s, figure %s, props %d, state %s" % [B.built, B.fig != null, B.nodes.size(), B.state])
	ok = ok and B.built and B.fig != null and B.nodes.size() >= 8
	# stand still: picks come and hurt
	var h0 := p.health; var thrown := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		p.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); p.health = maxf(p.health, 30.0); p.dead = false
		thrown = maxi(thrown, B.picks.size()); await process_frame
	print("fighting %s, picks out %d, health %.0f -> %.0f, bar visible %s" % [B.fighting(), thrown, h0, p.health, main.hud.boss_card.visible])
	ok = ok and B.fighting() and thrown >= 1 and p.health < h0 and main.hud.boss_card.visible
	# up close: a slam
	p.health = p.max_health
	var h1 := p.health; var slammed := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		var bp := B.pos(); p.pos = Vector3(bp.x + 2.0, Terrain.get_height(bp.x + 2.0, bp.z), bp.z); p.dead = false; p.health = maxf(p.health, 30.0)
		if B.slam_t >= 0.0: slammed = true
		await process_frame
	print("slam wound up %s, health %.0f -> %.0f" % [slammed, h1, p.health])
	ok = ok and slammed and p.health < h1
	# beat him
	p.health = p.max_health
	var n0: int = main.drops.size()
	while not B.beaten: B.damage(4, B.hooks)
	await _wait(0.3)
	var deed = main.drops.filter(func(d): return d.loot.has("deed"))
	print("beaten %s, deed dropped %s, bar hidden %s" % [B.beaten, deed.size() == 1, not main.hud.boss_card.visible])
	ok = ok and deed.size() == 1 and main.drops.size() == n0 + 1 and not main.hud.boss_card.visible
	# it keeps past a day
	main.sky.day += 2; await _wait(0.2)
	ok = ok and main.drops.any(func(d): return d.loot.has("deed"))
	var dp: Vector3 = deed[0].pos
	p.pos = Vector3(dp.x, Terrain.get_height(dp.x, dp.z), dp.z)
	await _wait(0.2)
	main.input.pressed["KeyE"] = true
	await _wait(0.2)
	print("deed in the pack: %d" % main.inventory.get("deed", 0))
	ok = ok and main.inventory.get("deed", 0) == 1
	# hand it in
	var ad: Vector3 = T.doors.assay
	p.pos = Vector3(ad.x, Terrain.get_height(ad.x, ad.z), ad.z)
	await _wait(0.3)
	main.input.pressed["KeyE"] = true
	await _wait(0.3)
	print("handed in: deed %d, delivered %s, Second Street opened %s" % [main.inventory.get("deed", 0), B.delivered, 0 in T.opened])
	ok = ok and main.inventory.get("deed", 0) == 0 and B.delivered and 0 in T.opened
	var sv: Dictionary = B.save()
	ok = ok and sv.beaten and sv.delivered
	# Big Angus: Second Street mended holds Third Street back till his timber rights are in
	var A: Boss = main.bosses[1]
	var da := Vector2(A.at.x - T.at.x, A.at.z - T.at.z).length(); var apart := Vector2(A.at.x - B.at.x, A.at.z - B.at.z).length()
	for bb in Town.STREETS[0].buildings: T.mend(bb.id)
	print("Angus %.0f m out (%.0f m from Jebediah); Second done %s, Third opened %s, gate told %s" % [da, apart, T.street_done(0), 1 in T.opened, gated])
	ok = ok and da > 420.0 and apart > 120.0 and T.street_done(0) and not 1 in T.opened and gated == [0, 1]
	var off2: Vector3 = A.at + (A.at - T.at).normalized() * -18.0
	p.pos = Vector3(off2.x, Terrain.get_height(off2.x, off2.z), off2.z); p.health = p.max_health
	var h2 := p.health; var axes := 0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		p.pos = Vector3(off2.x, Terrain.get_height(off2.x, off2.z), off2.z); p.health = maxf(p.health, 30.0); p.dead = false
		axes = maxi(axes, A.picks.size()); await process_frame
	print("Angus built %s, props %d, fighting %s, axes out %d, health %.0f -> %.0f, bar: %s" % [A.built, A.nodes.size(), A.fighting(), axes, h2, p.health, main.hud._boss_name.text])
	ok = ok and A.built and A.nodes.size() >= 12 and A.fighting() and axes >= 1 and p.health < h2 and main.hud._boss_name.text == "Big Angus Hackett"
	p.health = p.max_health
	while not A.beaten: A.damage(4, A.hooks)
	await _wait(0.3)
	var pr = main.drops.filter(func(d): return d.loot.has("timber_rights"))
	ok = ok and pr.size() == 1
	var tp: Vector3 = pr[0].pos; p.pos = Vector3(tp.x, Terrain.get_height(tp.x, tp.z), tp.z)
	await _wait(0.2); main.input.pressed["KeyE"] = true; await _wait(0.2)
	p.pos = Vector3(ad.x, Terrain.get_height(ad.x, ad.z), ad.z); await _wait(0.3); main.input.pressed["KeyE"] = true; await _wait(0.3)
	print("timber rights handed in %s, Third Street opened %s" % [A.delivered, 1 in T.opened])
	ok = ok and A.delivered and 1 in T.opened
	var all: Dictionary = main._bosses_save()
	ok = ok and all.jebediah.delivered and all.angus.delivered
	# Thaddeus Crane: once Third Street is mended he's the one left holding the town (the mortgage); dynamite blasts wide
	var C: Boss = main.bosses[2]
	ok = ok and main._boss_holding() == null
	for bb in Town.STREETS[1].buildings: T.mend(bb.id)
	print("Third done %s; holding: %s" % [T.street_done(1), main._boss_holding().title() if main._boss_holding() else "none"])
	ok = ok and main._boss_holding() == C
	var off3: Vector3 = C.at + (C.at - T.at).normalized() * -18.0
	p.pos = Vector3(off3.x, Terrain.get_height(off3.x, off3.z), off3.z); p.health = p.max_health
	var h3 := p.health; var sticks := 0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000:
		p.pos = Vector3(off3.x, Terrain.get_height(off3.x, off3.z), off3.z); p.health = maxf(p.health, 30.0); p.dead = false
		sticks = maxi(sticks, C.picks.size()); await process_frame
	print("Crane built %s, props %d, fighting %s, sticks out %d, health %.0f -> %.0f" % [C.built, C.nodes.size(), C.fighting(), sticks, h3, p.health])
	ok = ok and C.built and C.nodes.size() >= 15 and C.fighting() and sticks >= 1 and p.health < h3
	p.health = p.max_health
	while not C.beaten: C.damage(5, C.hooks)
	await _wait(0.3)
	var mg = main.drops.filter(func(d): return d.loot.has("mortgage"))
	ok = ok and mg.size() == 1
	var mp: Vector3 = mg[0].pos; p.pos = Vector3(mp.x, Terrain.get_height(mp.x, mp.z), mp.z)
	await _wait(0.2); main.input.pressed["KeyE"] = true; await _wait(0.2)
	var cash0: int = main.inventory.get("dollars", 0)
	p.pos = Vector3(ad.x, Terrain.get_height(ad.x, ad.z), ad.z); await _wait(0.3); main.input.pressed["KeyE"] = true; await _wait(0.3)
	print("mortgage handed in %s, +$%d, holding now %s" % [C.delivered, main.inventory.get("dollars", 0) - cash0, main._boss_holding()])
	ok = ok and C.delivered and main.inventory.get("dollars", 0) - cash0 == 150 and main._boss_holding() == null
	print("trophies over the assay office: %d" % T.trophies.get_child_count())
	ok = ok and T.trophies.get_child_count() == 3
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
