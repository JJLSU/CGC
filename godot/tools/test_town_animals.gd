extends SceneTree
## The wild ones keep out of town (the player: deer shouldn't come into the town): standing in the middle of town and
## then at its edge for a while, no rabbit, deer, turkey or bison is ever inside it, while some are about outside.
## Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.4
	var T: Town = main.town; var C = main.critters
	var inside := 0; var seen_wild := {}
	for spot in [T.at, T.at - T.along * 95.0, T.at + T.toward * 70.0]:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 6000:
			main.player.pos = Vector3(spot.x, Terrain.get_height(spot.x, spot.z), spot.z)
			for c in C.list:
				if c.type in Critters.FARM: continue
				seen_wild[c.type] = true
				var q: Vector3 = C.pos(c)
				if C.in_town.call(q.x, q.z): inside += 1
			await process_frame
	print("wild seen %s; wild inside town (frames x animals) %d" % [seen_wild.keys(), inside])
	var ok: bool = inside == 0 and seen_wild.size() > 0
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("TOWN ANIMALS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
