extends SceneTree
## Build mode: with a hammer and wood, place a workbench a few metres ahead, then a campfire beside it, a floor and
## a wall; check costs spent, the workbench station answers the crafting panel, the wall blocks walking, and take a
## screenshot once they've risen.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 60: await process_frame
	main.tools["hammer"] = true
	main.inventory.wood = 40; main.inventory.stone = 10
	var b: BuildSystem = main.build
	var p: Player = main.player
	var f := p.forward()
	var put := func(t: String, at: Vector3, r := 0) -> Dictionary:
		b.selected = BuildSystem.ORDER.find(t)
		var pl := b.snap({"point": at, "normal": Vector3.UP, "piece": null, "dist": 5.0})
		pl.rot = r if t != "roof" else pl.rot
		pl.reason = b.validate(pl, main.inventory, p.pos); pl.valid = pl.reason == ""
		b.preview = pl
		var msg := b.place(main.inventory)
		return {"t": t, "msg": msg}
	var base := p.pos + f * 5.0
	var r1: Dictionary = put.call("workbench", base)
	var r2: Dictionary = put.call("campfire", base + Vector3(2.5, 0, 0))
	var r3: Dictionary = put.call("floor", base + Vector3(-4, 0, 3))
	var r4: Dictionary = put.call("wall", base + Vector3(-4, 0, 4))
	var crafted: String = main.crafting.blocked(main.crafting.by_id.pickaxe)
	print([r1.msg, r2.msg, r3.msg, r4.msg], " wood left ", main.inventory.wood, " pickaxe now: ", crafted)
	# walk into the wall
	var wall: Dictionary = b.pieces[3]
	var probe := Vector3(wall.x, wall.y + 0.5, wall.z)
	var pushed := b.collide(probe)
	print("wall at ", Vector2(wall.x, wall.z), " probe pushed to ", Vector2(pushed.x, pushed.z))
	var ok: bool = r1.msg == "Built workbench" and r2.msg == "Built campfire" and r3.msg == "Built floor" and r4.msg == "Built wall" and main.inventory.wood == 40 - 8 - 2 - 2 - 3 and crafted == "Need more" and Vector2(pushed.x - wall.x, pushed.z - wall.z).length() > 0.1
	print("BUILD TEST ", "PASS" if ok else "FAIL")
	main.rig.dist = 16.0; main.rig.pitch = 0.6
	for i in 120: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	quit()
