extends SceneTree
## The fort kit close up (<out>_gate_day/_gate_night/_corner/_breach.png): the gate leaves open by day and shut at
## night, a corner piece, the breached section at the back. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	var f: Dictionary = main.forts.forts[0]
	if OS.get_environment("CLEARED") != "": f.cleared_day = main.sky.day # (its garrison beaten)
	var fz := Vector3(sin(f.face), 0, cos(f.face)); var fx := Vector3(fz.z, 0, -fz.x); var H := ArmyForts.SIDE / 2.0
	var gate: Vector3 = f.at + fz * H
	var views := [["gate_day", 0.45, gate + fz * 9.0 + fx * 3.0, gate], ["gate_night", 0.9, gate + fz * 9.0 + fx * 3.0, gate],
		["corner", 0.45, f.at + (fx + fz) * (H + 7.0), f.at + (fx + fz) * H], ["breach", 0.45, f.at - fz * (H + 9.0) + fx * 2.0, f.at - fz * H]]
	for v in views:
		main.sky.time = v[1]; main.set_process(true)
		for i in 400: main.player.pos = gate + fz * 30.0; await process_frame # (the leaves swing slowly)
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera; var e: Vector3 = v[2]; var t: Vector3 = v[3]
		cam.global_position = Vector3(e.x, Terrain.get_height(e.x, e.z) + 4.0, e.z); cam.look_at(Vector3(t.x, Terrain.get_height(t.x, t.z) + 1.5, t.z), Vector3.UP); cam.fov = 55.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % v[0]))
	print("leaves %d, open %s" % [f.get("leaves", []).size(), f.get("leaves", []).map(func(L): return snappedf(L.open, 0.01))])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
