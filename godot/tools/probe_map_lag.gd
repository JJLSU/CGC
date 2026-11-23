extends SceneTree
## Frame times with the county map open (M), after walking a little way: median, p95, worst, and how many frames the
## faint-iron fill ran. Headless.
func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	main.input.pressed["KeyM"] = true
	var f := []; var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 6000:
		var a := Time.get_ticks_usec(); await process_frame; f.append((Time.get_ticks_usec() - a) / 1000.0)
	var open_ms: float = f[0] + f[1]
	f.sort()
	print("map open: first frames %.0f ms; then median %.1f  p95 %.1f  worst %.1f ms over %d frames; still filling %s" % [open_ms, f[f.size() / 2], f[int(f.size() * 0.95)], f[-1], f.size(), main._map_filling])
	quit()
