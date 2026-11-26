extends SceneTree
## Rattlesnakes in the Redrock Breaks: one coiled at its spot; come near and it rattles, closer and it strikes (a
## snakebite) and slithers off for the day; another one, struck first with the axe, dies and gives its skin. With a
## user arg <out.png> (windowed) a picture of one coiled. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	for i in 10: await process_frame
	var R: Rattlers = main.rattlers; var p: Player = main.player
	# two spots in the Breaks, nearest the farm
	var found := []
	var r := 4
	while found.size() < 2 and r < 40:
		for cx in range(-r, r + 1):
			for cz in range(-r, r + 1):
				if maxi(absi(cx), absi(cz)) != r: continue
				var q = Rattlers.spot(floori(main.spawn.x / Rattlers.CELL) + cx, floori(main.spawn.z / Rattlers.CELL) + cz)
				if q != null and found.size() < 2: found.append(q)
		r += 1
	print("rattler spots: %s" % [found])
	var ok := found.size() == 2
	if not ok: print("RATTLERS TEST FAIL"); quit(1); return
	var a: Vector3 = found[0]
	var d0 := Vector3(1, 0, 0)
	for i in 30: p.pos = a + d0 * 14.0; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); await process_frame
	var here: bool = R.snakes.size() > 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		main.set_process(false); p.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera; var gy := Terrain.get_height(a.x, a.z)
		cam.global_position = Vector3(a.x + 2.5, gy + 1.6, a.z + 2.5); cam.look_at(Vector3(a.x, gy + 0.2, a.z), Vector3.UP); cam.fov = 45.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
		main.set_process(true); cam.fov = 30.0; p.avatar.root.visible = true
	var rattled := false; var bitten := false; var hp0 := p.health
	main.met_keepers.erase("rattler")
	R.on_rattle = R.on_rattle # (main's)
	for i in 40: p.pos = a + d0 * 4.0; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); await process_frame
	rattled = main.met_keepers.has("rattler")
	for i in 60: p.pos = a + d0 * 1.2; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); await process_frame
	bitten = p.health < hp0
	for i in 150: p.pos = a + d0 * 6.0; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); await process_frame
	var left: bool = R.gone.size() > 0
	# the second: an axe blow first
	var b: Vector3 = found[1]
	for i in 30: p.pos = b + d0 * 14.0; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); await process_frame
	var pelts: int = main.inventory.get("pelt", 0)
	p.pos = b + d0 * 2.2; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); p.facing = atan2(-(-d0).z, (-d0).x)
	main.rig.yaw = atan2(d0.x, d0.z) # (facing the snake)
	var killed: bool = R.hit(p.pos, -d0, Player.REACH)
	print("there %s; rattled %s; bit you %s (health %.0f -> %.0f); slithered off %s; killed by a blow %s" % [here, rattled, bitten, hp0, p.health, left, killed])
	ok = here and rattled and bitten and left and killed
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("RATTLERS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
