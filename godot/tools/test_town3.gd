extends SceneTree
## The town's days and evenings: the stage comes in mid-morning and waits by the boarding house (its passenger out);
## the opera's playbill on its post; at sundown the queue at the opera house and a $3 seat; the dance hall's couples
## and fiddler. Screenshots: the stage waiting (out); the dance hall at night (out_dance).

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.3; main.sky.day = 3
	for i in 10: await process_frame
	var p: Player = main.player; var T: Town = main.town
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	for b in Town.STREETS[0].buildings: T.mend(b.id)
	for b in Town.STREETS[1].buildings: T.mend(b.id)
	# the stage: in at mid-morning, waits by the boarding house
	var bh: Vector3 = T.at + T.along * 10.0
	p.pos = Vector3(bh.x, T.y0, bh.z)
	main.sky.time = 0.41
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and (T.coach == null or T.coach.phase != "wait"): await process_frame
	var waited: bool = T.coach != null and T.coach.phase == "wait" and T.rider != null
	main.rig.dist = 16.0; main.rig.pitch = 0.55; main.rig.yaw = atan2(T.toward.x, T.toward.z) + 0.6; main.rig.snap()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	var billed: bool = T.bill != null
	# sundown: the queue, a seat at the opera
	main.sky.time = 0.78
	var od: Vector3 = T.doors.opera
	p.pos = Vector3(od.x, T.y0, od.z)
	for i in 10: await process_frame
	var queued: bool = T.queue != null and T.queue.all(func(f): return f.root.visible)
	main.inventory.dollars = 10
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var seen: bool = main.inventory.dollars == 7 and main.opera_day == main.sky.day
	# the dance hall
	main.sky.time = 0.8
	var dd: Vector3 = T.doors.dance
	p.pos = Vector3(dd.x, T.y0, dd.z) - T.toward * T.find_b("dance").side * 6.0
	main.rig.dist = 11.0; main.rig.pitch = 0.6; main.rig.yaw = atan2(-T.toward.x * T.find_b("dance").side, -T.toward.z * T.find_b("dance").side) + PI; main.rig.snap()
	for i in 60: await process_frame
	var dancing: bool = T.hall_dancers != null and T.hall_dancers.all(func(d): return d.fig.root.visible) and T.hall_fiddler.root.visible
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_dance.png"))
	print("stage waited %s  playbill %s  opera queue %s  a seat %s  dance hall %s" % [waited, billed, queued, seen, dancing])
	var ok: bool = waited and billed and queued and seen and dancing
	print("TOWN3 TEST ", "PASS" if ok else "FAIL")
	quit()
