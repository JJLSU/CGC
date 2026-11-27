extends SceneTree
## The fort gate (the player's gate leaves): by day you walk in through the open gateway; at night it's shut and stops
## you at the gate. Headless; CGC_SAVE_PATH a throwaway.
func _walk_in(main: Node, f: Dictionary) -> float:
	var fz := Vector3(sin(f.face), 0, cos(f.face)); var a: Vector3 = f.at + fz * (ArmyForts.SIDE / 2.0 + 6.0)
	var p: Player = main.player; p.pos = Vector3(a.x, Terrain.get_height(a.x, a.z), a.z); p.vel = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		main.rig.yaw = atan2(fz.x, fz.z); main.input.keys["KeyW"] = true
		await process_frame
	main.input.keys.erase("KeyW")
	return (p.pos - f.at).dot(fz) # (how far from the middle, out along the gate's way: under SIDE/2 is inside)
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	var f: Dictionary = main.forts.forts[0]
	main.sky.time = 0.45
	var fz := Vector3(sin(f.face), 0, cos(f.face))
	for i in 600: main.player.pos = f.at + fz * 40.0; await process_frame # (the leaves swing open)
	var day: float = await _walk_in(main, f)
	main.sky.time = 0.9
	for i in 600: main.player.pos = f.at + fz * 40.0; await process_frame # (and shut)
	var night: float = await _walk_in(main, f)
	var H := ArmyForts.SIDE / 2.0
	print("by day got to %.1f m from the middle (gate at %.0f); at night stopped at %.1f m" % [day, H, night])
	var ok := day < H - 2.0 and night > H - 0.5
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("FORT GATE TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
