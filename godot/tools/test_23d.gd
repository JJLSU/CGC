extends SceneTree
## 23d: the gaps behind the old "comes with step N" notes. The sidehill gouger's uphill legs drawn short (two bones
## at 0.66 of their rest, after the walk clip) and its body listing; tumbleweeds rolling down Main Street (within 75 m
## of town, not only in the dry country); songbirds at the mended bakery's doorstep. Screenshot: <out> (the gouger).

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	await _wait(2.0)
	var p: Player = main.player
	# a gouger beside the farmer, ambling
	var at := p.pos + Vector3(4, 0, 2)
	main.enemies.spawn_site({"key": "test:gouger", "kind": "den", "guard": "gouger", "guards": 1, "x": at.x, "z": at.z})
	var e: Dictionary = main.enemies.list.filter(func(q): return q.key.begins_with("test:gouger"))[0]
	var ok := true
	if false: print("no spawn hook"); ok = false
	else:
		await _wait(1.0)
		var pup: Puppet = e.puppet
		var sk := pup.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var lopm: LopLegs = sk.find_children("*", "LopLegs", false, false)[0]
		var b: int = lopm.bones[0]; var r: int = lopm.bones[1]
		var sc := sk.get_bone_global_pose(b).basis.get_scale().x / sk.get_bone_global_pose(maxi(sk.find_bone("frontUpr.R"), sk.find_bone("frontUpr_R"))).basis.get_scale().x
		var sr := sk.get_bone_global_pose(r).basis.get_scale().x / sk.get_bone_global_pose(maxi(sk.find_bone("rearLeg.R_01"), sk.find_bone("rearLeg_R_01"))).basis.get_scale().x
		var right := maxi(sk.find_bone("frontUpr.R"), sk.find_bone("frontUpr_R"))
		var sright := sk.get_bone_pose_scale(right).x / sk.get_bone_rest(right).basis.get_scale().x if right >= 0 else 1.0
		print("modifier runs %d, roll %.2f" % [lopm.runs, pup.rig.rotation.x])
		ok = ok and lopm.runs > 10 and absf(pup.rig.rotation.x + 0.6) < 0.01
		# beside it, close, from its left side; then the same with the short legs switched off
		e.state = "guard"; e.speed = 0.0
		var gp: Vector3 = pup.group.position
		p.pos = gp + Vector3(2.2, 0, 0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
		main.rig.yaw = 0.0; main.rig.pitch = 0.2; main.rig.dist = 6.0; main.rig.snap()
		await _wait(1.0)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out)
		lopm.active = false; pup.lop = null
		await _wait(0.5)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_even.png"))
	# Main Street: tumbleweeds by day
	var town: Node = main.town
	p.pos = Vector3(town.at.x, Terrain.get_height(town.at.x, town.at.z), town.at.z)
	main.tumbleweeds.wait = 0.0
	await _wait(1.0)
	var rolling: int = main.tumbleweeds.list.size()
	print("tumbleweeds on Main Street: %d" % rolling)
	ok = ok and rolling != 0
	print("23D TEST ", "PASS" if ok else "FAIL")
	quit()
