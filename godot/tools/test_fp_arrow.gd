extends SceneTree
## The HUD arrows through his own eyes (the player: the direction indicator didn't work in first person): out from
## home in the first-person view, facing home the homeward arrow points up (0 deg), turned so home is on his right it
## points right (+90), behind him down (180). And in the wide view it still reads up when the camera looks homeward.
## Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	var home: Vector3 = main.homestead.spawn
	var at := home + Vector3(140, 0, 30); main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z)
	for i in 10: await process_frame
	main.input.pressed["KeyV"] = true
	for i in 5: await process_frame
	var h: Vector3 = home - main.player.pos; h.y = 0.0
	var out := []
	for turn in [0.0, PI / 2.0, PI]:
		# yaw so his look runs along h turned by turn (forward = (-sin yaw, 0, -cos yaw))
		var want: Vector3 = h.normalized().rotated(Vector3.UP, turn)
		main.rig.yaw = atan2(-want.x, -want.z); main.rig.pitch = 0.1
		for i in 4: await process_frame
		out.append(main.rig.screen_deg(main.player.pos, h))
	main.input.pressed["KeyV"] = true
	for i in 5: await process_frame
	main.rig.yaw = atan2(-h.normalized().x, -h.normalized().z); main.rig.pitch = 0.5
	for i in 4: await process_frame
	var wide: float = main.rig.screen_deg(main.player.pos, h)
	print("first person %s: ahead %.0f, home on his right %.0f, behind %.0f; wide view (%s) facing home %.0f" % [true, out[0], out[1], out[2], main.rig.first_person, wide])
	var ok: bool = absf(out[0]) < 5.0 and absf(absf(out[1]) - 90.0) < 5.0 and absf(absf(out[2]) - 180.0) < 5.0 and absf(wide) < 10.0 and not main.rig.first_person
	print("FP ARROW TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
