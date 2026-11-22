extends SceneTree
## Side-by-side views (step 20b): the web game's own save (assets/baked/compare/web_save.json, Day 28) loaded into
## Godot, and the same four views the web was captured at (player spot, camera yaw/pitch/distance, clock): the farm
## in the morning, Main Street at noon, the Redrock Breaks stop in the afternoon, the farm at night. Writes
## <out>_1..4.png at 1600x900 to set beside the web's captures.

const VIEWS := [[-3.0, -23.5, 0.32, 0.35, 0.46, 15.0], [-70.11, 24.64, 0.5, 0.9, 0.5, 22.0], [-126.0, 149.0, 0.55, 2.2, 0.5, 18.0], [-3.0, -23.5, 0.9, 0.35, 0.46, 15.0]]

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var copy := "user://compare_save.json"
	var f := FileAccess.open(copy, FileAccess.WRITE); f.store_string(FileAccess.get_file_as_string("res://assets/baked/compare/web_save.json")); f.close()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.save_path = copy; main.saving = true
	root.add_child(main)
	await process_frame
	main.force_active = true
	var p: Player = main.player
	for i in VIEWS.size():
		var v: Array = VIEWS[i]
		p.pos = Vector3(v[0], Terrain.get_height(v[0], v[1]), v[1]); p.vel = Vector3.ZERO
		main.sky.time = v[2]; main.weather.rain = 0.0; main.weather.target = 0
		main.rig.yaw = v[3]; main.rig.pitch = v[4]; main.rig.dist = v[5]; main.rig.snap()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % (i + 1)))
	print("day %d  town tiers %s" % [main.sky.day, main.town.tiers])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))
	quit()
