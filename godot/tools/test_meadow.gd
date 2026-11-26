extends SceneTree
## Dandelion clocks stand in the meadows and puff away when brushed; Johnny Appleseed walks the lane on his day and
## gives apples and a sapling; the coyote goes up on the rise of a dark night. Screenshots: Johnny in the lane, and a
## clump of clocks puffing.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0
	var p: Player = main.player
	# Johnny's day
	var day := 3
	while not Wanderer.visits(day): day += 1
	main.sky.day = day; main.sky.time = 0.4
	for i in 3: await process_frame
	var jw: Wanderer = main.johnny
	var came := jw.state == "walking"
	var x0 := jw.pos.x
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await process_frame
	var walked := jw.pos.x - x0
	p.pos = Vector3(jw.pos.x + 2.0, Terrain.get_height(jw.pos.x + 2.0, jw.pos.z), jw.pos.z)
	for i in 3: await process_frame
	var apples0: int = main.inventory.get("apples", 0); var pieces0: int = main.build.pieces.size()
	main.input.pressed["KeyE"] = true
	for i in 3: await process_frame
	var gave: bool = main.inventory.get("apples", 0) == apples0 + 3 and main.build.pieces.size() == pieces0 + 1
	main.rig.dist = 7.0; main.rig.pitch = 0.4; main.rig.yaw = 0.3
	main.rig.snap()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("johnny day %d came %s walked %.1f m gave %s" % [day, came, walked, gave])
	# dandelions: walk to the nearest clump and brush through it
	var dd: Dandelions = main.dandelions
	var near_c = null
	for r in range(1, 30):
		for c in dd.list: if near_c == null: near_c = c
		if near_c != null: break
		p.pos.x += 13.0; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
		await process_frame
	var puffed := 0
	if near_c != null:
		p.pos = Vector3(near_c.x + 3.0, Terrain.get_height(near_c.x + 3.0, near_c.z + 2.0), near_c.z + 2.0)
		for i in 5: await process_frame
		puffed = dd.update(0.016, main.sky.day, p.pos, [{"pos": Vector3(near_c.x, 0, near_c.z), "speed": 3.0}])
		for i in 40: await process_frame
		main.rig.dist = 6.0; main.rig.pitch = 0.35
		main.rig.snap()
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_puff.png"))
	print("clocks round here %d  puffed %d  seeds in the air %d  bald %d" % [dd.list.size(), puffed, dd.flying.size(), dd.bald.visible_instance_count])
	# the coyote on the rise
	main.sky.time = 0.97
	main.night_howl.wait = 0.0
	var sp: Vector3 = main.homestead.spawn
	for k in 200: # dry open country 50-150 m out
		var a := k * 0.37; var q := sp + Vector3(cos(a), 0, sin(a)) * (50.0 + k * 0.5)
		if not Terrain.is_water(q.x, q.z) and Terrain.get_height(q.x, q.z) > 0.0 and Vector2(q.x, q.z).length() > 60.0 and Vector2(q.x - main.town.at.x, q.z - main.town.at.z).length() > 95.0: p.pos = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z); break # (and away from town: the howl's out in the country, 90 m from Paydirt Hollow, as the web)
	t0 = Time.get_ticks_msec()
	var phases := {}
	while Time.get_ticks_msec() - t0 < 12000:
		await process_frame
		if main.night_howl.c != null: phases[main.night_howl.c.phase] = true
		elif phases.size() == 0: main.night_howl.wait = 0.0
	print("coyote phases %s  night %.2f rain %.2f  farmer y %.2f  r %.0f" % [phases.keys(), main.sky.night, main.weather.rain, p.pos.y, Vector2(p.pos.x, p.pos.z).length()])
	var ok: bool = came and walked > 1.5 and gave and puffed > 0 and dd.flying.size() > 0 and phases.has("howl")
	print("MEADOW TEST ", "PASS" if ok else "FAIL")
	quit()
