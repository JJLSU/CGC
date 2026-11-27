class_name Landmarks
extends Node3D
## landmarks.js: one rare, tall set piece per wild land, seen from far off, each with something to find the first time
## you reach it: the Redrock Arch (Breaks), the Belle of the Fen (a sunk sternwheeler), the fire lookout (Highlands;
## its view from the top), the lost schooner (Prairie), the Grandmother Birch (Hollows); and the legends: Babe the Blue
## Ox (wants apples; her blessing gives an extra stick from every tree) and Old Asa the hermit at his lean-to. The
## set pieces were baked from the web's builders (assets/baked/landmarks/*.glb, the reference-art models placed per
## its json); the arch, the wreck and the lookout carry climbable decks and ladders.

const CLIMB := {
	"lookout": {"decks": [{"x": 0, "z": 0, "hw": 1.75, "hd": 1.75, "y": 9.07, "rail": true}],
		"ladders": [{"foot": [2.6, 0, 0], "top": [1.35, 9.07, 0], "land": [1.55, 0], "name": "the fire lookout"}]},
	"arch": {"decks": [{"x": 0, "z": 0, "hw": 4.3, "hd": 0.8, "y": 0, "y_at": "arch"}],
		"ladders": [{"foot": [-5.4, 0, 0], "top": [-4.1, 5.2428, 0], "land": [-3.8, 0], "name": "the stone arch"}]},
	"steamboat": {"decks": [{"x": 0, "z": 0, "hw": 5, "hd": 1.35, "y": 0, "y_at": "boat_deck", "rail": true}, {"x": -0.5, "z": 0, "hw": 3.3, "hd": 1.2, "y": 0, "y_at": "boat_roof", "rail": true}],
		"ladders": [{"foot": [3.4, 0, 2.6], "top": [3.4, 1.486, 1.4], "land": [3.4, 0.5], "name": "the wreck of the Belle"},
			{"foot": [3.3, 1.477, -0.9], "top": [2.75, 3.0075, -0.9], "land": [2.4, -1.0], "name": "the Belle's hurricane deck"}]},
}

const SCHOONER := "veh_conestoga_wreck_hoops"
## The Belle as the player's Meshy paddle-wheel wreck (in place of the web's baked boat): 12 m long down x, settled
## into the marsh; her main deck and the deck above it walked on, flat, at their measured heights.
const BELLE := "veh_paddleboat_wreck"
const BELLE_SINK := 0.35
const BELLE_CLIMB := {"decks": [{"x": 0, "z": 0, "hw": 5.2, "hd": 1.6, "y": 1.0 - BELLE_SINK, "rail": true}, {"x": 0.4, "z": 0, "hw": 4.0, "hd": 1.2, "y": 2.95 - BELLE_SINK, "rail": true}],
	"ladders": [{"foot": [4.6, 0, 2.7], "top": [4.6, 1.0 - BELLE_SINK, 1.4], "land": [4.6, 0.6], "name": "the wreck of the Belle"},
		{"foot": [4.7, 1.0 - BELLE_SINK, -0.6], "top": [4.0, 2.95 - BELLE_SINK, -0.6], "land": [3.6, -0.6], "name": "the Belle's upper deck"}]}
## The fire lookout as the player's Meshy tower (its stairs and cabin), 14 m to the roof's peak: its cabin floor,
## walked on, at 9.1 m (the old one's was 9.07), its balcony round it; up by the ladder as before.
const LOOKOUT := "bldg_lookout"
const LOOKOUT_CLIMB := {"decks": [{"x": 0, "z": -0.38, "hw": 2.2, "hd": 2.0, "y": 9.1, "rail": true}],
	"ladders": [{"foot": [3.4, 0, 0], "top": [2.0, 9.1, 0], "land": [1.7, 0], "name": "the fire lookout"}]}
