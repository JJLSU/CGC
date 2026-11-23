extends SceneTree
## The county map's opening, in parts: the whole _open_map, then a wash alone and an ink-only repaint. Headless.
func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	var M: CountyMap = main.hud.county_map
	for k in 3:
		var a := Time.get_ticks_usec(); main._open_map(); var b := Time.get_ticks_usec()
		var c0 := Time.get_ticks_usec(); M.paint(M.ctx, true); var c1 := Time.get_ticks_usec()
		var d0 := Time.get_ticks_usec(); main._open_map(false); var d1 := Time.get_ticks_usec()
		await process_frame
		var e0 := Time.get_ticks_usec(); await process_frame; var e1 := Time.get_ticks_usec()
		print("open %.0f ms (wash alone %.0f, a gather + ink-only repaint %.0f); next frame %.0f ms" % [(b - a) / 1000.0, (c1 - c0) / 1000.0, (d1 - d0) / 1000.0, (e1 - e0) / 1000.0])
		main.hud.map_card.visible = false
		for i in 5: await process_frame
	quit()
