extends SceneTree
## The Hidebehind as the player's Meshy one: a sang site set down near the farm with its keeper, walked up to till it
## springs up (<out>) and comes on (<out>_chase.png). Prints its state. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
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
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	for i in 30: main.player.health = 100; await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_chase.png"))
	print("then: %s" % e.state)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
