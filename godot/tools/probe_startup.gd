extends SceneTree
## How long a new county takes to its first frame (seed after --), and the railroad's share. Headless.
func _initialize() -> void:
	var k := int(OS.get_cmdline_user_args()[0]); seed(k)
	var path := "user://startup_probe.json"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var t0 := Time.get_ticks_msec()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.save_path = path; main.saving = true
	root.add_child(main)
	await process_frame
	main.saving = false
	var t1 := Time.get_ticks_msec()
	var r0 := Time.get_ticks_usec(); var rr := Railroad.new(main.world, main.town, main.spawn); var r1 := Time.get_ticks_usec()
	print("seed %d: first frame after %d ms; a Railroad's route %.0f ms" % [k, t1 - t0, (r1 - r0) / 1000.0])
	rr.free()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()
