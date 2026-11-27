extends SceneTree
## No camp hangs in the air (the player saw a boss's camp floating): a boss's lair loaded but its ground not yet built
## is hidden; walk up and it shows once the ground's in, every piece on it. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	var B: Boss = main.bosses[0]; var dir: Vector3 = (main.town.at - B.at).normalized()
	var far_spot: Vector3 = B.at + dir * 140.0
	for i in 60: main.player.pos = Vector3(far_spot.x, Terrain.get_height(far_spot.x, far_spot.z), far_spot.z); await process_frame
	var far_built: bool = B.built; var far_ground: bool = World.ground_ready(B.at.x, B.at.z); var far_shown: bool = B.visible
	var near_spot: Vector3 = B.at + dir * 40.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000 and not World.ground_ready(B.at.x, B.at.z):
		main.player.pos = Vector3(near_spot.x, Terrain.get_height(near_spot.x, near_spot.z), near_spot.z); await process_frame
	for i in 5: await process_frame
	print("140 m off: lair built %s, its ground in %s, shown %s; walked up: ground in %s, shown %s" % [far_built, far_ground, far_shown, World.ground_ready(B.at.x, B.at.z), B.visible])
	var ok: bool = far_built and (far_shown == far_ground) and World.ground_ready(B.at.x, B.at.z) and B.visible
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("NO FLOATING TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
