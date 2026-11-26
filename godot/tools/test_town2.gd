extends SceneTree
## The town's people: with Second Street up, four families on the back rank of Squatters' Row each want something
## (a "!" note, a tick when you carry it); bringing it pays; a keeper says hello as you pass; at dusk the lamplighter
## lights the lamps one by one; after dark the can-can on the Golden Garter's boardwalk; on a Sunday morning the
## families walk up to the church; deep snow raises the snowmen. Screenshots: the Row (out); the revue (out_revue).

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.42; main.sky.day = 2
	for i in 10: await process_frame
	var p: Player = main.player; var T: Town = main.town
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	var fams := T.civilians.size()
	# the Row, with their notes
	var c0: Dictionary = T.civilians[0]
	var v: Vector3 = c0.at + T.along * 4.0
	p.pos = Vector3(v.x, Terrain.get_height(v.x, v.z), v.z)
	main.rig.dist = 14.0; main.rig.pitch = 0.5; main.rig.yaw = atan2(-T.toward.x, -T.toward.z); main.rig.snap()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000: await process_frame
	var noted: bool = c0.note.visible
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# bring what they want: the tick, then E pays
	var w: Array = c0.want
	main.inventory[w[0]] = w[1]; main.inventory.dollars = 0
	for i in 5: await process_frame
	var ticked: bool = c0.ready.visible
	p.pos = c0.fig.root.position + T.along * 0.8; p.pos.y = T.y0
	for i in 3: await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var paid: bool = main.inventory.dollars == w[2] and c0.want == null
	# a keeper's greeting
	var keeper: Node3D = T.folk.store.fig.root
	p.pos = keeper.position + T.along * 1.0
	for i in 10: await process_frame
	var hello: bool = T.hello != null and T.hello.visible
	print("families %d  note %s  tick %s  prompt [%s]  paid %s  hello %s" % [fams, noted, ticked, prompt, paid, hello])
	# dusk: the lamplighter's round
	var mid: Vector3 = T.at
	p.pos = Vector3(mid.x, T.y0, mid.z)
	main.sky.time = 0.746
	t0 = Time.get_ticks_msec()
	var saw_lighter := false; var lit_n := 0
	while Time.get_ticks_msec() - t0 < 30000:
		await process_frame
		if T.lighter != null: saw_lighter = true
		lit_n = T.street_lamps.filter(func(S): return S.lit).size()
		if lit_n >= 2: break
	# after dark: the revue
	main.sky.time = 0.85
	var sal: Vector3 = T.doors.saloon
	p.pos = Vector3(sal.x, T.y0, sal.z) - T.toward * 4.0
	main.rig.dist = 8.0; main.rig.pitch = 0.75; main.rig.yaw = atan2(-T.toward.x, -T.toward.z) + PI; main.rig.snap()
	for i in 60: await process_frame
	var dancing: bool = T.revue != null and T.revue.all(func(f): return f.root.visible)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_revue.png"))
	# Sunday meeting
	main.sky.day = 7; main.sky.time = 0.3
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500: await process_frame
	var meeting: bool = T.civilians.all(func(c): return c.atMeeting)
	# snow: the snowmen
	main.weather.snow = 0.9
	for i in 10: await process_frame
	var snowmen: bool = T.snowmen != null and T.snowmen.all(func(h): return h.visible)
	print("lamplighter %s, lamps lit %d  revue %s  Sunday meeting %s  snowmen %s" % [saw_lighter, lit_n, dancing, meeting, snowmen])
	var ok: bool = fams == 4 and noted and ticked and paid and hello and saw_lighter and lit_n >= 2 and dancing and meeting and snowmen
	print("TOWN2 TEST ", "PASS" if ok else "FAIL")
	quit()
