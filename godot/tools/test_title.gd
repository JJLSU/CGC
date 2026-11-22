extends SceneTree
## 22a: the title card (#overlay) at the start, "Click to resume" once the mouse is taken and let go, Escape folding
## it into the pause note (#peek) and back, the New game confirm card, and the crosshair in build mode. Screenshots:
## <out>_title.png (the card), <out>_peek.png (the pause note), <out>_confirm.png.

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _esc(main: Node) -> void:
	var e := InputEventKey.new(); e.physical_keycode = KEY_ESCAPE; e.keycode = KEY_ESCAPE; e.pressed = true
	main._unhandled_input(e)

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.weather.rain = 0.0; main.sky.time = 0.4
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await process_frame
	var hud: Hud = main.hud
	var ok := hud.overlay.visible and hud.overlay_on and hud.cta.text == "Click to begin" and not hud.peek.visible
	print("at the start: card %s, cta '%s'" % [hud.overlay.visible, hud.cta.text])
	await _shot(out.replace(".png", "_title.png"))
	# taken and let go (as the input would report it)
	main.input.on_lock_change.call(true)
	await _wait(0.6)
	ok = ok and not hud.overlay.visible
	main.input.on_lock_change.call(false)
	await _wait(0.6)
	ok = ok and hud.overlay.visible and hud.cta.text == "Click to resume"
	print("let go: card %s, cta '%s'" % [hud.overlay.visible, hud.cta.text])
	main.lock_changed_at = 0
	_esc(main)
	await _wait(0.6)
	ok = ok and not hud.overlay.visible and hud.peek.visible
	print("Esc: card %s, peek %s" % [hud.overlay.visible, hud.peek.visible])
	await _shot(out.replace(".png", "_peek.png"))
	_esc(main)
	await _wait(0.6)
	ok = ok and hud.overlay.visible and not hud.peek.visible
	hud.newgame_btn.pressed.emit()
	for i in 5: await process_frame
	ok = ok and hud.confirm_card.visible
	await _shot(out.replace(".png", "_confirm.png"))
	hud.confirm_card.visible = false
	# tests: force_active folds the card away at once
	main.force_active = true
	await process_frame; await process_frame
	ok = ok and not hud.overlay.visible
	main.tools["hammer"] = true; main.build.active = true
	await process_frame; await process_frame
	ok = ok and hud.crosshair.visible
	print("force_active: card %s; building: crosshair %s" % [hud.overlay.visible, hud.crosshair.visible])
	print("TITLE TEST ", "PASS" if ok else "FAIL")
	quit()
