extends SceneTree
## Domino: after three wins over Dusty Jake, on foot at his post, E buys his bay ($60 and Biscuit in trade): your horse
## dyed bay and 1.15x quicker under you, Jake's own horse back to a chestnut. Saved and reloaded: still Domino. Headless.
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
	m1.force_active = true; m1.sky.time = 0.45
	var R: HorseRace = m1.race
	m1.make_horse(R.start.x + 2, R.start.z + 2); m1.inventory.dollars = 100
	for i in 5: m1.player.pos = R.start; await process_frame
	var before_offer: String = m1.beast_prompt
	R.wins = 3
	for i in 3: m1.player.pos = R.start; await process_frame
	var offer: String = m1.beast_prompt
	m1.input.pressed["KeyE"] = true; await process_frame
	print("before: '%s'; at three wins: '%s'; bought %s, $%d left, pace %.2f" % [before_offer, offer, R.sold, m1.inventory.dollars, m1.player.mount_k])
	var ok: bool = not before_offer.contains("Domino") and offer.contains("Domino") and R.sold and m1.inventory.dollars == 40 and is_equal_approx(m1.player.mount_k, 1.15)
	m1.save_all(); m1.reset_world(); reload_current_scene()
	var t0 := Time.get_ticks_msec()
	while (current_scene == m1 or current_scene == null) and Time.get_ticks_msec() - t0 < 30000: await process_frame
	await _wait(2.0)
	var m2: Node = current_scene
	print("after reload: Domino %s, pace %.2f, horse %s" % [m2.race.sold, m2.player.mount_k, m2.horse != null])
	ok = ok and m2.race.sold and is_equal_approx(m2.player.mount_k, 1.15) and m2.horse != null
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DOMINO TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
