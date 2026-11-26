extends SceneTree
## The new church (the player's bigger church): offered at the church door only once the old church is mended; E pays
## $120 and it stands in the old one's place, the preacher at its new door; kept in the save. With a user arg
## <out.png> (windowed) a picture of it at the head of Main Street. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	for i in 10: await process_frame
	var T: Town = main.town
	var before: bool = T.projects().any(func(p): return p.id == "church2")
	T.mend("church")
	var pr: Dictionary = T.projects().filter(func(p): return p.id == "church2")[0]
	main.inventory.dollars = 150
	for i in 10: main.player.pos = pr.door; main.player.vel = Vector3.ZERO; await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 5: main.player.pos = pr.door; await process_frame
	var built: bool = T.tiers.get("church2", 0) == 1
	var preacher_at: bool = T.folk.has("church") and T.folk.church.fig.root.position.distance_to(T.doors.church) < 4.0
	main.save_all()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sp))
	var kept: bool = int(saved.get("town", {}).get("church2", 0)) == 1
	var cg: Node3D = T.parts.church; var cbb := PaperMats._aabb(cg, Transform3D.IDENTITY); var back := -1e9
	for i in 8: back = maxf(back, (cbb.get_endpoint(i) - T.at).dot(T.along))
	print("its back %.1f m along Main Street (the north cross street's near edge at %.1f)" % [back, Town.CROSS_N - Town.CROSS_HW])
	var clear_of_cross: bool = back < Town.CROSS_N - Town.CROSS_HW
	var near_church: bool = T.doors.church.distance_to(T.church_at) < 12.0
	print("its door %.1f m from where the church stands" % T.doors.church.distance_to(T.church_at))
	print("offered before the old church was mended: %s; prompt [%s]; built %s, $%d left, the preacher at its door %s, saved %s" % [before, prompt, built, main.inventory.dollars, preacher_at, kept])
	var ok: bool = not before and prompt.contains("new church") and built and main.inventory.dollars == 30 and preacher_at and kept and near_church and clear_of_cross
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var d: Vector3 = T.doors.church
		for i in 40: main.player.pos = d - T.along * 10.0; await process_frame
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera
		cam.global_position = d - T.along * 16.0 + T.toward * 5.0 + Vector3(0, T.y0 + 6.0 - d.y, 0); cam.look_at(d + T.along * 5.0 + Vector3(0, T.y0 + 3.0 - d.y, 0), Vector3.UP); cam.fov = 55.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("CHURCH2 TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
