extends SceneTree
## Chops the nearest tree: faces it, holds the mouse down till it falls, then checks the wood came in, the tree is
## marked destroyed and set to regrow, and it fell over (the fall animation ran). Also picks a bush with E if one's
## close.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 90: await process_frame # (let the chunks pop up)
	var p: Player = main.player
	var best = null; var bd := INF
	for r in main.world.resources_near(p.pos.x, p.pos.z, 25.0):
		if r.type in ["pine", "maple", "goldtree", "birch", "sagetree"]:
			var d := Vector2(r.x - p.pos.x, r.z - p.pos.z).length()
			if d < bd: bd = d; best = r
	if best == null: print("no tree near"); quit(); return
	# stand 1.2 m off it, facing it (the camera behind)
	var dir := Vector2(best.x - p.pos.x, best.z - p.pos.z).normalized()
	p.pos = Vector3(best.x - dir.x * 1.3, Terrain.get_height(best.x - dir.x * 1.3, best.z - dir.y * 1.3), best.z - dir.y * 1.3)
	p.rig.yaw = atan2(-dir.x, -dir.y)
	var wood0: int = main.inventory.wood
	main.input.mouse_down = true
	var t0 := Time.get_ticks_msec()
	while best.alive and Time.get_ticks_msec() - t0 < 15000: await process_frame
	main.input.mouse_down = false
	for i in 80: await process_frame
	var got: int = main.inventory.wood - wood0
	print("tree %s felled: %s  wood +%d  destroyed: %s  regrow set: %s  hint: %s" % [best.type, not best.alive, got, main.world.destroyed.has(best.key), main.world.regrow.has(best.key), main.hud.hint_label.text.replace("\n", " / ")])
	var ok: bool = not best.alive and got >= 2 and main.world.destroyed.has(best.key) and main.world.regrow.has(best.key)
	print("GATHER TEST ", "PASS" if ok else "FAIL")
	quit()
