extends SceneTree
## The HUD with something in it: a couple of notes, a hint, some goods, the pack open, a few tools.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.inventory.wood = 12; main.inventory.stone = 5; main.inventory.gold = 3; main.inventory.berries = 7; main.inventory.rope = 2; main.inventory.pie = 1
	main.tools["pickaxe"] = true; main.tools["rod"] = true
	main.player.stamina = 80.0; main.player.health = 70.0
	main.hud.pack.visible = true
	main.hud.set_next("Build a workbench (B) by the cabin")
	main.hud.toast("+3 wood")
	main.hud.toast("You came west chasing a gold rumour. Something glints by the cabin...")
	for i in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	quit()
