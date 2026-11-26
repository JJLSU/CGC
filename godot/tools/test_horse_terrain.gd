extends SceneTree
## The horse's ground (the player's ask): over the county, how much more a rider can cross than a man on foot; and two
## real crossings, ridden: a ford too deep to wade, and a hillside too steep to walk, the rider pushing straight on
## (held from turning) gets through where on foot he's turned back. Headless; CGC_SAVE_PATH a throwaway.
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _blocked_foot(x: float, z: float) -> bool: return (Terrain.is_water(x, z) and not Terrain.wadeable(x, z)) or Terrain.impassable(x, z)
func _blocked_horse(x: float, z: float) -> bool: return (Terrain.is_water(x, z) and not Terrain.wadeable(x, z, Terrain.HORSE_WADE)) or Terrain.impassable(x, z, Terrain.HORSE_STEEP)

## Push the player from a to b for sec seconds (riding or not); how far along he got (0-1).
func _push(main: Node, a: Vector3, b: Vector3, ride: bool, sec: float) -> float:
	var p: Player = main.player
	p.pos = Vector3(a.x, Terrain.get_height(a.x, a.z), a.z); p.vel = Vector3.ZERO; p.riding = ride; p.health = p.max_health; p.dead = false
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		p.facing = atan2(-dir.z, dir.x); main.input.keys["KeyW"] = true; p.stamina = p.max_stamina
		main.rig.yaw = atan2(-dir.x, -dir.z) # (W walks the way the camera looks)
		await process_frame
	main.input.keys.erase("KeyW")
	return clampf((p.pos - a).dot(dir) / a.distance_to(b), 0.0, 1.0)

func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	await _wait(1.0)
	var home: Vector3 = main.spawn
	var foot := 0; var horse := 0; var n := 0; var fords := []; var hills := []
	for i in 120:
		for j in 120:
			var x: float = home.x - 600.0 + i * 10.0; var z: float = home.z - 600.0 + j * 10.0
			n += 1
			var bf := _blocked_foot(x, z); var bh := _blocked_horse(x, z)
			if bf: foot += 1
			if bh: horse += 1
			if bf and not bh:
				if Terrain.is_water(x, z) and not Terrain.wadeable(x, z): fords.append(Vector3(x, 0, z))
				elif Terrain.impassable(x, z) and not Terrain.is_water(x, z): hills.append(Vector3(x, 0, z))
	print("of %d spots: on foot %d blocked (%.1f%%), on horseback %d (%.1f%%)" % [n, foot, 100.0 * foot / n, horse, 100.0 * horse / n])
	var ok := horse < foot
	for e in [["ford", fords], ["hill", hills]]:
		var best = null; var c := Vector3.ZERO
		for cand in e[1]:
			if best != null: break
			c = cand
			for k in 16:
				var ang := k * TAU / 16.0; var d := Vector3(cos(ang), 0, sin(ang))
				var a := c - d * 9.0; var b := c + d * 9.0
				if _blocked_horse(a.x, a.z) or _blocked_horse(b.x, b.z) or _blocked_foot(a.x, a.z) or _blocked_foot(b.x, b.z): continue
				var clear := true
				for s in 19: var q := a.lerp(b, s / 18.0); if _blocked_horse(q.x, q.z): clear = false; break
				if clear: best = [a, b]; break
		if best == null: print("%s: no clean line through to ride (of %d spots)" % [e[0], e[1].size()]); continue
		var on_foot: float = await _push(main, best[0], best[1], false, 6.0)
		var mounted: float = await _push(main, best[0], best[1], true, 6.0)
		print("%s at %s: on foot got %.0f%% across, mounted %.0f%%" % [e[0], c.round(), on_foot * 100.0, mounted * 100.0])
		ok = ok and mounted > 0.9 and on_foot < 0.9
	main.player.riding = false
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("HORSE TERRAIN TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
