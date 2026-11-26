extends SceneTree
## 21f: the faster noise and the elevation memo change no value. Simplex.at against the original (at_ref) over 200k
## points and several seeds, bit for bit; get_height with the memo against a fresh computation without it; timings.
func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	for i in 30: await process_frame
	var bad := 0; var n := 0
	for sd in [20261120, 7, 99991]:
		var sx := PNoise.Simplex.new(sd)
		for k in 70000:
			var x := randf_range(-5000.0, 5000.0) * (0.001 if k % 3 == 0 else 1.0); var y := randf_range(-5000.0, 5000.0) * (0.013 if k % 5 == 0 else 1.0)
			if sx.at(x, y) != sx.at_ref(x, y): bad += 1
			n += 1
	print("simplex: %d of %d differ" % [bad, n])
	# heights: memoised get_height vs a fresh one (memo cleared before each)
	var pts := []
	for k in 3000: pts.append(Vector2(randf_range(-600, 600), randf_range(-600, 600)))
	var a := []
	for q in pts: a.append(Terrain.get_height(q.x, q.y))
	var hbad := 0
	for i in pts.size():
		Terrain.e_memo.clear()
		if Terrain.get_height(pts[i].x, pts[i].y) != a[i]: hbad += 1
	print("heights: %d of %d differ" % [hbad, pts.size()])
	# timings, away from built chunks
	var far := []
	for k in 400: far.append(Vector2(randf_range(400, 900), randf_range(400, 900)))
	var sxx := PNoise.Simplex.new(5); var t0 := Time.get_ticks_usec()
	for k in 100000: sxx.at(k * 0.37, k * 0.11)
	var t_new := (Time.get_ticks_usec() - t0) / 100000.0
	t0 = Time.get_ticks_usec()
	for k in 100000: sxx.at_ref(k * 0.37, k * 0.11)
	var t_old := (Time.get_ticks_usec() - t0) / 100000.0
	Terrain.e_memo.clear(); t0 = Time.get_ticks_usec()
	for q in far: Terrain.get_height(q.x, q.y)
	var gh1 := (Time.get_ticks_usec() - t0) / float(far.size())
	t0 = Time.get_ticks_usec()
	for q in far: Terrain.is_water(q.x, q.y)
	var gh2 := (Time.get_ticks_usec() - t0) / float(far.size())
	var cs := []
	for q in far.slice(0, 6): cs.append(Vector2i(floori(q.x / 32.0) + 20, floori(q.y / 32.0)))
	Terrain.e_memo.clear(); t0 = Time.get_ticks_usec()
	for c in cs: Props._place(c.x, c.y, main.world.exclusions)
	print("simplex.at %.2f us (was %.2f)  get_height far %.1f us  is_water same spots after %.1f us  a far layout %.1f ms" % [t_new, t_old, gh1, gh2, (Time.get_ticks_usec() - t0) / 1000.0 / cs.size()])
	# against the web itself: world.js's getHeight, regionAt and rangeAt at 600 points of the same world
	var ref: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/compare/web_heights.json"))
	var wh := 0; var wr := 0; var wm := 0; var worst := 0.0
	for q in ref:
		var h := Terrain.get_height(q[0], q[1]); worst = maxf(worst, absf(h - q[2]))
		if absf(h - q[2]) > 0.001: wh += 1
		if Terrain.region_at(q[0], q[1]) != q[3]: wr += 1
		if absf(Terrain.range_at(q[0], q[1]) - q[4]) > 1e-6: wm += 1
	print("against the web: heights off %d, regions off %d, range off %d of %d (worst height diff %.6f)" % [wh, wr, wm, ref.size(), worst])
	print("TERRAIN EXACT TEST ", "PASS" if bad == 0 and hbad == 0 and wh == 0 and wr == 0 and wm == 0 else "FAIL")
	quit()
