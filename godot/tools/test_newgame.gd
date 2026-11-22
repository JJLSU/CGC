extends SceneTree
## New game, as the title card's button does it: the game started as it really starts (the main scene current), a
## game played a little and saved, then New game: the save is gone, a new county is laid out in place (a new random
## seed, the old county's flats and caches forgotten) under a paper card, the farm and town near each other, and the
## game running on. Run with CGC_SAVE_PATH set to a throwaway save (never the player's): headless.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _initialize() -> void:
	var path := OS.get_environment("CGC_SAVE_PATH")
	if path == "" or path.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame; await process_frame
	await _wait(3.0)
	var m1: Node = current_scene
	var seed1: int = m1.world_seed; var town1: Vector3 = m1.town.at
	m1.save_all()
	print("first county: seed %d  town %s  saved %s" % [seed1, Vector2(town1.x, town1.z).round(), FileAccess.file_exists(path)])
	m1._new_game()
	var t0 := Time.get_ticks_msec()
	while (current_scene == m1 or current_scene == null) and Time.get_ticks_msec() - t0 < 30000: await process_frame
	var card_up := get_nodes_in_group("newgame_card").size() > 0
	await _wait(3.0)
	var m2: Node = current_scene
	var farm: Vector3 = m2.spawn; var town2: Vector3 = m2.town.at
	var apart := Vector2(farm.x - town2.x, farm.z - town2.z).length()
	print("new county after %d ms: seed %d  farm %s  town %s  apart %.0f m  old save gone %s  card while loading %s, gone now %s  extra flats %d" % [Time.get_ticks_msec() - t0, m2.world_seed, Vector2(farm.x, farm.z).round(), Vector2(town2.x, town2.z).round(), apart, not FileAccess.file_exists(path), card_up, get_nodes_in_group("newgame_card").is_empty(), Terrain.extra_flats.size()])
	var frames := 0; t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await process_frame; frames += 1
	print("  running: %d frames in 3 s" % frames)
	var ok: bool = m2.world_seed != seed1 and apart < 120.0 and get_nodes_in_group("newgame_card").is_empty() and frames > 30
	m2.saving = false
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("NEWGAME TEST ", "PASS" if ok else "FAIL")
	quit()
