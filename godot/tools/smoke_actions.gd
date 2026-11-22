extends SceneTree
## A smoke test of what a player does, catching every error the engine or scripts raise (crash-like faults show up
## here first: a freed object mid-signal, a null where a node was expected, an out-of-range index). Phases: walk,
## sprint and jump; every key on the controls card; the centre panels open and shut; crafting presses; build mode
## (shelves, pieces, rotate, place, remove); every tool in hand with clicks and the bow drawn; E at every spot on a
## grid round the farm and at every town door, by day and by night; the title card's buttons; a save. Headless; runs
## on a throwaway save (CGC_SAVE_PATH) so the player's own is never touched. Prints each phase's errors.

class Catch extends Logger:
	var errs: Array = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var msg := (rationale if rationale != "" else code)
		if msg.contains("leaked") or msg.contains("RID") or msg.contains("still in use") or msg.contains("never freed"): return
		var where := "%s:%d %s" % [file.get_file(), line, function]
		if script_backtraces.size() and script_backtraces[0].get_frame_count() > 0:
			where = "%s:%d %s" % [script_backtraces[0].get_frame_file(0).get_file(), script_backtraces[0].get_frame_line(0), script_backtraces[0].get_frame_function(0)]
		mutex.lock(); errs.append("%s  [%s]" % [msg, where]); mutex.unlock()

var catch := Catch.new()
var main: Node
var phase_errs := {}
var _seen := 0

func _boom() -> int:
	var a: Array = []
	return a[5]

func _frames(n: int) -> void:
	for i in n: await process_frame

func _press(k: String, frames := 2) -> void:
	main.input.pressed[k] = true
	await _frames(frames)

func _phase(name: String) -> void:
	var new: Array = catch.errs.slice(_seen); _seen = catch.errs.size()
	var uniq := {}
	for e in new: uniq[e] = uniq.get(e, 0) + 1
	phase_errs[name] = uniq
	print("%-28s %d error%s" % [name, new.size(), "" if new.size() == 1 else "s"])
	for e in uniq: print("    %dx %s" % [uniq[e], e])

func _goto(p: Vector3) -> void:
	var pl: Player = main.player
	pl.pos = Vector3(p.x, Terrain.get_height(p.x, p.z), p.z); pl.vel = Vector3.ZERO

