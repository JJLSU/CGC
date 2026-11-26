extends SceneTree
## Evenings and trouble in town: the barn dance on a dance night (join in with E); Saturday's fireworks once every
## street is mended; smoke over a campfire; a war party rides on a mended building and circles it, is driven off when
## two riders fall (+$10); a second raid left alone wrecks the building. Screenshots: the dance (out), the fireworks
## (out_fw), the raid (out_raid).

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0
	for i in 10: await process_frame
	var p: Player = main.player; var T: Town = main.town
	var shot := func(path: String) -> void:
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(path)
	# the barn dance, on a dance night
	main.sky.day = 7; main.sky.time = 0.78
	var D: BarnDance = main.dance
	p.pos = D.at + Vector3(2.5, 0, 2.5); p.pos.y = T.y0
	main.rig.dist = 12.0; main.rig.pitch = 0.6; main.rig.yaw = 0.8; main.rig.snap()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await process_frame
	var dance_up: bool = D.shown and D.up > 0.9
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var joined: bool = main.dance_t > 0.0
	await shot.call(out)
	# a campfire's smoke
	main.sky.day = 2; main.sky.time = 0.45
	var fx := p.pos.x + 30.0; var fz := p.pos.z
	main.build.add({"type": "campfire", "x": fx, "y": Terrain.get_height(fx, fz), "z": fz, "rot": 0})
	p.pos = Vector3(fx + 4.0, Terrain.get_height(fx + 4.0, fz), fz)
	for i in 10: await process_frame
	var smoke: int = main.fire_smoke.puffs.visible_instance_count
	# a raid on the mended store, driven off
	T.mend("store")
	main.camp.raid.end()
	var started: bool = main.camp.start_raid(T.at, {"id": "store", "name": "general store", "door": T.doors.store})
	var R = main.camp.raid
	var sd: Vector3 = T.doors.store
	p.pos = Vector3(sd.x, T.y0, sd.z) - T.toward * T.find_b("store").side * 6.0
	main.rig.dist = 20.0; main.rig.pitch = 0.6; main.rig.snap()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000 and not R.riders.any(func(w): return w.circling): await process_frame
	var circled: bool = R.riders.any(func(w): return w.circling)
	var rp: Vector3 = R.riders[0].fig.root.position
	p.pos = rp + (T.doors.store - rp).normalized() * 5.0; p.pos.y = T.y0
	main.rig.yaw = atan2(p.pos.x - rp.x, p.pos.z - rp.z); main.rig.dist = 12.0; main.rig.pitch = 0.45; main.rig.snap()
	for i in 5: await process_frame
	await shot.call(out.replace(".png", "_raid.png"))
	var d0: int = main.inventory.get("dollars", 0)
	for k in 2:
		var w = R.riders[k]
		for i in 3: main.camp.damage(w, 4, main.camp_hooks, main.raid_hooks)
	var repelled: bool = R.fleeing and main.inventory.get("dollars", 0) == d0 + 10
	R.end()
	# a second raid, left alone: the store is wrecked
	var again: bool = main.camp.start_raid(T.at, {"id": "store", "name": "general store", "door": T.doors.store})
	for w in R.riders: w.circling = true
	print("second raid %s riders %d on %s" % [again, R.riders.size(), R.on])
	R.sack_t = 21.9
	for i in 30: await process_frame
	var sacked: bool = T.tiers.get("store", 0) == 0 and T.raided.has("store")
	print("sack_t %.2f fleeing %s tiers %s" % [R.sack_t, R.fleeing, T.tiers.get("store", 0)])
	R.end()
	# Saturday's fireworks: every street mended
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: if not T.tiers.get(id, 0): T.mend(id)
	for st in Town.STREETS: for b in st.buildings: if not T.tiers.get(b.id, 0): T.mend(b.id)
	main.sky.day = 6; main.sky.time = 0.8
	p.pos = T.at - T.along * 8.0; p.pos.y = T.y0
	main.rig.dist = 30.0; main.rig.pitch = -0.25; main.rig.yaw = atan2(-T.along.x, -T.along.z); main.rig.snap()
	t0 = Time.get_ticks_msec()
	var stars := 0
	while Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		stars = maxi(stars, main.fireworks.mm.visible_instance_count)
		if stars > 40: break
	await shot.call(out.replace(".png", "_fw.png"))
	print("dance %s joined %s  smoke puffs %d  raid started %s circled %s repelled %s sacked %s  fireworks stars %d  crowd out %s" % [dance_up, joined, smoke, started, circled, repelled, sacked, stars, T.fireworks_on])
	var ok: bool = dance_up and joined and smoke > 0 and started and circled and repelled and sacked and stars > 20
	print("TOWN4 TEST ", "PASS" if ok else "FAIL")
	quit()
