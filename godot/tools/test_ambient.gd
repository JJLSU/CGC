extends SceneTree
## Leaves and butterflies by day (screenshot), fireflies at night and one caught in the jar.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0
	main.sky.time = 0.45
	for i in 30: await process_frame
	var bf: Butterflies = main.butterflies; var am: Ambient = main.ambient
	var nb := bf.wl.visible_instance_count
	var falling := 0
	for s in am.leaf_state: if s.alive: falling += 1
	main.rig.dist = 7.0; main.rig.pitch = 0.35
	main.rig.snap()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# night: the fireflies, and one into the jar
	main.sky.time = 0.97
	for i in 30: await process_frame
	var glow := am.glow
	main.tools["jar"] = true
	var p: Player = main.player
	am.fly_state[0].home = p.pos + Vector3(0.3, 0.6, 0.3)
	for i in 2: await process_frame
	p.pos = Vector3(am.fly_state[0].pos.x, p.pos.y, am.fly_state[0].pos.z)
	await process_frame
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	print("butterflies %d  leaves %d  night glow %.2f  jar %d  day bugs after dark %d" % [nb, falling, glow, main.jar_count, bf.wl.visible_instance_count])
	var ok: bool = nb == 18 and falling > 40 and glow > 0.9 and main.jar_count == 1 and bf.wl.visible_instance_count == 0
	print("AMBIENT TEST ", "PASS" if ok else "FAIL")
	quit()
