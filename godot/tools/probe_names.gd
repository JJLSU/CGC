extends SceneTree
func _initialize() -> void:
	for n in ["bunkhouse", "porch", "vane", "laundry", "coop", "cellar"]:
		var r := (load("res://assets/baked/homestead/%s.glb" % n) as PackedScene).instantiate()
		var names := []
		_walk(r, 0, names)
		print(n, ": ", names.slice(0, 14))
		r.free()
	quit()
func _walk(x: Node, d: int, out: Array) -> void:
	if d <= 3: out.append("%s%s" % ["-".repeat(d), x.name])
	for c in x.get_children(): _walk(c, d + 1, out)
