extends SceneTree
## The everyday extras (tools/meshy_extras.py, merged by blender_folk.py as x_*): a figure with them, stood about for a
## minute of game time, plays some of them now and then and goes back to its idle between. Headless.
func _initialize() -> void:
	var ok := true
	for nm in ["cgc_man_elder", "cgc_man_bandana"]:
		var f := ModelFigure.new(nm); root.add_child(f.root)
		var t0 := Time.get_ticks_msec()
		while f.player == null and Time.get_ticks_msec() - t0 < 20000: f.update(0.016); await process_frame
		var xs := []
		if f.player: for a in f.player.get_animation_list(): if String(a).begins_with("x_"): xs.append(a)
		var seen := {}
		for i in 3600: f.update(1.0 / 30.0); seen[f.current] = true # (two minutes, stood still)
		var played := seen.keys().filter(func(c): return String(c).begins_with("x_") and c != f.rest_idle)
		print("%s: %d extras in the model %s; rests in %s; played while standing: %s" % [nm, xs.size(), xs, f.rest_idle, played])
		ok = ok and xs.size() >= 5 and played.size() >= 2 and seen.has(f.rest_idle) # (each figure rests in its own idle now, the player's ask)
		f.root.queue_free()
	print("IDLE EXTRAS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
