extends SceneTree
## The fort's Gatling gun inside the gate, and a sentry with his rifle, close up (<out>_gun.png, <out>_sentry.png).
## Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	var f: Dictionary = main.forts.forts[0]
	var fz := Vector3(sin(f.face), 0, cos(f.face)); var fx := Vector3(fz.z, 0, -fz.x)
	var gate: Vector3 = f.at + fz * (ArmyForts.SIDE / 2.0)
	for i in 120: main.player.pos = gate + fz * 6.0; await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	var gun: Vector3 = f.at + fx * 6.0 + fz * 13.0; var gy := Terrain.get_height(gun.x, gun.z)
	cam.global_position = Vector3(gun.x, gy, gun.z) - fz * 4.0 - fx * 2.5 + Vector3(0, 2.4, 0); cam.look_at(Vector3(gun.x, gy + 0.6, gun.z), Vector3.UP); cam.fov = 50.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_gun.png"))
	var sentry = null
	for m in f.men: if m.role == "sentry": sentry = m; break
	if sentry:
		var sp2: Vector3 = sentry.fig.root.global_position
		cam.global_position = sp2 + fz * 2.6 + fx * 1.2 + Vector3(0, 1.5, 0); cam.look_at(sp2 + Vector3(0, 1.1, 0), Vector3.UP)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_sentry.png"))
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
