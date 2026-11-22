extends SceneTree
## 23e: the panels side by side with the web. The web game's Day 32 save (assets/baked/compare/web_save_day32.json)
## loaded, noon, and the pack (I), crafting (C), the almanac (H) and settlers & works (J) opened in turn; each is
## saved as <out>_<name>.png and its text printed, to set beside the web's.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _text(n: Node) -> String:
	var out := []
	for c in n.find_children("*", "", true, false):
		if c is Label and c.is_visible_in_tree() and c.text != "": out.append(c.text)
		elif c is Button and c.is_visible_in_tree() and c.text != "": out.append("[" + c.text + "]")
		elif c is RichTextLabel and c.is_visible_in_tree(): out.append(c.get_parsed_text())
	return " | ".join(out)

func _key(main: Node, k: String) -> void:
	main.input.pressed[k] = true
	await process_frame; await process_frame

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var copy := "user://compare_save.json"
	var f := FileAccess.open(copy, FileAccess.WRITE); f.store_string(FileAccess.get_file_as_string("res://assets/baked/compare/web_save_day32.json")); f.close()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.save_path = copy; main.saving = true
	root.add_child(main)
	await process_frame
	main.saving = false # (nothing written back)
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.5
	await _wait(3.0)
	var hud: Hud = main.hud
	for pass_ in [["pack", "KeyI", hud.pack], ["craft", "KeyC", null], ["almanac", "KeyH", hud.calendar], ["settlers", "KeyJ", null]]:
		await _key(main, pass_[1])
		await _wait(0.8)
		var node: Node = pass_[2] if pass_[2] != null else (main.panel.card if pass_[0] == "craft" else main.settlers_card)
		print("=== %s (visible %s, ledger %s)\n%s" % [pass_[0], node.visible, hud.ledger.is_visible_in_tree(), _text(node)])
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % pass_[0]))
		await _key(main, pass_[1])
		await _wait(0.4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))
	quit()
