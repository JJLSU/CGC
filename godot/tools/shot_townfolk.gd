extends SceneTree
## The new townsfolk in place: every street mended and open, standing before <door id> (after --, default "bank"),
## looking at its keeper: <out.png>. Windowed. Run with CGC_SAVE_PATH set to a throwaway.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]; var id: String = args[1] if args.size() > 1 else "bank"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var T: Town = main.town
	for b in main.bosses: b.delivered = true
	main._trophies() # (all three trophies over the assay office)
	for b in Town.BUILDINGS: T.mend(b.id)
	T.mend("church")
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	var f = T.folk.get(id)
	if id.begins_with("row"): var c: Dictionary = T.civilians[int(id.substr(3))]; f = {"fig": c.fig, "face": c.fig.root.rotation.y} # (row<N>: the Row's Nth family)
	var d: Vector3 = T.doors.get(id, T.at)
	if id == "assay": f = {"fig": T.assayer, "face": T.assayer.root.rotation.y} # (the assayer, under the trophies)
	var keeper: Vector3 = f.fig.root.position if f != null else d
	print("keeper of %s: %s" % [id, f.fig.name if f != null else "none"])
	main.player.avatar.root.visible = false # (stood just in front of the keeper, out of the way)
	if args.has("night"): main.sky.time = 0.9 # (the can-can revue on the saloon's boardwalk)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		var stand: Vector3 = keeper + Vector3(sin(f.face if f != null else 0.0), 0, cos(f.face if f != null else 0.0)) * 1.2
		main.player.pos = Vector3(stand.x, Terrain.get_height(stand.x, stand.z), stand.z)
		main.rig.yaw = (f.face if f != null else 0.0) + (0.0 if id.begins_with("row") or args.has("flip") else PI) + 0.35; main.rig.pitch = 0.22 if not args.has("high") else 0.05; main.rig.dist = 7.0 if not args.has("far") else 11.0
		await process_frame
	if T.revue != null: print("revue: ", T.revue.map(func(r): return r.name))
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
