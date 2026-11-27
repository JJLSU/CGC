extends SceneTree
## Domino at Dusty Jake's post: before (his bay beside your chestnut Biscuit, <out>) and after you've bought her (your
## bay, Jake on the chestnut, <out>_after.png). Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var R: HorseRace = main.race
	var at: Vector3 = R.jpos + (R.start - R.jpos).normalized() * 3.5
	main.make_horse(at.x, at.z)
	var stand: Vector3 = R.jpos + Vector3(5, 0, 5)
	for k in 2:
		for i in 60: main.player.pos = Vector3(stand.x, Terrain.get_height(stand.x, stand.z), stand.z); await process_frame
		main.rig.dist = 11.0; main.rig.pitch = 0.3; main.rig.yaw = atan2(stand.x - R.jpos.x, stand.z - R.jpos.z) + 0.4; main.rig.snap()
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out if k == 0 else out.replace(".png", "_after.png"))
		R.sell_domino(); main._domino(true)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
