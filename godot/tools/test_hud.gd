extends SceneTree
## The HUD leftovers: the NEXT line (the glint first, hunger urgent), the homeward chip (home when 90 m out; the
## assay office while carrying gold), the poke; and the tools in his fist (axe, pickaxe, bow with the quiver, the
## six-shooter) and the lightning-bug jar glowing in his left hand by night. Screenshots: the HUD far out with the
## axe (out), the bow and quiver (out_bow), the six-shooter (out_gun), the jar at night (out_jar).

func _shot(path: String, n := 20) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4; main.sky.day = 3
	for i in 20: await process_frame
	var p: Player = main.player; var hud: Hud = main.hud; var A: Avatar = p.avatar; var res := {}
	res.next_glint = hud.next_label.text.begins_with("Pick up the gold glint")
	main.glint.queue_free(); main.glint = null
	p.fullness = 10.0; main.next_t = 0.0
	for i in 3: await process_frame
	res.next_hungry = hud.next_label.text.begins_with("Hungry!") and hud.next_urgent
	p.fullness = 80.0; main.next_t = 0.0
	for i in 3: await process_frame
	print("NEXT: %s" % hud.next_label.text)
	res.next_road = not hud.next_urgent and hud.next_label.text != ""
	# out past 90 m: the homeward chip; the poke
	var h: Vector3 = main.homestead.spawn
	p.pos = Vector3(h.x + 110, 0, h.z + 40); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.inventory.dollars = 12
	for i in 5: await process_frame
	res.homeward = hud.homeward.visible and hud.homeward_label.text.begins_with("Home, ")
	res.poke = hud.fortune.visible and hud.fortune_label.text == "$12 in your poke"
	print("homeward: %s · %s" % [hud.homeward_label.text, hud.fortune_label.text])
	# the axe in his fist
	main.pick_tool("axe")
	main.rig.dist = 4.5; main.rig.pitch = 0.3; main.rig.yaw = p.facing + 2.4; main.rig.snap()
	await _shot(out)
	res.axe = A.tools_by.axe.visible and A.fist.visible and A.grip.global_position.distance_to(p.pos + Vector3(0, 1, 0)) < 1.2
	# carrying gold: the chip points to the assayer
	main.inventory.gold = 3
	for i in 3: await process_frame
	res.to_assay = hud.homeward_label.text.begins_with("Assay office (3 pinches)") and hud.homeward_icon.kind == "gold"
	main.inventory.gold = 0
	# the bow and its quiver (on dry ground, seen from the front)
	var dry := p.pos
	for r in range(0, 200, 4):
		var q := p.pos + Vector3(r, 0, 0)
		if not Terrain.is_water(q.x, q.z) and not Terrain.is_water(q.x + 2, q.z + 2): dry = q; break
	p.pos = Vector3(dry.x, Terrain.get_height(dry.x, dry.z), dry.z)
	main.rig.dist = 4.0; main.rig.pitch = 0.25; main.rig.yaw = p.facing + 0.6; main.rig.snap()
	main.tools["bow"] = true; main.pick_tool("bow")
	await _shot(out.replace(".png", "_bow.png"))
	res.bow = A.tools_by.bow.visible and A.quiver.visible
	# the six-shooter
	main.tools["revolver"] = true; main.pick_tool("revolver")
	await _shot(out.replace(".png", "_gun.png"))
	res.gun = A.tools_by.revolver.visible and not A.tools_by.bow.visible
	# the jar by night, full of lightning bugs
	main.sky.time = 0.92; await process_frame; await process_frame # (night first: at first light the jar is let go)
	main.tools["jar"] = true; main.jar_count = 6; main.pick_tool("hands")
	main.rig.yaw = p.facing + 0.6; main.rig.snap()
	await _shot(out.replace(".png", "_jar.png"), 40)
	res.jar = A.jar.visible and A.jar_light.light_energy > 0.3 and not A.fist.visible
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("HUD TEST ", "PASS" if ok else "FAIL")
	quit()
