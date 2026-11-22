extends SceneTree
## 22c: O cycles graphics auto → high → medium → low → auto (SSAO, bloom, the lens blur, the cut line, the shadow
## atlas and filter, the render scale), auto steps down after three slow seconds, P turns the depth of field off and
## on. Screenshots: <out>_high.png, <out>_low.png, <out>_nodof.png.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _key(main: Node, k: String) -> void:
	main.input.pressed[k] = true
	await process_frame; await process_frame

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.42
	await _wait(3.0)
	var q: Quality = main.quality
	var env: Environment = main.env.environment
	var ok := q.mode == "auto" and q.level == "high" and env.ssao_enabled and env.glow_enabled
	await _shot(out.replace(".png", "_high.png"))
	var seen := []
	for i in 4:
		await _key(main, "KeyO")
		seen.append("%s/%s ao=%s bloom=%s dof=%s line=%s" % [q.mode, q.level, env.ssao_enabled, env.glow_enabled, main.post.get_shader_parameter("dof_enabled"), main.post.get_shader_parameter("line_enabled")])
		if q.level == "low": await _wait(0.5); await _shot(out.replace(".png", "_low.png"))
	print("O: ", seen)
	ok = ok and seen[0].begins_with("manual/high") and seen[1].begins_with("manual/medium ao=true bloom=false") and seen[2].begins_with("manual/low ao=false bloom=false dof=0") and seen[3].begins_with("auto/high")
	await _key(main, "KeyP")
	ok = ok and not q.dof_on and main.post.get_shader_parameter("dof_enabled") == 0.0
	await _wait(0.5); await _shot(out.replace(".png", "_nodof.png"))
	await _key(main, "KeyP")
	ok = ok and q.dof_on and main.post.get_shader_parameter("dof_enabled") == 1.0
	# auto: three slow seconds after the warm-up step it down one level
	q.auto_ok = true; q.started_at -= 10000
	for i in 3:
		q._frames = 20; q._since = Time.get_ticks_msec() - 1000
		var msg := q.tick()
		if i == 2: print("auto: ", msg)
	ok = ok and q.level == "medium" and q.mode == "auto"
	print("QUALITY TEST ", "PASS" if ok else "FAIL")
	quit()
