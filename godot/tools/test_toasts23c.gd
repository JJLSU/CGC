extends SceneTree
## 23c: the toasts the audit found missing. A daytime shower ending (the rainbow, and its note 2.5 s on), the first
## iron, newcomers at the mended boarding house, the barn dance starting, a falling star landing, the jar's bugs let
## go at first light.

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _has(hud: Hud, s: String) -> bool:
	return hud.heard.any(func(h): return s in h)

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.sky.time = 0.45
	await _wait(2.5)
	var hud: Hud = main.hud
	var got := {}
	main.weather.kind = "rain"; main.weather.on_end.call()
	await _wait(3.0)
	got.rainbow = _has(hud, "rainbow, standing up")
	main.crafting.on_craft.call({"id": "iron", "name": "Iron"})
	got.iron = _has(hud, "Your first iron")
	main.newcomer_news = true; main.settlers.on_newcomer.call({"S": {"name": "Nell Harper", "pitch": "a placer miner"}})
	await _wait(0.2)
	got.newcomers = _has(hud, "boarding house has rooms again")
	main.jar_count = 3; main.sky.time = 0.3
	await _wait(0.3)
	got.jar = _has(hud, "lightning bugs drift off home") and main.jar_count == 0
	# the dance: the first evening it runs
	var d := 0
	for k in range(main.sky.day, main.sky.day + 14): if main.dance.is_dance_night(k): d = k; break
	main.sky.day = d; main.sky.time = BarnDance.DANCE_FROM + 0.01
	await _wait(0.3)
	got.dance = _has(hud, "a barn dance has started")
	hud.queue.clear()
	print(got)
	var ok := got.values().all(func(v): return v)
	print("TOASTS23C TEST ", "PASS" if ok else "FAIL")
	quit()
