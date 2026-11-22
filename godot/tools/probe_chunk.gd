extends SceneTree
## Times a chunk's finish in parts (step 28): Props.place (the layout), the pools (instances written), the sites'
## spawns, for chunks out in the wilds that haven't been laid out yet.
func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 120: await process_frame
	var w: World = main.world
	for k in 8:
		var cx := -6 - k; var cz := 7 + k
		var t0 := Time.get_ticks_usec()
		var placed := Props.place(cx, cz, w.exclusions)
		var t1 := Time.get_ticks_usec()
		var placed2 := Props.place(cx, cz, w.exclusions)
		var t2 := Time.get_ticks_usec()
		var job := Terrain.chunk_job(cx, cz); while not Terrain.chunk_step(job, 1 << 30): pass
		var t3 := Time.get_ticks_usec()
		var sites0: int = main.enemies.list.size()
		w.create_chunk(cx, cz, job.mesh, true)
		var t4 := Time.get_ticks_usec()
		print("chunk %d,%d: place %.1f ms (again %.1f, cached %s)  mesh %.1f  create_chunk %.1f  props %d sites %d guards +%d" % [cx, cz, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, Props.site_cache.has("%d,%d" % [cx, cz]), (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, placed.list.size(), placed.sites.size(), main.enemies.list.size() - sites0])
	quit()
