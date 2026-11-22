class_name PropKinds
## props.js propKinds(): one card mesh + printed card material per prop kind (and its cuts, "rock~1" etc.). The
## meshes and prints are baked from the running web game (assets/baked/props/<kind>.json + .png; see PORT.md), so
## the silhouettes, crossed slots, rock slabs, the log and the hill sails are exactly the web's. The wind sway and
## snow caps are the material options props.js gives each kind.

const OPTS := {
	"pine": {"sway": 0.006, "snow_cap": 0.8}, "pine~1": {"sway": 0.007, "snow_cap": 0.8}, "pine~2": {"sway": 0.005, "snow_cap": 0.8},
	"maple": {"sway": 0.007, "snow_cap": 0.8}, "goldtree": {"sway": 0.008, "snow_cap": 0.8}, "appletree": {"sway": 0.006, "snow_cap": 0.8},
	"satchel": {"sway": 0.01}, "birch": {"sway": 0.009, "snow_cap": 0.8}, "sagetree": {"sway": 0.006, "snow_cap": 0.8},
	"bush": {"sway": 0.03}, "bush~1": {"sway": 0.03}, "bush~2": {"sway": 0.03},
	"flowers": {"sway": 0.05}, "flowers~1": {"sway": 0.05}, "flowers~2": {"sway": 0.05},
	"sang": {"sway": 0.04}, "stook": {"sway": 0.02}, "cattail": {"sway": 0.05}, "corn": {"sway": 0.03}, "grass": {"sway": 0.09},
}
static var _kinds := {}

## {mesh: ArrayMesh, material: ShaderMaterial} for a kind, loaded on first use (null if it wasn't baked).
static func get_kind(kind: String):
	if _kinds.has(kind): return _kinds[kind]
	var base := "res://assets/baked/props/" + kind.replace("~", "_")
	var f := FileAccess.open(base + ".json", FileAccess.READ)
	if f == null:
		_kinds[kind] = null
		return null
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var tex: Texture2D = load(base + ".png")
	var opts: Dictionary = OPTS.get(kind, {}).duplicate()
	opts["flip"] = d.get("flipY", true)
	var k := {"mesh": mesh_from_arrays(d.pos, d.nor, d.uv), "material": PaperMats.card(tex, opts)}
	_kinds[kind] = k
	return k

## A non-indexed three.js triangle list as a Godot mesh (each triangle's winding reversed: Godot's front faces wind
## clockwise).
static func mesh_from_arrays(p: Array, n: Array, u: Array) -> ArrayMesh:
	var count := p.size() / 3
	var pos := PackedVector3Array(); pos.resize(count)
	var nor := PackedVector3Array(); nor.resize(count)
	var uv := PackedVector2Array(); uv.resize(count)
	for t in count / 3:
		for c in 3:
			var src := t * 3 + c
			var dst := t * 3 + (0 if c == 0 else 3 - c) # (0, 2, 1)
			pos[dst] = Vector3(p[src * 3], p[src * 3 + 1], p[src * 3 + 2])
			nor[dst] = Vector3(n[src * 3], n[src * 3 + 1], n[src * 3 + 2])
			uv[dst] = Vector2(u[src * 2], u[src * 2 + 1])
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos; arrays[Mesh.ARRAY_NORMAL] = nor; arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
