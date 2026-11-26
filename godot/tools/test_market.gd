extends SceneTree
## The market's stalls, each yours to fix up (the player: anything with a ruined and a good model can be paid to put
## right): at first all wrecked; at a stall's front the prompt offers to mend it; E pays and it stands restored with
## its stallkeeper; it's kept in the save. With a user arg <out.png> (windowed) a picture of the row, one mended.
## Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	for i in 20: await process_frame
	var T: Town = main.town
	var wrecked := range(Town.MARKET.size()).all(func(i): return not T.tiers.get("mkt_%d" % i, 0))
	var pr: Dictionary = T.projects().filter(func(p): return p.id == "mkt_3")[0]
	main.inventory.dollars = 50
	for i in 10: main.player.pos = pr.door; main.player.vel = Vector3.ZERO; await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 5: main.player.pos = pr.door; await process_frame
	var mended: bool = T.tiers.get("mkt_3", 0) == 1
	var paid: bool = main.inventory.dollars == 50 - int(pr.cost)
	var keeper: bool = T.folk.has("mkt_3")
	main.save_all()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sp))
	var kept: bool = int(saved.get("town", {}).get("mkt_3", 0)) == 1
	print("all wrecked at first %s; prompt [%s]; mended %s, paid $%d %s, stallkeeper %s, saved %s" % [wrecked, prompt, mended, pr.cost, paid, keeper, kept])
	var ok: bool = wrecked and prompt.contains("red-striped food stall") and mended and paid and keeper and kept
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var mc: Vector3 = T.at + T.along * Town.MARKET_S + T.toward * Town.MARKET_O[3]
		for i in 30: main.player.pos = mc - T.along * 10.0; await process_frame
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera
		cam.global_position = mc - T.along * 14.0 + Vector3(0, T.y0 + 6.0 - mc.y, 0); cam.look_at(mc + Vector3(0, T.y0 + 1.0 - mc.y, 0), Vector3.UP); cam.fov = 70.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("MARKET TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
