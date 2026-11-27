extends SceneTree
## The bosses across a save and a reload: Jebediah beaten and his deed handed in (Second Street up, his pick nailed
## over the assay office), Big Angus beaten but his timber rights left lying; saved, the game reloaded: both beaten,
## the deed still delivered, Second Street still up, one trophy, the rights lying at his camp to be picked up, the
## lairs where they were. Run with CGC_SAVE_PATH set to a throwaway save (never the player's): headless.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _initialize() -> void:
	var path := OS.get_environment("CGC_SAVE_PATH")
	if path == "" or path.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame; await process_frame
	await _wait(2.0)
	var m1: Node = current_scene
	var T: Town = m1.town
	for b in Town.BUILDINGS: T.mend(b.id)
	T.mend("church")
	var J: Boss = m1.bosses[0]; var A: Boss = m1.bosses[1]
	J.beaten = true; m1._hand_in(J)
	A.beaten = true
	var at_j: Vector3 = J.at; var at_a: Vector3 = A.at
	print("before: Second opened %s, trophies %d" % [0 in T.opened, T.trophies.get_child_count()])
	var ok: bool = 0 in T.opened and T.trophies.get_child_count() == 1
	m1.save_all()
	m1.reset_world() # (as the game does before its own reload: the old county's terrain statics forgotten)
	reload_current_scene()
	var t0 := Time.get_ticks_msec()
	while (current_scene == m1 or current_scene == null) and Time.get_ticks_msec() - t0 < 30000: await process_frame
	await _wait(2.0)
	var m2: Node = current_scene
	m2.force_active = true # (a headless run: let the game take E)
	var J2: Boss = m2.bosses[0]; var A2: Boss = m2.bosses[1]; var C2: Boss = m2.bosses[2]
	var rights = m2.drops.filter(func(d): return d.loot.has("timber_rights"))
	print("after: Jebediah beaten %s delivered %s; Angus beaten %s delivered %s; Crane beaten %s; Second opened %s; trophies %d; rights lying %d; lairs moved %.1f m, %.1f m" % [
		J2.beaten, J2.delivered, A2.beaten, A2.delivered, C2.beaten, 0 in m2.town.opened, m2.town.trophies.get_child_count(), rights.size(),
		(J2.at - at_j).length(), (A2.at - at_a).length()])
	ok = ok and J2.beaten and J2.delivered and A2.beaten and not A2.delivered and not C2.beaten and 0 in m2.town.opened
	ok = ok and m2.town.trophies.get_child_count() == 1 and rights.size() == 1 and (J2.at - at_j).length() < 0.5 and (A2.at - at_a).length() < 0.5
	# a rematch: a week after Jebediah fell he's back, tougher; beaten again he drops nothing, the sheriff pays more,
	# and the town keeps its street
	var Jr: Boss = J2; Jr.fell_day = m2.sky.day; m2.sky.day += 7; m2.sky.time = 0.4
	await _wait(0.3)
	print("rematch: back %s, returns %d, max hp %d (was %d), on the board %s" % [Jr.back, Jr.returns, Jr.max_hp(), Jr.spec.hp, m2.boss_board != null])
	ok = ok and Jr.back and Jr.returns == 1 and Jr.max_hp() > int(Jr.spec.hp) and m2.boss_board != null
	var ofr: Vector3 = Jr.at + (Jr.at - m2.town.at).normalized() * -20.0; m2.player.pos = Vector3(ofr.x, Terrain.get_height(ofr.x, ofr.z), ofr.z)
	await _wait(0.6)
	var d0: int = m2.drops.size()
	while Jr.alive(): Jr.damage(6, Jr.hooks)
	await _wait(0.3)
	print("farmer dead after the fight: %s" % m2.player.dead); m2.player.dead = false; m2.player.health = m2.player.max_health; m2.death_timer = 0.0
	m2.town.mend("jail"); var jd: Vector3 = m2.town.doors.jail; var c0: int = m2.inventory.get("dollars", 0)
	m2.player.pos = Vector3(jd.x, Terrain.get_height(jd.x, jd.z), jd.z); await _wait(0.3); m2.input.pressed["KeyE"] = true; await _wait(0.3)
	print("jail prompt: '%s'  paid %s  inv %s" % [m2.beast_prompt, Jr.bounty_paid, m2.inventory.get("dollars", 0)])
	print("rematch won: back %s, drops +%d, reward +$%d, Second still open %s" % [Jr.back, m2.drops.size() - d0, m2.inventory.get("dollars", 0) - c0, 0 in m2.town.opened])
	ok = ok and not Jr.back and m2.drops.size() == d0 and m2.inventory.get("dollars", 0) - c0 > 50 and 0 in m2.town.opened
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
