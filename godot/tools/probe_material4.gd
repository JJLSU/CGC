extends SceneTree
## The first dusk of a session only: with main's children [FROM, TO) not processing (env PAUSE_FROM / PAUSE_TO),
## does "Parameter material is null" still come? Prints the children's names too (LIST=1).
class Catch extends Logger:
	var n := 0
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if (rationale + code).contains("material"): n += 1
var c := Catch.new()
func _initialize() -> void:
	OS.add_logger(c)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.weather.rain = 0.0; main.weather.target = 0; main.weather.next = 9999.0; main.sky.time = 0.5
	for i in 200: await process_frame
	var kids := main.get_children()
	if OS.get_environment("LIST") != "":
		for i in kids.size(): print("%d %s" % [i, kids[i].get_script().resource_path.get_file() if kids[i].get_script() else kids[i].get_class()])
	var a := int(OS.get_environment("PAUSE_FROM")); var b := int(OS.get_environment("PAUSE_TO"))
	for i in range(a, mini(b, kids.size())):
		if kids[i] is Camera3D or kids[i] == main.sky: continue
		kids[i].process_mode = Node.PROCESS_MODE_DISABLED
	var n0 := c.n
	main.sky.time = 0.70
	for i in 40: main.sky.time += 0.0025; await process_frame
	print("RESULT kids %d  paused [%d,%d)  errors %d" % [kids.size(), a, b, c.n - n0])
	OS.remove_logger(c)
	quit()
