extends SceneTree
## The game's first seconds (the start made quicker: only the nine chunks round the farm built up front, the rest
## streamed in fast behind the title): the view at 1 s (<out>_1) and 4 s (<out>_4), and how many chunks are in.
## Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	for sec in [1, 4]:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < (1000 if sec == 1 else 3000): await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % sec))
		print("at %d s: %d chunks, boost %s" % [sec, main.world.chunks.size(), main.world.boost])
	quit()
