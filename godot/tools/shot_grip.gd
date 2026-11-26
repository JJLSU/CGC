extends SceneTree
## The tool in the farmer's fist, close up on his right hand from two sides (<out>_a.png, <out>_b.png): where the hand bone
## is, where the grip is put, and where the handle crosses. Args: <out.png> [tool] [tools...]. Windowed; a throwaway save.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args(); var out: String = args[0]
	var held: String = args[1] if args.size() > 1 else "axe"
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main.tools = {}
	for t in args.slice(2): main.tools[t] = true
	main.tools[held] = true; main.held = held
	var base: Vector3 = main.spawn + Vector3(6, 0, 9)
	for i in 60:
		main.player.pos = base; main.player.vel = Vector3.ZERO
		await process_frame
	var av: Avatar = main.player.avatar
	var gv := OS.get_environment("GRIP").split(",")
	if gv.size() == 2: av.grip_along = float(gv[0]); av.grip_palm = float(gv[1])
	for i in 5: await process_frame
	var hb: Node3D = av.fig.hands[1].get_parent()
	var hand: Vector3 = hb.global_position; var g: Vector3 = av.grip.global_position
	print("hand bone at %s, grip at %s (%.3f m apart); fist shown %s; root scale %s" % [hand, g, hand.distance_to(g), av.fist.visible, av.root.global_basis.get_scale()])
	var sk: Skeleton3D = av.fig.skeleton; var hi := sk.find_bone("RightHand")
	print("hand pose scale %s (rest %s); modifier on %s; hand holder global scale %s; forearm-to-hand %.3f m" % [sk.get_bone_pose_scale(hi), sk.get_bone_rest(hi).basis.get_scale(), false, hb.global_basis.get_scale(), hb.global_position.distance_to((sk.global_transform * sk.get_bone_global_pose(sk.get_bone_parent(hi))).origin)])
	main.set_process(false)
	var cam: Camera3D = main.rig.camera
	var fwd: Vector3 = av.root.global_basis.z.normalized(); var right: Vector3 = -av.root.global_basis.x.normalized()
	for v in [["a", right * 0.9 + fwd * 0.5], ["b", fwd * 1.0 + right * 0.2]]:
		cam.global_position = g + v[1] + Vector3(0, 0.25, 0); cam.look_at(g, Vector3.UP); cam.fov = 40.0
		await process_frame; await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % v[0]))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
