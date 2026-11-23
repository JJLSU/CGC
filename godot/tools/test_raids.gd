extends SceneTree
## The raids as the player asked: a war party only comes down on the town while you're in it (within 60 m), falls
## on a mended building and, left at it, wrecks it back to run-down (to be mended again); if you leave (past 150 m)
## they ride off and the building is spared. And a warrior's blow or arrow takes a quarter of the farmer's starting
## health (25).

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _has(hud: Hud, s: String) -> bool:
	return hud.heard.any(func(h): return s in h)

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.5
	await _wait(2.0)
	var T: Town = main.town; var p: Player = main.player
	if not T.tiers.get("store", 0): T.mend("store")
	var ok := true
	# unarmed: no raid even in town (the player's ask: not till you've a bow or a gun)
	p.pos = T.at; p.pos.y = T.y0; main.raid_day = 0; main.sky.day = 5
	main.tools.erase("bow"); main.tools.erase("revolver"); main.tools.erase("rifle")
	await process_frame; await process_frame
	print("unarmed in town: raid %s" % main.camp.raid.on)
	ok = ok and not main.camp.raid.on
	main.raid_day = 999; main.tools["bow"] = true
	await process_frame
	if main.camp.raid.on: main.camp.raid.end()
	# away from town (100 m): no raid, even on raid day
	p.pos = T.at + Vector3(100, 0, 0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.raid_day = 0; main.sky.day = 5
	main._raid_tick()
	print("100 m out: raid %s" % main.camp.raid.on)
	ok = ok and not main.camp.raid.on
	# in town: it comes
	p.pos = T.at; p.pos.y = T.y0
	main.raid_day = 0
	main._raid_tick()
	print("in town: raid %s on %s" % [main.camp.raid.on, main.camp.raid.target.get("id", "")])
	ok = ok and main.camp.raid.on
	# you leave: they ride off, the building spared
	var tgt: String = main.camp.raid.target.id
	p.pos = T.at + Vector3(180, 0, 0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	await _wait(0.5)
	print("left: fleeing %s  toast %s  %s still mended %s" % [main.camp.raid.fleeing, _has(main.hud, "rides back into the hills"), tgt, T.tiers.get(tgt, 0) > 0])
	ok = ok and main.camp.raid.fleeing and T.tiers.get(tgt, 0) > 0 and _has(main.hud, "rides back into the hills")
	main.camp.raid.end()
	# stay, and leave them at it: the building is wrecked back to run-down
	p.pos = T.at; p.pos.y = T.y0
	main.camp.start_raid(T.at, {"id": "store", "name": "general store", "door": T.doors.store})
	for w in main.camp.raid.riders: w.circling = true
	main.camp.raid.sack_t = 21.9
	await _wait(0.5)
	print("left at it: store tier %d (run-down 0), raided %s" % [T.tiers.get("store", 0), T.raided.has("store")])
	ok = ok and T.tiers.get("store", 0) == 0
	main.camp.raid.end()
	# a blow: 25 off 100
	p.health = p.max_health; p.hurt_timer = 0.0; main.tools.erase("coat")
	main.camp_hooks.on_hit.call(NativeCamps.HIT)
	print("a blow: health %.0f of %.0f" % [p.health, p.max_health])
	ok = ok and is_equal_approx(p.health, p.max_health - 25.0)
	print("RAIDS TEST ", "PASS" if ok else "FAIL")
	quit()
