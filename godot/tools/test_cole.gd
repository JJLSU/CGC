extends SceneTree
## Cottonmouth Cole, the outlaw gang's boss: his hideout out past town; come close and he fights, shooting (each shot a
## bullet flying flat to a mark on the ground); beaten, the stolen payroll drops; handed in at the assay office it pays
## $200 and breaks the gang: no train robbery comes after that. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.42
	var C: Boss = main.bosses.filter(func(b): return b.id == "cole")[0]
	var known_before: bool = main._boss_known(C)
	main._dev_town() # (every street built: word comes of Cole, his poster goes up)
	for i in 5: await process_frame
	var told: bool = main.cole_told and main.boss_board != null
	print("known before the streets %s; word come and poster up %s" % [known_before, told])
	print("Cole's hideout %.0f m from town; %d bosses" % [Vector2(C.at.x - main.town.at.x, C.at.z - main.town.at.z).length(), main.bosses.size()])
	var dir: Vector3 = (main.town.at - C.at).normalized(); var off: Vector3 = C.at + dir * 16.0
	var shots := 0; var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		main.player.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z); main.player.health = main.player.max_health; main.player.dead = false
		shots = maxi(shots, C.picks.size() + (1 if C.throws > 0 else 0))
		await process_frame
	var gone: int = C.gang.filter(func(g): return g.mounted and Vector2(g.horse.group.position.x - C.at.x, g.horse.group.position.z - C.at.z).length() > 20.0).size()
	print("fighting %s, threw %d, bullets in the air seen %d; his gang %d, ridden off %d" % [C.fighting(), C.throws, shots, C.gang.size(), gone])
	while C.alive(): C.damage(10, C.hooks)
	for i in 30: await process_frame
	var payroll = main.drops.filter(func(d): return d.loot.has("payroll"))
	print("beaten %s, the payroll lying %d" % [C.beaten, payroll.size()])
	main.inventory.payroll = 1; for d in payroll: (d.node as Node3D).queue_free(); main.drops.erase(d)
	var before: int = main.inventory.get("dollars", 0)
	main._hand_in(C)
	var pay: int = main.inventory.get("dollars", 0) - before
	# a run out on the line with you aboard and armed: no robbers now
	main.railroad.build(); main.tools["revolver"] = true
	main.train.passenger = true; main.train.state = "run"; main.train.leg = 0; main.train.s = main.train.home_s() + 200.0
	for k in 20: main.rob_run = false; main.robbers.last_day = -99; main._robbers_update(0.016)
	print("handed in: +$%d, gang broken %s, robbers came %s, rank '%s'" % [pay, main.gang_broken(), main.robbers.active, main.town_rank()])
	var ok: bool = C.gang.size() == 2 and gone == 2 and not known_before and told and main.bosses.size() == 4 and C.throws > 0 and C.beaten and payroll.size() == 1 and pay == 200 and main.gang_broken() and not main.robbers.active
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("COLE TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
