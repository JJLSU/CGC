extends SceneTree
## Quaternius's clips on the Meshy folk, side by side: a townsman and a townswoman each playing the model's own walk
## and idle beside the library's Walk, Walk_Formal, Idle_Talking, Sitting_Idle, Interact (<out>_0, <out>_1 a beat later).
## Windowed; CGC_SAVE_PATH a throwaway.
const CLIPS := ["walk", "u_Walk", "u_Walk_Formal", "u_Idle_Talking", "u_Sitting_Idle", "u_Interact"]
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42; main.weather.rain = 0.0
	var p: Vector3 = main.player.pos
	var figs := []
	var who: String = OS.get_environment("UAL_WHO") if OS.get_environment("UAL_WHO") != "" else "cgc_man_suspenders"
	for i in CLIPS.size():
		var f := ModelFigure.new(who)
		var t0 := Time.get_ticks_usec()
		var ok := f.add_ual(["Walk", "Walk_Formal", "Idle_Talking", "Sitting_Idle", "Interact"])
		if i == 0: print("ual added %s in %d ms" % [ok, (Time.get_ticks_usec() - t0) / 1000])
		var q := p + Vector3(-4.5 + i * 1.8, 0, 1.2); q.y = Terrain.get_height(q.x, q.z)
		f.root.position = q; f.root.rotation.y = PI / 2.0; main.add_child(f.root); figs.append(f)
		f.play(CLIPS[i], 0.0)
	for n in 2:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < (2500 if n == 0 else 600):
			main.player.avatar.root.visible = false
			main.rig.yaw = PI; main.rig.pitch = 0.12; main.rig.dist = 7.5
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % n))
	quit()
