extends SceneTree
## 22b: K snaps a postcard: the view without the HUD on a deckled cream card with the caption and the 2¢ stamp,
## saved as paperfjord-day<N>.png (here into the folder of <out>), the size the page makes it.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.42
	main.postcard_dir = out.get_base_dir()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	main.input.pressed["KeyK"] = true
	t0 = Time.get_ticks_msec()
	while main.last_postcard == "" and Time.get_ticks_msec() - t0 < 5000: await process_frame
	var path: String = main.last_postcard
	var img := Image.load_from_file(path) if path != "" else null
	var vs := root.get_viewport().get_texture().get_size()
	var pad := roundi(minf(vs.x, vs.y) * 0.06)
	var want := Vector2i(int(vs.x) + pad * 2, int(vs.y) + pad + roundi(pad * 2.2))
	print("postcard: %s  size %s (want %s)" % [path, img.get_size() if img else Vector2i.ZERO, want])
	var ok := img != null and img.get_size() == want and path.get_file() == "cold-glitter-creek-day%d.png" % main.sky.day
	# the HUD is back after the snap
	ok = ok and main.hud.visible
	if img: img.save_png(out)
	print("POSTCARD TEST ", "PASS" if ok else "FAIL")
	quit()
