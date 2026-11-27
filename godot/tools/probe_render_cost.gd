extends SceneTree
## Render cost on Main Street at noon, the whole town mended and the railroad laid (fixed seed): GPU ms a frame,
## triangles and draw calls the renderer actually drew (after culling and draw distances). Windowed; a throwaway save.
func _initialize() -> void:
	seed(20261127)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.5; main._dev_town()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var T: Town = main.town; var at: Vector3 = T.at - T.along * 15.0
	if OS.get_environment("LOD_T") != "": root.get_viewport().mesh_lod_threshold = float(OS.get_environment("LOD_T"))
	for i in 240: main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); await process_frame
	var g := 0.0; var tr := 0.0; var dc := 0.0
	for i in 120:
		main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); await process_frame
		g += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()) / 120.0
		tr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 120.0
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) / 120.0
	print("RENDER COST gpu %.1f ms, %.0fk triangles, %.0f draw calls" % [g, tr / 1000.0, dc])
	quit()
