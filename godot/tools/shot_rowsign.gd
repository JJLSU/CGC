extends SceneTree
## The Squatters' Row signpost from in front (<out>_a) and behind (<out>_b): its words clear of the post and brace.
## Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var T: Town = main.town
	var sp: Vector3 = T.at + T.along * -31.0 + T.toward * -3.6
	for k in [["a", -1.0], ["b", 1.0]]:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			var at: Vector3 = sp + T.toward * float(k[1]) * 3.0
			main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); main.player.avatar.root.visible = false
			var look: Vector3 = -T.toward * float(k[1])
			main.rig.yaw = atan2(-look.x, -look.z); main.rig.pitch = 0.0; main.rig.dist = 2.5
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % k[0]))
	quit()
