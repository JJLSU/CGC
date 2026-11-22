extends SceneTree
## Performance (step 20c): walks the farmer at a sprint along a route across the county (the farm, the lane, Paydirt
## Hollow, the woods, out into a wild land, back at night) and reports per leg: average frame, 95th percentile, worst,
## Godot's process time and draw calls, and which of main.gd's systems took the most (timed with section stamps).

const LEGS := [["farm, morning", Vector3(-3, 0, -23.5), Vector3(10, 0, -10), 0.33], ["the lane to town", Vector3(-10, 0, -15), Vector3(-65, 0, 20), 0.4],
	["Main Street, noon", Vector3(-80, 0, 20), Vector3(-55, 0, 32), 0.5], ["the woods north", Vector3(0, 0, -30), Vector3(60, 0, -110), 0.55],
	["into the wilds", Vector3(-100, 0, 120), Vector3(-160, 0, 200), 0.6], ["the farm at night", Vector3(-3, 0, -23.5), Vector3(15, 0, 5), 0.9]]
const SPEED := 6.0

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0
	var ts := Time.get_ticks_msec()
	while Time.get_ticks_msec() - ts < 8000: await process_frame # (settle: the pools and models load ahead)
	main.prof = {}
	var p: Player = main.player
	print("leg | avg ms | p95 | worst | process ms | draw calls | objects")
	for leg in LEGS:
		var a: Vector3 = leg[1]; var b: Vector3 = leg[2]; main.sky.time = leg[3]
		p.pos = Vector3(a.x, Terrain.get_height(a.x, a.z), a.z)
		for i in 30: await process_frame
		var prof0: Dictionary = main.prof.duplicate()
		var frames := []; var procs := []; var draws := 0; var objs := 0; var n := 0
		var dist := a.distance_to(b); var t := 0.0
		while t * SPEED < dist:
			var t0 := Time.get_ticks_usec(); var before: Dictionary = main.prof.duplicate(); main.world.last_finish_ms = 0.0
			await process_frame
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			if dt > float(OS.get_environment("SPIKE_MS") if OS.get_environment("SPIKE_MS") != "" else "40"):
				var spikes := []
				for k in main.prof: if main.prof[k] - before.get(k, 0.0) > 4.0: spikes.append("%s %.0f" % [k, main.prof[k] - before.get(k, 0.0)])
				print("  spike %.0f ms in %s: %s  chunk finish %.0f ms  render %.1f ms" % [dt, leg[0], spikes, main.world.last_finish_ms, RenderingServer.get_frame_setup_time_cpu()])
			frames.append(dt); t += dt / 1000.0
			var q := a.lerp(b, minf(1.0, t * SPEED / dist)); p.pos = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z)
			procs.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME); objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME); n += 1
		frames.sort(); procs.sort()
		var avg: float = frames.reduce(func(s, x): return s + x, 0.0) / frames.size()
		var pavg: float = procs.reduce(func(s, x): return s + x, 0.0) / procs.size()
		print("%s | %.1f | %.1f | %.1f | %.1f | %d | %d" % [leg[0], avg, frames[int(frames.size() * 0.95)], frames[-1], pavg, draws / maxi(1, n), objs / maxi(1, n)])
		var dl := []
		for k in main.prof: dl.append([k, (main.prof[k] - prof0.get(k, 0.0)) / maxi(1, n)])
		dl.sort_custom(func(x, y): return x[1] > y[1])
		print("    per frame: ", dl.slice(0, 6).map(func(x): return "%s %.2f" % x))
	if main.get("prof") != null:
		var items: Array = main.prof.keys().map(func(k): return [k, main.prof[k]])
		items.sort_custom(func(x, y): return x[1] > y[1])
		print("main.gd sections (total ms over the walk): ", items.slice(0, 14))
	quit()
