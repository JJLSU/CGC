extends SceneTree
## The railroad: surveyed where the web lays it (depot -97.69, 47.78; stops breaks, prairie, pines, fen, hollows);
## built once every street is mended; freight on the platform goes East with the train; board at the depot ($1), ride
## the back platform to the first whistle-stop and step off; its trading post opens the crafting panel; a rush order
## comes over the wire. Screenshots: the train at the depot (out); a whistle-stop and its trading post (out_post).

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.2; main.sky.day = 2
	for i in 10: await process_frame
	var p: Player = main.player; var T: Town = main.town; var R: Railroad = main.railroad; var TR: Train = main.train
	print("depot %s  stops %s  path %d   (web: -97.69, 47.78; breaks -126,149 prairie -91,178 pines -139,197 fen -203,42 hollows -78,-181; 700)" % [R.depot, R.stops.map(func(s): return [s.land, roundi(s.at.x), roundi(s.at.z)]), R.path.size()])
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and not R.built: await process_frame
	var built := R.built
	R.add_freight(); R.add_freight()
	# at the depot, the train standing
	var plat: Vector3 = TR.stopped_at().platform
	p.pos = Vector3(plat.x, Terrain.get_height(plat.x, plat.z) + 0.3, plat.z)
	main.rig.dist = 18.0; main.rig.pitch = 0.5; main.rig.yaw = atan2(p.pos.x - TR.cars[1].position.x, p.pos.z - TR.cars[1].position.z) + 0.5; main.rig.snap()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# board her: she leaves at once, taking the freight
	main.inventory.dollars = 5
	p.pos = TR.ride_car().position + Vector3(1.5, 0, 0)
	for i in 3: await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var aboard: bool = TR.passenger and TR.state == "run" and R.freight == 0
	# (one long line, one stop at town: she runs out to the far end and waits, back through town to the other end, and
	# home. Skipped along: put near the far end, then near home on the last leg)
	TR.s = TR.end - 6.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and TR.state != "dwell": await process_frame
	var reached: bool = TR.state == "dwell" and absf(TR.s - TR.end) < 0.5 and TR.passenger
	TR.state = "run"; TR.leg = 2; TR.dir = 1; TR.s = TR.home_s() - 8.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and TR.state != "home": await process_frame
	var stop = TR.stopped_at()
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var off: bool = not TR.passenger and stop != null and Vector2(p.pos.x - stop.platform.x, p.pos.z - stop.platform.z).length() < 2.0
	# the trading post there
	var st: Dictionary = R.stops[0] # (the trading posts stand out in the lands, off the line)
	p.pos = st.door; p.pos.y = Terrain.get_height(st.door.x, st.door.z)
	for i in 3: await process_frame
	var post_prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var traded: bool = main.panel.open
	main._close_craft()
	var pf: Vector3 = st.platform
	p.pos = st.door + (pf - st.door) * 0.5; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.rig.dist = 16.0; main.rig.pitch = 0.55; main.rig.yaw = atan2(st.geo.side.x, st.geo.side.z) + 0.7; main.rig.snap()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_post.png"))
	# a rush order by day
	main.sky.time = 0.4
	for i in 3: await process_frame
	var order = main.crafting.order_state()
	print("built %s  board prompt [%s]  aboard %s  out to the end of the line and waiting %s  off at %s %s  post [%s] panel %s  rush order %s" % [built, prompt, aboard, reached, stop.name if stop else "-", off, post_prompt, traded, order])
	var ok: bool = built and aboard and reached and off and traded and order != null
	print("RAIL TEST ", "PASS" if ok else "FAIL")
	quit()
