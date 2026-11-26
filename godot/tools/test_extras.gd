extends SceneTree
## The extras: gather the eggs, dig the cellar ($20) and take its food, sit in the rocker and watch time run 24x,
## buy the bunkhouse ($40); then a screenshot of the farm with them.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 30: await process_frame
	var x: FarmExtras = main.extras
	var p: Player = main.player
	var press := func(at: Vector3) -> void:
		p.pos = Vector3(at.x + 0.5, Terrain.get_height(at.x + 0.5, at.z), at.z)
		for i in 2: await process_frame
		main.input.pressed["KeyE"] = true
		for i in 2: await process_frame
	await press.call(x.coop_pos)
	var eggs: int = main.inventory.egg
	main.inventory.dollars = 70
	await press.call(x.cellar_pos)
	var dug := x.cellar_built
	await press.call(x.cellar_pos)
	var food: int = main.inventory.apples
	await press.call(x.bunk_pos)
	var bunk := x.bunk_built
	var t0: float = main.sky.time
	await press.call(x.seat)
	var sat := x.sitting
	for i in 60: await process_frame
	var drift: float = main.sky.time - t0
	main.input.pressed["KeyE"] = true
	for i in 2: await process_frame
	print("eggs %d  cellar %s apples %d  bunkhouse %s  sat %s drift %.4f  up %s  dollars %d" % [eggs, dug, food, bunk, sat, drift, not x.sitting, main.inventory.dollars])
	var ok: bool = eggs == 3 and dug and food == 2 and bunk and sat and drift > 0.01 and not x.sitting and main.inventory.dollars == 10
	print("EXTRAS TEST ", "PASS" if ok else "FAIL")
	p.pos = main.homestead.spawn
	main.rig.dist = 34.0; main.rig.pitch = 0.8; main.rig.yaw = 0.9
	for i in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	quit()
