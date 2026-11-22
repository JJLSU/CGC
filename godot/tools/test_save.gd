extends SceneTree
## Save and load (step 20a): a game set up (inventory, tools, fortune, a workbench built, a building mended, the
## clock, letters read, a tale heard, country explored, a land found, a guardian beaten, a pie from Grandma, the
## railroad laid with freight) is saved to a file, thrown away, and a fresh game loaded from it must match; the world
## keeps its seed. Screenshot: the loaded game (out).

func _game(path: String) -> Node:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.save_path = path; main.saving = true
	root.add_child(main)
	return main

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var path := "user://test_save.json"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var A := _game(path)
	await process_frame
	A.force_active = true
	for i in 10: await process_frame
	var seed_a: int = A.world_seed
	A.inventory.wood = 17; A.inventory.dollars = 41; A.tools["pickaxe"] = true; A.held = "pick"; A.fortune = 33
	var p: Player = A.player; var f := p.forward(); var bx := p.pos.x + f.x * 3.0; var bz := p.pos.z + f.z * 3.0
	A.build.add({"type": "workbench", "x": bx, "y": Terrain.get_height(bx, bz), "z": bz, "rot": 1}, true)
	A.town.mend("store"); A.sky.day = 5; A.sky.time = 0.5 # (not 0.6: the afternoon train would take the freight)
	A.mail.read = 2; A.tales.heard[3] = true; A.hud.county_map.explored["40,40"] = true; A.lands_found["fen"] = true
	A.world.destroyed["9,9,site:g0"] = true; A.grandma.pie_day = 5; A.journal.record("chop")
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: A.town.mend(id)
	for st in Town.STREETS: for b in st.buildings: A.town.mend(b.id)
	A.railroad.build(); A.railroad.add_freight(); A.railroad.add_freight()
	for i in 5: await process_frame
	A.save_all()
	var wrote := FileAccess.file_exists(path)
	A.queue_free()
	for i in 5: await process_frame
	var B := _game(path)
	await process_frame
	B.force_active = true
	for i in 20: await process_frame
	var res := {}
	res.wrote = wrote
	res.seed = B.world_seed == seed_a
	res.inventory = B.inventory.wood == 17 and B.inventory.dollars == 41 and B.tools.has("pickaxe") and B.held == "pick" and B.fortune == 33
	res.pieces = B.build.pieces.any(func(q): return q.type == "workbench" and absf(q.x - bx) < 0.01 and absf(q.z - bz) < 0.01)
	res.town = B.town.tiers.get("store", 0) > 0 and B.town.tiers.get("church", 0) > 0
	res.clock = B.sky.day == 5 and absf(B.sky.time - 0.5) < 0.01
	res.mail_tales_map = B.mail.read == 2 and B.tales.heard.has(3) and B.hud.county_map.explored.has("40,40") and B.lands_found.has("fen")
	res.beaten = B.world.destroyed.has("9,9,site:g0") and B.grandma.pie_day == 5 and B.journal.day_log.get("chop", 0) >= 1
	res.rail = B.railroad.built and B.railroad.freight == 2
	res.no_glint = B.glint == null # (an old game: the opening's over, as fortune > 0)
	B.rig.dist = 12.0; B.rig.pitch = 0.6; B.rig.snap()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("seed %d  file %s  rail built %s freight %d  saved %s" % [seed_a, ProjectSettings.globalize_path(path), B.railroad.built, B.railroad.freight, B.saved.get("railroad")])
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("SAVE TEST ", "PASS" if ok else "FAIL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()
