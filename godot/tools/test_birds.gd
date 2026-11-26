extends SceneTree
## The birds: songbirds come to a feeder with seed and burst away when the farmer walks up; crows land in the kitchen
## garden and scatter; a skein of geese goes over; the eagle finds high ground if there is any; the owl comes to its
## post at night. Screenshot of the crows pecking in the corn.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4
	for i in 30: await process_frame
	var p: Player = main.player
	# a feeder with seed, 10 m off
	var fx := p.pos.x + 10.0; var fz := p.pos.z
	main.build.add({"type": "feeder", "x": fx, "y": Terrain.get_height(fx, fz), "z": fz, "rot": 0.0})
	var feeder: Dictionary = main.build.pieces[-1]; feeder.stock = 3; feeder.stockDay = main.sky.day
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000: await process_frame
	var perched := 0
	for b in main.songbirds.birds: if b.state == "perch": perched += 1
	p.pos = Vector3(fx + 1.0, Terrain.get_height(fx + 1.0, fz), fz)
	for i in 10: await process_frame
	var leaving := 0
	for b in main.songbirds.birds: if b.leaving: leaving += 1
	main.build.fold_away(feeder)
	print("songbirds perched %d  flushed %d" % [perched, leaving])
	# crows in the garden
	var cr: Crows = main.crows
	var crops := cr.crops(main.world)
	cr.timer = 0.0
	for i in 3: await process_frame
	var came := cr.state == "coming"
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000 and cr.state != "pecking": await process_frame
	var pecked := cr.state == "pecking"
	if pecked:
		var c: Vector3 = cr.birds[0].to
		p.pos = Vector3(c.x + 9.0, Terrain.get_height(c.x + 9.0, c.z), c.z)
		main.rig.dist = 10.0; main.rig.pitch = 0.6; main.rig.yaw = PI / 2.0
		main.rig.snap()
		for i in 60: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
		p.pos = Vector3(c.x + 3.0, p.pos.y, c.z)
		for i in 3: await process_frame
	var scattered := cr.state == "leaving"
	print("crops %d  crows came %s pecked %s scattered %s" % [crops.size(), came, pecked, scattered])
	# geese, eagle
	main.geese.timer = 0.0
	for i in 3: await process_frame
	print("geese flying %s  eagle over high ground %s" % [main.geese.flying, main.eagle.has])
	# the owl at night
	main.sky.time = 0.97
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and main.owl.state != "perched": await process_frame
	print("owl %s at %s" % [main.owl.state, main.owl.g.position])
	var ok: bool = perched > 0 and leaving > 0 and came and pecked and scattered and main.geese.flying and main.owl.state == "perched"
	print("BIRDS TEST ", "PASS" if ok else "FAIL")
	quit()
