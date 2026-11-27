extends SceneTree
## A boss back for a rematch greets you with a line of his own ("You again!"), not his first-meeting one. Headless.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	var B: Boss = main.bosses[0]
	var near: Vector3 = B.at + (main.town.at - B.at).normalized() * 40.0
	for i in 60: main.player.pos = Vector3(near.x, Terrain.get_height(near.x, near.z), near.z); await process_frame
	B.say("spot", true); var first: String = B.say_card.text
	B.returns = 1; B.say("spot", true); var again: String = B.say_card.text
	print("first meeting: '%s'; rematch: '%s'" % [first, again])
	var ok: bool = first in Boss.TAUNTS.jebediah.spot and again in Boss.AGAIN.jebediah
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("BOSS AGAIN TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
