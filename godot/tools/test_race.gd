extends SceneTree
## The horse race: the course laid out (six flags on dry, open ground round a loop off the south end of town, the post
## the start and finish); Dusty Jake at the post; on foot he only talks; mounted, E takes the $5 stake and counts down;
## galloping the flags in turn beats him ($10 back); sitting still, he wins. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45
	var R: HorseRace = main.race
	var bad: int = R._bad(R.flags)
	var span := 0.0
	for f in R.flags: span = maxf(span, Vector2(f.x - R.start.x, f.z - R.start.z).length())
	print("course: %d flags, %.0f m round, %d bad samples, farthest flag %.0f m from the post; post %.0f m from town" % [R.flags.size(), R.cum[-1], bad, span, R.start.distance_to(main.town.at)])
	main.inventory.dollars = 20
	for i in 5: main.player.pos = R.start; await process_frame
	var hail: String = R.say_card.text if R.say_card else ""
	print("Jake hails you on foot: '%s'" % hail)
	main.input.pressed["KeyE"] = true; await process_frame
	var on_foot_state: String = R.state
	main.make_horse(R.start.x + 2, R.start.z); main.riding = true; main.player.riding = true; main.player.avatar.riding = true
	for i in 5: main.player.pos = R.start; await process_frame
	main.input.pressed["KeyE"] = true; await process_frame
	var began: bool = R.state == "count" and main.inventory.dollars == 15
	for i in 400:
		if R.state == "run": break
		main.player.pos = R.start; await process_frame
	# race 1: gallop flag to flag, a touch faster than he rides
	var course: Array = R.flags + [R.start]; var k := 0; var p: Vector3 = R.start
	var t0 := Time.get_ticks_msec()
	while R.state == "run" and Time.get_ticks_msec() - t0 < 120000:
		var dt := get_root().get_process_delta_time() if false else 0.016
		var tgt: Vector3 = course[mini(k, course.size() - 1)]
		var d := Vector3(tgt.x - p.x, 0, tgt.z - p.z)
		p += d.normalized() * minf(d.length(), 19.0 * maxf(0.001, main.get_process_delta_time()))
		if d.length() < 1.0: k += 1
		p.y = Terrain.get_height(p.x, p.z); main.player.pos = p
		await process_frame
	print("Jake's last word: '%s' (card %s, wins %d, state %s)" % [R.say_card.text if R.say_card else "-", R.say_card != null, R.wins, R.state])
	var said: bool = R.say_card.text in R.JAKE_LINES.lost
	var won1: bool = said and R.wins == 1 and main.inventory.dollars == 25
	print("race 1: began %s, won %s ($%d), on foot it stayed %s" % [began, won1, main.inventory.dollars, on_foot_state])
	while R.state != "idle": main.player.pos = R.start; await process_frame # (he's back at the post)
	# race 2: sit at the post: Jake wins
	main.input.pressed["KeyE"] = true; await process_frame
	t0 = Time.get_ticks_msec()
	while (R.state == "run" or R.state == "count") and Time.get_ticks_msec() - t0 < 120000:
		main.player.pos = R.start + Vector3(0, 0, 0.5); await process_frame
	var lost2: bool = R.wins == 1 and main.inventory.dollars == 15 and R.state == "done" # (the stake doubled to $10 after his first loss)
	print("race 2 (sat still): lost %s ($%d), Jake's next %d" % [lost2, main.inventory.dollars, R.jake_next])
	var ok: bool = hail in R.JAKE_LINES.hail_foot and R.flags.size() == 6 and bad < 6 and on_foot_state == "idle" and began and won1 and lost2
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("RACE TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
