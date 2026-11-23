extends SceneTree
## 22d: F3 shows the renderer/fps badge and the time-of-day chips (a chip sets the clock), F4 and the +$500 button add
## $500, and a script error mid-game brings the "little tear in the paper" toast once while the game carries on.
## Screenshot: <out> (F3 on, the Night chip picked).

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _key(main: Node, k: String) -> void:
	main.input.pressed[k] = true
	await process_frame; await process_frame

func _boom() -> int:
	var a: Array = []
	return a[3] # (an out-of-bounds read: a script error)

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.42
	await _wait(2.0)
	var hud: Hud = main.hud
	var ok := hud.devcash.visible and not hud.backend.visible and not hud.times.visible and not hud.error_card.visible
	await _key(main, "F3")
	await _wait(1.3)
	ok = ok and hud.backend.visible and hud.times.visible and "fps" in hud.backend_label.text
	print("badge: '%s'" % hud.backend_label.text)
	hud.time_chips[3].pressed.emit()
	ok = ok and is_equal_approx(main.sky.time, 0.9)
	var d0: int = main.inventory.get("dollars", 0)
	await _key(main, "F4")
	hud.devcash.pressed.emit()
	ok = ok and main.inventory.get("dollars", 0) == d0 + 1000
	print("dollars %d -> %d" % [d0, main.inventory.get("dollars", 0)])
	_boom(); _boom()
	await _wait(0.5)
	ok = ok and main.tears == 2 and not hud.error_card.visible and hud.heard.any(func(h): return "little tear" in h)
	print("tears %d, toast %s" % [main.tears, hud.heard.any(func(h): return "little tear" in h)])
	await _wait(1.5)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	await _key(main, "F3")
	ok = ok and not hud.backend.visible
	print("DEV TEST ", "PASS" if ok else "FAIL")
	quit()
