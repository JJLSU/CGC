extends SceneTree
## The "Whole town" dev button (beside +$500): one press and every street is up, every building mended (Chinatown
## too), the bosses' prizes back; it doesn't touch your money. With a user arg <out.png> (windowed) a picture of the
## buttons. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 30: await process_frame
	var cash: int = main.inventory.get("dollars", 0)
	main.hud.devtown.pressed.emit()
	for i in 30: await process_frame
	var T: Town = main.town
	var ids := Town.BUILDINGS.map(func(b): return b.id) + ["church"]
	for st in Town.STREETS: ids.append_array(st.buildings.map(func(b): return b.id))
	var mended := ids.filter(func(id): return T.tiers.get(id, 0)).size()
	print("streets up %d of %d; mended %d of %d; dollars %d -> %d" % [T.opened.size(), Town.STREETS.size(), mended, ids.size(), cash, main.inventory.get("dollars", 0)])
	var ok: bool = T.opened.size() == Town.STREETS.size() and mended == ids.size() and main.inventory.get("dollars", 0) == cash
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(args[0])
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("DEV TOWN TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
