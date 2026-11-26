extends SceneTree
## The dance hall (the player's open-fronted hall): you can walk in off the street to the middle of the floor; the bar
## counter and the stage's front stop you; the girls are on the stage after dark and the bartender behind the bar; it
## never backs onto Main Street. Headless; CGC_SAVE_PATH a throwaway.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

## Walk the farmer from a toward b (hall-local points) for sec; where he got to, in hall-local coordinates.
func _walk(main: Node, g: Node3D, a: Vector3, b: Vector3, sec: float) -> Vector3:
	var p: Player = main.player
	var wa: Vector3 = g.global_transform * a; var wb: Vector3 = g.global_transform * b
	p.pos = Vector3(wa.x, Terrain.get_height(wa.x, wa.z), wa.z); p.vel = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		var dir := Vector3(wb.x - p.pos.x, 0, wb.z - p.pos.z)
		if dir.length() < 0.4: break
		main.rig.yaw = atan2(-dir.x, -dir.z); main.input.keys["KeyW"] = true
		await process_frame
	main.input.keys.erase("KeyW")
	return g.global_transform.affine_inverse() * p.pos

func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.86
	var T: Town = main.town
	for b in main.bosses: b.delivered = true
	for b in Town.BUILDINGS: T.mend(b.id)
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	await _wait(0.5)
	var g: Node3D = T.parts.dance; var k := Town.hall_k(); var b := Town.find_b("dance"); var dk := Town.street_of("dance")
	var away: bool = T.street_offs[dk] * float(b.side) > 0.0
	print("hall %.1f m wide, %.1f deep; backs away from Main Street: %s" % [b.w, b.d, away])
	var ok := away
	var inside := await _walk(main, g, Vector3(0, 0, 3.0 * k), Vector3(0, 0, -7.0 * k), 6.0)
	print("walked in from the street to z %.1f (aim %.1f)" % [inside.z / k, -7.0])
	ok = ok and inside.z / k < -6.0
	var at_stage := await _walk(main, g, Vector3(0, 0, -7.0 * k), Vector3(0, 0, -14.0 * k), 4.0)
	print("toward the stage: stopped at z %.1f (its front at -11)" % (at_stage.z / k))
	ok = ok and at_stage.z / k > -11.3
	var at_bar := await _walk(main, g, Vector3(0.5 * k, 0, -6.6 * k), Vector3(-5.0 * k, 0, -6.6 * k), 4.0)
	print("toward the bar: stopped at x %.1f (the counter at -2.4)" % (at_bar.x / k))
	ok = ok and at_bar.x / k > -2.2
	await _wait(0.3)
	var girls: int = T.hall_girls.filter(func(f): return f.root.is_visible_in_tree()).size() if T.hall_girls else 0
	var barman: bool = T.hall_barman != null and T.hall_barman.root.is_visible_in_tree()
	print("after dark: %d girls on the stage, the bartender in %s" % [girls, barman])
	ok = ok and girls == 3 and barman
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("DANCE HALL TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
