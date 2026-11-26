extends SceneTree
## Each boss's special, once he's riled (below half health), every third throw: Jebediah's rockfall (three boulders
## dropping round you, each marked), Angus's fan of three axes, Crane's ring of dynamite (three round you and one
## where you stand); and they hurt. Run with CGC_SAVE_PATH set to a throwaway save (never the player's): headless.

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
	var p: Player = main.player; var ok := true
	var want := {"jebediah": [3, 3], "angus": [3, 0], "crane": [4, 0]} # (how many come, how many fall from above)
	for b in main.bosses:
		var off: Vector3 = b.at + (b.at - main.town.at).normalized() * -16.0
		p.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); p.health = p.max_health; p.dead = false
		await _wait(0.5)
		b.vel = Vector3.ZERO; b.last_p = p.pos # (the teleport here would read as a sprint to his aim)
		b.state = "fight"; b.hp = int(b.spec.hp) / 3; b.throws = 2; b.cool = 0.0; b.slam_t = -1.0
		var most := 0; var drops := 0; var h0 := p.health
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500:
			p.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); p.health = maxf(p.health, 30.0); p.dead = false
			var live: Array = b.picks.filter(func(k): return k.landed < 0.0)
			if live.size() > most: most = live.size(); drops = live.filter(func(k): return k.get("drop", false)).size()
			await process_frame
		print("%s: special of %d (%d falling), health %.0f -> %.0f" % [b.title(), most, drops, h0, p.health])
		ok = ok and most >= want[b.id][0] and drops == want[b.id][1] and p.health < h0
		b.state = "home"; b.picks.map(func(k): (k.node as Node).queue_free()); b.picks.clear()
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
