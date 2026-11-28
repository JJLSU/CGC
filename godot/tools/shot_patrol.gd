extends SceneTree
## A look at a fort's mounted patrol, close from outside the ring, square on to the first rider (<out>), and from
## a little ahead of him (<out>_b). Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var f: Dictionary = main.forts.forts[0]
	for k in [["", 0.0], ["_b", 0.7]]:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 6000:
			var pt: Array = f.get("patrol", [])
			if pt.size():
				var rp: Vector3 = pt[0].pos; var u: Vector3 = rp - f.at; u.y = 0.0; u = u.normalized()
				var yaw: float = atan2(u.x, u.z) + float(k[1])
				var at := rp + Vector3(sin(yaw), 0, cos(yaw)) * 1.0
				main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); main.rig.yaw = yaw
			else:
				main.player.pos = f.at + Vector3(30, 0, 0)
			main.rig.pitch = 0.22; main.rig.dist = 7.5; main.player.avatar.root.visible = false
			await process_frame
		print("patrol: %d riders" % f.get("patrol", []).size())
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", k[0] + ".png"))
	quit()
