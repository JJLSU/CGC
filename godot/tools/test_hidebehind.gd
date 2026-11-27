extends SceneTree
## The Hidebehind keeps to the tale: up close it springs up and comes on; while you look at it, it stands still (or
## slips behind a trunk); look away and it comes on. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var at: Vector3 = main.spawn + Vector3(-22, 0, 18)
	var site := {"key": "test:hb", "kind": "sang", "guard": "hidebehind", "guards": 1, "x": at.x, "z": at.z}
	main.enemies.spawn_site(site)
	var e = main.enemies.list.filter(func(q): return q.key.begins_with("test:hb"))[0]
	var stand := at + Vector3(9, 0, 6)
	for i in 30: main.player.pos = Vector3(stand.x, Terrain.get_height(stand.x, stand.z), stand.z); await process_frame
	print("lurking: %s, visible %s" % [e.state, e.puppet.group.visible])
	var near := at + Vector3(3, 0, 2.5)
	for i in 50: main.player.pos = Vector3(near.x, Terrain.get_height(near.x, near.z), near.z); main.player.health = 100; await process_frame
	main.rig.dist = 9.0; main.rig.pitch = 0.25; main.rig.yaw = atan2(near.x - at.x, near.z - at.z) + 0.5; main.rig.snap()
	for i in 5: await process_frame
	print("near: %s, visible %s" % [e.state, e.puppet.group.visible])
	for i in 30: main.player.health = 100; await process_frame
	print("then: %s" % e.state)
	# watched: face it (the camera behind him, looking at it) and it stands still; turn away and it comes on
	var hb: Vector3 = e.puppet.group.position
	var far: Vector3 = hb + (main.player.pos - hb).normalized() * 7.0
	for i in 5: main.player.pos = Vector3(far.x, Terrain.get_height(far.x, far.z), far.z); await process_frame
	main.rig.yaw = atan2(far.x - hb.x, far.z - hb.z); main.rig.pitch = 0.2; main.rig.dist = 8.0; main.rig.snap()
	for i in 10: main.player.pos = Vector3(far.x, Terrain.get_height(far.x, far.z), far.z); main.player.health = 100; await process_frame
	var w0: Vector3 = e.puppet.group.position
	for i in 60: main.player.pos = Vector3(far.x, Terrain.get_height(far.x, far.z), far.z); main.player.health = 100; await process_frame
	var w1: Vector3 = e.puppet.group.position
	main.rig.yaw += PI; main.rig.dist = 3.0; main.rig.snap() # (look away: the camera between him and it, looking at him)
	for i in 60: main.player.pos = Vector3(far.x, Terrain.get_height(far.x, far.z), far.z); main.player.health = 100; await process_frame
	var w2: Vector3 = e.puppet.group.position
	print("watched %s: moved %.2f m in a second watched; %.2f m in a second looking away" % [e.get("watched"), Vector2(w1.x - w0.x, w1.z - w0.z).length(), Vector2(w2.x - w1.x, w2.z - w1.z).length()])
	var m_w := Vector2(w1.x - w0.x, w1.z - w0.z).length(); var m_a := Vector2(w2.x - w1.x, w2.z - w1.z).length()
	var ok: bool = m_w < 0.5 and m_a > 1.0
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("HIDEBEHIND TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
