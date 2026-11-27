extends SceneTree
## The county map with the county explored, the railroad laid and every street mended: the forts, the rail line, the
## depot and the whistle-stops' posts, the race course (<out>_0 opened, <out>_1 zoomed out). Prints which kinds the
## map was handed. Windowed; a throwaway save.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame
func _shot(p: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(p)
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45
	main._dev_town(); main.railroad.build()
	await _wait(2.0)
	main.hud.county_map.reveal(main.spawn.x, main.spawn.z, 750.0, 0.15, 25.0)
	main.input.pressed["KeyM"] = true
	await _wait(1.5)
	var M = main.hud.county_map
	var kinds := {}
	for s in M.ctx.sites: kinds[s.kind] = kinds.get(s.kind, 0) + 1
	print("sites handed to the map: %s; rail %s (%d points, %d posts); race %s" % [kinds, M.ctx.get("rail") != null, M.ctx.rail.pts.size() if M.ctx.get("rail") else 0, M.ctx.rail.posts.size() if M.ctx.get("rail") else 0, M.ctx.get("race") != null])
	for f in main.forts.forts: print("  fort %s at %.0f m from home, seen %s" % [f.name, Vector2(f.at.x - main.spawn.x, f.at.z - main.spawn.z).length(), M.seen(f.at.x, f.at.z)])
	await _shot(out.replace(".png", "_0.png"))
	for i in 10: main.input.wheel = 1.0; await process_frame
	await _wait(1.5); await _shot(out.replace(".png", "_1.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
