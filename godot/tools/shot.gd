extends SceneTree
## Renders a scene for N frames and saves the viewport to a PNG, for checking a step by eye.
## godot --path godot --script res://tools/shot.gd -- res://scenes/main.tscn C:/path/out.png 90

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/main.tscn"
	var out: String = args[1] if args.size() > 1 else "user://shot.png"
	var frames: int = int(args[2]) if args.size() > 2 else 90
	var s: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(s)
	await process_frame # (so the scene's _ready has run)
	# extra args "node.prop=value" set a property on a child of the scene root after it's ready (e.g. rig.dist=42)
	for a in args.slice(3):
		var kv: PackedStringArray = a.split("=")
		var path: PackedStringArray = kv[0].split(".")
		var obj: Object = s.get(path[0]) if path.size() > 1 else s
		obj.set(path[path.size() - 1], str_to_var(kv[1]))
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT saved ", out, " ", img.get_size())
	quit()
