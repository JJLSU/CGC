extends SceneTree
## The lever-action rifle at the general store: offered only once you own the buffalo rifle; bought, it holds seven
## rounds, the farmer carries the repeater's own model, and the tool bar names it. Headless; CGC_SAVE_PATH a throwaway.
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
	var r: Dictionary = C.recipes.filter(func(x): return x.id == "s-leverrifle")[0] if C.get("recipes") != null else {}
	main.inventory.dollars = 200
	var why_before: String = C.blocked(r)
	main.tools["rifle"] = true
	C.station_near = func(_s) -> bool: return true # (as if at the store counter)
	var bought: bool = C.craft("s-leverrifle"); main.held = "rifle"
	for i in 10: await process_frame
	var av: Avatar = main.player.avatar
	var name: String = main.hud._tool_name("rifle", main.tools)
	print("bought %s ($%d left)" % [bought, main.inventory.dollars])
	print("before the buffalo rifle: [%s]; magazine %d; model %s; tool bar [%s]" % [why_before, main.guns.rifle.size, av.made.has("rifle_lever") and av._made_on == av.made.rifle_lever, name])
	var ok: bool = why_before != "" and bought and main.guns.rifle.size == 7 and av._made_on == av.made.get("rifle_lever") and name == "Lever-action rifle"
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("LEVER TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
