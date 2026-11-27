extends SceneTree
## The double-barrel shotgun at the general store: bought for $40 (with a box of shells), it holds two, the farmer
## carries the Meshy shotgun model, the tool bar names it, and one shot throws five pellets. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 10: await process_frame
	var C = main.crafting
	main.inventory.dollars = 100
	C.station_near = func(_s) -> bool: return true # (as if at the store counter)
	var bought: bool = C.craft("shotgun")
	main.pick_tool("shotgun")
	for i in 10: await process_frame
	var av: Avatar = main.player.avatar
	var name: String = main.hud._tool_name("shotgun", main.tools)
	var before: int = main.hunting.arrows.size()
	main.hunting.charge = 1.0; main.hunting.aim_dir = main.player.forward()
	var shot: bool = main.hunting.loose(main.player.pos + Vector3(0, 1.45, 0), main.critters, Hunting.SHOTGUN)
	var pellets: int = main.hunting.arrows.size() - before
	print("bought %s ($%d left, %d cartridges); held %s; barrels %d; model %s; tool bar [%s]; pellets %d" % [bought, main.inventory.dollars, main.inventory.get("cartridges", 0), main.held, main.guns.shotgun.size, av._made_on != null and av._made_on == av.made.get("shotgun"), name, pellets])
	var ok: bool = bought and main.inventory.dollars == 60 and main.held == "shotgun" and main.guns.shotgun.size == 2 and av._made_on == av.made.get("shotgun") and av._made_on != null and name == "Shotgun" and shot and pellets == 5
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("SHOTGUN TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
