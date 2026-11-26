extends SceneTree
## The menu on the title card (the port's own, asked for by the player): Save game, Options, New game, Quit; the
## options card (display, vsync, interface size, graphics, depth of field, sound) cycling its values; and the new
## name, Cold Glitter Creek, on the card. Screenshots: <out>_card.png, <out>_options.png.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.weather.rain = 0.0; main.sky.time = 0.42
	await _wait(3.0)
	var hud: Hud = main.hud
	var ok := hud.overlay.visible and hud.save_btn != null and hud.quit_btn != null and main.get_window().title.begins_with("Cold Glitter Creek")
	print("window title '%s'" % main.get_window().title)
	await _shot(out.replace(".png", "_card.png"))
	hud.save_btn.pressed.emit()
	ok = ok and hud.save_btn.text != "Save game"
	print("save: '%s'" % hud.save_btn.text)
	hud._refresh_options(); hud.options_card.visible = true
	var before := {}
	for id in hud.option_buttons: before[id] = hud.option_buttons[id].text
	for id in ["vsync", "ui", "quality", "dof", "sound"]: hud.option_buttons[id].pressed.emit()
	var after := {}
	for id in hud.option_buttons: after[id] = hud.option_buttons[id].text
	print("options before %s\n        after  %s" % [before, after])
	for id in ["vsync", "ui", "quality", "dof", "sound"]: ok = ok and before[id] != after[id]
	ok = ok and is_equal_approx(root.content_scale_factor, 1.25)
	await _wait(0.5)
	await _shot(out.replace(".png", "_options.png"))
	print("MENU TEST ", "PASS" if ok else "FAIL")
	quit()
