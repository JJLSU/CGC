extends SceneTree
## How long the game takes to come up: loading the main scene, building it (its _ready), and the first frames.
## Windowed; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var ps := load("res://scenes/main.tscn") as PackedScene
	var t1 := Time.get_ticks_msec()
	var main: Node = ps.instantiate()
	var t2 := Time.get_ticks_msec()
	root.add_child(main)
	var t3 := Time.get_ticks_msec()
	await process_frame
	var t4 := Time.get_ticks_msec()
	for i in 30: await process_frame
	var t5 := Time.get_ticks_msec()
	print("STARTUP load %d ms, instantiate %d ms, add (ready) %d ms, first frame %d ms, next 30 frames %d ms; total %d ms" % [t1 - t0, t2 - t1, t3 - t2, t4 - t3, t5 - t4, t5 - t0])
	quit()
