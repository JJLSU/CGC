extends SceneTree
## The yard: build a skep, a woodpile, a bed and a sapling next to the farmer; next morning the skep has a comb, the
## sapling grows into an apple tree two mornings on; E at the woodpile stacks four logs; at night E at the bed sleeps
## through to 06:28 (time 0.27) with a full stamina.

func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 30: await process_frame
	var b: BuildSystem = main.build
	var p: Player = main.player
	var at := func(dx: float, dz: float) -> Dictionary: return {"x": p.pos.x + dx, "y": p.pos.y, "z": p.pos.z + dz, "rot": 0}
	var skep := b.add(at.call(3.0, 0.0).merged({"type": "skep"}), true)
	var pile := b.add(at.call(-3.0, 0.0).merged({"type": "woodpile"}), true)
	var sap := b.add(at.call(0.0, 4.0).merged({"type": "sapling"}), true)
	var bed := b.add(at.call(0.0, -4.0).merged({"type": "bed"}), true)
	main.sky.time = 0.3
	for i in 3: await process_frame
	var d0: int = main.sky.day
	# the next morning, and the one after
	main.sky.day = d0 + 1
	for i in 3: await process_frame
	var comb = skep.stock
	main.sky.day = d0 + 2
	for i in 3: await process_frame
	var grown := false
	for q in b.pieces: if q.type == "homeapple": grown = true
	# stack wood
	main.inventory.wood = 10
	p.pos = Vector3(pile.x + 1.0, p.pos.y, pile.z)
	main.input.pressed["KeyE"] = true
	for i in 2: await process_frame
	var stacked = pile.stock
	# sleep
	main.sky.time = 0.9
	p.pos = Vector3(bed.x + 1.0, p.pos.y, bed.z)
	p.stamina = 20.0
	main.input.pressed["KeyE"] = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500: await process_frame
	print("comb %s  grown %s  stacked %s  woke at %.2f day %d stamina %.0f" % [comb, grown, stacked, main.sky.time, main.sky.day, p.stamina])
	var ok: bool = comb == 1 and grown and stacked == 4 and main.sky.time < 0.3 and p.stamina > 150.0
	print("YARD TEST ", "PASS" if ok else "FAIL")
	quit()