static func meshy_lookout() -> bool: return ResourceLoader.exists("res://assets/models/props/%s.glb" % LOOKOUT)
static func belle() -> bool: return ResourceLoader.exists("res://assets/models/props/%s.glb" % BELLE)
var info := {}
var models := {}     ## kind -> {scene, json}
var live := {}       ## site key -> {site, group, figure?, puppet?}
var found := {}
var blessed := false
var hint_at := {}
var climbs: Climbs

func _init() -> void:
	info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/landmarks/info.json")).INFO

func _model(kind: String) -> Dictionary:
	if not models.has(kind):
		models[kind] = {"scene": load("res://assets/baked/landmarks/%s.glb" % kind), "json": JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/landmarks/%s.json" % kind))}
	return models[kind]

func _build(kind: String) -> Node3D:
	var M := _model(kind)
	var g := Node3D.new()
	var inst: Node3D = (M.scene as PackedScene).instantiate()
	Homestead.bake_materials(inst)
	g.add_child(inst)
	if kind == "lookout" and meshy_lookout():
		inst.visible = false # (the old baked tower let go)
		g.add_child(PaperMats.seated_axis(load("res://assets/models/props/%s.glb" % LOOKOUT), 14.0, 1, false))
	if kind == "steamboat" and belle():
		inst.visible = false # (the old baked boat let go)
		var b := PaperMats.seated_axis(load("res://assets/models/props/%s.glb" % BELLE), 12.0, 0, false)
		b.position.y = -BELLE_SINK; g.add_child(b)
	for m in M.json.models: # the reference-art models (the broken wagon, Asa's lean-to), placed as the web did
		if kind == "schooner" and m.model == "veh_broken_wagon" and ResourceLoader.exists("res://assets/models/props/%s.glb" % SCHOONER):
			# the lost schooner as the player's wrecked Conestoga (bare hoops, collapsed running gear), where the old one lay
			var xf := Homestead._m(m.m)
			var w := PaperMats.seated_axis(load("res://assets/models/props/%s.glb" % SCHOONER), 6.2, 0, false)
			var hold := Node3D.new(); hold.transform = Transform3D(xf.basis.orthonormalized(), Vector3(xf.origin.x, 0.0, xf.origin.z)); hold.add_child(w); g.add_child(hold)
			continue
		var scene: PackedScene = load("res://assets/models/props/%s.glb" % m.model)
		if scene == null: continue
		var src := scene.instantiate(); PaperMats.paperize(src, false)
		var meshes := PaperMats._meshes(src)
		if meshes.size() > int(m.mesh):
			var sm: MeshInstance3D = meshes[int(m.mesh)]
			var mi := MeshInstance3D.new(); mi.mesh = sm.mesh
			for s in sm.mesh.get_surface_count(): mi.set_surface_override_material(s, sm.get_surface_override_material(s))
			mi.transform = Homestead._m(m.m); g.add_child(mi)
		src.free()
	return g

func spawn(site: Dictionary) -> void:
	if site.mark == "babe": # a living legend: a big paper puppet grazing on her own
		var pup := Puppet.new("ox", 2.3); pup.group.position = Vector3(site.x, site.y, site.z); add_child(pup.group)
		live[site.key] = {"site": site, "group": pup.group, "puppet": pup}
		return
	var g := _build(site.mark)
	g.position = Vector3(site.x, site.y, site.z); g.rotation.y = site.rot
	add_child(g)
	var l := {"site": site, "group": g}
	if site.mark == "hermit": # old Asa himself, standing by his fire
		var fig := ModelFigure.new("folk_asa"); fig.root.position = Vector3(0.9, 0, 1.9); fig.root.rotation.y = 0.4; g.add_child(fig.root)
		l.figure = fig
	live[site.key] = l
	if CLIMB.has(site.mark) and climbs: climbs.add(site.key, site.x, site.y, site.z, site.rot, BELLE_CLIMB if site.mark == "steamboat" and belle() else (LOOKOUT_CLIMB if site.mark == "lookout" and meshy_lookout() else CLIMB[site.mark]))

func despawn(site: Dictionary) -> void:
	if live.has(site.key): (live[site.key].group as Node).queue_free(); live.erase(site.key)
	if climbs: climbs.remove(site.key)

func radius(kind: String) -> float: return 4.0 if kind == "babe" else float(_model(kind).json.radius)

## Asa idles by his fire; Babe grazes, swishes her tail and turns her head to watch you.
func update(dt: float, camera: Camera3D) -> void:
	var cam := camera.global_position
	for l in live.values():
		if l.has("figure"): l.figure.update(dt, 0.0)
		if l.has("puppet"):
			var p: Vector3 = l.group.position
			l.puppet.update(dt, 0.0, "idle", false, atan2(cam.x - p.x, cam.z - p.z), 0.0)

## Up in the fire lookout's cabin, its roof and the walls' tops above your head are cut away so the camera sees you
## inside (the player couldn't see the farmer once up there); whole again as soon as you're down off its floor.
var _cut_on := false
func cutaway(p: Vector3) -> void:
	for l in live.values():
		if l.site.mark != "lookout" or not meshy_lookout(): continue
		var s: Dictionary = l.site
		var inside: bool = p.y > float(s.y) + 8.0 and Vector2(p.x - s.x, p.z - s.z).length() < 3.2
		if inside == _cut_on and l.has("cut_meshes"): continue
		_cut_on = inside
		if not l.has("cut_meshes"): l.cut_meshes = (l.group as Node).find_children("*", "MeshInstance3D", true, false)
		var v := Vector4(float(s.x), float(s.z), float(s.y) + LOOKOUT_CLIMB.decks[0].y + 1.7, 4.5) if inside else Vector4.ZERO
		for mi in l.cut_meshes: (mi as GeometryInstance3D).set_instance_shader_parameter("cutaway", v)

## The landmark you've just reached for the first time ({site} then it's remembered), or a hint ({site, hint}) when
## Babe wants apples you haven't got (now and then), or null.
func reached(pos: Vector3, inv: Dictionary, r := 7.5):
	for l in live.values():
		var site: Dictionary = l.site
		if found.has(site.key): continue
		if Vector2(pos.x - site.x, pos.z - site.z).length() >= r + radius(site.mark) * (1.0 if site.mark == "babe" else 0.5): continue
		if site.mark == "lookout" and pos.y < site.y + 8.0: continue # (the lookout's view is only had from the top)
		var needs: Dictionary = info[site.mark].get("needs", {})
		var short := false
		for k in needs: if inv.get(k, 0) < needs[k]: short = true
		if short:
			var t := Time.get_ticks_msec()
			if t - hint_at.get(site.key, -1e9) < 60000: continue
			hint_at[site.key] = t; return {"site": site, "hint": true}
		found[site.key] = true
		return {"site": site}
	return null

func save() -> Dictionary: return {"found": found.keys(), "blessed": blessed}
func load_state(d) -> void:
	if d == null: return
	for k in (d if d is Array else d.get("found", [])): found[k] = true
	if d is Dictionary: blessed = d.get("blessed", false)

## Collider circles of a landmark kind at a placement.
static func colliders(mark: String, x: float, z: float, rot: float) -> Array:
	var spec: Array = {"hermit": [[0, -0.6, 1.6]], "babe": [[0, 0, 1.6]], "arch": [[-3.6, 0, 1.3], [3.6, 0, 1.3]], "steamboat": [[-4, 0, 1.6], [-1.5, 0, 1.7], [1, 0, 1.7], [3.5, 0, 1.6], [-5.9, 0, 1.2]],
		"lookout": [[-1.9, -1.9, 0.6], [1.9, -1.9, 0.6], [1.9, 1.9, 0.6], [-1.9, 1.9, 0.6]], "schooner": [[-1, 0, 1.3], [1, 0, 1.3]], "birch": [[0, 0, 0.9]]}.get(mark, [])
	var c := cos(rot); var s := sin(rot)
	return spec.map(func(e): return {"x": x + e[0] * c + e[1] * s, "z": z - e[0] * s + e[1] * c, "r": e[2]})
