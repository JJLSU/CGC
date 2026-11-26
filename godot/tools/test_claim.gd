extends SceneTree
## The gold claim and the opening glint: a glint by the cabin on a new game (picked up with E: 2 gold); the claim
## staked out once the line is down and it's filed; work the vein once a day with a pick; hire a hand, and the next
## day his takings wait in the ore cart; the stamp mill. Screenshots: the glint (out_glint); the claim (out).

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4; main.sky.day = 2
	for i in 10: await process_frame
	var p: Player = main.player; var T: Town = main.town; var R: Railroad = main.railroad; var C: Claim = main.claim; var inv: Dictionary = main.inventory
	var res := {}
	var press := func() -> void:
		main.input.pressed["KeyE"] = true
		for i in 3: await process_frame
	# the glint by the cabin
	res.glint_there = main.glint != null
	var gp: Vector3 = main.glint.position
	p.pos = gp + Vector3(1.2, 0, 0.6); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.rig.dist = 5.0; main.rig.pitch = 0.6; main.rig.yaw = 0.4; main.rig.snap()
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_glint.png"))
	var gprompt: String = main.beast_prompt
	inv.gold = 0; await press.call()
	res.glint_taken = main.glint == null and inv.gold == 2 and main.opening_done
	# the line, and the claim filed
	for st in Town.STREETS: for b in st.buildings: T.mend(b.id)
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: T.mend(id)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and not R.built: await process_frame
	main.tools["claim"] = true
	for i in 3: await process_frame
	res.staked = C.group != null
	var at: Vector3 = C.dig_at
	print("claim at %s  dig at %s  (web: breaks stop + side*11 - along*17)" % [C.at(), at])
	p.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z)
	for i in 3: await process_frame
	var p0: String = main.beast_prompt
	main.tools.erase("pickaxe"); main.tools.erase("ironpick"); main.tools.erase("steelpick")
	await press.call(); res.no_pick = C.dug_day == -1
	main.tools["pickaxe"] = true; inv.gold = 0
	await press.call(); res.dug = C.dug_day == main.sky.day and inv.gold >= 2
	var g1: int = inv.gold
	await press.call(); res.once_a_day = inv.gold == g1
	# a hired hand and the mill; the next day the cart has his takings
	main.tools["claimhand"] = true; main.tools["stampmill"] = true
	for i in 3: await process_frame
	res.hand = C.hand != null and C.mill != null
	main.sky.day += 1
	for i in 3: await process_frame
	var cart: int = C.stock.gold
	var p1: String = main.beast_prompt
	await press.call(); res.collected = cart >= 4 and inv.gold == g1 + cart and C.stock.gold == 0
	# a look at it all
	var side: Vector3 = C.stop.geo.side
	p.pos = C.group.transform * Vector3(1.5, 0, 6.0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.rig.dist = 16.0; main.rig.pitch = 0.6; main.rig.yaw = C.group.rotation.y + 0.5; main.rig.snap()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("glint prompt [%s]  claim prompts [%s] [%s]  cart %d  hand visible %s" % [gprompt, p0, p1, cart, C.hand.root.visible])
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("CLAIM TEST ", "PASS" if ok else "FAIL")
	quit()
