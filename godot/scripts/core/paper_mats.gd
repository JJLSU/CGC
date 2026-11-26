class_name PaperMats
## materials.js in Godot: paperMaterial / cardMaterial / groundMaterial as ShaderMaterials over the shaders in
## res://shaders, plus putting the paper look on a loaded glTF model (modelfolk.js loadModels: every mesh's texture
## printed on card, fine quiet grain, both sides, a soft self-fill) and seating it on its bounding box (put()).

static var _ground: Shader = preload("res://shaders/ground.gdshader")
static var _paper: Shader = preload("res://shaders/paper.gdshader")
static var _card: Shader = preload("res://shaders/card.gdshader")
static var _paper_cache := {}

## Solid-colour paper (cached per colour and snow).
static func paper(color: Color, snow := true) -> ShaderMaterial:
	var k := "%s/%s" % [color.to_html(), snow]
	if _paper_cache.has(k): return _paper_cache[k]
	var m := ShaderMaterial.new(); m.shader = _paper
	m.set_shader_parameter("albedo", color); m.set_shader_parameter("snow", snow)
	_paper_cache[k] = m
	return m

## A printed card. opts: flip (canvas print), paper_scale, pulp, hue, snow (0..1), snow_cap, sway, self_fill.
static func card(map: Texture2D, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = _card
	m.set_shader_parameter("map", map)
	m.set_shader_parameter("has_map", map != null)
	m.set_shader_parameter("flip_map", opts.get("flip", false))
	m.set_shader_parameter("paper_scale", opts.get("paper_scale", 1.0))
	m.set_shader_parameter("pulp", opts.get("pulp", 0.55))
	m.set_shader_parameter("hue", opts.get("hue", 0.0))
	m.set_shader_parameter("snow", float(opts.get("snow", 1.0)))
	m.set_shader_parameter("snow_cap", opts.get("snow_cap", 0.0))
	m.set_shader_parameter("sway", opts.get("sway", 0.0))
	m.set_shader_parameter("self_fill", opts.get("self_fill", 0.0))
	if opts.has("albedo"): m.set_shader_parameter("albedo", opts.albedo)
	if opts.has("alpha_cut"): m.set_shader_parameter("alpha_cut", opts.alpha_cut)
	return m

static func ground(map_tex: Texture2D, land_tex: Texture2D, backdrop := false) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = _ground
	m.set_shader_parameter("map_tex", map_tex)
	m.set_shader_parameter("land_tex", land_tex)
	m.set_shader_parameter("water_t", (Terrain.WATER_T + 10.0) / 60.0)
	m.set_shader_parameter("high_t", (Terrain.HIGH_T + 10.0) / 60.0)
	m.set_shader_parameter("peak_t", (Terrain.PEAK_T + 10.0) / 60.0)
	m.set_shader_parameter("kind", 3.0 if backdrop else 0.0)
	return m

## Every mesh of a loaded model printed on card (paper_scale 6, pulp 0.08, self-fill 0.28; snow for buildings and
## props, none for folk and beasts). Materials are shared per source texture, so clones cost nothing extra.
static var _model_mats := {}
static func paperize(root: Node, snow := true, hue := 0.0) -> void:
	for n in _meshes(root):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var tex: Texture2D = null
			if src is BaseMaterial3D: tex = (src as BaseMaterial3D).albedo_texture
			var k := "%s/%s/%s" % [tex.get_rid() if tex else "none", snow, hue]
			if not _model_mats.has(k):
				_model_mats[k] = card(tex, {"paper_scale": 6.0, "pulp": 0.08, "snow": 1.0 if snow else 0.0, "self_fill": 0.28, "hue": hue})
			mi.set_surface_override_material(s, _model_mats[k])

static func _meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): _meshes(c, out)
	return out

## A model scaled to `size` (its largest footprint side, or its height with by_height) and seated with its bounding
## box's floor at y = 0, centred: the web's put() helper. Returns the holder node.
static func seated(scene: PackedScene, size: float, by_height := false, snow := true) -> Node3D:
	var m := scene.instantiate() as Node3D
	paperize(m, snow)
	var bb := _aabb(m, Transform3D.IDENTITY)
	var k := size / (bb.size.y if by_height else maxf(bb.size.x, bb.size.z))
	var hold := Node3D.new()
	m.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	hold.add_child(m)
	hold.scale = Vector3.ONE * k
	return hold

## town.js put(): a model scaled so its extent along axis (0 x, 1 y, 2 z) is size, centred, its floor at y 0.
static func seated_axis(scene: PackedScene, size: float, axis: int, snow := true) -> Node3D:
	var m := scene.instantiate() as Node3D
	paperize(m, snow)
	var bb := _aabb(m, Transform3D.IDENTITY)
	var hold := Node3D.new()
	m.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	hold.add_child(m)
	hold.scale = Vector3.ONE * (size / bb.size[axis])
	return hold

static func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB(); var first := true
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	if n is MeshInstance3D:
		var a := t * (n as MeshInstance3D).get_aabb()
		out = a; first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size == Vector3.ZERO and b.position == Vector3.ZERO: continue
		out = b if first else out.merge(b); first = false
	return out
