extends SceneTree
## The county map's faint iron (21e): opened in a fresh game, the unexplored chunks round you are laid out while the
## map stays open, nearest first, within ~20 ms a frame, and the faint "Iron?" veins the assayer knows of are inked in
## as they come. Screenshot: the map once filled (out).

func _veins(main: Node) -> int:
	var n := 0
	for s in main.hud.county_map.ctx.get("sites", []): if s.kind == "vein" and s.get("rumour", false): n += 1
	return n

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000: await process_frame
	var cached0: int = Props.site_cache.size()
	main.input.pressed["KeyM"] = true
	await process_frame; await process_frame
	var v0 := _veins(main)
	var frames := []
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and main._map_filling:
		var f0 := Time.get_ticks_usec(); await process_frame; frames.append((Time.get_ticks_usec() - f0) / 1000.0)
	frames.sort()
	var v1 := _veins(main)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("chunks laid out: %d before, %d after  faint veins: %d at once, %d once filled  fill took %.1f s  frames: median %.1f ms, worst %.1f ms" % [cached0, Props.site_cache.size(), v0, v1, (Time.get_ticks_msec() - t0) / 1000.0, frames[frames.size() / 2] if frames.size() else 0.0, frames[-1] if frames.size() else 0.0])
	var ok: bool = v1 > v0 and not main._map_filling and frames.size() > 0 and frames[-1] < 160.0 # (one far layout a frame: ~80 ms, see PORT.md 21e)
	print("MAP2 TEST ", "PASS" if ok else "FAIL")
	quit()
