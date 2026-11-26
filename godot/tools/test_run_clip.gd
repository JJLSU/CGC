extends SceneTree
## The farmer runs when he sprints (the player's ask): his figure borrows the warriors' run clip, and plays it above
## ModelFigure.RUN_AT; walking he walks. Headless.
func _initialize() -> void:
	var _sp := OS.get_environment("CGC_SAVE_PATH") # (a fresh throwaway each run, never the player's save: an old one would carry the last run's state in)
	if _sp != "" and not _sp.contains("paperfjord.builds") and FileAccess.file_exists(_sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(_sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true
	for i in 60: await process_frame
	var fig: ModelFigure = main.player.avatar.fig
	var has_run: bool = fig.player.has_animation("run")
	var inp: GameInput = main.input
	inp.keys["KeyW"] = true
	for i in 90: await process_frame
	var walking := fig.current
	inp.keys["ShiftLeft"] = true
	for i in 90: await process_frame
	var sprinting := fig.current
	var playing: String = fig.player.current_animation
	inp.keys.clear()
	print("run clip %s  walking: %s  sprinting: %s (player playing %s, pos %.2f)" % [has_run, walking, sprinting, playing, fig.player.current_animation_position])
	print("RUN CLIP TEST ", "PASS" if has_run and walking == "walk" and sprinting == "run" and playing == "run" else "FAIL")
	quit()
