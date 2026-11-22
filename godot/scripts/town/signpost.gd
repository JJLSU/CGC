class_name Signpost
extends Node3D
## signpost.js: the fingerpost at the farm end of the lane to town. A weathered post with hand-lettered arrow boards,
## one pointing the true way to Cold Glitter Creek and one to the nearest stretch of each wild land, each with its
## distance in paces, stacked up the post at a slant. The boards (and where each points) are baked from the web's
## own: assets/baked/town/fingerpost_*.png and fingerpost.json. Each is lettered on both sides.

const LEN := 1.25
const H := 0.3

func _init(at: Vector3) -> void:
	position = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z)
	var wood := PaperMats.paper(Color.hex(0x6a4a30ff))
	var post := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.16, 3.1, 0.16); post.mesh = bm; post.material_override = wood; post.position.y = 1.55; add_child(post)
	var cap := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.16; cm.height = 0.22; cm.radial_segments = 4; cm.rings = 1
	cap.mesh = cm; cap.material_override = PaperMats.paper(Color.hex(0x4a3424ff)); cap.position.y = 3.21; cap.rotation.y = PI / 4; add_child(cap)
	var f := FileAccess.open("res://assets/baked/town/fingerpost.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var pts := [[0, -H / 2], [LEN - 0.2, -H / 2], [LEN, 0], [LEN - 0.2, H / 2], [0, H / 2]]
	var back_pts := pts.map(func(q): return [-q[0], q[1]])
	for i in data.arms.size():
		var a: Dictionary = data.arms[i]
		var arm := Node3D.new(); arm.position.y = a.y; arm.rotation.y = a.rot; add_child(arm) # (its length along local +x, turned to point the way)
		var tilt := Node3D.new(); tilt.rotation.z = a.tilt; arm.add_child(tilt)
		var board := Town.card(pts, "res://assets/baked/town/fingerpost_%d" % i, 0.05, 0.6); board.position = Vector3(a.bx, 0, 0.02); tilt.add_child(board)
		var back := Town.card(back_pts, "res://assets/baked/town/fingerpost_%db" % i, 0.05, 0.6); back.position = Vector3(a.bx, 0, -0.02); back.rotation.y = PI; tilt.add_child(back)
