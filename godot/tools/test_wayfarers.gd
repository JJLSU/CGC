extends SceneTree
## Wayfarers (the player's new folk out in the county): six camped about, each built as you come near; each says
## who he is the first time; E once a day for what he offers (the map inked, rope, a blessing, gold sold dear, jerky,
## silver for a meal); come back the same day: nothing more; saved. Headless; CGC_SAVE_PATH a throwaway.
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
	var W: Wayfarers = main.wayfarers; var p: Player = main.player
	print("wayfarers: %s" % ", ".join(W.camps.map(func(c): return c.kind.id)))
	var ok: bool = W.camps.size() == 6
	var inv: Dictionary = main.inventory
	inv.dollars = 20; inv.gold = 2; inv.pelt = 1; inv.bread = 1
	for c in W.camps:
		var st: Vector3 = c.at + Vector3(0, 0, 0.2)
		p.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); p.health = 40.0; p.dead = false
		await _wait(0.4)
		var fp: Vector3 = c.fig.root.position if c.fig else c.at
		p.pos = Vector3(fp.x + 1.2, Terrain.get_height(fp.x + 1.2, fp.z), fp.z)
		await _wait(0.2)
		var before: Dictionary = inv.duplicate(); var prompt: String = main.beast_prompt
		main.input.pressed["KeyE"] = true; await _wait(0.2)
		var got := {}
		for key in inv: if inv.get(key, 0) != before.get(key, 0): got[key] = inv[key] - before.get(key, 0)
		main.input.pressed["KeyE"] = true; await _wait(0.2)
		var again := {}
		for key in inv: if inv.get(key, 0) != before.get(key, 0) + got.get(key, 0): again[key] = true
		print("  %s: built %s, met %s, prompt '%s', got %s, health %.0f, then again %s" % [c.kind.id, c.built, c.met, prompt, got, p.health, again])
		var did: bool = not got.is_empty() or (c.kind.id == "preacher" and p.health == p.max_health) or c.kind.id == "surveyor"
		ok = ok and c.built and c.met and prompt.begins_with("[E]") and did and again.is_empty() and c.day == main.sky.day
	# they move on: four days later each is somewhere else, all on spots of their own
	var before_at: Array = W.camps.map(func(c): return c.at)
	main.sky.day += Wayfarers.MOVE_DAYS; await _wait(0.3)
	var moved: int = 0
	for i in W.camps.size(): if W.camps[i].at.distance_to(before_at[i]) > 50.0: moved += 1
	var distinct := {}
	for c in W.camps: distinct[str(c.at.round())] = true
	print("after %d days: %d of %d moved, %d spots in all (%d found)" % [Wayfarers.MOVE_DAYS, moved, W.camps.size(), distinct.size(), W.spots.size()])
	ok = ok and moved == W.camps.size() and distinct.size() == W.camps.size()
	ok = ok and W.save().size() == 6
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("WAYFARERS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
