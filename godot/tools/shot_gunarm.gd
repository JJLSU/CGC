extends SceneTree
## Shooters raise their gun hand at you (the player's ask): an outlaw of the hold-up gang caught as he fires (<out>), and
## Cottonmouth Cole the same (<out>_cole.png). Prints the arm's lift. Windowed; a throwaway save.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var at: Vector3 = main.spawn + Vector3(14, 0, 10)
	main.jumper_hooks.on_hit = func(_d: int) -> void: pass
	var fired := [null]
	var base: Callable = main.jumper_hooks.on_shoot
	main.jumper_hooks.on_shoot = func(q: Vector3) -> void: fired[0] = q; base.call(q)
	main.jumpers.start_raid(Vector3(at.x, Terrain.get_height(at.x, at.z), at.z), 4)
	for m in main.jumpers.raid.men: m.angry = true
	var me := at + Vector3(-12, 0, 4)
	var t0 := Time.get_ticks_msec(); var got := false
	while Time.get_ticks_msec() - t0 < 15000:
		main.player.pos = Vector3(me.x, Terrain.get_height(me.x, me.z), me.z); main.player.health = 100
		if fired[0] != null:
			for i in 6: main.player.pos = Vector3(me.x, Terrain.get_height(me.x, me.z), me.z); await process_frame
			var sh: Vector3 = fired[0]
			main.rig.yaw = atan2(me.x - sh.x, me.z - sh.z) + 1.3; main.rig.dist = 5.0; main.rig.pitch = 0.12
			var g = null
			for m in main.jumpers.raid.men: if m.fig.root.position.distance_to(sh) < 0.5: g = m
			main.rig.target_node = g.fig.root if g else main.player.avatar.root; main.rig.snap()
			for i in 2: await process_frame
			var aa = AimArm.on(g.fig) if g else null
			print("a gunman fired; his arm up %.2f" % (aa.w if aa else -1.0))
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out)
			got = true; break
		await process_frame
	print("caught one firing: %s" % got)
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	quit()
