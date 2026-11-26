extends SceneTree
## The county map (M): explored cells round where you've walked, washed in; the town, the home badge and inset;
## the rumour note under NEXT (the nearest unseen landmark, with an arrow); the stage passenger's news inking a
## landmark onto the map; the fingerpost at the end of the lane. Screenshots: the map (out), with a far landmark
## sketched in (out_far), the fingerpost (out_post).

func _shot(path: String) -> void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4; main.sky.day = 3
	for i in 10: await process_frame
	var p: Player = main.player; var hud: Hud = main.hud; var M: CountyMap = hud.county_map
	var res := {}
	var press := func(key := "KeyE") -> void:
		main.input.pressed[key] = true
		for i in 3: await process_frame
	# walk the lane to town (a few cells at a time)
	var a: Vector3 = main.homestead.spawn; var b: Vector3 = main.town.at
	for k in 13:
		var q := a.lerp(b, k / 12.0); p.pos = Vector3(q.x, Terrain.get_height(q.x, q.z) + 0.2, q.z)
		for i in 2: await process_frame
	res.explored = M.seen(a.x, a.z) and M.seen(b.x, b.z) and M.explored.size() > 60
	# the rumour note: the nearest landmark you haven't seen (the scan lays out a chunk a frame)
	p.pos = Vector3(a.x + 20, Terrain.get_height(a.x + 20, a.z + 10), a.z + 10)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not hud.rumour.visible: await process_frame
	res.rumour = hud.rumour.visible and hud.rumour_text.text != ""
	print("rumour: %s · %s" % [hud.rumour_text.text, hud.rumour_small.text])
	# the map
	t0 = Time.get_ticks_msec()
	await press.call("KeyM")
	print("map painted in %d ms" % (Time.get_ticks_msec() - t0))
	res.map_open = hud.map_card.visible
	await _shot(out)
	await press.call("KeyM"); res.map_closed = not hud.map_card.visible
	# the stage passenger's news: mend the boarding house and wait for the stage at mid-morning
	var T: Town = main.town; T.mend("boarding")
	main.sky.time = 0.41
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and (T.rider == null or T.rider.length() < 1.0): await process_frame
	for i in 2: await process_frame
	p.pos = T.rider + Vector3(0.8, 0, 0); p.pos.y = T.y0
	for i in 3: await process_frame
	var rprompt: String = main.beast_prompt
	print("rider %s  me %s  town at %s  dist %.2f" % [T.rider, p.pos, T.position, Vector2(p.pos.x - T.rider.x, p.pos.z - T.rider.z).length() if T.rider != null else -1.0])
	var n0 := M.explored.size()
	await press.call()
	res.rider = main.rider_day == main.sky.day and M.explored.size() > n0
	await press.call("KeyM")
	await _shot(out.replace(".png", "_far.png"))
	await press.call("KeyM")
	# the fingerpost
	var tdir := Vector2(b.x - (a.x - 2), b.z - (a.z - 6.5)).normalized()
	var c := Vector3(a.x - 2, 0, a.z - 6.5); var sp := Vector3(c.x + tdir.x * 24.0 - tdir.y * 2.6, 0, c.z + tdir.y * 24.0 + tdir.x * 2.6)
	p.pos = Vector3(sp.x - 3, Terrain.get_height(sp.x - 3, sp.z + 2), sp.z + 2)
	main.rig.dist = 6.0; main.rig.pitch = 0.35; main.rig.yaw = 2.4; main.rig.snap()
	await _shot(out.replace(".png", "_post.png"))
	print("rider prompt [%s]  post at %s (web -25.06, -16.56)" % [rprompt, sp])
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("MAP TEST ", "PASS" if ok else "FAIL")
	quit()
