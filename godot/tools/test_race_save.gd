extends SceneTree
## Jake's record and the train robbers across a save and a reload: two wins over Jake (so the stake has doubled
## twice, to $20, and he rides 6% harder), a robbery two days back and $24 of bounty still owed; saved and reloaded:
## all as it was. Headless; a throwaway save.
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
	var stakes := []
	for w in 4: m1.race.wins = w; stakes.append(m1.race.stake())
	m1.race.wins = 2; m1.robbers.last_day = 7; m1.robbers.owed = 24
	m1.save_all()
	m1.reset_world()
	reload_current_scene()
	var t0 := Time.get_ticks_msec()
	while (current_scene == m1 or current_scene == null) and Time.get_ticks_msec() - t0 < 30000: await process_frame
	await _wait(2.0)
	var m2: Node = current_scene
	print("stakes by wins %s; after reload: wins %d, stake $%d, pace %.2f; robbery day %d, owed $%d" % [stakes, m2.race.wins, m2.race.stake(), m2.race.pace0() / HorseRace.JAKE, m2.robbers.last_day, m2.robbers.owed])
	var ok: bool = stakes == [5, 10, 20, 20] and m2.race.wins == 2 and m2.race.stake() == 20 and m2.robbers.last_day == 7 and m2.robbers.owed == 24
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RACE SAVE TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
