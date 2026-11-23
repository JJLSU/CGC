extends SceneTree
## Build mode on the Works shelf with a storehouse and a quarry already standing: each marked "✓ built" (<out>).
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	for i in 120: await process_frame
	var h: Vector3 = main.spawn
	main.build.add({"type": "storehouse", "x": h.x + 20.0, "y": Terrain.get_height(h.x + 20.0, h.z + 14.0), "z": h.z + 14.0, "rot": 0})
	main.build.add({"type": "quarry", "x": h.x - 20.0, "y": Terrain.get_height(h.x - 20.0, h.z + 14.0), "z": h.z + 14.0, "rot": 0})
	main.tools["hammer"] = true
	for k in ["wood", "stone", "fiber", "rope", "clay", "honey", "iron"]: main.inventory[k] = 30
	main.input.pressed["KeyB"] = true; await process_frame; await process_frame
	main.input.pressed["Digit5"] = true
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("works built: ", main.build.pieces.filter(func(q): return q.type in ["storehouse", "quarry"]).size())
	quit()
