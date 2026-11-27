extends SceneTree
## The rail line and the train are drawn only over the built ground (never hanging over the flat sheet out past it): every
## piece of the line and each car marked near_only, and the reach the shaders cut at follows the farmer. Headless.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main._dev_town(); main.railroad.build()
	for i in 5: await process_frame
	var geo: Array = main.railroad.find_children("*", "GeometryInstance3D", true, false) + main.train.find_children("*", "GeometryInstance3D", true, false)
	var marked: int = geo.filter(func(g): return float((g as GeometryInstance3D).get_instance_shader_parameter("near_only")) > 0.5).size()
	var r: Vector4 = Vector4(main.world.ground.position.x, main.world.ground.position.z, (World.VIEW_RADIUS - 0.1) * Terrain.CHUNK, 0.0) # (the reach World hands the shaders each frame; a headless server keeps no globals to read back)
	var p: Vector3 = main.player.pos
	for g in geo: if float((g as GeometryInstance3D).get_instance_shader_parameter("near_only")) < 0.5: print("  unmarked: %s (%s) under %s" % [g.name, g.get_class(), g.get_parent().name])
	print("rail and train pieces %d, near_only %d; reach centred %.1f m from the farmer, radius %.0f m" % [geo.size(), marked, Vector2(r.x - p.x, r.y - p.z).length(), r.z])
	var ok: bool = geo.size() > 0 and marked == geo.size() and Vector2(r.x - p.x, r.y - p.z).length() < 2.0 and r.z > 60.0 and r.z < 120.0
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("RAIL NEAR ONLY TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
