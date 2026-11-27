extends SceneTree
## The mine kit laid out in a row from above (<out>), each piece at scale F with its origin marked: a red post toward its
## +x, a blue one toward +z. Prints each piece's footprint. Windowed; a throwaway save.
const F := 3.0
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var sp := OS.get_environment("CGC_SAVE_PATH")
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.force_active = true; main.sky.time = 0.5; main.weather.rain = 0.0
	var base: Vector3 = main.spawn - (main.town.at - main.spawn).normalized() * 40.0
	var names := ["mine_tunnel_straight", "mine_tunnel_corner", "mine_tunnel_t", "mine_collapsed", "mine_ladder_shaft", "mine_vein_rich"]
	var gy := Terrain.get_height(base.x, base.z) + 3.0 # (raised clear of the ground, to see them whole)
	for i in names.size():
		var m := (load("res://assets/models/props/%s.glb" % names[i]) as PackedScene).instantiate() as Node3D
		PaperMats.paperize(m)
		var g := Node3D.new(); g.add_child(m); g.scale = Vector3.ONE * F
		g.position = base + Vector3(i * 8.0, 0, 0); g.position.y = gy; main.add_child(g)
		var bb := PaperMats._aabb(g, g.global_transform.affine_inverse() * Transform3D(Basis(), g.position))
		print("%s: x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f" % [names[i], bb.position.x - g.position.x, bb.end.x - g.position.x, bb.position.y - gy, bb.end.y - gy, bb.position.z - g.position.z, bb.end.z - g.position.z])
		for e in [[Vector3(1.2, 0, 0), Color.RED], [Vector3(0, 0, 1.2), Color.BLUE]]:
			var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.3, 4, 0.3); b.mesh = bm
			var mat := StandardMaterial3D.new(); mat.albedo_color = e[1]; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; b.material_override = mat
			b.position = g.position + e[0]; main.add_child(b)
	for i in 30: main.player.pos = base + Vector3(20, 0, 30); await process_frame
	main.set_process(false); main.player.avatar.root.visible = false
	var cam: Camera3D = main.rig.camera
	cam.global_position = base + Vector3(20, gy - base.y + 38, 0.01); cam.look_at(base + Vector3(20, gy - base.y, 0), Vector3(0, 0, -1)); cam.fov = 50.0
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
