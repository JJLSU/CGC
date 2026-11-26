extends SceneTree
## The saloon (<out>), forced to the second model; ruined first (<out>_ruined), then mended. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp != "" and not sp.contains("paperfjord.builds") and FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var T: Town = main.town
	for b in main.bosses: b.delivered = true
	for b in Town.BUILDINGS: T.mend(b.id)
	for st in Town.STREETS: for b in st.buildings: if b.id != "dance": T.mend(b.id)
	var k := Town.street_of("dance")

	if OS.get_cmdline_user_args().has("night"): main.sky.time = 0.86
	for tier in [0, 1]:
		if tier == 1: T.mend("dance")
		var d: Vector3 = T.doors.dance; var c: Vector3 = T.parts.dance.global_position
		var o2: Vector3 = Vector3(d.x - c.x, 0, d.z - c.z).normalized()
		for i in 60: main.player.pos = d + o2 * 3.0; await process_frame
		main.set_process(false)
		var cam: Camera3D = main.rig.camera
		var eye: Vector3 = (c + o2 * 0.5 + Vector3(0, 22, 0)) if OS.get_cmdline_user_args().has("top") else ((d + o2 * 2.0 + Vector3(0, T.y0 + 2.6 - d.y, 0)) if OS.get_cmdline_user_args().has("inside") else (d + o2 * 12.0 + Vector3(0, T.y0 + 6.0 - d.y, 0)))
		cam.global_position = eye; cam.look_at((c - o2 * 12.0 + Vector3(0, T.y0 + 1.2 - c.y, 0)) if OS.get_cmdline_user_args().has("inside") else Vector3(c.x, T.y0 + 1.5, c.z), Vector3.UP); cam.fov = 50.0
		main.player.avatar.root.visible = false
		await process_frame; await process_frame
		if T.hall_barman: var bp: Vector3 = T.hall_barman.root.global_position + Vector3(0, 1.5, 0); print("barman on screen %s behind %s vis %s scale %s girls %s" % [cam.unproject_position(bp), cam.is_position_behind(bp), T.hall_barman.root.is_visible_in_tree(), T.hall_barman.root.global_transform.basis.get_scale(), T.hall_girls[0].root.global_position.round() if T.hall_girls else null])
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_ruined.png" if tier == 0 else ".png"))
		main.set_process(true); cam.fov = 30.0
	quit()
