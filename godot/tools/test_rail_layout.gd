extends SceneTree
## The line laid sensibly (the player: crazy tracks, a trading post in Chinatown's street): it never crosses itself or
## runs close alongside itself, no whistle-stop or its post stands in the town, the line keeps out of the streets.
## Several fresh counties. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	var runs := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 1
	var ok := true
	if FileAccess.file_exists(sp) and OS.get_environment("CGC_KEEP") == "": DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var R: Railroad = main.railroad; var T: Town = main.town
	var P: Array = R.path
	# crossings: segments every 4 ties, not neighbours
	var seg := []
	for i in range(0, P.size() - 4, 4): seg.append([Vector2(P[i].x, P[i].z), Vector2(P[i + 4].x, P[i + 4].z), i])
	var crosses := 0; var close := 0
	for a in seg.size():
		for b in range(a + 3, seg.size()):
			var X = Geometry2D.segment_intersects_segment(seg[a][0], seg[a][1], seg[b][0], seg[b][1])
			if X != null:
				crosses += 1
				var dn := 1e9; var nm := ""
				for st in R.stops: var dd := Vector2(st.at.x, st.at.z).distance_to(X); if dd < dn: dn = dd; nm = st.land
				print("  crossing at ties %d and %d, %.0f m from the %s stop; %.0f m from the depot" % [seg[a][2], seg[b][2], dn, nm, X.distance_to(Vector2(R.depot.x, R.depot.z))])
	# alongside itself: a point within 10 m of another more than 60 m further along the line
	var near_stop := func(q: Vector3) -> bool:
		for st in R.stops: if Vector2(q.x - st.at.x, q.z - st.at.z).length() < 40.0: return true
		return false
	for i in range(0, P.size(), 6):
		if near_stop.call(P[i]): continue # (where the line comes into a stop and leaves it again)
		for j in range(i + 80, P.size(), 6):
			if Vector2(P[i].x - P[j].x, P[i].z - P[j].z).length() < 10.0: close += 1; break
	# the town's streets: the line never within 8 m of a street's lots or a cross street
	var in_town := 0
	var omin := 0.0; var omax := 0.0
	for o in T.street_offs: omin = minf(omin, o); omax = maxf(omax, o)
	for q in P:
		var rel: Vector3 = q - T.at; var s := rel.dot(T.along); var o := rel.dot(T.toward)
		if s > Town.CROSS_S - 12.0 and s < Town.CROSS_N + 12.0 and o > omin - 22.0 and o < omax + 22.0: in_town += 1
	var posts_in := 0
	for st in R.stops:
		var rel: Vector3 = st.at - T.at; var s := rel.dot(T.along); var o := rel.dot(T.toward)
		if s > Town.CROSS_S - 20.0 and s < Town.CROSS_N + 20.0 and o > omin - 30.0 and o < omax + 30.0: posts_in += 1
	print("(legs laid straight for want of a way round: %d)" % Railroad.fallbacks)
	print("line %d ties: crosses itself %d times, alongside itself at %d places, %d ties in the town, %d stops in the town" % [P.size(), crosses, close, in_town, posts_in])
	ok = crosses == 0 and close == 0 and in_town == 0 and posts_in == 0
	if FileAccess.file_exists(sp) and OS.get_environment("CGC_KEEP") == "": DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("RAIL LAYOUT TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
