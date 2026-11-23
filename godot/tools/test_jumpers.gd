extends SceneTree
## Claim jumpers (the player's addition): five camps placed for the world, built as you come near; they see you and
## come at you (no warning), their blows and bullets hurt; struck down, one drops his poke, which E picks up; a
## camp beaten to the last man is marked cleared (and saved). Also: a fallen warrior's parfleche. Headless.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	await _wait(2.0)
	var J: ClaimJumpers = main.jumpers; var p: Player = main.player
	print("camps: %d at %s" % [J.camps.size(), J.camps.map(func(c): return Vector2(c.at.x, c.at.z).round())])
	var ok: bool = J.camps.size() >= 3
	var c: Dictionary = J.camps[0]
	# stand 25 m off: the camp is built, and they come
	var off: Vector3 = c.at + Vector3(25, 0, 0)
	p.pos = Vector3(off.x, Terrain.get_height(off.x, off.z), off.z)
	main.player.health = main.player.max_health
	await _wait(0.5)
	print("built %s, %d men" % [c.built, c.men.size()])
	ok = ok and c.built and c.men.size() >= 3
	var h0: float = p.health
	await _wait(1.5)
	var chasing: int = c.men.filter(func(m): return m.state == "chase").size()
	await _wait(2.5)
	print("chasing %d, health %.0f -> %.0f" % [chasing, h0, p.health])
	ok = ok and chasing >= 2 and p.health < h0
	# only men fight, three at least; the women aren't targets and keep to the shack in a fight
	var men_ok: bool = c.men.size() >= 3 and c.men.all(func(m): return ClaimJumpers.MEN.has(m.fig.name))
	var targets: Array = J.targets()
	var women_safe: bool = c.women.all(func(w): return not targets.any(func(t): return t.pos == w.fig.root.position))
	var by_shack: bool = c.women.all(func(w): return Vector2(w.fig.root.position.x - c.shack.x, w.fig.root.position.z - c.shack.z).length() < 4.0)
	print("men %d (all men %s), women %d (not targets %s, at the shack in the fight %s), camp pieces %d" % [c.men.size(), men_ok, c.women.size(), women_safe, by_shack, c.nodes.size()])
	ok = ok and men_ok and c.women.size() >= 1 and women_safe and by_shack and c.nodes.size() >= 10
	# beat every one of them (blows straight to each), then pick up a poke
	p.health = p.max_health; p.dead = false
	for m in c.men: while not m.dead: J.damage(m, 3, main.jumper_hooks)
	await _wait(0.3)
	print("cleared day %d (today %d), drops %d" % [c.cleared_day, main.sky.day, main.drops.size()])
	ok = ok and c.cleared_day == main.sky.day and main.drops.size() >= c.men.size()
	var d0: int = main.inventory.get("dollars", 0) + main.inventory.get("gold", 0) + main.inventory.get("silver", 0) + main.inventory.get("cartridges", 0) + main.inventory.get("rope", 0)
	var dp: Vector3 = main.drops[0].pos
	p.pos = Vector3(dp.x, Terrain.get_height(dp.x, dp.z), dp.z)
	await _wait(0.2)
	main.input.pressed["KeyE"] = true
	await _wait(0.2)
	var d1: int = main.inventory.get("dollars", 0) + main.inventory.get("gold", 0) + main.inventory.get("silver", 0) + main.inventory.get("cartridges", 0) + main.inventory.get("rope", 0)
	print("picked up: %d more in the pack, drops left %d" % [d1 - d0, main.drops.size()])
	ok = ok and d1 > d0
	ok = ok and main.jumpers.save()[0] == main.sky.day
	# a fallen warrior's parfleche
	var n0: int = main.drops.size()
	var w: Dictionary = main.camp.list[0].warriors[0]
	while not w.dead: main.camp.damage(w, 3, main.camp_hooks, main.raid_hooks)
	print("warriors in a camp: %d; parfleche dropped %s" % [main.camp.list[0].warriors.size(), main.drops.size() > n0])
	ok = ok and main.camp.list[0].warriors.size() == 6 and main.drops.size() > n0
	print("JUMPERS TEST ", "PASS" if ok else "FAIL")
	quit()
