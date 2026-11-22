extends SceneTree
## Prints the window, viewport and 3D render sizes (checking a --resolution run really renders at that size).
func _initialize() -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	print("window %s  root.size %s  visible %s  image %s  content_scale %s x%.2f  screen scale %.2f" % [DisplayServer.window_get_size(), root.size, root.get_visible_rect().size, img.get_size(), root.content_scale_size, root.content_scale_factor, DisplayServer.screen_get_scale()])
	quit()
