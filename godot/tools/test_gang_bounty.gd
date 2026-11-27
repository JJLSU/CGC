extends SceneTree
## The sheriff's reward for breaking up an outlaws' camp (the player's outlaws live with the claim jumpers): a camp
## cleared, the sheriff pays at the jail door, once; it's kept in the save. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45
	main._dev_town()
	for i in 10: await process_frame
	for b in main.bosses: b.bounty_paid = true # (no boss reward waiting first)
	main.jumpers.camps[1].cleared_day = main.sky.day
	main.inventory.dollars = 0
	var door: Vector3 = main.town.doors.jail
	for i in 10: main.player.pos = door; main.player.vel = Vector3.ZERO; await process_frame
	var prompt: String = main.beast_prompt
	main.input.pressed["KeyE"] = true
	for i in 5: main.player.pos = door; await process_frame
	var paid: int = main.inventory.get("dollars", 0)
	for i in 10: main.player.pos = door; await process_frame
	var again: String = main.beast_prompt
	main.save_all()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sp))
	print("prompt [%s]; paid $%d; then [%s]; saved %s" % [prompt, paid, again, saved.get("gangPaid")])
	var ok: bool = prompt.contains("outlaws' camp") and paid == 35 and not again.contains("outlaws' camp") and int(saved.get("gangPaid", [0, -1])[1]) == main.sky.day
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("GANG BOUNTY TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
