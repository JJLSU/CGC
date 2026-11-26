extends SceneTree
## One street up close (<out>_top.png from above, <out>_<id>.png each building from across the street), the whole
## town mended. Args: <out.png> <street index, -1 Main Street>. Prints each building's lot and its model's real
## footprint, and any two that overlap. Windowed; a throwaway save.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]; var k := int(args[1]) if args.size() > 1 else 2
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp) and OS.get_environment("CGC_KEEP") == "": DirAccess.remove_absolute(ProjectSettings.globalize_path(sp)) # (CGC_KEEP: start from that save, a copy of one)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.5; main.weather.rain = 0.0
	main._dev_town()
	var T: Town = main.town
	var off: float = 0.0 if k < 0 else T.street_offs[k]
	var list: Array = Town.BUILDINGS if k < 0 else Town.STREETS[k].buildings
	var c: Vector3 = T.at + T.toward * off
	for i in 150: main.player.pos = c - T.along * 20.0; await process_frame
	# each model's footprint in the town's frame (s along, o across)
	var boxes := {}
	for b in list:
		var g: Node3D = T.parts[b.id]; var mn := Vector2(1e9, 1e9); var mx := -mn
		for mi in g.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D; if m.mesh == null: continue
			var ab := m.mesh.get_aabb()
			for ci in 8:
				var q := m.global_transform * ab.get_endpoint(ci); var rel := q - T.at
				var s := rel.dot(T.along); var o := rel.dot(T.toward)
				mn = Vector2(minf(mn.x, s), minf(mn.y, o)); mx = Vector2(maxf(mx.x, s), maxf(mx.y, o))
		boxes[b.id] = Rect2(mn, mx - mn)
		print("%s: lot s %.1f w %.1f side %d; model s %.1f..%.1f, o %.1f..%.1f" % [b.id, b.s, b.w, b.side, mn.x, mx.x, mn.y, mx.y])
	var ids := boxes.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var r: Rect2 = boxes[ids[i]].intersection(boxes[ids[j]])
			if r.size.x > 0.3 and r.size.y > 0.3: print("OVERLAP %s / %s: %.1f x %.1f m" % [ids[i], ids[j], r.size.x, r.size.y])
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	cam.global_position = c + Vector3(0, T.y0 + 55.0 - c.y, 0) + T.toward * 0.01; cam.look_at(c + Vector3(0, T.y0 - c.y, 0), T.along); cam.fov = 50.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_top.png"))
	for b in list:
		var d: Vector3 = T.doors[b.id]; var g: Node3D = T.parts[b.id]; var gp := g.global_position
		var o2 := Vector3(d.x - gp.x, 0, d.z - gp.z).normalized()
		cam.global_position = d + o2 * 11.0 + Vector3(0, T.y0 + 4.0 - d.y, 0); cam.look_at(gp + Vector3(0, T.y0 + 2.5 - gp.y, 0), Vector3.UP); cam.fov = 55.0
		if OS.get_environment("FEET") != "": # (down at their feet, close)
			cam.global_position = d + o2 * 5.0 + Vector3(0, T.y0 + 0.7 - d.y, 0); cam.look_at(d + Vector3(0, T.y0 + 0.3 - d.y, 0), Vector3.UP); cam.fov = 60.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % b.id))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
