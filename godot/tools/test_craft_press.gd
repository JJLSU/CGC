extends SceneTree
## The crash the player hit: crafting the first few things from the panel. Each Craft press re-renders the panel from
## inside its own button's pressed signal; the old rows must go with queue_free, not free(). Opens the panel with
## plenty in the pack and presses Craft on the first four craftable recipes, a frame apart. Headless.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 30: await process_frame
	for k in ["wood", "stone", "fiber", "rope", "honey", "berries", "apples"]: main.inventory[k] = 40
	main._open_craft()
	await process_frame; await process_frame
	var made := []
	for n in 4:
		var btn: Button = null
		for b in main.panel.list.find_children("*", "Button", true, false):
			if b.text == "Craft" and not b.disabled and b.is_inside_tree(): btn = b; break
		if btn == null: break
		var before: Array = main.tools.keys()
		btn.pressed.emit()
		await process_frame; await process_frame
		made.append(main.tools.keys().filter(func(t): return not before.has(t)))
	print("crafted: %s" % [made])
	main._close_craft()
	await process_frame
	print("CRAFT PRESS TEST ", "PASS" if made.size() == 4 else "FAIL")
	quit()