func _initialize() -> void:
	var path := OS.get_environment("CGC_SAVE_PATH")
	if path == "" or path.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.add_logger(catch)
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	main = current_scene
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.4
	await _frames(240)
	if OS.get_environment("SMOKE_SELFTEST") != "": _boom() # (the catcher must see this)
	_phase("start")
	var pl: Player = main.player; var inp: GameInput = main.input
	var home: Vector3 = main.spawn
	# walk, sprint, jump about the yard
	for d in [["KeyW", 60], ["KeyA", 40], ["KeyS", 60], ["KeyD", 40]]:
		inp.keys[d[0]] = true; inp.keys["ShiftLeft"] = d[0] == "KeyS"
		for i in d[1]:
			if i % 20 == 0: inp.pressed["Space"] = true
			inp.dx = 3.0; await process_frame
		inp.keys.erase(d[0]); inp.keys.erase("ShiftLeft")
	inp.dx = 0.0
	_phase("walk, sprint, jump")
	# every key on the card (K, the postcard, needs a rendered frame: not headless)
	for k in ["KeyI", "KeyI", "KeyM", "KeyM", "Tab", "Tab", "KeyH", "KeyH", "KeyJ", "KeyJ", "KeyF", "KeyG", "KeyG", "KeyN", "KeyN", "KeyO", "KeyO", "KeyO", "KeyO", "KeyP", "KeyP", "F3", "F3", "F4", "KeyC", "KeyC", "KeyB", "KeyB"]:
		await _press(k, 6)
	await _frames(60)
	_phase("keys on the controls card")
	# panels opened over one another, then shut in turn
	for k in ["KeyI", "KeyH", "KeyJ", "KeyM"]: await _press(k, 4)
	for k in ["KeyM", "KeyJ", "KeyH", "KeyI"]: await _press(k, 4)
	_phase("panels stacked")
	# everything a beginner crafts, and a few more
	for k in ["wood", "stone", "fiber", "rope", "honey", "berries", "apples", "ore", "iron", "clay", "pelt", "leather", "mushrooms", "corn", "egg", "milk", "fish", "dollars"]: main.inventory[k] = 60
	main._open_craft(); await _frames(3)
	for n in 14:
		var btn: Button = null
		for b in main.panel.list.find_children("*", "Button", true, false):
			if b.text == "Craft" and not b.disabled and b.is_inside_tree(): btn = b; break
		if btn == null: break
		btn.pressed.emit(); await _frames(2)
	main._close_craft(); await _frames(3)
	_phase("crafting")
	# eat a few times (F)
	for i in 4: await _press("KeyF", 4)
	_phase("eating")
	# build mode: each shelf, a few pieces, rotate, place, remove
	main.tools["hammer"] = true
	_goto(home + Vector3(14, 0, 10)); await _frames(10)
	await _press("KeyB", 4)
	for shelf in ["Digit1", "Digit2", "Digit3", "Digit4"]:
		await _press(shelf, 3)
		for j in 3:
			await _press("KeyR", 2)
			inp.clicked = true; await _frames(3)
			await _press("KeyE", 2)
		inp.right_clicked = true; await _frames(3)
	await _press("KeyB", 4)
	_phase("build mode")
	# every tool, swung and fired
	for t in ["axe", "pickaxe", "spear", "rod", "bow", "revolver", "rifle", "basket", "jar", "kite"]: main.tools[t] = true
	main.inventory["arrows"] = 20; main.inventory["bullets"] = 20
	for i in 8:
		await _press("Digit%d" % (i + 1), 3)
		inp.clicked = true; inp.mouse_down = true; await _frames(20)
		inp.mouse_down = false; await _frames(10)
	await _press("Digit1", 3)
	_phase("tools in hand")
	# E everywhere round the farm, by day and by night
	for t in [0.45, 0.92]:
		main.sky.time = t; await _frames(5)
		for gx in range(-30, 31, 3):
			for gz in range(-30, 31, 3):
				_goto(home + Vector3(gx, 0, gz)); await _frames(2)
				inp.pressed["KeyE"] = true; await _frames(2)
				if main.panel.open: main._close_craft(); await _frames(1)
				if main.hud.story.visible: inp.pressed["KeyE"] = true; await _frames(1)
		for spot in [main.dog.pos, main.cat.pos, main.mail.at, main.extras.seat]:
			_goto(spot); await _frames(3); await _press("KeyE", 3); await _press("KeyE", 3)
		_phase("E round the farm at %s" % ("night" if t > 0.8 else "day"))
	# every door in town, with money in the poke
	main.sky.time = 0.5; main.inventory["dollars"] = 900; main.inventory["gold"] = 5
	for id in main.town.doors:
		var d: Vector3 = main.town.doors[id]
		_goto(d); await _frames(4)
		await _press("KeyE", 4)
		if main.panel.open: main._close_craft(); await _frames(2)
		await _press("KeyE", 3)
	_phase("E at every town door")
	# the title card's buttons
	inp.unlock(); main.force_active = false
	main.hud.show_overlay(true, true); await _frames(3)
	main.hud.save_btn.pressed.emit(); await _frames(3)
	main.hud._refresh_options(); main.hud.options_card.visible = true
	for id in ["vsync", "ui", "quality", "dof", "sound"]:
		for j in 3: main.hud.option_buttons[id].pressed.emit(); await _frames(2)
	main.hud.options_card.visible = false
	main.hud.newgame_btn.pressed.emit(); await _frames(2); main.hud.confirm_card.visible = false
	main.hud.show_overlay(false, true); main.force_active = true
	_phase("title card buttons")
	main.save_all(); await _frames(5)
	_phase("save")
	# Biscuit: bought, whistled over, mounted, ridden hard, got down
	_goto(home + Vector3(6, 0, 6)); await _frames(4)
	if main.horse == null: main.make_horse(home.x + 9.0, home.z + 6.0)
	await _frames(10)
	await _press("KeyX", 30)
	_goto(main.horse.pos); await _frames(3); await _press("KeyX", 5)
	inp.keys["KeyW"] = true; inp.keys["ShiftLeft"] = true
	for i in 300:
		inp.dx = 2.0 if i % 60 < 30 else -2.0
		if i % 50 == 0: inp.pressed["Space"] = true
		await process_frame
	inp.keys.erase("KeyW"); inp.keys.erase("ShiftLeft"); inp.dx = 0.0
	await _press("KeyX", 10)
	_phase("riding")
	# fishing at the nearest pond
	var pond := Vector3.INF; var r := 8.0
	while r < 300.0 and pond == Vector3.INF:
		for k in 36:
			var x := home.x + cos(k * 0.1745) * r; var z := home.z + sin(k * 0.1745) * r
			if Terrain.is_water(x, z) and not Terrain.is_water(x + cos(k * 0.1745) * 3.0, z + sin(k * 0.1745) * 3.0): pond = Vector3(x, 0, z); break
			if Terrain.is_water(x, z): pond = Vector3(x - cos(k * 0.1745) * 2.5, 0, z - sin(k * 0.1745) * 2.5); break
		r += 4.0
	if pond != Vector3.INF:
		_goto(pond); await _frames(5)
		for i in 8:
			await _press("Digit5", 2)
			inp.clicked = true; await _frames(90)
			inp.clicked = true; await _frames(20)
	_phase("fishing")
	# days and nights pass quickly, with rain, snow and a storm
	_goto(home); await _frames(5)
	for kind in ["rain", "snow", "rain"]:
		main.weather.storm = kind == "rain" and main.sky.day % 2 == 0
		main.weather.start(30.0, kind)
		for i in 500:
			main.sky.time = fmod(main.sky.time + 0.004, 1.0)
			if main.sky.time < 0.004: main.sky.day += 1
			await process_frame
	_phase("days, nights and weather")
	# every street mended, the railroad laid, a ride on the train and back
	for id in ["store", "assay", "boarding", "saloon", "livery", "smithy", "church"]: if not main.town.tiers.get(id, 0): main.town.mend(id)
	for st in Town.STREETS: for b in st.buildings: if not main.town.tiers.get(b.id, 0): main.town.mend(b.id)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and not main.railroad.built: await process_frame
	main.sky.time = 0.4
	var stop = main.train.stopped_at()
	if stop != null:
		_goto(stop.platform); await _frames(5)
		await _press("KeyE", 5)
		await _frames(600)
		await _press("KeyE", 5)
	_phase("the town mended, the train")
	# a fight with a guardian: spawned beside the farmer, struck with each weapon, and the farmer struck down by it
	main.sky.time = 0.5; await _frames(3)
	var gat: Vector3 = main.player.pos + Vector3(5, 0, 3)
	main.enemies.spawn_site({"key": "smoke:den", "kind": "den", "guard": "gouger", "guards": 2, "x": gat.x, "z": gat.z})
	await _frames(30)
	for w in ["Digit2", "Digit4", "Digit6", "Digit7"]:
		await _press(w, 3)
		for i in 6:
			var e = main.enemies.list.filter(func(q): return q.key.begins_with("smoke:den"))
			if e.size(): main.player.facing = atan2(-(Enemies.pos(e[0]).z - main.player.pos.z), Enemies.pos(e[0]).x - main.player.pos.x)
			inp.clicked = true; inp.mouse_down = true; await _frames(12); inp.mouse_down = false; await _frames(8)
	_phase("a fight with guardians")
	# struck down: the farmer comes to at home
	main.player.hurt(999.0); main.death_timer = 3.0
	var tw := Time.get_ticks_msec()
	while main.player.dead and Time.get_ticks_msec() - tw < 8000: await process_frame
	await _frames(60)
	print("  after the fall: dead %s  health %.0f" % [main.player.dead, main.player.health])
	_phase("struck down, coming to")
	# a raid on the town, met with the rifle
	main.tools["rifle"] = true
	_goto(main.town.at); await _frames(10)
	main.raid_day = 0; main.sky.time = 0.5; main._raid_tick(); await _frames(30)
	await _press("Digit7", 3)
	for i in 30: inp.clicked = true; inp.mouse_down = true; await _frames(6); inp.mouse_down = false; await _frames(6)
	await _frames(600)
	if main.camp.raid.on: main.camp.raid.end()
	_phase("a raid on the town")
	# into a camp's land and out again
	var cp = main.camp.list[0] if main.camp.list.size() else null
	if cp != null:
		var dir: Vector3 = (main.spawn - cp.at); dir.y = 0; dir = dir.normalized()
		var inside: Vector3 = cp.at + dir * (NativeCamps.R - 4.0)
		for i in 600:
			if i % 2 == 0: _goto(inside)
			await process_frame
		_goto(main.spawn); await _frames(120)
	_phase("into a camp and out")
	# a well-played save (horse, the whole town mended, the railroad, every tool) loaded back, and played on
	main.save_all(); await _frames(3)
	var size := FileAccess.get_file_as_string(path).length()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	main = current_scene
	main.force_active = true
	await _frames(400)
	inp = main.input
	inp.keys["KeyW"] = true
	await _frames(120)
	inp.keys.erase("KeyW")
	main.save_all(); await _frames(3)
	print("  reloaded a %d-byte save: horse %s, railroad %s, town tiers %d, tools %d" % [size, main.horse != null, main.railroad.built, main.town.tiers.size(), main.tools.size()])
	_phase("save loaded and played on")
	var total := 0
	for p in phase_errs: for e in phase_errs[p]: total += phase_errs[p][e]
	print("SMOKE: %d errors in all" % total)
	main.saving = false
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.remove_logger(catch)
	quit()
