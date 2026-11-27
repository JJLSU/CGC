extends SceneTree
## The first-person camera option (the player's ask): V puts the camera at the farmer's eyes with a 90-degree lens, his
## own body off the camera (its layer culled), the tilt-shift off, and the look free to tip up at the sky; V again (or
## the Options card's Camera button) back to the wide view at 30 degrees. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 10: await process_frame
	var cam: Camera3D = main.rig.camera
	var wide_fov := cam.fov
	main.input.pressed["KeyV"] = true
	for i in 5: await process_frame
	var head: Vector3 = main.player.avatar.fig.head.global_position
	var eye_gap := cam.global_position.distance_to(head)
	var body_layer: int = 0
	for mi in main.player.avatar.root.find_children("*", "MeshInstance3D", true, false): body_layer = (mi as VisualInstance3D).layers; break
	var culled: bool = (cam.cull_mask & body_layer) == 0
	var dof: float = main.post.get_shader_parameter("dof_enabled")
	main.input.dy = -900.0; await process_frame; main.input.dy = 0.0 # (a hard look up)
	var up: float = main.rig.pitch
	print("wide %.0f; first person %s at %.0f deg, eye %.2f m from his head, body culled %s, tilt-shift %.0f, look up to %.2f" % [wide_fov, main.rig.first_person, cam.fov, eye_gap, culled, dof, up])
	var b1: String = main._cycle_option("view")
	for i in 3: await process_frame
	print("Options > Camera: '%s', first person %s, %.0f deg" % [b1, main.rig.first_person, cam.fov])
	var ok: bool = is_equal_approx(wide_fov, 30.0) and eye_gap < 0.4 and culled and dof == 0.0 and up < -0.5 and b1 == "Wide" and not main.rig.first_person and is_equal_approx(cam.fov, 30.0)
	main.rig.first_person = true; main.rig.first_person = false
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("FIRST PERSON TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
