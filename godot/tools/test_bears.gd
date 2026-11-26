extends SceneTree
## The bears (the player's black bear and grizzly): a grove keeper each, standing on the ground on their own models,
## coming for you when you go in close, and landing a blow. With a user arg <out.png> (windowed) a picture of the
## two side by side. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	for i in 20: await process_frame
	var E: Enemies = main.enemies; var p: Player = main.player
	var base: Vector3 = main.spawn - (main.town.at - main.spawn).normalized() * 45.0 # (away from town)
	base.y = 0
	var ok := true
	var args := OS.get_cmdline_user_args()
	var spawned := []
	for kind in ["bear", "grizzly"]:
		var at: Vector3 = base + (Vector3(0, 0, 0) if kind == "bear" else Vector3(9, 0, 0))
		var site := {"key": "test:%s" % kind, "kind": "grove", "guard": kind, "guards": 1, "x": at.x, "z": at.z}
		E.spawn_site(site)
		var e: Dictionary = E.list.filter(func(x): return x.site.key == site.key)[0]
		spawned.append(e)
		print("%s: own model %s" % [e.spec.name, e.puppet.model != null])
		ok = ok and e.puppet.model != null
	if args.size() > 0:
		for i in 40: p.pos = base + Vector3(4.5, 0, 12); await process_frame
		main.set_process(false); p.avatar.root.visible = false
		var cam: Camera3D = main.rig.camera
		cam.global_position = base + Vector3(4.5, Terrain.get_height(base.x, base.z) + 3.0 - base.y, 9.0); cam.look_at(base + Vector3(4.5, Terrain.get_height(base.x, base.z) + 0.9 - base.y, 0), Vector3.UP); cam.fov = 50.0
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
		main.set_process(true); cam.fov = 30.0
	for e in spawned:
		var hp0 := p.health; p.health = p.max_health; hp0 = p.health
		var t0 := Time.get_ticks_msec()
		var gp: Vector3 = e.puppet.group.position
		while Time.get_ticks_msec() - t0 < 12000 and p.health >= hp0:
			p.pos = gp + Vector3(2.5, 0, 0); p.pos.y = Terrain.get_height(p.pos.x, p.pos.z); p.dead = false
			await process_frame
		print("%s: came at you and hit for %.0f" % [e.spec.name, hp0 - p.health])
		ok = ok and p.health < hp0
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("BEARS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
