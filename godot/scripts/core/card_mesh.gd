class_name CardMesh
## props.js cardGeometry(): a silhouette extruded into a thin card (front and back faces printed from the
## silhouette's bounding box with textures.js frame() padding; the cut sides sample the cream paper-core pixel at
## EDGE_UV; backAt gives a plain back by pointing every back-face uv at one swatch). For cards made at runtime (signs,
## name boards, the train's flanks...). UVs are in three.js convention (v up), so use flip=true on the material.

const EDGE_UV := Vector2(0.992, 0.992)

static func build(points: PackedVector2Array, thickness := 0.06, back_at = null) -> ArrayMesh:
	var minv := Vector2(INF, INF); var maxv := Vector2(-INF, -INF)
	for q in points: minv = minv.min(q); maxv = maxv.max(q)
	var w0 := maxv - minv
	minv -= w0 * 0.04; maxv += w0 * 0.04
	var wh := maxv - minv
	var tris := Geometry2D.triangulate_polygon(points)
	if tris.is_empty():
		var rev := points.duplicate(); rev.reverse(); points = rev; tris = Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := thickness * 0.5
	var face_uv := func(q: Vector2) -> Vector2: return (q - minv) / wh
	# is the outline wound counter-clockwise (in x right, y up)? decides which way the faces and sides look
	var ccw := Geometry2D.is_polygon_clockwise(points) == false
	for i in range(0, tris.size(), 3):
		var a := points[tris[i]]; var b := points[tris[i + 1]]; var c := points[tris[i + 2]]
		var tri_ccw := (b - a).cross(c - a) > 0.0
		if not tri_ccw: var t := b; b = c; c = t
		# front (+z), seen from +z: Godot wants clockwise as seen by the viewer, so a, c, b
		for q in [a, c, b]:
			st.set_normal(Vector3(0, 0, 1)); st.set_uv(face_uv.call(q)); st.add_vertex(Vector3(q.x, q.y, hz))
		# back (-z)
		for q in [a, b, c]:
			st.set_normal(Vector3(0, 0, -1))
			st.set_uv(face_uv.call(back_at) if back_at != null else face_uv.call(q))
			st.add_vertex(Vector3(q.x, q.y, -hz))
	# the cut sides: a quad per outline edge, facing outward
	var n := points.size()
	for i in n:
		var p0 := points[i]; var p1 := points[(i + 1) % n]
		var e := p1 - p0
		var out := Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
		var nn := Vector3(out.x, out.y, 0)
		var A := Vector3(p0.x, p0.y, hz); var B := Vector3(p1.x, p1.y, hz); var C := Vector3(p1.x, p1.y, -hz); var D := Vector3(p0.x, p0.y, -hz)
		var quad := [A, B, C, A, C, D] if not ccw else [A, C, B, A, D, C]
		for v in quad:
			st.set_normal(nn); st.set_uv(EDGE_UV); st.add_vertex(v)
	return st.commit()
