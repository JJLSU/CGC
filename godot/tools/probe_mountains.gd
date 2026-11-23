extends SceneTree
## For new counties (seeds after --): where the town, its buildings' doors and the railroad's line sit against the
## mountains: Terrain.range_at (0 = none) and the height above the farm. Headless.
func _initialize() -> void:
	var seeds: Array = Array(OS.get_cmdline_user_args()).map(func(a): return int(a))
	var k: int = seeds[0]
	seed(k)
	var path := "user://mtn_probe_%d.json" % k
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.save_path = path; main.saving = true
	root.add_child(main)
	await process_frame
	main.saving = false
	for i in 30: await process_frame
	var T: Town = main.town; var R: Railroad = main.railroad
	var farm_y: float = main.spawn.y
	var worst_door := 0.0; var worst_door_h := -INF
	for id in T.doors: var d: Vector3 = T.doors[id]; worst_door = maxf(worst_door, Terrain.range_at(d.x, d.z)); worst_door_h = maxf(worst_door_h, Terrain.get_height(d.x, d.z) - farm_y)
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000 and not R.built: await process_frame
	var rail_r := 0.0; var rail_h := -INF; var n_mtn := 0
	for q in R.path: var rr := Terrain.range_at(q.x, q.z); rail_r = maxf(rail_r, rr); rail_h = maxf(rail_h, Terrain.get_height(q.x, q.z) - farm_y); if rr > 0.05: n_mtn += 1
	print("seed %d world %d ring %s: town at range %.2f (h %+.1f); doors worst range %.2f h %+.1f; rail %d pts, %d on mountain, worst range %.2f h %+.1f" % [k, main.world_seed, main.world_ring, Terrain.range_at(T.at.x, T.at.z), Terrain.get_height(T.at.x, T.at.z) - farm_y, worst_door, worst_door_h, R.path.size(), n_mtn, rail_r, rail_h])
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()
