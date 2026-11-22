extends SceneTree
## Crafting: with 4 wood and 1 stone, the hammer is craftable by hand and the pickaxe is blocked (needs a workbench);
## crafting the hammer spends them and adds the tool; F eats a pie. Then a screenshot of the open panel.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	var c: Crafting = main.crafting
	main.inventory.wood = 10; main.inventory.stone = 3; main.inventory.pie = 1; main.inventory.fiber = 2
	var before := [c.blocked(c.by_id.hammer), c.blocked(c.by_id.pickaxe)]
	var made := c.craft("hammer")
	var after := [main.tools.has("hammer"), main.inventory.wood, main.inventory.stone, c.blocked(c.by_id.hammer)]
	main.player.fullness = 20.0
	main._eat()
	print("before %s  made %s  after %s  pie %d fullness %.0f" % [before, made, after, main.inventory.pie, main.player.fullness])
	var ok: bool = before[0] == "" and before[1] == "Needs a workbench" and made and after[0] and after[1] == 6 and after[2] == 2 and after[3] == "Made" and main.inventory.pie == 0 and main.player.fullness == 60.0
	print("CRAFT TEST ", "PASS" if ok else "FAIL")
	main._open_craft()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	quit()
