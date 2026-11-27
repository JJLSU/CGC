extends SceneTree
## The town's and the railroad's signs and lanterns on the player's Meshy posts, each close up (<out>_<what>.png).
## Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build()
	var T: Town = main.town; var R: Railroad = main.railroad
	var shots := []
	var face_of := func(n: Node3D) -> Vector3: return n.global_basis.z.normalized()
	for ch in T.get_children():
		pass
	shots.append(["town", T.sign.global_position, (T.sign as Node3D).global_basis.z.normalized(), 0.45])
	var lamp: Node3D = T.lamps.values()[0] if T.lamps.size() else null
	if lamp: shots.append(["lantern_day", lamp.global_position, lamp.global_basis.z.normalized(), 0.45]); shots.append(["lantern_night", lamp.global_position, lamp.global_basis.z.normalized(), 0.9])
	shots.append(["depot", R.depot_group.to_global(Vector3(5.2, 0, 4.6)), R.depot_group.global_basis.z.normalized(), 0.45])
	if R.stops.size(): var g: Node3D = R.stops[0].get("post_group"); if g: shots.append(["post", g.to_global(Vector3(-2.6, 0, 3.0)), g.global_basis.z.normalized(), 0.45])
	var ra: Vector3 = T.at + T.along * -31.0 + T.toward * -3.6; shots.append(["row", ra, -T.along, 0.45])
	var sa: Vector3 = T.at + T.along * -18.0 + T.toward * (T.street_offs[0] - signf(T.street_offs[0]) * 5.2); shots.append(["street", sa, -T.along, 0.45])
	var pa: Vector3 = T.doors.assay - T.along * 1.7 + T.toward * 1.0; shots.append(["placard", pa, T.toward, 0.45])
	if OS.get_environment("ONLY") != "": shots = shots.filter(func(s): return OS.get_environment("ONLY").split(",").has(s[0]))
	for s in shots:
		main.sky.time = s[3]; main.set_process(true)
		for i in 90: main.player.pos = s[1] + s[2] * 10.0; await process_frame
		main.set_process(false); main.player.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera; var p: Vector3 = s[1]; var y := Terrain.get_height(p.x, p.z)
		cam.global_position = Vector3(p.x, y + 3.6, p.z) + s[2] * 6.0 + Vector3(s[2].z, 0, -s[2].x) * 0.5; cam.look_at(Vector3(p.x, y + 1.5, p.z), Vector3.UP); cam.fov = 50.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % s[0]))
	print("shots: %s" % [shots.map(func(s): return s[0])])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
