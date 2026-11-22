extends SceneTree
## Screenshots of the step-10c effects: morning mist, a rainbow, puddles in rain, a fallen star at night.
## godot --path godot --script res://tools/shot_weather.gd -- <out_dir>

func _shot(main: Node, out: String, frames: int) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)

func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.rig.dist = 26.0; main.rig.pitch = 0.5
	# mist at first light
	main.sky.time = 0.235; main.sky.day = 4; main.night_rain = true
	await _shot(main, dir + "/g_mist.png", 120)
	# a rainbow after a daytime shower (the camera turned away from the sun)
	main.sky.time = 0.42
	main.mist.misty = false
	main.rainbow.show_at(main.player.pos, main.sky.sun_dir)
	main.rig.yaw = atan2(main.sky.sun_dir.x, main.sky.sun_dir.z); main.rig.pitch = 0.15
	await _shot(main, dir + "/g_rainbow.png", 400)
	# puddles in the rain
	main.rig.pitch = 0.7; main.rig.dist = 20.0
	main.weather.start(120.0, "rain"); main.weather.rain = 1.0; main.puddles.level = 1.0
	await _shot(main, dir + "/g_puddles.png", 120)
	# a fallen star at night
	main.weather.target = 0; main.weather.rain = 0.0; main.puddles.level = 0.0
	main.sky.time = 0.96
	main.falling_stars.launch(main.player.pos)
	await _shot(main, dir + "/g_star.png", 300)
	print("star state ", main.falling_stars.state, " at ", main.falling_stars.at)
	quit()
