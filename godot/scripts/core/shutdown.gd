class_name Shutdown
## The way out. The exported game died on its way out on every quit (0xC0000374 heap corruption, sometimes 0xC0000005),
## inside the engine's own teardown, after everything of ours was done: freeing the scene first and letting go of the
## static caches beforehand only moved the crash about. So an exported game, once the save is written and the loads are
## finished (main._quit_game does both first), ends its own process there instead of going through that teardown.
## Editor and test runs quit the ordinary way.

static func quit(tree: SceneTree) -> void:
	if OS.has_feature("template"): # (the exported game)
		OS.kill(OS.get_process_id())
		return
	tree.quit()
