extends SceneTree
## The lost calf goes missing on its day, is led home by E for two pails of milk; Biscuit is mounted with X (the
## farmer on her saddle), dismounted, whistled for from 30 m and comes. Screenshot of the farmer riding.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 30: await process_frame
	var p: Player = main.player; var calf: Calf = main.calf
	var day := 4
	while not Calf.lost_today(day): day += 1
	main.sky.day = day; main.sky.time = 0.3
	for i in 3: await process_frame
	var lost := calf.state == "lost"
	var far := Vector2(calf.pos.x - calf.pasture.x, calf.pos.z - calf.pasture.z).length()
	p.pos = Vector3(calf.pos.x + 1.0, Terrain.get_height(calf.pos.x + 1.0, calf.pos.z), calf.pos.z)
	for i in 2: await process_frame
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var following := calf.state == "follow"
	var milk0: int = main.inventory.get("milk", 0)
	var hx := calf.pasture.x + 9.0; var hz := calf.pasture.z
	p.pos = Vector3(hx, Terrain.get_height(hx, hz), hz)
	calf.pos = Vector3(hx + 1.0, Terrain.get_height(hx + 1.0, hz), hz)
	for i in 5: await process_frame
	var milk1: int = main.inventory.get("milk", 0)
	print("calf day %d lost %s (%.0f m out)  follow %s  milk %d -> %d  state %s" % [day, lost, far, following, milk0, milk1, calf.state])
	# Biscuit
	main.sky.time = 0.4
	var sp: Vector3 = main.homestead.spawn
	p.pos = Vector3(sp.x + 6, Terrain.get_height(sp.x + 6, sp.z + 4), sp.z + 4)
	main.make_horse(p.pos.x + 1.5, p.pos.z)
	for i in 3: await process_frame
	main.input.pressed["KeyX"] = true
	for i in 30: await process_frame
	var rode: bool = main.riding
	var lift: float = p.avatar.root.position.y - p.pos.y
	main.rig.dist = 8.0; main.rig.pitch = 0.4; main.rig.yaw = 1.2
	main.rig.snap()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	main.input.pressed["KeyX"] = true
	for i in 3: await process_frame
	var off: bool = not main.riding
	p.pos = Vector3(p.pos.x + 30, Terrain.get_height(p.pos.x + 30, p.pos.z), p.pos.z)
	for i in 2: await process_frame
	var d0 := Vector2(main.horse.pos.x - p.pos.x, main.horse.pos.z - p.pos.z).length()
	main.input.pressed["KeyX"] = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000: await process_frame
	var d1 := Vector2(main.horse.pos.x - p.pos.x, main.horse.pos.z - p.pos.z).length()
	print("horse: rode %s  rider lift %.2f  off %s  whistle %.1f -> %.1f m  saddle %s" % [rode, lift, off, d0, d1, main.horse.saddle.visible])
	var ok: bool = lost and following and milk1 == milk0 + 2 and rode and lift > 0.8 and off and d1 < 3.0
	print("CALFHORSE TEST ", "PASS" if ok else "FAIL")
	quit()
