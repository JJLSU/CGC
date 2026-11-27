extends SceneTree
## On the Sabbath (day % 7 == 6) the preacher has a word as you pass the church door, once that day; not on other days.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42
	main._dev_town()
	var T: Town = main.town
	var said := []
	for d in [5, 6]:
		main.sky.day = d; T.sermon_day = -1
		var fr: Node3D = T.folk.church.fig.root
		var far: Vector3 = fr.global_position + T.along * 30.0
		for i in 10: main.player.pos = Vector3(far.x, Terrain.get_height(far.x, far.z), far.z); await process_frame
		var near: Vector3 = fr.global_position + T.along * 3.0
		for i in 20: main.player.pos = Vector3(near.x, Terrain.get_height(near.x, near.z), near.z); await process_frame
		said.append(T.sermon_day == d)
	var args := OS.get_cmdline_user_args()
	if args.size():
		var fr2: Node3D = T.folk.church.fig.root
		main.rig.dist = 12.0; main.rig.pitch = 0.3; main.rig.yaw = atan2(-T.along.x, -T.along.z); main.rig.snap()
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
	print("day 5 sermon %s, day 6 (Sabbath) sermon %s: '%s'" % [said[0], said[1], T.sermon_card.text if T.sermon_card else "-"])
	var ok: bool = not said[0] and said[1]
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("SERMON TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
