extends SceneTree
## A figure rigged but never animated (the wild young cowboy: the credits ran out before his clips) borrows the
## standard set and stands, walks and works like the rest. Headless.
func _initialize() -> void:
	var f := ModelFigure.new("cgc_man_outlaw_cowboy"); root.add_child(f.root)
	for i in 5: await process_frame
	var have := ["idle", "walk", "work", "run"].filter(func(c): return f.player != null and f.player.has_animation(c))
	f.update(0.1, 1.5, null); for i in 5: await process_frame
	var walking := f.current == "walk"
	print("lent clips: %s; walks: %s" % [have, walking])
	var ok := have.size() == 4 and walking
	print("LENT CLIPS TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
