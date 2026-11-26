extends SceneTree
## Chinatown (the player's Chinatown set): the town's third new street. It waits for Crane's mortgage even with Third
## Street all mended; once that's burnt it goes up, a row beyond its neighbour, its lots clear of the other streets;
## its buildings use their own models where they're in; mended, its folk stand out front. With a user arg <out.png>
## (windowed) a picture down the street. Headless; CGC_SAVE_PATH a throwaway.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	var T: Town = main.town
	var ck := Town.street_of("cn_store")
	for b in main.bosses: if b.spec.street != ck: b.delivered = true
	for b in Town.BUILDINGS: T.mend(b.id)
	for k in ck: for b in Town.STREETS[k].buildings: T.mend(b.id)
	var held := not ck in T.opened
	print("Third Street mended, Crane's mortgage still out: Chinatown held back: %s" % held)
	for b in main.bosses: b.delivered = true
	T.grow()
	var up := ck in T.opened
	print("mortgage burnt: Chinatown up: %s, %.0f m off Main Street (others %s)" % [up, T.street_offs[ck], T.street_offs.slice(0, ck)])
	var apart := true
	for k in ck: if absf(T.street_offs[k] - T.street_offs[ck]) < 30.0: apart = false
	var own := 0
	for b in Town.STREETS[ck].buildings:
		T.mend(b.id)
		if ResourceLoader.exists("res://assets/models/props/bldg_%s_ruined.glb" % b.id): own += 1
	await _wait(1.0)
	var folk := 0
	for id in T.folk.keys(): if String(id).begins_with("cn_"): folk += 1
	print("its own models: %d of 4; folk out front: %d" % [own, folk])
	var ok := held and up and apart and own == 4 and folk >= 4
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var a: Vector3 = T.at + T.toward * T.street_offs[ck]
		for i in 90: main.player.pos = a + T.along * -22.0; await process_frame
		main.set_process(false)
		var cam: Camera3D = main.rig.camera
		cam.global_position = a + T.along * -26.0 + Vector3(0, T.y0 + 9.0 - a.y, 0); cam.look_at(a + T.along * 0.0 + Vector3(0, T.y0 + 1.0 - a.y, 0), Vector3.UP); cam.fov = 50.0
		if args.has("close"): # (in close on the store's and the herbalist's folk, from mid-street)
			var mid: Vector3 = a + T.along * -10.0
			cam.global_position = mid + T.along * 9.0 + Vector3(0, T.y0 + 3.2 - mid.y, 0); cam.look_at(mid + Vector3(0, T.y0 + 1.0 - mid.y, 0), Vector3.UP); cam.fov = 60.0
		await process_frame; await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("CHINATOWN TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
