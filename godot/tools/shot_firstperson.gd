extends SceneTree
## First person (V, the player's ask): through the farmer's eyes down Main Street with a 90-degree lens (<out>), the
## six-shooter in hand (<out>_gun.png), up on Biscuit (<out>_ride.png), and V again for the wide view (<out>_back.png).
## Prints the lens and where the eye sits. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	main._dev_town()
	var T: Town = main.town
	var at: Vector3 = T.at - T.along * 26.0
	for i in 60: main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); await process_frame
	main.rig.yaw = atan2(-T.along.x, -T.along.z); main.rig.pitch = 0.05
	main.input.pressed["KeyV"] = true
	for i in 40: main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); await process_frame
	var cam: Camera3D = main.rig.camera
	print("first person %s, fov %.0f, eye %.2f m above his feet" % [main.rig.first_person, cam.fov, cam.global_position.y - main.player.pos.y])
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	main.tools["revolver"] = true; main.pick_tool("revolver")
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_gun.png"))
	main.make_horse(at.x + 1.5, at.z); main.riding = true; main.player.riding = true; main.player.avatar.riding = true
	for i in 40: main.player.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); await process_frame
	print("mounted: eye %.2f m above the ground" % (cam.global_position.y - Terrain.get_height(at.x, at.z)))
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_ride.png"))
	main.input.pressed["KeyV"] = true
	for i in 20: await process_frame
	print("back: first person %s, fov %.0f" % [main.rig.first_person, cam.fov])
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_back.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
