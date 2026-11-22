extends SceneTree
## The mail (the flag springs up mid-morning from Day 2; E reads the letter, the gift comes with it), tall tales by
## a campfire after dark (an hour passes, the fire mends you, the tale counts), the journal's day log read back by the
## almanac when you sleep, and the Farmer's Almanac card (H). Screenshots: the letter by the mailbox (out), a tale
## (out_tale), the almanac's day (out_almanac), the H card (out_cal).

func _shot(path: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	main.weather.rain = 0.0; main.sky.time = 0.3; main.sky.day = 1
	for i in 10: await process_frame
	var p: Player = main.player; var inv: Dictionary = main.inventory; var M: Mail = main.mail; var hud: Hud = main.hud
	if main.glint != null: main.glint.queue_free(); main.glint = null # (out of the way)
	var res := {}
	var press := func(key := "KeyE") -> void:
		main.input.pressed[key] = true
		for i in 3: await process_frame
	# the mail: nothing on day 1; the flag up on day 2 at 09:00
	main.sky.time = 0.4
	for i in 3: await process_frame
	res.no_mail_day1 = not M.waiting
	main.sky.day = 2
	for i in 30: await process_frame
	res.flag_up = M.waiting and M.flag != null and absf(M.flag.basis.get_euler().x - M._rest.get_euler().x) < 0.4
	p.pos = Vector3(M.at.x + 1.0, Terrain.get_height(M.at.x + 1.0, M.at.z + 0.6), M.at.z + 0.6)
	for i in 3: await process_frame
	var mprompt: String = main.beast_prompt
	inv.rope = 0
	await press.call()
	res.letter = main.story_kind == "letter" and hud.story.visible and inv.rope == 2 and main.journal.day_log.has("letter")
	main.rig.dist = 7.0; main.rig.pitch = 0.5; main.rig.yaw = 0.6; main.rig.snap()
	await _shot(out)
	await press.call(); res.letter_folded = not hud.story.visible
	# a tall tale by a campfire after dark
	var fx: float = p.pos.x + 6.0; var fz: float = p.pos.z + 4.0
	main.build.add({"type": "campfire", "x": fx, "y": Terrain.get_height(fx, fz), "z": fz, "rot": 0.0}, true)
	main.sky.time = 0.85; p.health = 50.0
	p.pos = Vector3(fx + 1.5, Terrain.get_height(fx + 1.5, fz), fz)
	for i in 5: await process_frame
	var t0: float = main.sky.time
	await press.call()
	res.tale = main.story_kind == "tale" and main.tales.heard.size() == 1 and p.health >= 69.0 and main.sky.time > t0 + 0.03 and main.journal.day_log.get("tale", 0) == 1
	await _shot(out.replace(".png", "_tale.png"))
	await press.call(); res.tale_closed = not hud.story.visible
	# the almanac at bedtime (away from the fire)
	p.pos = Vector3(fx + 12.0, Terrain.get_height(fx + 12.0, fz), fz)
	for i in 3: await process_frame
	main.journal.record("chop"); main.journal.record("chop"); main.journal.record("craft:hammer"); main.journal.record("build:workbench")
	main._show_almanac(2)
	res.almanac = main.story_kind == "almanac" and hud.story.visible and main.journal.day_log.is_empty()
	await _shot(out.replace(".png", "_almanac.png"))
	await press.call(); res.almanac_closed = not hud.story.visible
	# the almanac card (H)
	main.sky.time = 0.4
	await press.call("KeyH"); res.calendar = hud.calendar.visible
	await _shot(out.replace(".png", "_cal.png"))
	await press.call("KeyH"); res.calendar_closed = not hud.calendar.visible
	print("mail prompt [%s]" % mprompt)
	print(res)
	var ok: bool = res.values().all(func(v): return v)
	print("JOURNAL TEST ", "PASS" if ok else "FAIL")
	quit()
