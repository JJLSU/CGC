extends SceneTree
## Iron near the farm (an outcrop of ore 45-75 m out) and the night's prowlers: after dark, away from home and town,
## a pair of night coyotes settles ahead and comes for you, biting lightly (6); beaten, they're gone, and at dawn any
## left go and nothing of theirs stays in the save's "gone" list. Headless.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame
func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	await _wait(3.0)
	var home: Vector3 = main.homestead.spawn
	var ore := []
	for ch in main.world.chunks.values():
		for r in ch.resources: if r.type == "ore" and Vector2(r.x - home.x, r.z - home.z).length() < 80.0: ore.append(Vector2(r.x - home.x, r.z - home.z).length())
	print("iron ore within 80 m of the farm: %d rocks (nearest %.0f m); the outcrop: %d pieces" % [ore.size(), ore.min() if ore.size() else -1.0, Props.starter_ore([]).size()])
	var ok: bool = ore.size() >= 3
	# night, out in the county
	var p: Player = main.player
	var out: Vector3 = home + Vector3(70, 0, 70)
	while Terrain.is_water(out.x, out.z) or Vector2(out.x - main.town.at.x, out.z - main.town.at.z).length() < 80.0: out += Vector3(15, 0, -10)
	p.pos = Vector3(out.x, Terrain.get_height(out.x, out.z), out.z); p.facing = 0.3
	main.sky.time = 0.9
	await _wait(0.5)
	main._night_t = 0.0 # (once it's dark: the first pair would come ~40 s after nightfall)
	await _wait(0.5)
	print("  night %.2f  timer %.1f  home %.0f m  town %.0f m  sites %d" % [main.sky.night, main._night_t, Vector2(p.pos.x - home.x, p.pos.z - home.z).length(), Vector2(p.pos.x - main.town.at.x, p.pos.z - main.town.at.z).length(), main._night_sites.size()])
	var pack: Array = main.enemies.list.filter(func(e): return String(e.key).begins_with("night:"))
	print("night: %d prowlers, %s, hp %s, bite %s" % [pack.size(), pack[0].spec.name if pack.size() else "-", pack.map(func(e): return e.hp), pack[0].spec.dmg if pack.size() else "-"])
	ok = ok and pack.size() == 2 and pack[0].spec.dmg == 6
	# let them come: you're hurt, but not badly
	var h0 := p.health
	var t0 := Time.get_ticks_msec()
	var st: Dictionary = pack[0].site
	p.pos = Vector3(st.x + 4.0, Terrain.get_height(st.x + 4.0, st.z), st.z)
	while Time.get_ticks_msec() - t0 < 6000: await process_frame
	print("six seconds among them: health %.0f -> %.0f" % [h0, p.health])
	ok = ok and p.health < h0 and p.health > h0 * 0.3
	for e in pack: while not e.dying: main.guardian_hit(e, 3)
	await _wait(0.5)
	# dawn
	main.sky.time = 0.3
	await _wait(1.0)
	var left: Array = main.enemies.list.filter(func(e): return String(e.key).begins_with("night:"))
	var kept: Array = main.world.destroyed.keys().filter(func(k): return String(k).begins_with("night:"))
	print("dawn: %d left, %d kept in the gone list" % [left.size(), kept.size()])
	ok = ok and left.is_empty() and kept.is_empty()
	print("NIGHT IRON TEST ", "PASS" if ok else "FAIL")
	quit()
