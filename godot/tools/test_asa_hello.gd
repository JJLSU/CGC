extends SceneTree
## Old Asa the hermit, once met, hails you as you come back to his fire (<out> if given: a look). A throwaway save.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0] if args.size() else ""
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var lm: Landmarks = main.landmarks
	var u = null
	for q in Props.unique_encounters(): if q.mark == "hermit": u = q
	var off := Vector3(u.x + 20, 0, u.z + 12)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and not lm.live.values().any(func(l): return l.site.mark == "hermit"):
		main.player.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); await process_frame
	var here = null
	for l in lm.live.values(): if l.site.mark == "hermit": here = l
	lm.found[here.site.key] = true # (met him before)
	var fp: Vector3 = here.figure.root.global_position
	var near := fp + Vector3(3, 0, 2.5)
	for i in 20: main.player.pos = Vector3(near.x, Terrain.get_height(near.x, near.z), near.z); await process_frame
	var said: String = lm.asa_card.text if lm.asa_card else ""
	print("Asa says: '%s'" % said)
	if out != "":
		main.rig.dist = 8.0; main.rig.pitch = 0.25; main.rig.yaw = atan2(near.x - fp.x, near.z - fp.z) + 0.5; main.rig.snap()
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
	var ok: bool = said in Landmarks.ASA
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("ASA HELLO TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
