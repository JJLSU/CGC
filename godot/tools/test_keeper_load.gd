extends SceneTree
## A building mended while the game is still loading its models in the background (the player saw its keeper as a
## floating "hello", no body): every keeper put out must have his model's meshes. Headless; CGC_SAVE_PATH a throwaway.
func _initialize() -> void:
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if sp == "" or sp.contains("paperfjord.builds"): print("set CGC_SAVE_PATH to a throwaway save"); quit(); return
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var T: Town = main.town
	print("models still loading in the background: %d" % main._loading.size())
	var ids := ["store", "boarding", "saloon", "livery", "smithy", "assay", "church"]
	var empty := []
	for id in ids:
		T.mend(id)
		await process_frame
	for i in 10: await process_frame
	for k in T.folk:
		var fig: ModelFigure = T.folk[k].fig
		var meshes := fig.model.find_children("*", "MeshInstance3D", true, false) if is_instance_valid(fig.model) else []
		if meshes.is_empty(): empty.append("%s (%s)" % [k, fig.name])
	print("keepers out %d, without a body: %s" % [T.folk.size(), empty])
	var ok: bool = T.folk.size() >= 7 and empty.is_empty()
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	print("KEEPER LOAD TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
