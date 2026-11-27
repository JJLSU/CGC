extends SceneTree
## Hoofbeats while riding: mounted and moving, the "hoof" sound plays in step; stood still, none. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	var n := [0]
	var real: Callable = main.sound.play
	main.make_horse(main.spawn.x + 2, main.spawn.z); main.riding = true; main.player.riding = true; main.player.avatar.riding = true
	var counts := []
	for moving in [false, true]:
		var c0: int = main.hoof_acc_count if main.get("hoof_acc_count") != null else 0
		var plays := 0; main.input.keys.erase("KeyW")
		if moving: main.input.keys["KeyW"] = true
		for i in 180:
			var before: float = main.hoof_acc
			await process_frame
			if main.hoof_acc < before: plays += 1
		counts.append(plays)
	main.input.keys.erase("KeyW")
	print("hoofbeats standing %d, riding on %d in 180 frames" % [counts[0], counts[1]])
	var ok: bool = counts[0] == 0 and counts[1] >= 4 and counts[1] < 40 and main.sound.bank.has("hoof")
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("HOOFBEATS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
