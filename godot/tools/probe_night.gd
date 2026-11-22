extends SceneTree
## Night-sky probe: how many stars are up after a few seconds of night, where the first is, and whether it's in view.

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.sky.time = 0.97
	main.rig.pitch = -0.45; main.rig.dist = 3.0
	for i in 400: await process_frame
	var ns: NightSky = main.night_sky
	var cam: Camera3D = main.rig.camera
	var n := ns.stars.visible_instance_count
	var inview := 0
	for i in n:
		var p := ns.stars.get_instance_transform(i).origin
		if cam.is_position_in_frustum(p): inview += 1
	print("night %.2f t %.2f stars %d in view %d moon %s" % [main.sky.night, ns.t, n, inview, ns.moon.visible])
	quit()
