extends SceneTree
## The tinker's wagon (every other day, at the head of Main Street: E opens his wares), the County Fair (every
## seventh day: E opens the classes; an entry pins a rosette on the porch), Grandma Pell in the window of an evening
## (a pie at her door once a night; her wish for the day). Screenshots: the wagon (out), the fair (out_fair), the
## porch at night with her shadow and a rosette (out_grandma).

func _shot(path: String) -> void:
	for i in 50: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.4; main.sky.day = 2
	for i in 10: await process_frame
	var p: Player = main.player; var inv: Dictionary = main.inventory
	var TK: Tinker = main.tinker; var F: Fair = main.fair; var GM: Grandma = main.grandma
	var res := {}
	var press := func() -> void:
		main.input.pressed["KeyE"] = true
		for i in 3: await process_frame
	var stand := func(at: Vector3) -> void:
		p.pos = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z)
		for i in 3: await process_frame
	# the tinker, on an even day
	for i in 60: await process_frame
	res.tinker_here = TK.here and TK.visible
	var fw := TK.global_basis.z
	await stand.call(TK.pos + fw * 3.0)
	var tprompt: String = main.beast_prompt
	await press.call(); res.tinker_panel = main.panel.open and main.crafting.station_near.call("tinker"); main._close_craft()
	p.pos += fw * 3.0
	main.rig.dist = 14.0; main.rig.pitch = 0.5; main.rig.yaw = atan2(fw.x, fw.z) + 0.4; main.rig.snap()
	await _shot(out)
	# the fair, on the seventh day
	main.sky.day = 7
	for i in 3: await process_frame
	res.tinker_gone = not TK.here
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	var ff := F.global_basis.z
	await stand.call(F.at + ff * 2.0)
	var fprompt: String = main.beast_prompt
	await press.call(); res.fair_panel = main.panel.open; main._close_craft()
	inv.pie = 1; inv.ribbon = 0
	res.entered = main.crafting.craft("f-pie") and inv.ribbon == 1 and F.rosettes[0].visible and F.entered.has("f-pie")
	res.once = not main.crafting.craft("f-pie")
	p.pos += ff * 2.0
	main.rig.dist = 9.0; main.rig.pitch = 0.45; main.rig.yaw = atan2(ff.x, ff.z) + 0.3; main.rig.snap()
	await _shot(out.replace(".png", "_fair.png"))
	# Grandma of an evening
	main.sky.day = 8; main.sky.time = 0.85
	for i in 3: await process_frame
	res.fair_told = main.fair_told_day == 7
	await stand.call(GM.door)
	var gprompt: String = main.beast_prompt
	var pie0: int = inv.get("pie", 0)
	await press.call(); res.pie = inv.pie == pie0 + 1 and GM.pie_day == 8
	await press.call(); res.one_slice = inv.pie == pie0 + 1
	var wish := Grandma.wish_for(8)
	for k in wish.cost: inv[k] = wish.cost[k]
	await press.call(); res.wish = GM.wish_day == 8
	res.window = GM.pivot.visible
	var hf := Vector3(sin(GM.rotation.y), 0, cos(GM.rotation.y))
	p.pos = GM.door + hf * 5.0; p.pos.y = Terrain.get_height(p.pos.x, p.pos.z)
	main.rig.dist = 9.0; main.rig.pitch = 0.3; main.rig.yaw = GM.rotation.y + 0.2; main.rig.snap()
	await _shot(out.replace(".png", "_grandma.png"))
	print("player %s  window %s  door %s  house %s  facing %.2f  fair toast day %d" % [p.pos, GM.global_position, GM.door, main.homestead.house.global_position, GM.rotation.y, main.fair_told_day])
	print("prompts [%s] [%s] [%s]  rosette at %s" % [tprompt, fprompt, gprompt, F.rosettes[0].global_position])
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("VISITORS TEST ", "PASS" if ok else "FAIL")
	quit()
