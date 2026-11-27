extends SceneTree
## The bank hold-up (the player's outlaws ride into town): the gang stands about the bank's door; beat them all and
## the bank pays (+$15 a man); a second gang left alone rides off at midnight with a fifth of your savings. With a
## user arg <out.png> (windowed) a picture of the gang at the bank. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.74; main.weather.rain = 0.0
	main._dev_town()
	for i in 10: await process_frame
	var J: ClaimJumpers = main.jumpers; var T: Town = main.town
	main.start_raid()
	var men: int = J.raid.men.size()
	var at_bank: bool = J.raid.men.all(func(m): return m.fig.root.position.distance_to(T.doors.bank) < 9.0)
	var outlaws: int = J.raid.men.filter(func(m): return String(m.fig.name).contains("outlaw")).size()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var d: Vector3 = T.doors.bank
		for i in 60: main.player.pos = d - T.along * 14.0; main.player.health = main.player.max_health; await process_frame
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera
		cam.global_position = d - T.along * 12.0 + Vector3(0, T.y0 + 5.0 - d.y, 0) - T.toward * float(Town.find_b("bank").side) * 7.0; cam.look_at(d + Vector3(0, T.y0 + 1.0 - d.y, 0), Vector3.UP); cam.fov = 55.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
		main.set_process(true); main.player.avatar.root.visible = true
	for i in 5: main.player.pos = T.at - T.along * 60.0; main.player.health = main.player.max_health; await process_frame
	var chip: String = main.hud.boss_chip_label.text if main.hud.get("boss_chip_label") != null else "?"
	print("chip [%s]" % chip)
	# beat them
	main.inventory.dollars = 0
	for m in J.raid.men: J.damage(m, 99, main.jumper_hooks)
	for i in 5: main.player.pos = T.at - T.along * 40.0; main.player.health = main.player.max_health; await process_frame
	var paid: int = main.inventory.get("dollars", 0)
	# a second gang, left alone till midnight
	main.sky.time = 0.75; main.start_raid()
	main.inventory.savings = 100
	for i in 3: main.player.pos = T.at - T.along * 60.0; await process_frame
	main.sky.time = 0.985
	for i in 5: main.player.pos = T.at - T.along * 60.0; main.player.health = main.player.max_health; await process_frame
	var left: int = main.inventory.get("savings", 0)
	print("gang of %d (%d outlaws), at the bank %s; beaten: paid $%d; ignored: savings 100 -> %d, gang gone %s" % [men, outlaws, at_bank, paid, left, J.raid == null])
	var ok: bool = men >= 3 and at_bank and paid == 15 * men and left == 80 and J.raid == null
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("HOLDUP TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
