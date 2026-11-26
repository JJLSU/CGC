extends SceneTree
## Does walking about leak? The farmer shuttled between the farm and far-off country (chunks built and let go each
## trip), the engine's object, resource and node counts sampled after each trip. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 60: await process_frame
	main.force_active = true
	var home: Vector3 = main.spawn
	var far := [home + Vector3(420, 0, 0), home + Vector3(0, 0, 420), home + Vector3(-420, 0, 0), home + Vector3(0, 0, -420)]
	for trip in 8:
		for target in [far[trip % 4], home]:
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 3500:
				var to: Vector3 = target - main.player.pos; to.y = 0
				if to.length() > 2.0: main.player.pos += to.normalized() * minf(to.length(), 2.5)
				main.player.pos.y = Terrain.get_height(main.player.pos.x, main.player.pos.z)
				await process_frame
		print("trip %d: objects %d  resources %d  nodes %d  orphans %d  chunks %d" % [trip, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), main.world.chunks.size()])
	quit()
