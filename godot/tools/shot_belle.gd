extends SceneTree
## The Belle of the Fen as the player's Meshy paddle-wheel wreck: from off her beam (<out>), then up her ladder onto the
## main deck and up the next onto the deck above (<out>_deck.png); prints where he stands against each deck. Windowed.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.42
	var p: Player = main.player; var lm: Landmarks = main.landmarks
	var u = null
	for q in Props.unique_encounters(): if q.mark == "steamboat": u = q
	var a: float = u.rot + 1.0
	var o := Vector3(u.x + cos(a) * 16.0, 0, u.z + sin(a) * 16.0)
	p.pos = Vector3(o.x, Terrain.get_height(o.x, o.z), o.z)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 and not lm.live.values().any(func(l): return l.site.mark == "steamboat"): await process_frame
	var here = null
	for l in lm.live.values(): if l.site.mark == "steamboat": here = l
	main.rig.dist = 24.0; main.rig.pitch = 0.5; main.rig.yaw = atan2(o.x - u.x, o.z - u.z); main.rig.snap()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	for nm in ["the wreck of the Belle", "the Belle's upper deck"]:
		var L = null
		for st in main.climbs.sets.values(): for l in st.ladders: if l.name == nm: L = l
		p.pos = L.foot
		for i in 15: p.pos = L.foot; await process_frame
		main.input.pressed["KeyE"] = true
		t0 = Time.get_ticks_msec()
		await process_frame
		print("  after E: climbing %s, prompt '%s', pos y %.2f" % [p.climbing != null, main.beast_prompt, p.pos.y - here.site.y])
		while Time.get_ticks_msec() - t0 < 8000 and p.climbing != null: await process_frame
		print("  climbed: y %.2f, standing %s" % [p.pos.y - here.site.y, main.climbs.standing(p.pos) != null])
		for i in 30: await process_frame
		main.rig.dist = 12.0; main.rig.pitch = 0.55; main.rig.snap()
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % (1 if nm.begins_with("the wreck") else 2)))
		print("%s: he stands %.2f m above the site (the ladder's top %.2f)" % [nm, p.pos.y - here.site.y, L.top.y - here.site.y])
	main.rig.dist = 12.0; main.rig.pitch = 0.55; main.rig.snap()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_deck.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
