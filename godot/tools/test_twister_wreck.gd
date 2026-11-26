extends SceneTree
## What a twister wrecks (the player's ask): sent through a mended town building, a pitched tent, a stand of trees and
## a built wall, it batters the building back to run-down, carries the tent off, fells the trees and knocks the wall
## apart. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.5; main.weather.rain = 0.0
	for i in 20: await process_frame
	var T: Town = main.town
	# 1) the town: the general store mended, the twister sent right through it
	T.mend("store")
	var sg: Vector3 = (T.parts.store as Node3D).global_position
	main.player.pos = sg + T.toward * 40.0
	for i in 30: await process_frame
	main.spawn_twister(); var tw: Twister = main.twister
	tw.start(sg - T.along * 30.0, sg + T.along * 60.0); tw.drop = 0.0
	var t0 := Time.get_ticks_msec()
	while T.tiers.get("store", 0) and Time.get_ticks_msec() - t0 < 12000:
		main.player.pos = sg + T.toward * 40.0; await process_frame
	var town_hit: bool = not T.tiers.get("store", 0)
	print("the store battered back to run-down: %s" % town_hit)
	# 2) out in the county: a tent, a wall, and whatever trees stand in its way
	var a: Vector3 = main.spawn + Vector3(30, 0, 30)
	var b: Vector3 = a + Vector3(60, 0, 0)
	main.player.pos = a + Vector3(0, 0, 45)
	for i in 30: await process_frame
	var mid := a.lerp(b, 0.5)
	var tent := NativeCamps.prop("prop_tent", 3.0); tent.position = Vector3(mid.x, Terrain.get_height(mid.x, mid.z), mid.z + 1.0); main.add_child(tent)
	var wq := a.lerp(b, 0.7)
	var wall: Dictionary = main.build.add({"type": "wall", "x": wq.x, "y": Terrain.get_height(wq.x, wq.z), "z": wq.z + 1.0, "rot": 0}, true)
	var trees := []
	for r in main.world.resources_near(mid.x, mid.z, 32.0):
		if Res.TYPES[r.type].get("falls", false) and absf(r.z - a.z) < 4.0 and r.x > a.x + 8.0 and r.x < b.x - 5.0: trees.append(r)
	main.spawn_twister(); tw = main.twister
	tw.start(a, b + (b - a) * 3.0); tw.drop = 0.0
	t0 = Time.get_ticks_msec()
	while tw.pos.distance_to(a) < 60.0 and Time.get_ticks_msec() - t0 < 20000:
		main.player.pos = a + Vector3(0, 0, 45); tw.dir = (b - a).normalized(); await process_frame
	print("twister went from %s to %s (tent at %s, wall at %s)" % [a.round(), tw.pos.round(), tent.global_position.round() if is_instance_valid(tent) else null, wq.round()])
	for i in 30: await process_frame
	var tent_gone: bool = not is_instance_valid(tent) or not tent.is_in_group("tents")
	var wall_gone: bool = not main.build.pieces.has(wall)
	var felled := trees.filter(func(r): return not r.alive).size()
	print("tent carried off: %s; wall knocked apart: %s; trees in its path felled: %d of %d" % [tent_gone, wall_gone, felled, trees.size()])
	var ok: bool = town_hit and tent_gone and wall_gone and felled == trees.size()
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("TWISTER WRECK TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
