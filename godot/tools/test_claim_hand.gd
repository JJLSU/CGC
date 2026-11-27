extends SceneTree
## Your hired hand at the claim speaks as you come up by day (how the cart stands), once a visit. Windowed for a look
## (<out>, optional); a throwaway save.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0] if args.size() else ""
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build(); main.tools["claim"] = true; main.claim.build()
	var C: Claim = main.claim; C.hire(main.sky.day); C.stock.gold = 12
	var hp: Vector3 = C.hand.root.global_position
	var a: Vector3 = hp + Vector3(8, 0, 6)
	for i in 60: main.player.pos = Vector3(a.x, Terrain.get_height(a.x, a.z), a.z); await process_frame
	var said: String = C.hand_card.text if C.hand_card else ""
	print("the hand says: '%s' (shown %s, %.1f m off, day %s)" % [said, C.hand.root.visible, Vector2(hp.x - main.player.pos.x, hp.z - main.player.pos.z).length(), main.sky.time])
	if out != "":
		main.rig.dist = 12.0; main.rig.pitch = 0.3; main.rig.yaw = atan2(a.x - hp.x, a.z - hp.z); main.rig.snap() # (from where you stand, outside)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
	var ok: bool = said in ["Cart's near full, boss!", "She's a fair vein, boss. Come see the cart."]
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("CLAIM HAND TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
