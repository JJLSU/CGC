extends SceneTree
## The barnyard: hens, the rooster, two cows and four sheep spawn and walk; milk a cow; at night they go in to the
## hen house and the barn; wild rabbits and deer turn up round the farmer. Screenshot of the pasture by day.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 120: await process_frame
	var cr: Critters = main.critters
	var kinds := {}
	for c in cr.list: kinds[c.type] = kinds.get(c.type, 0) + 1
	var cow = null
	for c in cr.list: if c.type == "cow": cow = c; break
	var start: Vector3 = cr.pos(cow)
	var p: Player = main.player
	var cp: Vector3 = cr.pos(cow)
	p.pos = Vector3(cp.x + 1.0, Terrain.get_height(cp.x + 1.0, cp.z), cp.z)
	for i in 2: await process_frame
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var milk: int = main.inventory.milk
	print("kinds %s  cow moved %.2f  milk %d  barn %s roost %s" % [kinds, start.distance_to(cr.pos(cow)), milk, cr.barn, cr.roost])
	# the pasture by day, from above
	p.pos = Vector3(cp.x, Terrain.get_height(cp.x, cp.z), cp.z + 6)
	main.rig.dist = 16.0; main.rig.pitch = 0.6; main.rig.yaw = 0.0
	for i in 120: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# night: in they go
	main.sky.time = 0.95
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000: await process_frame
	var in_n := 0
	for c in cr.list: if c.roosting: in_n += 1
	print("roosting at night: %d" % in_n)
	var ok: bool = kinds.get("hen", 0) == 5 and kinds.get("cow", 0) == 2 and kinds.get("sheep", 0) == 4 and milk == 1 and in_n >= 6
	print("CRITTERS TEST ", "PASS" if ok else "FAIL")
	quit()
