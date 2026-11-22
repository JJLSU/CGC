extends SceneTree
## Old Blue and Marmalade: the dog potters near the farmer and follows when he walks off, a scratch, the stick thrown
## and fetched back; the cat rests on her bale and walks to another spot, purrs at a scratch. Screenshot of the yard.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 60: await process_frame
	var dog: Dog = main.dog; var cat: Cat = main.cat; var p: Player = main.player
	# walk the farmer 25 m off: Old Blue follows
	var home := p.pos
	p.pos = Vector3(home.x + 25, Terrain.get_height(home.x + 25, home.z), home.z)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000: await process_frame
	var follow := Vector2(dog.pos.x - p.pos.x, dog.pos.z - p.pos.z).length()
	# a scratch, then the stick
	p.pos = Vector3(dog.pos.x + 1.0, Terrain.get_height(dog.pos.x + 1.0, dog.pos.z), dog.pos.z)
	dog.potter = null; dog.potter_t = 30.0
	await process_frame
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var patted := dog.pat_t > 0.0
	if dog.fetch == null: dog.offer_stick(p)
	p.pos = Vector3(dog.fetch.to.x + 0.5, p.pos.y, dog.fetch.to.z); p.facing = 0.0
	await process_frame
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var thrown: bool = dog.fetch != null and dog.fetch.phase != "offered"
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and main.fetches == 0: await process_frame
	print("dog follow %.1f m  patted %s  thrown %s  fetched %d" % [follow, patted, thrown, main.fetches])
	# the cat: on her bale, then off to another spot
	var c0 := cat.pos
	var perch := c0.y - Terrain.get_height(c0.x, c0.z)
	cat.t = 999.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	var moved := c0.distance_to(cat.pos)
	print("cat perch %.2f  moved %.2f  state %s" % [perch, moved, cat.state])
	# screenshot: the farmer by the cat and dog
	p.pos = Vector3(cat.pos.x + 1.5, Terrain.get_height(cat.pos.x + 1.5, cat.pos.z + 1.0), cat.pos.z + 1.0)
	dog.pos = Vector3(p.pos.x + 1.2, p.pos.y, p.pos.z - 0.8)
	main.rig.dist = 9.0; main.rig.pitch = 0.55
	main.rig.snap()
	for i in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	var ok: bool = follow < 16.0 and patted and thrown and main.fetches >= 1 and perch > 0.8 and moved > 0.5
	print("DOGCAT TEST ", "PASS" if ok else "FAIL")
	quit()
