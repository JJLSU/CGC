extends SceneTree
## Step 26: the county map (M), a tall tale and a letter on the story card, and the crafting panel (C), from the web's
## Day 32 save, as the web was captured; each saved as <out>_<name>.png with its rect printed beside the web's.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _shot(out: String, nm: String, c: Control) -> void:
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % nm))
	var r := c.get_global_rect()
	print("%s: %d %d %d %d" % [nm, r.position.x, r.position.y, r.size.x, r.size.y])

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var copy := "user://compare_save.json"
	var f := FileAccess.open(copy, FileAccess.WRITE); f.store_string(FileAccess.get_file_as_string("res://assets/baked/compare/web_save_day32.json")); f.close()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.save_path = copy; main.saving = true
	root.add_child(main)
	await process_frame
	main.saving = false
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.sky.time = 0.5
	await _wait(3.0)
	var hud: Hud = main.hud
	main.input.pressed["KeyM"] = true
	await _wait(2.0)
	await _shot(out, "map", hud.map_card)
	main.input.pressed["KeyM"] = true; await _wait(0.3)
	var tl: Dictionary = Tales.TALES[0]
	hud.story_show(tl.title, [tl.text], [], "1 of %d tall tales heard · E to stir the fire and close" % Tales.TALES.size())
	await _shot(out, "tale", hud.story)
	var L: Dictionary = Mail.LETTERS[0]
	hud.story_show("A letter from " + L.from, [L.text], [], "Folded inside: %s · E to fold it away" % L.note)
	await _shot(out, "letter", hud.story)
	hud.story_hide()
	main.input.pressed["KeyC"] = true
	await _shot(out, "craft", main.panel.card)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))
	quit()
