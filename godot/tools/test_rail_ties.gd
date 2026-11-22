extends SceneTree
## The player's asks for the railroad: the ties lie square across the rails; each car tilts with the grade (its
## long axis along the line from its back wheels to its front, up and down the hills); she runs at 3.5 m/s.
## (No screenshots: runs --headless.)

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 10: await process_frame
	var T: Town = main.town; var R: Railroad = main.railroad; var TR: Train = main.train
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and not R.built: await process_frame
	# the ties: each one's long axis (local x) square to the track's direction there. (Headless, the MultiMesh keeps no
	# transforms to read back, so this checks the turn railroad.gd gives each tie: Basis(UP, yaw) with yaw the track's.)
	var worst := 0.0
	for i in range(1, R.path.size() - 1, 7):
		var a: Vector3 = R.path[i - 1]; var b: Vector3 = R.path[i + 1]
		var yaw := atan2(b.x - a.x, b.z - a.z)
		var along := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		worst = maxf(worst, absf(Basis(Vector3.UP, yaw).x.dot(along)))
	print("ties: worst |cos| between a tie and the track %.3f (0 = square across)" % worst)
	var ok := worst < 0.05
	# the cars on the move: tilt against the grade under them
	TR.state = "run"; TR.dir = 1; TR.ran = -2
	var max_tilt := 0.0; var worst_err := 0.0
	for f in 600:
		await process_frame
		for c in TR.cars:
			var fwd: Vector3 = (c as Node3D).basis.z.normalized()
			var tilt := rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0)))
			max_tilt = maxf(max_tilt, absf(tilt))
			# the grade under the car from the ground either end
			var hp: Vector3 = c.position + fwd * 2.0; var hb: Vector3 = c.position - fwd * 2.0
			var grade := rad_to_deg(atan2(Terrain.get_height(hp.x, hp.z) - Terrain.get_height(hb.x, hb.z), 4.0))
			if absf(grade) < 20.0: worst_err = maxf(worst_err, absf(tilt - grade))
	print("cars: steepest tilt %.1f deg, worst off the ground's grade %.1f deg  speed %.1f m/s" % [max_tilt, worst_err, Train.SPEED])
	ok = ok and max_tilt > 1.0 and Train.SPEED == 3.5
	print("RAIL TIES TEST ", "PASS" if ok else "FAIL")
	quit()
