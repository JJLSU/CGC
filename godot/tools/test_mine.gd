extends SceneTree
## Your claim's mine (the player's mine kit): walk in at the portal and along the drifts to the face; at the face the
## prompt offers to work the vein; the rich vein shows till you've dug today, then the worked-out face; the drift's
## open side stops you stepping out of it. Headless; CGC_SAVE_PATH a throwaway.
func _walk(main: Node, g: Node3D, a: Vector3, b: Vector3, sec: float) -> Vector3:
	var p: Player = main.player
	var wa: Vector3 = g.global_transform * a; var wb: Vector3 = g.global_transform * b
	p.pos = Vector3(wa.x, Terrain.get_height(wa.x, wa.z), wa.z); p.vel = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		var dir := Vector3(wb.x - p.pos.x, 0, wb.z - p.pos.z)
		if dir.length() < 0.4: break
		main.rig.yaw = atan2(-dir.x, -dir.z); main.input.keys["KeyW"] = true
		await process_frame
	main.input.keys.erase("KeyW")
	return g.global_transform.affine_inverse() * p.pos
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45; main.weather.rain = 0.0
	main._dev_town(); main.railroad.build(); main.tools["claim"] = true; main.tools["pickaxe"] = true; main.claim.build()
	var C: Claim = main.claim; var g: Node3D = C.group
	for i in 10: await process_frame
	var p1: Vector3 = await _walk(main, g, Vector3(-3, 0, 0), Vector3(-22.4, 0, 0), 9.0)
	print("walked in from the portal to x %.1f (the face's spot %.1f)" % [p1.x, Claim.MINE_DIG.x])
	for i in 5: await process_frame
	var prompt: String = main.beast_prompt
	var rich_before: bool = C.vein_rich.visible
	main.input.pressed["KeyE"] = true
	for i in 5: await process_frame
	var worked: bool = C.vein_worked.visible and not C.vein_rich.visible
	var p2: Vector3 = await _walk(main, g, Vector3(-21.0, 0, 0), Vector3(-21.0, 0, 6.0), 3.0)
	print("prompt at the face [%s]; rich vein before %s, worked face after %s; tried to step out of the drift: got to z %.1f (its side at 1.45)" % [prompt, rich_before, worked, p2.z])
	var ok: bool = p1.x < -20.5 and prompt.contains("claim") and rich_before and worked and p2.z < 1.4
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("MINE TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
