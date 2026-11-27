extends SceneTree
## The train robbers: with you aboard well out on the line, a gang gallops up from behind and rides alongside the open
## car (within reach of a pistol), firing; shot down, they fall; once she turns for home they're gone, and the
## bounty is paid at the depot. Also: the hold-up comes on its own on a run when you're armed. Headless; a throwaway save.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.45
	main._dev_town(); main.railroad.build()
	var TR: Train = main.train; var RB: TrainRobbers = main.robbers
	main.tools["revolver"] = true; main.held = "revolver"
	TR.passenger = true; TR.state = "run"; TR.leg = 0; TR.dir = 1; TR.s = TR.home_s() + 200.0
	var shots := [0]
	var base_shoot: Callable = main.rob_hooks.on_shoot
	main.rob_hooks.on_shoot = func(a: Vector3, b: Vector3) -> void: shots[0] += 1; base_shoot.call(a, b)
	main.rob_hooks.on_hit = func(_d: int) -> void: pass # (the test's farmer can't be killed)
	for i in 30: await process_frame # (the cars drawn where she now is)
	# it comes on its own: armed, out on the line, the dice loaded
	var came := false
	for k in 20:
		main.rob_run = false; RB.last_day = -99; main._robbers_update(0.016)
		if RB.active: came = true; break
	print("came on its own: %s, %d riders" % [came, RB.men.size()])
	if not came: RB.start(TR, 3)
	for i in 600: await process_frame # (~10 s: they catch up and keep pace)
	var car: Vector3 = TR.ride_car().global_position
	for m in RB.men: print("  rider at %s, car %s, d %.1f" % [m.pos.round(), car.round(), Vector2(m.pos.x - car.x, m.pos.z - car.z).length()])
	var near := 0
	for m in RB.up(): if Vector2(m.pos.x - car.x, m.pos.z - car.z).length() < 14.0: near += 1
	print("alongside: %d of %d; shots fired %d; s %.0f" % [near, RB.men.size(), shots[0], TR.s])
	# shoot them down
	for t in RB.targets(): main.hunting.on_target.call(t, {"dmg": 5}); main.hunting.on_target.call(t, {"dmg": 5})
	var down := RB.men.filter(func(m): return m.dead).size()
	for i in 30: await process_frame
	TR.leg = 1 # (she turns for home)
	for i in 30: await process_frame
	var gone: bool = not RB.active and RB.men.is_empty()
	var owed: int = RB.owed
	TR.state = "home"; TR.passenger = false; main.player.pos = main.railroad.depot
	var before: int = main.inventory.get("dollars", 0)
	for i in 10: await process_frame
	var paid: int = main.inventory.get("dollars", 0) - before
	print("down %d; gone %s; owed %d; paid %d" % [down, gone, owed, paid])
	var ok: bool = came and near == 3 and shots[0] > 0 and down == 3 and gone and owed == 3 * TrainRobbers.BOUNTY and paid == owed
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("ROBBERS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
