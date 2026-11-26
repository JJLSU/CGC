extends SceneTree
## The saloon's supper (E at its door, $3) and the sheriff's bounty: each must answer at once (they laid out every
## chunk in reach at the press: up to ~14 s frozen). Times the frame each is pressed in. Headless.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame
func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.6
	await _wait(2.0)
	var T: Town = main.town
	for id in ["saloon", "jail", "store", "assay", "boarding", "livery", "smithy", "church"]: if not T.tiers.get(id, 0): T.mend(id)
	for st in Town.STREETS: for b in st.buildings: if not T.tiers.get(b.id, 0): T.mend(b.id)
	main.inventory["dollars"] = 50
	var worst := 0.0
	for door in ["saloon", "jail"]:
		var d: Vector3 = T.doors[door]
		main.player.pos = Vector3(d.x, T.y0, d.z)
		await _wait(1.0)
		main.input.pressed["KeyE"] = true
		var t0 := Time.get_ticks_usec(); await process_frame; var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		print("%s: E answered in a %.0f ms frame; dollars %d" % [door, ms, main.inventory.dollars])
	print("SALOON TEST ", "PASS" if worst < 400.0 and main.inventory.dollars < 50 else "FAIL")
	quit()
