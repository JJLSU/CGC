extends SceneTree
## A traveller you've met says hello as you come back (<out>). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var W: Wayfarers = main.wayfarers; var c = W.camps[0]
	var st: Vector3 = c.at + Vector3(12, 0, 8)
	for i in 120: main.player.pos = Vector3(st.x, Terrain.get_height(st.x, st.z), st.z); await process_frame
	if c.fig == null: print("no traveller here"); quit(); return
	c.met = true
	var fp: Vector3 = c.fig.root.position
	var near := fp + Vector3(3, 0, 2)
	for i in 20: main.player.pos = Vector3(near.x, Terrain.get_height(near.x, near.z), near.z); await process_frame
	main.rig.dist = 9.0; main.rig.pitch = 0.25; main.rig.yaw = atan2(near.x - fp.x, near.z - fp.z) + 0.4; main.rig.snap()
	for i in 4: await process_frame
	print("%s says '%s'" % [c.kind.id, W.card.text if W.card else "-"])
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
