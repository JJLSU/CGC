extends SceneTree
## The farm's hens and rooster and a wild turkey as the player's Meshy birds (<out>), close up (<out>_close.png).
## Prints how many of each are wearing their model. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.4; main.weather.rain = 0.0
	var C = main.critters
	var hens: Array = C.list.filter(func(c): return c.type == "hen")
	var yard: Vector3 = hens[0].home if hens.size() else main.spawn
	var tk = C.spawn("turkey", yard.x + 2.5, yard.z + 1.5)
	var kinds := {}
	for c in C.list: if c.type in ["hen", "turkey"]: kinds["%s %s" % [c.puppet.kind, c.puppet.still != null]] = kinds.get("%s %s" % [c.puppet.kind, c.puppet.still != null], 0) + 1
	print("birds wearing their models: %s" % kinds)
	var stand := yard + Vector3(6, 0, 6)
	for i in 90: main.player.pos = Vector3(stand.x, Terrain.get_height(stand.x, stand.z), stand.z); await process_frame
	main.rig.dist = 9.0; main.rig.pitch = 0.35; main.rig.yaw = atan2(stand.x - yard.x, stand.z - yard.z); main.rig.snap()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	main.rig.dist = 4.0; main.rig.pitch = 0.25; main.rig.snap()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_close.png"))
	if tk != null: # (the turkey up close)
		var tp: Vector3 = C.pos(tk)
		main.rig.target_node = tk.puppet.group; main.rig.dist = 3.5; main.rig.pitch = 0.2; main.rig.yaw += 1.2; main.rig.snap()
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_turkey.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
