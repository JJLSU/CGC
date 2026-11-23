extends SceneTree
## The county map opened (<out>_0), zoomed out with the wheel (<out>_1), then dragged with the mouse (<out>_2) and
## washed afresh where it came to rest; the claim jumpers' camps and the natives' land marked.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame
func _shot(p: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(p)
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45
	await _wait(3.0)
	main.hud.county_map.reveal(main.spawn.x, main.spawn.z, 700.0, 0.2, 30.0) # (the county explored, for the look)
	main.input.pressed["KeyM"] = true
	await _wait(1.0); await _shot(out.replace(".png", "_0.png"))
	for i in 8: main.input.wheel = 1.0; await process_frame
	await _wait(1.0); await _shot(out.replace(".png", "_1.png"))
	for i in 20: main.input.dx = -12.0; main.input.dy = -6.0; await process_frame
	await _wait(1.5); await _shot(out.replace(".png", "_2.png"))
	print("span %.0f  view %s" % [main.hud.county_map.span, main.hud.county_map.view.round()])
	quit()
