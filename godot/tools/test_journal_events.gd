extends SceneTree
## 23a: journal events now recorded as main.js records them: three deer spotted (the goal done), Old Blue patted
## (with one of the pat lines or the stick), Marmalade patted, logs stacked on a woodpile.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _e(main: Node) -> void:
	main.input.pressed["KeyE"] = true
	await process_frame; await process_frame

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.42
	await _wait(3.0)
	var j: Journal = main.journal
	for i in 3: main.critters.on_spotted.call({})
	var ok: bool = j.done.has("deer") or j.progress.get("deer", 0) == 3
	print("deer: %s" % j.day_log.get("deer", 0))
	# Old Blue
	var p: Player = main.player
	main.dog.pos = p.pos + Vector3(1.0, 0, 0)
	await process_frame
	await _e(main)
	print("pat: %s  dog prompt was '%s'" % [j.day_log.get("pat", 0), main.beast_prompt])
	ok = ok and j.day_log.get("pat", 0) == 1
	main.dog.pos = p.pos + Vector3(40, 0, 0)
	main.cat.pos = p.pos + Vector3(1.0, 0, 0) if "pos" in main.cat else main.cat.pos
	await _wait(0.3)
	await _e(main)
	print("cat: %s  prompt '%s'" % [j.day_log.get("cat", 0), main.beast_prompt])
	ok = ok and j.day_log.get("cat", 0) == 1
	print("JOURNAL EVENTS TEST ", "PASS" if ok else "FAIL")
	quit()
