class_name TearLogger
extends Logger
## main.js's frame guard: a stray error in a frame must never freeze the farm. GDScript can't catch, and an error
## already only ends the one function it struck in (the frame carries on), so this listens to the engine's log
## instead: a script error tells main once, which shows the page's "A little tear in the paper" toast, or the red
## #error card if the game hasn't got as far as its first frame ("Could not start: ..."). Called from any thread, so
## it only hands the message over (call_deferred).

var main: Node

func _init(m: Node) -> void: main = m

func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT or not is_instance_valid(main): return
	main.call_deferred("_tear", rationale if rationale != "" else code)
