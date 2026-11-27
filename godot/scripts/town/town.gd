class_name Town
extends Node3D
## town.js, part one: Cold Glitter Creek down the lane. A crooked Main Street of false-front buildings (the reference-art
## models, ruined till mended, restored after; the assay office and livery, drawn in one state, stand faded and askew
## till mended), a leaning church at the far end, canvas tents behind, Squatters' Row on the farm side, the assayer on
## his boardwalk with his brass scales and placard, the town sign (its population rising as you mend), the dirt street
## sheet. Mending (E at a door, dollars) rebuilds a building, brings its keeper out with a barrel of flowers, and
## once a street is all mended the next goes up beside it. The street is dressed by what's mended: wagons, a water
## tower, back-lot clutter, the oxen and donkey, hitched horses, door lanterns, bunting, street lamps lit after dark.
## (Part two: the Row's folk and their wants, greetings, the can-can, the lamplighter, the stage, the
## playbill and opera, the dance hall, fireworks, snowmen, Sunday meeting, the raids.)

const HALF := 6.2
const STREET_OFF := 32.0
const BUILDINGS := [
	{"id": "store", "name": "general store", "cost": 25, "w": 7.0, "h": 3.6, "d": 7.0, "side": -1, "s": -12.0},
	{"id": "assay", "name": "assay office", "cost": 15, "w": 4.6, "h": 3.2, "d": 5.0, "side": -1, "s": -3.0},
	{"id": "boarding", "name": "boarding house", "cost": 35, "w": 6.4, "h": 5.6, "d": 6.5, "side": -1, "s": 6.5},
	{"id": "saloon", "name": "Golden Garter saloon", "cost": 30, "w": 6.6, "h": 4.0, "d": 7.0, "side": 1, "s": -11.0},
	{"id": "livery", "name": "livery barn", "cost": 20, "w": 7.4, "h": 4.4, "d": 8.0, "side": 1, "s": -1.0, "barn": true},
	{"id": "smithy", "name": "blacksmith's", "cost": 20, "w": 5.0, "h": 3.4, "d": 5.5, "side": 1, "s": 8.0},
]
static var STREETS := [ # (a static var, not a const: the dance hall's side and place are set as the town is laid out)
	{"id": "second", "name": "Second Street", "buildings": [
		{"id": "bank", "name": "Miners' bank", "model": "hotel", "cost": 40, "w": 6.4, "h": 5.2, "d": 6.5, "side": -1, "s": -12.0},
		{"id": "barber", "name": "barber shop", "model": "assay", "cost": 15, "w": 4.6, "h": 3.2, "d": 5.0, "side": -1, "s": -3.0},
		{"id": "bakery", "name": "bakery", "model": "store", "cost": 25, "w": 7.0, "h": 3.6, "d": 7.0, "side": -1, "s": 7.0},
		{"id": "jail", "name": "sheriff's jail", "model": "blacksmith", "cost": 25, "w": 5.0, "h": 3.4, "d": 5.5, "side": 1, "s": -11.0},
		{"id": "feed", "name": "feed & grain", "model": "livery", "cost": 25, "w": 7.4, "h": 4.4, "d": 8.0, "side": 1, "s": -1.0, "barn": true},
		{"id": "opera", "name": "opera house", "model": "saloon", "cost": 45, "w": 6.6, "h": 4.0, "d": 7.0, "side": 1, "s": 9.0}]},
	{"id": "third", "name": "Third Street", "buildings": [
		{"id": "telegraph", "name": "telegraph office", "model": "assay", "cost": 30, "w": 4.6, "h": 3.2, "d": 5.0, "side": -1, "s": -12.0},
		{"id": "hotel2", "name": "Grand Hotel", "model": "hotel", "cost": 50, "w": 6.4, "h": 5.6, "d": 6.5, "side": -1, "s": -2.0},
		{"id": "drygoods", "name": "dry goods", "model": "store", "cost": 30, "w": 7.0, "h": 3.6, "d": 7.0, "side": -1, "s": 8.0},
		{"id": "cooper", "name": "cooperage", "model": "blacksmith", "cost": 25, "w": 5.0, "h": 3.4, "d": 5.5, "side": 1, "s": -11.0},
		{"id": "stable2", "name": "stage stables", "model": "livery", "cost": 30, "w": 7.4, "h": 4.4, "d": 8.0, "side": 1, "s": -1.0, "barn": true},
		{"id": "dance", "name": "dance hall", "model": "saloon", "cost": 45, "w": 8.6, "h": 4.4, "d": 13.4, "side": 1, "s": 9.4}]},
	# Chinatown (the player's Chinatown set: its four buildings and folk through Meshy), past Second or Third Street; it
	# goes up once Thaddeus Crane's mortgage is burnt (his gate: Boss.SPECS crane street 2). Each uses its own model
	# (bldg_cn_*_restored / _ruined) once it's in, else the nearest old one.
	{"id": "chinatown", "name": "Chinatown", "buildings": [
		{"id": "cn_store", "name": "Chinese general store", "model": "store", "cost": 40, "w": 6.6, "h": 5.0, "d": 7.0, "side": -1, "s": -10.0},
		{"id": "cn_laundry", "name": "Chinese laundry", "model": "store", "cost": 35, "w": 7.4, "h": 3.8, "d": 6.6, "side": -1, "s": 3.0},
		{"id": "cn_herbalist", "name": "herbalist's shop", "model": "assay", "cost": 40, "w": 4.6, "h": 6.0, "d": 6.6, "side": 1, "s": -10.0},
		{"id": "cn_boarding", "name": "Chinese boarding house", "model": "hotel", "cost": 50, "w": 7.4, "h": 5.4, "d": 7.0, "side": 1, "s": 2.0}]},
]
const MODEL_OF := {"smithy": "blacksmith", "saloon": "saloon", "store": "store", "boarding": "hotel", "church": "church", "assay": "assay", "livery": "livery"}
const NIGHT_OWLS := ["saloon", "hotel2"]
const SMOKERS := {"smithy": "day", "bakery": "day", "cooper": "day", "boarding": "meals", "hotel2": "meals"}
## who stands out front of each building once it's mended (at: metres along the boardwalk from the door). "new": a figure of
## their own (the player's 20 new folk, through Meshy), used once its model is in; till then the old one, re-dyed.
const TOWNSFOLK := {
	"store": {"model": "townsfolk_3", "with": [{"model": "townsfolk_4", "at": -2.5, "out": 0.7, "turn": 0.35}]},
	"boarding": {"model": "trades_5", "with": [{"new": "cgc_woman_pinafore", "model": "trades_2", "at": -2.4, "out": 0.6, "turn": 0.3}]},
	"opera": {"new": "cgc_saloon_angel", "model": "saloon_2", "at": 2.0},
	"dance": {"new": "cgc_saloon_burgundy", "model": "saloon_3", "at": 2.4, "pose": "beckon"},
	"saloon": {"at": 2.9, "pose": "beckon", "model": "saloon_1", "with": [{"model": "prospectors_4", "at": -1.7, "out": 0.5, "turn": 0.6}]},
	"livery": {"model": "folk_liveryman", "with": [{"model": "trades_4", "at": -2.7, "out": 0.6, "turn": 0.35}]},
	"smithy": {"pose": "work", "model": "folk_amos", "modelScale": 1.1},
	"stable2": {"model": "folk_silas", "hue": -1.3},
	"cooper": {"model": "folk_ezra", "hue": 1.9, "pose": "work"},
	"drygoods": {"new": "cgc_woman_vest", "model": "townsfolk_1", "hue": -2.2},
	"telegraph": {"new": "cgc_man_glasses", "model": "trades_7", "hue": 2.3},
	"hotel2": {"new": "cgc_man_gent", "model": "prospectors_4", "hue": -0.35},
	"feed": {"new": "cgc_man_suspenders", "model": "prospectors_1", "hue": 0.7},
	"barber": {"new": "cgc_man_goatee", "model": "townsfolk_3", "hue": 2.8},
	"jail": {"new": ["cgc_man_sheriff", "cgc_man_bandana"], "model": "trades_1", "hue": 1.6}, # (the sheriff himself, once in)
	"bank": {"new": "cgc_man_elder", "model": "townsfolk_2"},
	"cn_store": {"new": "cgc_man_cn_elder", "model": "townsfolk_2", "hue": 1.2, "with": [{"new": "cgc_boy_cn", "model": "townsfolk_4", "at": -2.2, "out": 0.6, "turn": 0.4}]},
	"cn_laundry": {"new": "cgc_woman_cn_thin", "model": "trades_6", "hue": 0.9, "with": [{"new": "cgc_man_cn_rust", "model": "trades_1", "at": -2.4, "out": 0.6, "turn": 0.3, "pose": "work"}, {"new": "cgc_woman_cn_curvy", "model": "trades_6", "at": 2.6, "out": 0.5, "turn": -0.35}]},
	"cn_herbalist": {"new": "cgc_man_cn_young", "model": "trades_7", "hue": -0.8, "with": [{"new": "cgc_man_cn_strong", "model": "prospectors_1", "at": -2.6, "out": 0.6, "turn": 0.35}]},
	"cn_boarding": {"new": "cgc_woman_cn_sultry", "model": "trades_2", "hue": 1.4, "with": [{"new": "cgc_man_cn_olive", "model": "prospectors_1", "at": -2.5, "out": 0.6, "turn": 0.35},
		{"new": "cgc_girl_cn", "model": "townsfolk_4", "at": 3.2, "out": 0.5, "turn": -0.4},
		{"new": "trades_3", "model": "trades_3", "at": -4.6, "out": 1.0, "turn": 0.6, "pose": "work"}]}, # (the carpenter with his toolbox, at work on the boarding house's porch)
	"bakery": {"new": "cgc_woman_stripe", "model": "trades_6"},
	"church": {"at": 2.2, "new": "cgc_man_preacher", "model": "trades_1", "with": [{"new": "cgc_woman_preacher_wife", "model": "trades_2", "at": -3.3, "out": 0.6, "turn": -0.3}]}, # (the player's frontier preacher and his prim wife)
}
const MEND_TEXT := {
	"store": "Planks off the windows, a fresh coat of buff paint, a new sign: GENERAL MDSE. The storekeeper sweeps the boardwalk and sets out a barrel of crackers.",
	"assay": "The assay office gets new glass and a coat of oxblood red. The assayer polishes his brass scales and almost smiles.",
	"boarding": "The boarding house is patched and painted blue-grey, every window glazed. Somebody hangs a sign: ROOMS · MEALS.",
	"saloon": "THE GOLDEN GARTER is back in business: fresh red and gold paint, the batwing doors swinging free, a piano being tuned, and a hand-lettered card in the window: \"Can-Can Revue Nightly\".",
	"livery": "The livery barn gets new doors and a whitewashed cross-brace. A mule looks out, unimpressed.",
	"smithy": "The forge is relit and the anvil rings again: the blacksmith's is open for business.",
	"church": "The steeple is set straight and the church is whitewashed till it shines. Sunday, the bell will ring.",
	"church2": "The whole town turns out for the raising. By sundown a proper church stands at the head of Main Street, its bell hung in a tower of its own.",
}
const YARD := {"smithy": ["prop_woodpile", "prop_barrel"], "cooper": ["prop_barrel", "prop_barrel", "prop_woodpile"], "bakery": ["prop_woodpile", "prop_crates"], "livery": ["prop_haybales", "veh_handcart"], "stable2": ["prop_haybale_round", "prop_haybales"], "feed": ["prop_haybales", "prop_crates"], "saloon": ["prop_barrel", "prop_crates", "prop_barrel"]}
const SIZE := {"prop_woodpile": [1.9, 0], "prop_barrel": [0.95, 1], "prop_crates": [1.2, 1], "prop_haybales": [2.2, 0], "prop_haybale_round": [1.3, 1], "veh_handcart": [2.6, 0]}

var world: World
var at := Vector3.ZERO
var along := Vector3.ZERO
var toward := Vector3.ZERO
var y0 := Terrain.STEP * 1.5
var street_offs: Array = []
var tiers := {}
var opened: Array = []
var raided := {}
var parts := {}
var doors := {}
var tents: Array = []
var squat: Array = []
var church_at := Vector3.ZERO
var sign_at := Vector3.ZERO
var sign: Node3D
var folk := {}
var lamps := {}
var hitch := {}
var beasts: Array = []
var street: Array = []
var street_cols: Array = []
var chimneys: Array = []
var street_lamps: Array = []
var assayer: ModelFigure
var lit = null
var far := false
var cam_pos = null
var player_pos = null
var bedtime := false
var raining := false
var clock := 0.5
var day := 0
var on_street: Callable
var gate: Callable    ## (street index) -> may it go up now?
var on_gate: Callable ## (street index): it's ready but held back
var on_gossip: Callable ## (keeper id): the first greeting of the day from a keeper; main may add a word about the bosses
var gated: Array = []
static var tent_mats: Array = []
static var glass_mat: StandardMaterial3D
static var lamp_glass: Array = []

static func hash_id(id: String) -> int:
	var h := 7
	for c in id: h = (h * 31 + c.unicode_at(0)) & 0xFFFFFFFF
	return h

static func _mat(hex: int) -> Material: return PaperMats.paper(Color.hex((hex << 8) | 0xff))
static func box(w: float, h: float, d: float, hex: int) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = Vector3(w, h, d)
	var m := MeshInstance3D.new(); m.mesh = b; m.material_override = _mat(hex); return m
## beams2: a post (or posts) at each x, 1.4 m tall.
## A board on one of the player's Meshy posts (the signposts, the wide two-post sign): the model standing h tall, and
## the printed board tex fitted to the model's own board (measured off it: the part of it from 50% to 85% of its
## height, between its post(s)), on its front and back. null if the model isn't in (the caller keeps its own).
## words: lettered in type instead of keyed out of the print (a print too dark to key, the Row's).
static func board_post(model_name: String, h: float, tex: String, aspect: float, words := "") -> Node3D:
	var m := model(model_name, h, 1)
	if m == null: return null
	var g := Node3D.new(); g.add_child(m)
	# the painted (whitewashed) patch on the model's own board, front and back: the triangles facing out whose texture
	# under them is pale (the player: the lettering goes on the white board, not on a board of its own below it)
	var img := _model_image(model_name)
	var fronts: Array = [[], []] # per side: [x, y, z] of each pale triangle's middle
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var xf := Railroad._rel(mi as MeshInstance3D, g)
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var UV = arr[Mesh.ARRAY_TEX_UV]; var I = arr[Mesh.ARRAY_INDEX]
			if img == null or UV == null or (UV as PackedVector2Array).size() != V.size(): continue
			var n_tri: int = (I.size() if I != null and I.size() else V.size()) / 3
			for t in n_tri:
				var ia: int = I[t * 3] if I != null and I.size() else t * 3
				var ib: int = I[t * 3 + 1] if I != null and I.size() else t * 3 + 1
				var ic: int = I[t * 3 + 2] if I != null and I.size() else t * 3 + 2
				var a := xf * V[ia]; var b := xf * V[ib]; var c := xf * V[ic]
				var mid := (a + b + c) / 3.0
				if mid.y < h * 0.3: continue
				var nrm := (b - a).cross(c - a)
				if nrm.length_squared() < 1e-12: continue
				nrm = nrm.normalized()
				if absf(nrm.z) < 0.75: continue
				var uv: Vector2 = (UV[ia] + UV[ib] + UV[ic]) / 3.0
				var px := img.get_pixel(clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1), clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
				if px.get_luminance() < 0.66: continue
				fronts[0 if nrm.z > 0.0 else 1].append(mid)
	# every triangle of the model, for what stands in front of the board (a post, a long thin brace)
	var tris: Array = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var xf2 := Railroad._rel(mi as MeshInstance3D, g)
		var mesh2 := (mi as MeshInstance3D).mesh
		for si in mesh2.get_surface_count():
			var arr2 := mesh2.surface_get_arrays(si)
			var V2: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]; var I2 = arr2[Mesh.ARRAY_INDEX]; var U2 = arr2[Mesh.ARRAY_TEX_UV]
			var idx: bool = I2 != null and I2.size() > 0
			var has_uv: bool = img != null and U2 != null and (U2 as PackedVector2Array).size() == V2.size()
			for t in (I2.size() if idx else V2.size()) / 3:
				var i0: int = I2[t * 3] if idx else t * 3; var i1: int = I2[t * 3 + 1] if idx else t * 3 + 1; var i2: int = I2[t * 3 + 2] if idx else t * 3 + 2
				var pale := false
				if has_uv:
					var uv: Vector2 = (U2[i0] + U2[i1] + U2[i2]) / 3.0
					pale = img.get_pixel(clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1), clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1)).get_luminance() >= 0.66
				tris.append([xf2 * V2[i0], xf2 * V2[i1], xf2 * V2[i2], pale])
	var ink := _ink_tex(tex)
	var side_rects: Array = []
	for k in 2:
		var P: Array = fronts[k]
		if P.size() < 6: side_rects.append(null); continue
		# the board: the band of heights where the pale triangles crowd thickest (a light post or brace below doesn't count)
		var bins := {}; var bin := h * 0.025
		for q in P: var bi := int(q.y / bin); bins[bi] = bins.get(bi, 0) + 1
		var peak: int = bins.keys()[0]
		for bi in bins: if bins[bi] > bins[peak]: peak = bi
		var lo_b := peak; var hi_b := peak
		var keep := func(bi: int) -> bool: return bins.get(bi, 0) > bins[peak] * 0.1
		while keep.call(lo_b - 1) or keep.call(lo_b - 2) or keep.call(lo_b - 3): lo_b -= 1
		while keep.call(hi_b + 1) or keep.call(hi_b + 2) or keep.call(hi_b + 3): hi_b += 1
		var B := P.filter(func(q): return q.y >= lo_b * bin and q.y < (hi_b + 1) * bin)
		var xs := B.map(func(q): return q.x); var ys := B.map(func(q): return q.y); var zs := B.map(func(q): return q.z)
		xs.sort(); ys.sort(); zs.sort()
		var n := B.size()
		side_rects.append({"x0": xs[int(n * 0.03)], "x1": xs[int(n * 0.97)], "y0": ys[int(n * 0.03)], "y1": ys[int(n * 0.97)], "z": zs[n - 1] if k == 0 else zs[0]})
	if side_rects[0] == null and side_rects[1] == null: return _board_post_card(g, m, h, tex, aspect) # (no white patch found: the printed card as before)
	if side_rects[0] == null: side_rects[0] = side_rects[1].duplicate(); side_rects[0].z = -side_rects[1].z
	if side_rects[1] == null: side_rects[1] = side_rects[0].duplicate(); side_rects[1].z = -side_rects[0].z
	var ia2: float = float(ink.get_width()) / ink.get_height()
	for k in 2:
		var r: Dictionary = side_rects[k]
		# whatever stands proud of the board on this side across the lettering's band (the post, a brace): letter the
		# longest clear stretch between them (the player: the brace ran across the end of the words)
		var NB := 48; var busy := []; busy.resize(NB); busy.fill(false)
		var ym0: float = lerpf(r.y0, r.y1, 0.2); var ym1: float = lerpf(r.y0, r.y1, 0.8)
		for tr in tris:
			var a0: Vector3 = tr[0]; var a1: Vector3 = tr[1]; var a2: Vector3 = tr[2]
			var zc := (a0.z + a1.z + a2.z) / 3.0
			var proud: bool = (k == 0 and zc > float(r.z) + 0.02) or (k == 1 and zc < float(r.z) - 0.02)
			var ty0 := minf(a0.y, minf(a1.y, a2.y)); var ty1 := maxf(a0.y, maxf(a1.y, a2.y))
			if not proud: continue
			if ty1 < ym0 or ty0 > ym1: continue
			var tx0 := minf(a0.x, minf(a1.x, a2.x)); var tx1 := maxf(a0.x, maxf(a1.x, a2.x))
			if tx1 < r.x0 or tx0 > r.x1: continue
			for bi in range(clampi(int((tx0 - r.x0) / (r.x1 - r.x0) * NB), 0, NB - 1), clampi(int((tx1 - r.x0) / (r.x1 - r.x0) * NB), 0, NB - 1) + 1): busy[bi] = true
		if OS.get_environment("SIGN_DBG") != "": print("%s side %d: rect x %.2f..%.2f y %.2f..%.2f z %.3f busy %s" % [model_name, k, r.x0, r.x1, r.y0, r.y1, r.z, "".join(busy.map(func(v): return "#" if v else "."))])
		var best0 := 0; var best_n := 0; var run0 := 0; var run_n := 0
		for i in NB:
			if busy[i]: run_n = 0; run0 = i + 1; continue
			run_n += 1
			if run_n > best_n: best_n = run_n; best0 = run0
		if best_n < NB and best_n >= NB * 0.3:
			var bw: float = (r.x1 - r.x0) / NB; r = r.duplicate()
			var nx0: float = r.x0 + (best0 + (0.5 if best0 > 0 else 0.0)) * bw; var nx1: float = r.x0 + (best0 + best_n - (0.5 if best0 + best_n < NB else 0.0)) * bw
			# (a signpost's brace runs up from the post to the board beside it: keep clear of the stretch nearest the post)
			var trim: float = (nx1 - nx0) * 0.25
			if best0 == 0: nx1 -= trim
			elif best0 + best_n >= NB: nx0 += trim
			r.x0 = nx0; r.x1 = nx1
			# and its height, from the painted facets over that stretch alone: where they crowd thickest (the board, not a
			# light brace or post below it)
			var B2: Array = fronts[k].filter(func(q): return q.x >= nx0 and q.x <= nx1)
			if B2.size() > 12:
				var bins2 := {}; var bsz := h * 0.02
				for q in B2: var bi2 := int(q.y / bsz); bins2[bi2] = bins2.get(bi2, 0) + 1
				var pk: int = bins2.keys()[0]
				for bi2 in bins2: if bins2[bi2] > bins2[pk]: pk = bi2
				var lo2 := pk; var hi2 := pk
				while bins2.get(lo2 - 1, 0) > bins2[pk] * 0.3 or bins2.get(lo2 - 2, 0) > bins2[pk] * 0.3: lo2 -= 1
				while bins2.get(hi2 + 1, 0) > bins2[pk] * 0.3 or bins2.get(hi2 + 2, 0) > bins2[pk] * 0.3: hi2 += 1
				r.y0 = lo2 * bsz; r.y1 = (hi2 + 1) * bsz
		var rw: float = r.x1 - r.x0; var rh: float = r.y1 - r.y0
		var w := minf(rw * 0.86, rh * 0.8 * ia2); var ht := w / ia2
		if words != "":
			var lb := Label3D.new(); lb.text = words
			var f := SystemFont.new(); f.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"]); f.font_weight = 700; f.font_italic = true
			lb.font = f; lb.font_size = 96; lb.outline_size = 0; lb.modulate = Color("2e2218")
			lb.shaded = true; lb.double_sided = false; lb.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			var tw: float = f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
			lb.pixel_size = minf(rw * 0.84 / maxf(tw, 1.0), rh * 0.62 / 96.0)
			lb.position = Vector3((r.x0 + r.x1) / 2.0, (r.y0 + r.y1) / 2.0, float(r.z) + (0.008 if k == 0 else -0.008)); lb.rotation.y = 0.0 if k == 0 else PI
			g.add_child(lb); continue
		var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(w, ht); q.mesh = qm
		q.material_override = _ink_mat(tex, ink)
		q.position = Vector3((r.x0 + r.x1) / 2.0, (r.y0 + r.y1) / 2.0, float(r.z) + (0.008 if k == 0 else -0.008))
		q.rotation.y = 0.0 if k == 0 else PI
		g.add_child(q)
	return g

## The sign as it was before the white patch was read: a printed card sized to the board, front and back.
static func _board_post_card(g: Node3D, m: Node3D, h: float, tex: String, aspect: float) -> Node3D:
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var xf := Railroad._rel(mi as MeshInstance3D, g)
		var verts: PackedVector3Array = (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0, verts.size(), 2):
			var q := xf * verts[i]
			if q.y > h * 0.5 and q.y < h * 0.86: lo = lo.min(q); hi = hi.max(q)
	if lo.x == INF: return g
	var bw := hi.x - lo.x; var bh := (hi.y - lo.y) * 0.7
	var w := minf(bw * 0.8, bh * aspect); var ht := w / aspect
	var c := Vector3((lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0, 0.0)
	for back in [false, true]:
		var cd := card([[-w / 2.0, 0], [w / 2.0, 0], [w / 2.0, ht], [-w / 2.0, ht]], tex, 0.015)
		cd.position = Vector3(c.x, c.y - ht / 2.0, (lo.z - 0.012) if back else (hi.z + 0.012)); cd.rotation.y = PI if back else 0.0; g.add_child(cd)
	return g

static var _img_cache := {}
## The model's own texture (its baked colour map), to read what's painted where.
static func _model_image(model_name: String) -> Image:
	if _img_cache.has(model_name): return _img_cache[model_name]
	var img: Image = null
	var path := "res://assets/models/props/%s_Image_0.jpg" % model_name
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
		if img != null and img.is_compressed(): img.decompress()
	_img_cache[model_name] = img
	return img

static var _ink_cache := {}
## Just the ink of a printed sign (its lettering), the paper and its ruled frame let go, to letter straight onto a board.
static func _ink_tex(tex: String) -> ImageTexture:
	if _ink_cache.has(tex): return _ink_cache[tex]
	var src: Image = (load(tex + ".png" if tex.begins_with("res://") else "res://assets/baked/town/%s.png" % tex) as Texture2D).get_image()
	if src.is_compressed(): src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var W := src.get_width(); var H := src.get_height()
	var mx := int(W * 0.05); var my := int(H * 0.12) # (inside the ruled frame)
	var img := Image.create(W - mx * 2, H - my * 2, false, Image.FORMAT_RGBA8)
	# the paper's own shade, from a band near the top inside the frame
	var bg := 0.0; var nb := 0
	for x in range(mx, W - mx, 7): bg += src.get_pixel(x, my + 2).get_luminance(); nb += 1
	bg /= maxf(1, nb)
	for y in img.get_height():
		for x in img.get_width():
			var c := src.get_pixel(x + mx, y + my)
			var a := clampf((bg - 0.1 - c.get_luminance()) / 0.22, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r * 0.8, c.g * 0.8, c.b * 0.8, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_ink_cache[tex] = t
	return t

static var _ink_mats := {}
static func _ink_mat(tex: String, ink: Texture2D) -> Material:
	if _ink_mats.has(tex): return _ink_mats[tex]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ink; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; mat.alpha_scissor_threshold = 0.45
	mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	mat.roughness = 1.0; mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_ink_mats[tex] = mat
	return mat

static func posts(xs: Array) -> Node3D:
	var g := Node3D.new()
	for x in xs: var p := box(0.16, 1.4, 0.16, 0x6a4a30); p.position = Vector3(x, 0.7, -0.06); g.add_child(p)
	return g
## A printed town card (town.js card()): the baked print, a plain back sampling the board swatch in the corner.
static func card(pts: Array, tex_name: String, thick := 0.08, snow := 1.0) -> MeshInstance3D:
	var P := PackedVector2Array()
	var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
	for q in pts: P.append(Vector2(q[0], q[1])); mn = mn.min(P[-1]); mx = mx.max(P[-1])
	var tex: Texture2D = load(tex_name + ".png" if tex_name.begins_with("res://") else "res://assets/baked/town/%s.png" % tex_name)
	var w0 := mx - mn
	var back := Vector2(mn.x - w0.x * 0.04 + (6.0 / tex.get_width()) * w0.x * 1.08, mx.y + w0.y * 0.04 - (6.0 / tex.get_height()) * w0.y * 1.08)
	var m := MeshInstance3D.new(); m.mesh = CardMesh.build(P, thick, back)
	m.material_override = PaperMats.card(tex, {"flip": true, "snow": snow})
	return m

## A full-bleed printed board (a canvas the web shows edge to edge on a box face: signs, painted boards) as a card w
## wide and h tall, its foot at y 0: the print is padded out so CardMesh's 4% margin lands on the board's edge.
static func board(w: float, h: float, tex_path: String, thick := 0.05) -> MeshInstance3D:
	var img := (load(tex_path + ".png") as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var iw := img.get_width(); var ih := img.get_height()
	var ox := roundi(iw * 0.04); var oy := roundi(ih * 0.04)
	var out := Image.create(iw + ox * 2, ih + oy * 2, false, Image.FORMAT_RGBA8); out.fill(img.get_pixel(1, 1))
	out.blit_rect(img, Rect2i(0, 0, iw, ih), Vector2i(ox, oy)); out.generate_mipmaps()
	var P := PackedVector2Array([Vector2(-w / 2, 0), Vector2(w / 2, 0), Vector2(w / 2, h), Vector2(-w / 2, h)])
	var m := MeshInstance3D.new(); m.mesh = CardMesh.build(P, thick, Vector2(-w / 2 - w * 0.03, h + h * 0.03))
	m.material_override = PaperMats.card(ImageTexture.create_from_image(out), {"flip": true, "snow": 0.0})
	return m

## A reference-art model scaled to size along axis (0 x, 1 y, 2 z), centred, feet at 0.
static func model(name: String, size: float, axis: int) -> Node3D:
	var path := "res://assets/models/props/%s.glb" % name
	if not ResourceLoader.exists(path): return null
	return PaperMats.seated_axis(load(path), size, axis)

func _init(w: World, home: Vector3) -> void:
	world = w
	var rng := PNoise.Mulberry32.new(919)
	# the site: about 85 m off, dry and in the home county, the street running across the way from the farm
	var best = null
	for k in 36:
		var a := (k / 36.0) * TAU; var x := home.x + cos(a) * 85.0; var z := home.z + sin(a) * 85.0
		Terrain.land_at(x, z)
		var reg := Terrain.region_at(x, z)
		var ok := Terrain.L_wild < 0.3 and reg != "highland" and reg != "peak"
		for j in 16:
			if not ok: break
			var b := (j / 16.0) * TAU
			for r in [8.0, 16.0, 26.0]:
				var xx: float = x + cos(b) * r; var zz: float = z + sin(b) * r
				if Terrain.is_water(xx, zz) or Terrain.region_at(xx, zz) == "water": ok = false
		if ok: best = Vector3(x, 0, z); break
	if best == null: best = Vector3(home.x + cos(0.8) * 85.0, 0, home.z + sin(0.8) * 85.0)
	at = best
	Terrain.add_flat_area(at.x, at.z, 30, 42) # (the town stands on its own level sheet)
	world.exclusions.append({"x": at.x, "z": at.z, "r": 31.0})
	along = Vector3(at.x - home.x, 0, at.z - home.z).normalized(); toward = Vector3(-along.z, 0, along.x)
	# the new streets' lots, levelled and kept clear from the start, on whichever side of Main Street has room
	var ok_side := func(side: int) -> bool:
		for sv in [-20, -10, 0, 10, 20]:
			for cv in [-10, 0, 10]:
				var q: Vector3 = at + along * sv + toward * (side * STREET_OFF + cv)
				if Terrain.is_water(q.x, q.z) or Terrain.range_at(q.x, q.z) >= 0.002: return false
		return true
	var sides := [1, -1].filter(func(sd): return ok_side.call(sd))
	for i in STREETS.size():
		if i < 2: street_offs.append(float(sides[i] if i < sides.size() else ((-sides[0]) if sides.size() else (-1 if i else 1))) * STREET_OFF); continue
		# a third new street (Chinatown) a row further out, beyond whichever of the first two has room
		var far_off := 0.0
		for k in [0, 1]:
			var o: float = street_offs[k] * 2.0 + (signf(street_offs[k]) * 18.0 if k == 1 else 0.0) # (beyond Third Street, past the dance hall's deep back)
			var fine := true
			for sv in [-20, 0, 20]:
				for cv in [-10, 0, 10]:
					var q: Vector3 = at + along * sv + toward * (o + cv)
					if Terrain.is_water(q.x, q.z) or Terrain.range_at(q.x, q.z) >= 0.002: fine = false
			if fine: far_off = o; break
		street_offs.append(far_off if far_off != 0.0 else street_offs[0] * 2.0)
	# the dance hall (the player's big open-fronted hall, ~17 m deep) goes on the side of its street that backs onto open
	# country, never onto Main Street's backs: 10.6 m along where that's side 1, else 18 m along on the other side
	var dh := find_b("dance"); var dk := street_of("dance")
	if not dh.is_empty() and dk >= 0:
		if street_offs[dk] > 0.0: dh.side = 1; dh.s = 9.4
		else: dh.side = -1; dh.s = 16.8
		# (its whole footprint levelled and kept clear of trees and rocks: it reaches past the street's own flats)
		var hc: Vector3 = at + along * float(dh.s) + toward * (street_offs[dk] + float(dh.side) * (HALF + float(dh.d) / 2.0))
		Terrain.add_flat_area(hc.x, hc.z, 11.0, 17.0)
		for u in [-0.5, -0.17, 0.17, 0.5]:
			for v in [-0.5, -0.17, 0.17, 0.5]:
				var q: Vector3 = hc + along * (u * float(dh.w)) + toward * (float(dh.side) * v * float(dh.d))
				world.exclusions.append({"x": q.x, "z": q.z, "r": 4.2})
	# the cross streets at either end (the player: not just rows), their whole run levelled and kept clear from the start
	var omin := 0.0; var omax := 0.0
	for off in street_offs: omin = minf(omin, off); omax = maxf(omax, off)
	for cs in [CROSS_N, CROSS_S]:
		var o := omin - 8.0
		while o <= omax + 8.0:
			var q: Vector3 = at + along * cs + toward * o
			Terrain.add_flat_area(q.x, q.z, 7, 13); world.exclusions.append({"x": q.x, "z": q.z, "r": 6.5}); o += 8.0
	var mo := -38.0
	while mo <= 38.0: # (just the market row's own ground, by the north cross street: level and clear of brush; the land behind left be)
		var q: Vector3 = at + along * (MARKET_S - 0.8) + toward * mo
		Terrain.add_flat_area(q.x, q.z, 3.6, 5.2); world.exclusions.append({"x": q.x, "z": q.z, "r": 3.6})
		mo += 5.0
	for off in street_offs:
		for sv in [-16, 0, 16]:
			var q: Vector3 = at + along * sv + toward * off
			Terrain.add_flat_area(q.x, q.z, 16, 24); world.exclusions.append({"x": q.x, "z": q.z, "r": 17.0})
	# Main Street's buildings, run-down
	for b in BUILDINGS:
		var g := building(b, 0); var p := place(g, b.s, b.side); parts[b.id] = g
		doors[b.id] = p - toward * b.side * 1.6 # (on the boardwalk before the door)
		_colliders(b, 0.0, true)
	# the assayer on his boardwalk, the brass scales at his elbow, the placard on its post
	var d: Vector3 = doors.assay; var face := atan2(toward.x, toward.z)
	var ap: Vector3 = d + along * 1.6 - toward * 0.35
	assayer = ModelFigure.new("trades_7"); assayer.root.position = Vector3(ap.x, y0 + 0.14, ap.z); assayer.root.rotation.y = face; add_child(assayer.root)
	var tbl := Node3D.new(); var bench := model("mine_scales", 1.35, 0)
	if bench: bench.rotation.y = PI; tbl.add_child(bench)
	var tp: Vector3 = d + along * 1.6 + toward * 0.45; tbl.position = Vector3(tp.x, y0 + 0.14, tp.z); tbl.rotation.y = face; add_child(tbl)
	var pp: Vector3 = d - along * 1.7 + toward * 1.0
	var pg := board_post("prop_signpost_small", 2.0, "placard", 2.0) # (the player's signpost)
	if pg == null: pg = Node3D.new(); var plac := card([[-0.62, 0], [0.64, 0.03], [0.6, 0.62], [-0.64, 0.6]], "placard"); plac.position.y = 1.15; plac.rotation.z = 0.04; pg.add_child(plac); pg.add_child(posts([0.0]))
	pg.position = Vector3(pp.x, y0, pp.z); pg.rotation.y = face; add_child(pg)
	# the church closes the far end of the street, facing back down it
	var ch := church(0); church_at = at + along * CHURCH_S # (forward enough that the bigger church, raised in its place front to front, clears the cross street behind)
	ch.position = Vector3(church_at.x, y0, church_at.z); ch.rotation.y = atan2(-along.x, -along.z); add_child(ch); parts.church = ch
	for t in [-0.2, 0.2]: world.colliders.append({"x": church_at.x + along.x * 4.0 + toward.x * t * 10.0, "z": church_at.z + along.z * 4.0 + toward.z * t * 10.0, "r": 3.0})
	doors.church = church_at - along * 1.5
	# tents behind the buildings, where the poorer folk live
	for e in [[-6, -1], [2, 1], [12, -1], [14, 1]]:
		var t := tent(rng); var p := place(t, e[0], e[1], 9.5); t.rotation.y += (rng.next() - 0.5) * 0.5; tents.append(p)
		world.colliders.append({"x": p.x + toward.x * e[1] * 2.6, "z": p.z + toward.z * e[1] * 2.6, "r": 1.6})
	# Squatters' Row: a ragged lane of patched tents on the farm side, where most of the folk who'll work for you live
	var row_c: Vector3 = at + along * -47.0
	Terrain.add_flat_area(row_c.x, row_c.z, 11, 17); world.exclusions.append({"x": row_c.x, "z": row_c.z, "r": 13.0})
	for side in [-1, 1]: var q: Vector3 = row_c + toward * side * 12.0; Terrain.add_flat_area(q.x, q.z, 10, 15); world.exclusions.append({"x": q.x, "z": q.z, "r": 11.0})
	for s in [-38.5, -43.0, -47.5, -52.0, -56.5]: # (the first a step back: the south cross street runs where it stood)
		for side in [-1, 1]:
			var p0: Vector3 = at + along * s + toward * side * 5.4
			if Terrain.is_water(p0.x, p0.z): continue
			var hut := tent(rng); var p := place(hut, s, side, -0.8); hut.rotation.y += (rng.next() - 0.5) * 0.35
			squat.append(p - toward * side * 1.5) # (a spot out front, by the cookfire)
			world.colliders.append({"x": p.x + toward.x * side * 1.2, "z": p.z + toward.z * side * 1.2, "r": 1.5})
	# the Row's own people (the player's gaunt townsfolk in rags): about the cookfires from the start, beside the spots
	# where settlers who come to live here will stand
	var rag := ["cgc_man_gaunt_old", "cgc_woman_gaunt_elder", "cgc_man_gaunt_young", "cgc_woman_gaunt_young", "cgc_woman_gaunt_redhead"]
	var ri := 0
	for nm in rag:
		if ri >= squat.size() or not ModelFigure.has_folk(nm): continue
		var q: Vector3 = squat[ri * 2 % squat.size()] + along * 1.7
		var side := 1.0 if (q - at).dot(toward) > 0.0 else -1.0
		var f := ModelFigure.new(nm); f.t = ri * 1.3
		var rface := atan2(-toward.x * side, -toward.z * side) + (rng.next() - 0.5) * 0.8 # (toward the lane, give or take)
		f.root.position = Vector3(q.x, y0, q.z); f.root.rotation.y = rface; add_child(f.root)
		folk["row_%d" % ri] = {"fig": f, "pose": null, "face": rface}
		ri += 1
	var sp: Vector3 = at + along * -31.0 + toward * -3.6
	var sg := board_post("prop_signpost_long", 2.6, "rowsign", 3.56, "Squatters' Row")
	if sg == null: sg = Node3D.new(); var rs := card([[-1.0, 0], [1.05, 0.05], [1.0, 0.5], [-1.05, 0.48]], "rowsign"); rs.position.y = 1.1; rs.rotation.z = -0.06; sg.add_child(rs); sg.add_child(posts([0.0]))
	sg.position = Vector3(sp.x, y0, sp.z); sg.rotation.y = atan2(-along.x, -along.z); add_child(sg)
	# the dirt street: a long torn sheet of ochre with wheel ruts
	var holder := street_sheet("street_main"); holder.position = Vector3(at.x, y0 + 0.03, at.z); add_child(holder)
	for cs in [CROSS_N, CROSS_S]: cross_sheet(-7.0, 7.0, cs) # (the crossings at Main Street's two ends)
	sign_at = at + along * -34.5 + toward * 5.5 # (at the corner, clear of the cross street)
	make_sign()
	dress_street()
	market_refresh()

## The cross streets (the player: cross streets at each end): at CROSS_N beyond the church's back and CROSS_S
## before Squatters' Row, run across the town; each new street adds its stretch out from its neighbour, and the
## railroad the last stretch out to the depot. Torn ochre sheets like the streets, in pieces of at most 40 m.
const CROSS_N := 36.0 # (behind the church's back: at 31 the player found the church standing in it)
const CROSS_S := -29.0
const CROSS_HW := 4.6 ## (half its width; its sides straight, where the streets end flush against them)
func cross_sheet(o0: float, o1: float, cs: float) -> void:
	var a := minf(o0, o1); var b := maxf(o0, o1)
	var n := maxi(1, ceili((b - a) / 40.0)); var L := (b - a) / n
	for i in n:
		var mid := a + L * (i + 0.5)
		var hl := L / 2.0 # (pieces end to end, flush; straight sides at the streets' ends)
		var sheet := card([[-CROSS_HW, -hl], [CROSS_HW, -hl], [CROSS_HW, hl], [-CROSS_HW, hl]], "street_new", 0.03, 0.45)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; sheet.rotation.x = -PI / 2.0
		var holder := Node3D.new(); holder.add_child(sheet); holder.rotation.y = atan2(toward.x, toward.z)
		var p: Vector3 = at + along * cs + toward * mid; holder.position = Vector3(p.x, y0 + 0.03, p.z); add_child(holder) # (level with the streets)

## Place obj at s along the street, side ±1, facing the street's centre line (street: its offset across from Main).
func place(obj: Node3D, s: float, side: int, offset := 0.0, street_off := 0.0) -> Vector3:
	var p: Vector3 = at + along * s + toward * (street_off + side * (HALF + offset))
	obj.position = Vector3(p.x, y0, p.z); obj.rotation.y = atan2(-side * toward.x, -side * toward.z)
	add_child(obj)
	return p

func _colliders(b: Dictionary, off: float, two: bool) -> void:
	if b.id == "dance" and ResourceLoader.exists("res://assets/models/props/bldg_saloon2_ruined.glb"): _hall_colliders(b, off); return
	var n := ceili(b.w / 2.4)
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var c: Vector3 = at + along * (b.s + t * b.w) + toward * (off + b.side * (HALF + b.d / 2.0))
		var r := minf(b.d, 2.6) / 2.0 + 0.3
		world.colliders.append({"x": c.x, "z": c.z, "r": r})
		if two: world.colliders.append({"x": c.x + toward.x * b.side * b.d * 0.3, "z": c.z + toward.z * b.side * b.d * 0.3, "r": r})

func street_sheet(tex: String) -> Node3D:
	# (it ends square at the cross streets' near edges, flush with them: no overlap to flicker, the player saw)
	var e0 := -(CROSS_N - CROSS_HW); var e1 := -(CROSS_S + CROSS_HW) # (the card's +y runs down -along once laid flat and turned)
	var sheet := card([[-4.6, e0], [4.6, e0], [5.2, -10], [4.4, 8], [4.6, e1], [-4.6, e1], [-4.2, 10], [-5.0, -9]], tex, 0.03, 0.45)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; sheet.rotation.x = -PI / 2.0
	var holder := Node3D.new(); holder.add_child(sheet); holder.rotation.y = atan2(along.x, along.z)
	return holder

## The building in its tier: the model (its own, or a Main Street one in a new trade) on the boardwalk planks.
func building(b: Dictionary, tier: int) -> Node3D:
	var own_name: String = b.id if (b.has("model") and ResourceLoader.exists("res://assets/models/props/bldg_%s_ruined.glb" % b.id)) else b.get("model", MODEL_OF.get(b.id, ""))
	if b.id == "dance" and ResourceLoader.exists("res://assets/models/props/bldg_saloon2_ruined.glb"): own_name = "saloon2" # (the player's open-fronted hall with its stage: the dance hall)
	var g := model_building(own_name, tier, b.w + 0.4, b.h + (1.8 if b.get("barn", false) else 1.5))
	if own_name == "saloon2": for c in g.get_children(): (c as Node3D).position.y -= HALL_SINK * hall_k() # (its floor at the ground you walk on)
	var walk := box(b.w + 0.6, 0.14, 1.8, 0xa8845a if tier else 0x8a7458); walk.position = Vector3(0, 0.07, 0.95); g.add_child(walk)
	return g

## modelBuilding: the ruined or restored model (or the one-state model, faded and askew till mended), its body as
## wide as the false front it stands in for, no taller than that front, its front to the street.
static func model_building(mname: String, tier: int, width: float, height: float) -> Node3D:
	var two := "res://assets/models/props/bldg_%s_%s.glb" % [mname, "restored" if tier else "ruined"]
	var one := "res://assets/models/props/bldg_%s.glb" % mname
	var path := two if ResourceLoader.exists(two) else one
	var g := Node3D.new()
	var m := (load(path) as PackedScene).instantiate() as Node3D
	PaperMats.paperize(m)
	if path == one and not tier: # (faded: greyed and darkened, a touch askew)
		for mi in PaperMats._meshes(m):
			for s in mi.mesh.get_surface_count():
				var c := (mi.get_surface_override_material(s) as ShaderMaterial).duplicate() as ShaderMaterial
				c.set_shader_parameter("faded", 1.0); mi.set_surface_override_material(s, c)
	var bb := PaperMats._aabb(m, Transform3D.IDENTITY)
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.replace(".glb", ".json")))
	var body: Dictionary = info.get("body", {})
	var k := minf(width * 1.15 / float(body.get("x", bb.size.x)), height / bb.size.y)
	var hold := Node3D.new(); hold.add_child(m)
	hold.scale = Vector3.ONE * k
	hold.position = Vector3(-float(body.get("cx", bb.position.x + bb.size.x / 2.0)) * k, -bb.position.y * k, -(bb.position.z + bb.size.z) * k + 0.5)
	if path == one and not tier: hold.rotation.z = 0.015
	g.add_child(hold)
	return g

func church(tier: int) -> Node3D:
	if tier and tiers.get("church2", 0) and ResourceLoader.exists("res://assets/models/props/bldg_church2_restored.glb"): return model_building("church2", 1, CHURCH2_W, 10.0)
	return model_building("church", tier, 5.6, 10.0)
## The new church (the player's bigger church with its bell tower): once the old one's mended, $120 puts it up in its
## place, its front a few paces further down Main Street (it's twice as long), the preacher and his wife at its door.
const CHURCH2_W := 6.2
const CHURCH_S := 13.3
const CHURCH2_COST := 120
## The church's front and back along Main Street (x, y).
func _church_span() -> Vector2:
	var cg: Node3D = parts.church; var cbb := PaperMats._aabb(cg, Transform3D.IDENTITY); var lo := 1e9; var hi := -1e9
	for i in 8: var d: float = (cbb.get_endpoint(i) - at).dot(along); lo = minf(lo, d); hi = maxf(hi, d)
	return Vector2(lo, hi)
func _church2_door() -> Vector3:
	# (in the church's own frame its front is +z, toward the street: the step before it, 1.4 m out)
	var g: Node3D = parts.church; var bb := PaperMats._aabb(g, g.transform.affine_inverse()) # (_aabb takes in the node's own transform: undone, its own frame)
	var p: Vector3 = g.transform * Vector3(0, 0, bb.end.z + 1.4)
	return Vector3(p.x, church_at.y, p.z)

## The patched wall tent from the reference art (each a little bigger or smaller), lit from within after dark.
func tent(rng: PNoise.Mulberry32) -> Node3D:
	var g := Node3D.new()
	var k := (2.6 + rng.next()) * 1.5
	var m := model("prop_tent", k, 0)
	if m:
		for mi in PaperMats._meshes(m):
			for s in mi.mesh.get_surface_count():
				var c := (mi.get_surface_override_material(s) as ShaderMaterial).duplicate() as ShaderMaterial
				mi.set_surface_override_material(s, c); tent_mats.append(c)
		g.add_child(m)
	return g

## The town sign by the lane, facing the farm; its population rises as the town is mended.
func make_sign() -> void:
	if sign: sign.queue_free()
	var mended := tiers.values().filter(func(v): return v).size()
	var sg := Node3D.new()
	var wide := board_post("prop_sign_wide", 2.6, "sign_%d" % mini(mended, 19), 384.0 / 112.0)
	if wide: sg.add_child(wide) # (the player's Meshy two-post sign, the printed board on its planks, front and back)
	else:
		var c := card([[-1.6, 0], [1.6, 0], [1.7, 0.9], [-1.7, 0.95]], "sign_%d" % mini(mended, 19))
		c.position.y = 1.2; sg.add_child(c); sg.add_child(posts([-1.3, 1.3]))
	sg.position = Vector3(sign_at.x, Terrain.get_height(sign_at.x, sign_at.z), sign_at.z); sg.rotation.y = atan2(-along.x, -along.z); sg.rotation.z = 0.0 if mended else 0.04
	add_child(sg); sign = sg

static func find_b(id: String) -> Dictionary:
	for b in BUILDINGS: if b.id == id: return b
	for st in STREETS:
		for b in st.buildings: if b.id == id: return b
	return {}
static func street_of(id: String) -> int:
	for k in STREETS.size():
		for b in STREETS[k].buildings: if b.id == id: return k
	return -1

## The town's mending projects, one per building: {id, name, cost, door}.
func projects() -> Array:
	var c := func(id: String, cost: int) -> int: return ceili(cost / 2.0) if raided.has(id) else cost # (wrecked by raiders: half the cost)
	var out := []
	for b in BUILDINGS: out.append({"id": b.id, "name": b.name, "cost": c.call(b.id, b.cost), "door": doors[b.id]})
	out.append({"id": "church", "name": "church", "cost": 40, "door": doors.church})
	if tiers.get("church", 0) and ResourceLoader.exists("res://assets/models/props/bldg_church2_restored.glb"):
		out.append({"id": "church2", "name": "new church, with a bell tower", "cost": CHURCH2_COST, "door": doors.church})
	for k in opened:
		for b in STREETS[k].buildings: out.append({"id": b.id, "name": b.name, "cost": c.call(b.id, b.cost), "door": doors[b.id]})
	for i in MARKET.size(): # (each market stall, tent and wagon, put to rights on its own: the player's ask)
		var id := "mkt_%d" % i
		out.append({"id": id, "name": MARKET_NAMES[i], "cost": c.call(id, MARKET_COST[i]), "door": at + along * (MARKET_S - 2.6) + toward * MARKET_O[i]})
	return out
## Is every building on Main Street (k = -1) or on the k-th new street mended?
func street_done(k: int) -> bool:
	var ids: Array = (BUILDINGS.map(func(b): return b.id) + ["church"]) if k < 0 else STREETS[k].buildings.map(func(b): return b.id)
	return ids.all(func(id): return tiers.get(id, 0))
## The unmended project whose door you're standing at, if any.
func project_at(pos: Vector3, r := 2.3):
	for p in projects(): if not tiers.get(p.id, 0) and Vector2(pos.x - p.door.x, pos.z - p.door.z).length() < r: return p
	return null

## Put up the k-th new street: its dirt street, its name on a post, and its buildings run-down.
func open_street(k: int) -> void:
	if k in opened: return
	opened.append(k)
	var st: Dictionary = STREETS[k]; var off: float = street_offs[k]
	for b in st.buildings:
		var g := building(b, 0); var p := place(g, b.s, b.side, 0.0, off); parts[b.id] = g
		doors[b.id] = p - toward * b.side * 1.6
		_colliders(b, off, false)
	var sheet := street_sheet("street_new"); var sp0: Vector3 = at + toward * off; sheet.position = Vector3(sp0.x, y0 + 0.03, sp0.z); add_child(sheet)
	var inner := 0.0 # (its neighbour toward Main Street)
	for o in street_offs: if signf(o) == signf(off) and absf(o) < absf(off): inner = o if absf(o) > absf(inner) else inner
	for cs in [CROSS_N, CROSS_S]: cross_sheet(inner + signf(off) * 7.0, off + signf(off) * 7.0, cs)
	var sp: Vector3 = at + along * -18.0 + toward * (off - signf(off) * 5.2)
	var sg := board_post("prop_signpost_long", 2.8, "streetsign_%d" % k, 4.0)
	if sg == null: sg = Node3D.new(); var c := card([[-1.1, 0], [1.1, 0.03], [1.05, 0.42], [-1.1, 0.4]], "streetsign_%d" % k); c.position.y = 1.6; sg.add_child(c); sg.add_child(posts([0.0]))
	sg.position = Vector3(sp.x, y0, sp.z); sg.rotation.y = atan2(-along.x, -along.z); add_child(sg)
	grow_row(k)
	if on_street.is_valid(): on_street.call(st.name)

## The folk who come back with a mended building, out on its boardwalk by the door, and a barrel of flowers there.
func dress_up(id: String) -> void:
	if folk.has(id) or not TOWNSFOLK.has(id): return
	var T: Dictionary = TOWNSFOLK[id]; var is_church := id == "church"
	var b := find_b(id); var side: int = b.get("side", 1); var door: Vector3 = doors[id]
	var out: Vector3 = -along if is_church else toward * -side
	var face := atan2(out.x, out.z); var y := y0 + 0.14
	var run: Vector3 = toward if is_church else along
	var p: Vector3 = door + run * float(T.get("at", 1.5)) - out * 0.3
	var who := Town.folk_of(T)
	if who.is_empty(): return # (Chinatown, its folk not in yet)
	var f := ModelFigure.new(who[0], {"scale": T.get("modelScale", 1.0), "hue": who[1]})
	f.root.position = Vector3(p.x, y0 if is_church else y, p.z); f.root.rotation.y = face; add_child(f.root)
	# a barrel of red and yellow flowers on the other side of the door
	var q: Vector3 = door - run * float(T.get("at", 1.5)) - out * 0.2
	var bar := Node3D.new(); bar.position = Vector3(q.x, y0 if is_church else y, q.z)
	var cm := CylinderMesh.new(); cm.top_radius = 0.28; cm.bottom_radius = 0.24; cm.height = 0.5; cm.radial_segments = 10; cm.rings = 1
	var keg := MeshInstance3D.new(); keg.mesh = cm; keg.material_override = _mat(0x8a6038); keg.position.y = 0.25; bar.add_child(keg)
	var fl := SphereMesh.new(); fl.radius = 0.08; fl.height = 0.16; fl.radial_segments = 5; fl.rings = 3
	for k in 7:
		var a := k * 0.9; var fm := MeshInstance3D.new(); fm.mesh = fl; fm.material_override = _mat([0xc4362f, 0xe8b84a, 0xf6efe0][k % 3])
		fm.position = Vector3(cos(a) * 0.16 * (k % 2 + 0.5), 0.55 + (k % 3) * 0.05, sin(a) * 0.16 * (k % 2 + 0.5)); bar.add_child(fm)
	var lm := SphereMesh.new(); lm.radius = 0.25; lm.height = 0.5; lm.radial_segments = 7; lm.rings = 4
	var leaf := MeshInstance3D.new(); leaf.mesh = lm; leaf.material_override = _mat(0x6a8a4a); leaf.position.y = 0.5; leaf.scale.y = 0.45; bar.add_child(leaf)
	add_child(bar)
	folk[id] = {"fig": f, "pose": T.get("pose"), "bar": bar, "face": face}
	var k := 0
	for E in T.get("with", []): # company: anyone else who hangs about this door
		var ew := Town.folk_of(E)
		if ew.is_empty(): continue
		var e := ModelFigure.new(ew[0], {"hue": ew[1]})
		var pe: Vector3 = door + run * float(E.get("at", -1.6)) + out * float(E.get("out", 0.3))
		e.root.position = Vector3(pe.x, y0 if is_church else surface_at(pe.x, pe.z, id), pe.z); e.root.rotation.y = face + float(E.get("turn", 0.0)); add_child(e.root)
		folk["%s_%d" % [id, k]] = {"fig": e, "pose": E.get("pose"), "face": face + float(E.get("turn", 0.0))}
		k += 1

func mend(id: String) -> void:
	if id == "church2":
		var front0 := _church_span().x
		tiers.church2 = 1; rebuild("church", 1, -1)
		# (raised where the old one stood, front to front: it reaches back toward the cross street, never out over you;
		# and if it would still reach the cross street, slid forward just enough)
		var cg: Node3D = parts.church; var sp := _church_span()
		cg.position += along * (front0 - sp.x)
		var over := sp.y + (front0 - sp.x) - (CROSS_N - CROSS_HW - 0.8)
		if over > 0.0: cg.position -= along * over
		doors.church = _church2_door()
		for key in folk.keys():
			if key == "church" or String(key).begins_with("church_"):
				folk[key].fig.root.queue_free()
				if folk[key].has("bar"): folk[key].bar.queue_free()
				folk.erase(key)
		dress_up("church")
		return
	if id.begins_with("mkt_"): tiers[id] = 1; raided.erase(id); market_refresh(); return
	var k := street_of(id)
	if k >= 0 and not k in opened: open_street(k) # (a saved game: put the street up first)
	tiers[id] = 1; raided.erase(id); dress_up(id)
	rebuild(id, 1, k)
	grow()
	market_refresh()

## The town grows: Main Street all mended puts up Second Street; that all mended puts up Third Street. A street may be
## held back (gate: the player's boss battles: Second Street waits for the townsite deed Mad Jebediah stole); then
## on_gate is told, once a street, and grow() is called again once the gate lifts.
func grow() -> void:
	for n in STREETS.size():
		if not n in opened and street_done(n - 1):
			if gate.is_valid() and not gate.call(n):
				if not n in gated: gated.append(n); if on_gate.is_valid(): on_gate.call(n)
				return
			open_street(n); return

## The mended buildings a war party could fall on (never the church).
func raidable() -> Array: return projects().filter(func(pr): return pr.id != "church" and tiers.get(pr.id, 0))

## Raiders wrecked it: run-down again, its folk gone, until it's mended once more.
func unmend(id: String) -> bool:
	if not tiers.get(id, 0) or id == "church": return false
	if id.begins_with("mkt_"): tiers[id] = 0; raided[id] = true; market_refresh(); return true
	tiers[id] = 0; raided[id] = true
	for key in folk.keys():
		if key == id or String(key).begins_with(id + "_"):
			folk[key].fig.root.queue_free()
			if folk[key].has("bar"): folk[key].bar.queue_free()
			folk.erase(key)
	rebuild(id, 0, street_of(id))
	return true

func rebuild(id: String, tier: int, k: int) -> void:
	var old: Node3D = parts[id]
	if id == "saloon": revue = null # (the dancers come back with the new building)
	var g: Node3D
	if id == "church":
		g = church(tier); g.transform = old.transform; add_child(g)
	elif k >= 0:
		var b := find_b(id); g = building(b, tier); place(g, b.s, b.side, 0.0, street_offs[k])
	else:
		var b := find_b(id); g = building(b, tier); place(g, b.s, b.side)
	old.queue_free()
	parts[id] = g; lit = null
	if tier > 0: _sign(id, g)
	if id != "church": # keeper, company and flower barrel on the mended building's boardwalk
		for key in folk.keys():
			if key == id or String(key).begins_with(id + "_"):
				var F: Dictionary = folk[key]
				F.fig.root.position.y = surface_at(F.fig.root.position.x, F.fig.root.position.z, id)
				if F.has("bar"): F.bar.position.y = surface_at(F.bar.position.x, F.bar.position.z, id)
	# a lantern on a post by the door of a mended building on the new streets, lit after dark
	if lamps.has(id): lamps[id].queue_free(); lamps.erase(id)
	if k >= 0 and tier:
		var b := find_b(id); var d: Vector3 = doors[id]; var lamp := Node3D.new()
		var p: Vector3 = d + along * (b.w / 2.0) * 0.55 - toward * b.side * 0.9
		var lp := model("prop_lantern_post", 2.3, 1)
		if lp: # (the player's Meshy lantern post, its lantern hung out over the boardwalk; a glow inside it after dark)
			lamp.add_child(lp)
			var cage := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.2, 0.2, 0.2); cage.mesh = bm; cage.material_override = _glass()
			lamp.add_child(cage); cage.position = _lantern_spot(lp, lamp, 2.3)
		else:
			var post := box(0.09, 2.1, 0.09, 0x4a3424); post.position.y = 1.05; lamp.add_child(post)
			var arm := box(0.42, 0.06, 0.06, 0x3a2a1c); arm.position = Vector3(0.18, 2.0, 0); lamp.add_child(arm)
			var cage := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.2, 0.28, 0.2); cage.mesh = bm; cage.material_override = _glass(); cage.position = Vector3(0.36, 1.78, 0); lamp.add_child(cage)
			var cap := box(0.26, 0.06, 0.26, 0x2e2a28); cap.position = Vector3(0.36, 1.95, 0); lamp.add_child(cap)
		lamp.position = Vector3(p.x, y0, p.z); lamp.rotation.y = atan2(along.x, along.z) - PI / 2.0; add_child(lamp)
		lamps[id] = lamp
	# a hitching rail before the feed barn and the stage stables once mended (and the Golden Garter's), a horse tied
	if hitch.has(id): hitch[id].g.queue_free(); hitch[id].horse.group.queue_free(); hitch.erase(id)
	if tier and ((k >= 0 and (id == "feed" or id == "stable2")) or (k < 0 and id == "saloon")):
		var b := find_b(id); var gg := Node3D.new()
		var sal := id == "saloon"
		var p: Vector3 = doors[id] + along * ((1.05 if sal else -0.6) * (b.w / 2.0)) - toward * b.side * (1.2 if sal else 2.2)
		for dx in [-1.3, 1.3]: var post := box(0.12, 1.1, 0.12, 0x5a3e28); post.position = Vector3(dx, 0.55, 0); gg.add_child(post)
		var rail := box(2.9, 0.09, 0.09, 0x6a4a30); rail.position.y = 1.0; gg.add_child(rail)
		gg.position = Vector3(p.x, y0, p.z); gg.rotation.y = atan2(along.x, along.z) - PI / 2.0; add_child(gg)
		var horse := Puppet.new("horse", 1.7); var hp: Vector3 = p - toward * b.side * 1.1
		horse.group.position = Vector3(hp.x, y0, hp.z); horse.heading = atan2(toward.x * b.side, toward.z * b.side) - PI / 2.0; add_child(horse.group) # (nose to the rail)
		hitch[id] = {"g": gg, "horse": horse}
	dress_street()
	make_sign()

static func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color.hex(0x5a5248ff)
	lamp_glass.append(m)
	return m

## The height to stand at (x, z) by building: its boardwalk if you're on it, else the street.
func surface_at(x: float, z: float, id: String) -> float:
	var g: Node3D = parts.get(id)
	if g == null or id == "church": return y0
	var b := find_b(id)
	var l := g.global_transform.affine_inverse() * Vector3(x, y0, z)
	return y0 + 0.14 if absf(l.x) <= (b.w + 0.6) / 2.0 and l.z > 0.05 and l.z < 1.85 else y0

## dressStreet: what stands in the street by what's mended (wagons, the water tower, the stage at the stables,
## back-lot clutter, the working beasts, stovepipe spots, bunting). Re-done whenever a building is mended.
func dress_street() -> void:
	for o in street: o.queue_free()
	for c in street_cols: world.colliders.erase(c)
	street = []; street_cols = []
	var yaw := atan2(-along.z, along.x) # (a model's length, its x, along the street)
	var put := func(name: String, size: float, axis: int, s: float, across: float, turn := 0.0, solid := false) -> void:
		var m := model(name, size, axis)
		if m == null: return
		var p: Vector3 = at + along * s + toward * across
		m.position = Vector3(p.x, y0, p.z); m.rotation.y = yaw + turn; add_child(m); street.append(m)
		if solid:
			var bb := PaperMats._aabb(m.get_child(0), Transform3D.IDENTITY) # (the model in its holder's frame)
			var r: float = bb.size.z * m.scale.x * 0.55
			for t in [-0.28, 0.28]:
				var q: Vector3 = p + along * cos(turn) * t * size - toward * sin(turn) * t * size
				var col := {"x": q.x, "z": q.z, "r": r}; world.colliders.append(col); street_cols.append(col)
	if tiers.get("store", 0): put.call("veh_freight_wagon", 5.4, 0, -8.5, -2.9, 0.0, true)
	else: put.call("veh_handcart", 3.2, 0, -8.5, -3.2, 0.5, true) # (an abandoned ore cart, its load still in it)
	put.call("prop_watertower", 7.5, 1, -6.0, HALF + 11.0)
	var at_b := func(id: String):
		var k := street_of(id)
		if k < 0 or not k in opened: return null
		return {"b": find_b(id), "off": street_offs[k]}
	var fd = at_b.call("feed") if tiers.get("feed", 0) else null
	if fd != null: put.call("veh_freight_wagon", 5.4, 0, fd.b.s + 4.6, fd.off + fd.b.side * (HALF - 3.4), 0.0, true)
	# working beasts: an ox in the traces of each freight wagon; a donkey tethered by the mended livery
	for B in beasts: B.group.queue_free()
	beasts = []
	var along0 := atan2(along.x, along.z) - PI / 2.0
	var beast := func(kind: String, scale: float, s: float, across: float, face: float) -> void:
		var pz := Puppet.new(kind, scale); var q: Vector3 = at + along * s + toward * across
		pz.group.position = Vector3(q.x, y0, q.z); pz.heading = face; add_child(pz.group); beasts.append(pz)
		var col := {"x": q.x, "z": q.z, "r": 0.8}; world.colliders.append(col); street_cols.append(col)
	if tiers.get("store", 0): beast.call("ox", 1.5, -8.5 + 4.4, -2.9, along0)
	if fd != null: beast.call("ox", 1.5, fd.b.s + 4.6 + 4.4, fd.off + fd.b.side * (HALF - 3.4), along0)
	if tiers.get("livery", 0): var lv := find_b("livery"); beast.call("donkey", 1.1, lv.s + lv.w / 2.0 + 1.4, lv.side * (HALF - 1.2), along0 + PI / 2.0 * lv.side)
	var sg = at_b.call("stable2") if tiers.get("stable2", 0) else null
	if sg != null: put.call("veh_stagecoach", 5.6, 0, sg.b.s + 4.2, sg.off + sg.b.side * (HALF - 3.4), PI, true)
	# back lots: behind each mended building, the clutter of a working yard, by trade (seeded per building)
	var lots := BUILDINGS.map(func(b): return [b, 0.0])
	for k in opened: lots.append_array(STREETS[k].buildings.map(func(b): return [b, street_offs[k]]))
	for e in lots:
		var b: Dictionary = e[0]; var off: float = e[1]
		if not tiers.get(b.id, 0): continue
		var rnd := PNoise.Mulberry32.new(hash_id("yard" + b.id)); var back: float = off + b.side * (HALF + b.d + 1.6)
		var items: Array = YARD.get(b.id, ["prop_barrel", "prop_crates"])
		for j in items.size():
			var nm: String = items[j]; var sz: Array = SIZE[nm]
			var s: float = b.s + (j - (items.size() - 1) / 2.0) * (b.w / items.size()) + (rnd.next() - 0.5) * 0.6
			var size: float = sz[0] * (0.9 + rnd.next() * 0.2)
			var acr: float = back + b.side * rnd.next() * 1.2
			put.call(nm, size, sz[1], s, acr, rnd.next() * 6.28, true)
	# stovepipes: where the smoke goes up from the mended smithy, bakery, cooperage, boarding house and Grand Hotel
	# (the web drops rays onto the roof; here the top of the model's box at the back third, where the smoke goes up)
	chimneys = []
	for id in SMOKERS:
		var g: Node3D = parts.get(id)
		if not tiers.get(id, 0) or g == null: continue
		var b := find_b(id)
		var bb := PaperMats._aabb(g, g.global_transform)
		var c: Vector3 = bb.get_center() + toward * b.side * b.d * 0.22 + along * b.w * 0.2
		chimneys.append({"x": c.x, "y": bb.end.y - 0.4, "z": c.z, "top": 0.15, "when": SMOKERS[id]})
	# bunting: a street with every building mended is strung across with three drooping cords of paper pennants
	var flags := [[], [], []]; var cords := SurfaceTool.new(); cords.begin(Mesh.PRIMITIVE_TRIANGLES); var any := false
	var done := ([-1] + opened).filter(func(k): return street_done(k))
	for k in done:
		var off: float = 0.0 if k < 0 else street_offs[k]
		var j := 0
		for s in [-9.0, 2.5, 13.0]:
			var rnd := PNoise.Mulberry32.new(hash_id("bunt%d%d" % [k, j])); var N := 15; var by0 := 3.5 + rnd.next() * 0.3; var sag := 0.7 + rnd.next() * 0.25
			var P := func(u: float) -> Vector3:
				var q: Vector3 = at + along * (s + (rnd.next() - 0.5) * 0.4) + toward * (off - HALF + 0.3 + u * (2.0 * HALF - 0.6))
				q.y = y0 + by0 - sin(u * PI) * sag; return q
			var prev: Vector3 = P.call(0.0)
			for i in range(1, N + 1):
				var q: Vector3 = P.call(i / float(N)); var mid := (prev + q) * 0.5; var ln := prev.distance_to(q)
				var bm := BoxMesh.new(); bm.size = Vector3(0.03, 0.03, ln)
				cords.append_from(bm, 0, Transform3D(Basis.looking_at(q - prev, Vector3.UP), mid)); any = true
				if i < N: # a pennant hung from this joint, flat across the street
					var w := 0.2; var h := 0.34 + rnd.next() * 0.06
					var tip := q - Vector3(0, h, 0) + along * (rnd.next() - 0.5) * 0.08
					flags[(i + j) % 3].append([q - toward * w, q + toward * w, tip])
				prev = q
			j += 1
	if any:
		var cm := MeshInstance3D.new(); cm.mesh = cords.commit(); cm.material_override = _mat(0x5a4030); add_child(cm); street.append(cm)
		for n in 3:
			if flags[n].is_empty(): continue
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for tri in flags[n]:
				for v in [tri[0], tri[1], tri[2], tri[0], tri[2], tri[1]]: st.add_vertex(v)
			st.generate_normals()
			var fm := MeshInstance3D.new(); fm.mesh = st.commit(); fm.material_override = _mat([0xb5473a, 0xefe3c4, 0x4f6f96][n]); add_child(fm); street.append(fm)

## Where a lantern post's lantern hangs, in the lamp's own frame: the middle of the model's points between 52% and 76%
## of its height that lie well off the post (the post: the middle of its points at a quarter of the height).
static var _lantern_cache = null
func _lantern_at(lp: Node3D, lamp: Node3D) -> Vector3:
	if _lantern_cache != null: return _lantern_cache
	var pts := []
	for mi in lp.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var to_lamp := lamp.global_transform.affine_inverse() * m.global_transform if m.is_inside_tree() else Transform3D.IDENTITY
		var arr := m.mesh.surface_get_arrays(0); var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in range(0, verts.size(), 2): pts.append(to_lamp * verts[i])
	var post := Vector3.ZERO; var np := 0
	for q in pts: if q.y > LAMP_H * 0.2 and q.y < LAMP_H * 0.3: post += q; np += 1
	if np: post /= np
	var c := Vector3.ZERO; var n := 0; var lo := Vector3(INF, INF, INF); var hi := -lo
	for q in pts:
		if q.y > LAMP_H * 0.53 and q.y < LAMP_H * 0.68 and Vector2(q.x - post.x, q.z - post.z).length() > 0.16: c += q; n += 1; lo = lo.min(q); hi = hi.max(q) # (the lantern's body: below its arm and roof)
	_lantern_cache = c / n if n else Vector3(-0.25, LAMP_H * 0.63, 0)
	_lantern_cache += Vector3(0, 0.04, 0)
	lantern_size = Vector3(0.27, 0.25, 0.27) # (just proud of its panes, so the glow shows through them)
	return _lantern_cache
static var lantern_size := Vector3(0.22, 0.32, 0.22)

## Where a lantern post of height h hangs its lantern, in the lamp's frame (the middle of its points from 52% to 76% of
## the height lying well off the post), measured once per height.
static var _spots := {}
func _lantern_spot(lp: Node3D, lamp: Node3D, h: float) -> Vector3:
	if _spots.has(h): return _spots[h]
	var pts := []
	for mi in lp.find_children("*", "MeshInstance3D", true, false):
		var xf := Railroad._rel(mi as MeshInstance3D, lamp)
		var verts: PackedVector3Array = (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0, verts.size(), 2): pts.append(xf * verts[i])
	var post := Vector3.ZERO; var np := 0
	for q in pts: if q.y > h * 0.2 and q.y < h * 0.3: post += q; np += 1
	if np: post /= np
	var c := Vector3.ZERO; var n := 0
	for q in pts:
		if q.y > h * 0.53 and q.y < h * 0.68 and Vector2(q.x - post.x, q.z - post.z).length() > 0.12: c += q; n += 1
	_spots[h] = c / n + Vector3(0, 0.03, 0) if n else Vector3(0.3, h * 0.62, 0)
	return _spots[h]

## The six street lamps of Main Street (made once), each with its pool of warm light on the dirt.
const LAMP_H := 3.4
func _make_street_lamps() -> void:
	var pool_mat := StandardMaterial3D.new(); pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 64).length() / 60.0
			var a := atan2(y - 64, x - 64); var rim := (54.0 + sin(a * 40.0 / TAU * 2.7) * 4.0) / 60.0
			var k := clampf(1.0 - d, 0.0, 1.0) if d < rim else 0.0
			img.set_pixel(x, y, Color(1.0, 0.72, 0.42, 0.55 * k * k + 0.1 * k))
	pool_mat.albedo_texture = ImageTexture.create_from_image(img)
	var entries := [[-15, 1], [-6, -1], [2.5, 1], [9, -1], [15.5, 1], [-1.5, -1]]
	entries.sort_custom(func(a, b): return a[0] < b[0])
	for e in entries:
		var p: Vector3 = at + along * e[0] + toward * e[1] * (HALF - 0.5)
		var lamp := Node3D.new(); lamp.position = Vector3(p.x, y0, p.z); add_child(lamp)
		var glass := MeshInstance3D.new()
		var lp := model("prop_lantern_tall", LAMP_H, 1)
		if lp: # (the player's Meshy lantern post: its lantern on the arm hung out over the street, a glowing pane inside it)
			var out: Vector3 = -toward * float(e[1])
			# (measured from the model, in its own units of a 1.903-tall post: the post stands at x +0.070, z +0.021; the
			# lantern hangs at x -0.068, z +0.022, its body from 55% to 72% of the height)
			var u := LAMP_H / 1.903
			lamp.rotation.y = atan2(out.z, -out.x) # (the model's -x, where its lantern hangs, out over the street)
			lp.position = Vector3(-0.070 * u, 0.0, -0.021 * u); lamp.add_child(lp)
			var gb := BoxMesh.new(); gb.size = Vector3(0.22, 0.32, 0.22); glass.mesh = gb; glass.material_override = _glass(); glass.visible = false
			lamp.add_child(glass); glass.position = _lantern_at(lp, lamp) # (measured off the model itself)
			(glass.mesh as BoxMesh).size = lantern_size
			var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.72, 0.4); glow.omni_range = 4.5; glow.light_energy = 0.0; glow.shadow_enabled = false
			glow.position = glass.position; lamp.add_child(glow); lamp.set_meta("glow", glow)
		else:
			var post := box(0.12, 3.0, 0.12, 0x342b25); post.position.y = 1.5; lamp.add_child(post)
			var bar := box(0.5, 0.05, 0.05, 0x342b25); bar.position.y = 2.55; lamp.add_child(bar)
			var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.26; cone.height = 0.2; cone.radial_segments = 6; cone.rings = 1
			var cap := MeshInstance3D.new(); cap.mesh = cone; cap.material_override = _mat(0x342b25); cap.position.y = 3.48; lamp.add_child(cap)
			var cyl := CylinderMesh.new(); cyl.top_radius = 0.17; cyl.bottom_radius = 0.12; cyl.height = 0.38; cyl.radial_segments = 6; cyl.rings = 1
			glass.mesh = cyl; glass.material_override = _glass(); glass.position.y = 3.2; lamp.add_child(glass)
		var pool := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(6.5, 6.5); qm.orientation = PlaneMesh.FACE_Y; pool.mesh = qm
		pool.material_override = pool_mat; pool.position = Vector3(p.x, y0 + 0.05, p.z); pool.rotation.y = e[0]; pool.visible = false
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(pool)
		world.colliders.append({"x": p.x, "z": p.z, "r": 0.25})
		street_lamps.append({"glass": glass.material_override, "pool": pool, "at": p, "side": e[1], "lit": false})
		if lp: street_lamps[-1].pane = glass; street_lamps[-1].glow = lamp.get_meta("glow")

## Each frame: folk hidden when far off; tents glow after dark; keepers look up as you pass; lamps lit at dusk.
func update(night: float, dt: float) -> void:
	if street_lamps.is_empty(): _make_street_lamps()
	var on := night > 0.45
	far = cam_pos != null and Vector2(cam_pos.x - at.x, cam_pos.z - at.z).length() > 130.0
	var tg := maxf(0.0, night - 0.35) * 0.4 * (0.94 + sin(Time.get_ticks_msec() * 0.0073) * 0.03)
	for m in tent_mats: (m as ShaderMaterial).set_shader_parameter("self_fill", 0.28 + tg * 1.6)
	if on != lit:
		lit = on
		for m in lamp_glass: if is_instance_valid(m): m.albedo_color = Color.hex(0xffc060ff if on else 0x5a5248ff)
	update_people(night, dt)
	var abed := bedtime or raining
	if assayer: assayer.root.visible = not abed and not far; if assayer.root.visible: assayer.update(dt, 0.0, "clipboard")
	for B in beasts: B.group.visible = not bedtime and not far; if B.group.visible: B.update(dt, 0.0, "idle", false, 0.0)
	for id in hitch: var h: Puppet = hitch[id].horse; h.group.visible = (not bedtime or id in NIGHT_OWLS) and not far; if h.group.visible: h.update(dt, 0.0, "idle", false, 0.0)
	for k in folk:
		var F: Dictionary = folk[k]; var r: Node3D = F.fig.root
		r.visible = (k.split("_")[0] in NIGHT_OWLS or not abed) and not far
		if not r.visible: continue
		# they look up as you pass: within a few paces a shopkeeper turns to watch you by (never more than a
		# quarter turn from the street), and eases back when you've gone on
		var want: float = F.face
		if player_pos != null:
			var dx: float = player_pos.x - r.position.x; var dz: float = player_pos.z - r.position.z; var d := sqrt(dx * dx + dz * dz)
			if d < 5.0 and d > 0.4:
				var off: float = atan2(dx, dz) - F.face; off = atan2(sin(off), cos(off)); want = F.face + clampf(off, -1.3, 1.3)
		var dr: float = want - r.rotation.y; dr = atan2(sin(dr), cos(dr)); r.rotation.y += dr * minf(1.0, dt * 3.0)
		F.fig.update(dt, 0.0, F.pose)

func save() -> Dictionary:
	var d := tiers.duplicate(); d.opened = opened.duplicate(); d.raided = raided.keys(); return d
func load_state(d) -> void:
	if d == null: return
	for k in d.get("opened", []): if k < STREETS.size(): open_street(int(k))
	var order: Array = BUILDINGS.map(func(b): return b.id) + ["church"]
	for st in STREETS: order.append_array(st.buildings.map(func(b): return b.id))
	for id in order: if int(d.get(id, 0)) == 1: mend(id)
	for i in MARKET.size(): if int(d.get("mkt_%d" % i, 0)) == 1: mend("mkt_%d" % i)
	if int(d.get("church2", 0)) == 1 and tiers.get("church", 0): mend("church2")
	for id in d.get("raided", []): if not tiers.get(id, 0): raided[id] = true

## Where settler i lives: most scrape by on Squatters' Row; newcomers who came for the boarding house's rooms live
## in the street before the house they lodge at.
func home_for(i: int, needs := "") -> Vector3:
	if needs == "" and squat.size():
		var p: Vector3 = squat[i % squat.size()]; return p + along * floori(i / float(squat.size())) * 1.2
	if needs != "" and doors.has(needs):
		var side: int = find_b(needs).get("side", 1)
		return doors[needs] - toward * side * 2.6 + along * (1.3 if i % 2 else -1.3)
	var spots: Array = doors.values() + tents
	var p: Vector3 = spots[i % spots.size()]; var k := floori(i / float(spots.size()))
	return p + along * ((1.4 if k else 0.0) * (1.0 if i % 2 else -1.0))
## A spot in the street: s along it, across metres from the centre line toward side +1; look is where it faces.
func spot(s: float, across: float, look_s = null, look_across := 0.0) -> Dictionary:
	var p: Vector3 = at + along * s + toward * across
	return {"x": p.x, "z": p.z, "look": at + along * (s if look_s == null else look_s) + toward * look_across}
func near_assay(pos: Vector3, r := 3.0) -> bool: return Vector2(pos.x - doors.assay.x, pos.z - doors.assay.z).length() < r
func near(pos: Vector3, r := 34.0) -> bool: return Vector2(pos.x - at.x, pos.z - at.z).length() < r

# ------------------------------------------------------------------ part two (16b): the town's people at their days
const WANTS := [["apples", 3, 4, "a sack of apples for the young ones"], ["fish", 2, 5, "a couple of fish for supper"], ["bread", 1, 4, "a loaf of bread"],
	["wood", 6, 3, "firewood: the nights are cold under canvas"], ["venison", 2, 7, "venison, if you hunt"], ["honey", 1, 5, "a jar of honey for a cough"],
	["pelt", 1, 6, "a hide to patch the tent"], ["egg", 4, 3, "a few eggs"], ["rope", 2, 4, "rope to guy the tent down"], ["berries", 4, 3, "berries for a pie"]]
const ROW_FOLK := [["folk_calico_01", "Widow Pruitt", "cgc_woman_patched"], ["folk_farmhand_01", "Jeb Calloway"], ["folk_calico_02", "Mrs. Dunaway", "cgc_woman_floral"], ["prospectors_3", "Old Hiram"],
	["folk_farmhand_02", "Tom Kessler", "cgc_man_youth"], ["folk_calico_03", "Ada Lark", "cgc_woman_gingham"], ["prospectors_4", "Rufus Pike"], ["folk_farmhand_03", "Silas Fry", "cgc_man_ragged"]]
var row_rng := PNoise.Mulberry32.new(4242)
var civilians: Array = []
var sunday := false
var fireworks_on := false
var snow_cover := 0.0
var inv := {}
var make_snowman: Callable   ## () -> Node3D (the build system's snowman card)
var snowmen = null
var revue = null
var lighter = null
var lit_round := false
var hello: MeshInstance3D
var hello_mats: Array = []
var hello_t := 0.0
var hello_at: Node3D
var greeted := {}
var _t := 0.0

## Four more tents behind the first rank on Squatters' Row, each with a family who wants something.
func grow_row(k: int) -> void:
	var spots := [[-37, -1], [-37, 1], [-44, -1], [-44, 1], [-51, -1], [-51, 1], [-40.5, -1], [-47.5, 1]].slice(k * 4, k * 4 + 4)
	for e in spots:
		var s: float = e[0]; var side: int = e[1]
		var p0: Vector3 = at + along * s + toward * side * 12.0
		if Terrain.is_water(p0.x, p0.z): continue
		# (the back rank turns its back on the front one and opens onto the field, so its folk stand out in the open)
		var hut := tent(row_rng); var p := place(hut, s, side, 12.0 - HALF); hut.rotation.y += PI + (row_rng.next() - 0.5) * 0.35
		world.colliders.append({"x": p.x - toward.x * side * 1.2, "z": p.z - toward.z * side * 1.2, "r": 1.5})
		var i := civilians.size(); var rf: Array = ROW_FOLK[i % ROW_FOLK.size()]
		var a: Vector3 = p + toward * side * 1.8
		var fig := ModelFigure.new(rf[2] if rf.size() > 2 and ModelFigure.has_folk(rf[2]) else rf[0]); fig.root.position = Vector3(a.x, y0 + 0.02, a.z); fig.root.rotation.y = atan2(side * toward.x, side * toward.z); add_child(fig.root)
		var note := _two_faced("note"); note.position = Vector3(a.x, y0 + 2.35, a.z); add_child(note)
		var ready := _two_faced("ready"); ready.visible = false; add_child(ready)
		civilians.append({"name": rf[1], "fig": fig, "at": a, "door": p + toward * side * 0.9, "note": note, "ready": ready, "want": WANTS[(i * 3 + 1) % WANTS.size()], "day": -1, "goal": a, "wait": 4.0 + row_rng.next() * 10.0, "atMeeting": false})

## A spinning note shows its print from both sides: two cards back to back.
func _two_faced(tex: String) -> Node3D:
	var g := Node3D.new()
	for k in 2:
		var c := card([[-0.22, 0], [0.22, 0.02], [0.2, 0.42], [-0.21, 0.4]], tex, 0.02)
		if k: c.rotation.y = PI; c.position.z = -0.03
		g.add_child(c)
	return g

## A Row family who wants something, at pos.
func want_at(pos: Vector3, r := 2.2):
	for c in civilians:
		var q: Vector3 = c.fig.root.position
		if c.want != null and c.fig.root.visible and Vector2(pos.x - q.x, pos.z - q.z).length() < r: return c
	return null
## Bring what they want and they pay for it (a dollar more from a clean-shaven neighbour); the next morning, a new want.
func fill(c: Dictionary, inventory: Dictionary, today: int, bonus := 0) -> Dictionary:
	var item: String = c.want[0]; var n: int = c.want[1]; var pay: int = c.want[2] + bonus
	if inventory.get(item, 0) < n: return {"ok": false, "text": "%s could use %s (%d %s). They'll pay $%d." % [c.name, c.want[3], n, item, pay]}
	inventory[item] -= n; inventory.dollars = inventory.get("dollars", 0) + pay
	c.want = null; c.day = today + 1; c.note.visible = false
	return {"ok": true, "text": "%s takes the %s gratefully and presses $%d into your hand. \"God bless you, neighbor.\"" % [c.name, item, pay]}

## Pop a greeting card up over a keeper's head (one at a time).
func say_hello(r: Node3D) -> void:
	if hello == null:
		for i in 5:
			var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.5; m.no_depth_test = true; m.render_priority = 10
			m.albedo_texture = load("res://assets/baked/town/hello_%d.png" % i); hello_mats.append(m)
		hello = MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.95, 0.42); qm.center_offset = Vector3(0, 0.21, 0); hello.mesh = qm
		hello.rotation_order = EULER_ORDER_YXZ; hello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; hello.visible = false; add_child(hello)
	var evening := clock > 0.66
	var i: int = 3 if evening else [0, 1, 2, 4][randi() % 4]
	hello.material_override = hello_mats[0 if (clock < 0.42 and randf() < 0.6) else i]
	hello_t = 2.6; hello_at = r

func _hello_tick(dt: float) -> void:
	if hello == null: return
	hello_t -= dt
	if hello_at == null or not is_instance_valid(hello_at): hello_t = 0.0 # (the one greeting has gone: a building rebuilt, or wrecked)
	var on := hello_t > 0.0 and not far; hello.visible = on
	if not on: return
	var r := hello_at.position
	var k := minf(1.0, (2.6 - hello_t) / 0.18); var out := minf(1.0, hello_t / 0.25); var up := minf(k, out)
	var e := minf(1.0, (2.6 - hello_t - 0.18) / 0.5)
	var over := 0.0 if k < 1.0 else sin(e * TAU) * 0.12 * (1.0 - e)
	hello.position = Vector3(r.x, r.y + 2.05, r.z); hello.rotation.x = -(1.0 - up) * PI / 2.0 + over # (it springs up on its hinge with a quiver)
	if cam_pos != null: hello.rotation.y = atan2(cam_pos.x - r.x, cam_pos.z - r.z)

## The lamplighter: at dusk, if you're near enough to see, he comes out from the farm end of Main Street and lights
## the six lamps one by one, then goes in at the church door. Otherwise (late, or far off) they're simply lit.
func _light(S: Dictionary, on: bool) -> void:
	if S.lit != on:
		S.lit = on; S.glass.albedo_color = Color.hex(0xffc060ff if on else 0x5a5248ff); S.pool.visible = on
		if S.has("pane"): S.pane.visible = on # (the model lantern's own panes by day; lit, the glow shows through them)
		if S.has("glow"): S.glow.light_energy = 1.4 if on else 0.0

func _lamplighter(dt: float) -> void:
	var dusk := clock > 0.745 or clock < 0.235
	if not dusk:
		for S in street_lamps: _light(S, false)
		lit_round = false
		if lighter != null: lighter.fig.root.visible = false
		return
	if lit_round: return
	if lighter == null and (far or not (clock > 0.745 and clock < 0.8)):
		for S in street_lamps: _light(S, true)
		lit_round = true; return
	if lighter == null:
		var fig := ModelFigure.new("cgc_man_elder" if ModelFigure.has_folk("cgc_man_elder") else "prospectors_3", {"hue": 2.6}); var p0: Vector3 = at + along * -21.0
		fig.root.position = Vector3(p0.x, y0 + 0.02, p0.z); add_child(fig.root)
		lighter = {"fig": fig, "i": 0, "wait": 0.0}
		return
	var L: Dictionary = lighter; var fr: Node3D = L.fig.root
	fr.visible = not far
	var S = street_lamps[L.i] if L.i < street_lamps.size() else null
	var q := fr.position
	var goal: Vector3 = (S.at - toward * S.side * 0.7) if S != null else (doors.church - along * 0.6)
	var gx := goal.x - q.x; var gz := goal.z - q.z; var gd := sqrt(gx * gx + gz * gz); var spd := 0.0
	if gd > 0.25:
		spd = 1.6; q.x += (gx / gd) * spd * dt; q.z += (gz / gd) * spd * dt; fr.position = q
		var d := atan2(gx, gz) - fr.rotation.y; fr.rotation.y += atan2(sin(d), cos(d)) * minf(1.0, dt * 6.0)
	elif S != null: # at the lamp: he reaches up a moment, and it catches
		var d := atan2(S.at.x - q.x, S.at.z - q.z) - fr.rotation.y; fr.rotation.y += atan2(sin(d), cos(d)) * minf(1.0, dt * 6.0)
		L.wait += dt
		if L.wait > 1.1: _light(S, true); L.wait = 0.0; L.i += 1
	else: # in at the church door: home for the night
		fr.queue_free(); lighter = null; lit_round = true; return
	L.fig.update(dt, spd, null)

## The Row's families at their days: home by their tents, a stroll to a neighbour's, in at bedtime or out of a
## downpour, up to the churchyard on a Sunday morning, out into Main Street for Saturday's fireworks.
func _civilians(dt: float, abed: bool) -> void:
	_t += dt
	for i in civilians.size():
		var c: Dictionary = civilians[i]; var fr: Node3D = c.fig.root; var q := fr.position
		if far: fr.visible = false; c.note.visible = false; c.ready.visible = false; continue
		if abed: # they walk to the tent flap and duck inside
			c.note.visible = false; c.ready.visible = false
			var dx: float = c.door.x - q.x; var dz: float = c.door.z - q.z; var d := sqrt(dx * dx + dz * dz)
			if fr.visible and d > 0.35:
				var sp := 1.6; q.x += (dx / d) * sp * dt; q.z += (dz / d) * sp * dt; fr.position = q
				var r := atan2(dx, dz) - fr.rotation.y; fr.rotation.y += atan2(sin(r), cos(r)) * minf(1.0, dt * 6.0); c.fig.update(dt, sp, null)
			else: fr.visible = false; fr.position = Vector3(c.door.x, q.y, c.door.z); c.goal = c.at; c.atMeeting = false
			continue
		fr.visible = true
		c.note.visible = c.want != null
		c.wait -= dt
		if c.wait <= 0.0: # now and then a stroll over to a neighbour's tent (on their own side of the Row), then home
			var my_side := signf((c.at.x - at.x) * toward.x + (c.at.z - at.z) * toward.z)
			var home: bool = c.goal.distance_to(c.at) < 0.5
			var others := civilians.filter(func(o): return o != c and signf((o.at.x - at.x) * toward.x + (o.at.z - at.z) * toward.z) == my_side)
			if home and others.size() and row_rng.next() < 0.5:
				var o: Dictionary = others[floori(row_rng.next() * others.size())]; c.goal = o.at + along * (1.1 if row_rng.next() < 0.5 else -1.1)
			else: c.goal = c.at
			c.wait = 6.0 + row_rng.next() * 12.0
		if sunday and tiers.get("church", 0): # Sunday meeting: loose rows before the church doors, facing in
			var row := floori(i / 5.0); var col := (i % 5) - 2 + (row % 2) * 0.5
			c.goal = doors.church - along * (3.0 + row * 1.25) + toward * col * 1.15; c.wait = 2.0; c.atMeeting = true
		elif fireworks_on: # Saturday's fireworks: a loose crowd in Main Street, looking up the street
			var j := i * 2.399; var s := 1.0 + (i % 4) * 2.7 + sin(j) * 0.5; var across := (floori(i / 4.0) - 1) * 2.3 + cos(j) * 0.5
			c.goal = at + along * s + toward * across; c.wait = 2.0; c.atMeeting = true
		elif c.atMeeting: c.atMeeting = false; c.goal = c.at; c.wait = 4.0 + row_rng.next() * 6.0
		var gx: float = c.goal.x - q.x; var gz: float = c.goal.z - q.z; var gd := sqrt(gx * gx + gz * gz); var spd := 0.0
		if gd < 0.3 and c.atMeeting:
			var d := atan2(along.x, along.z) - fr.rotation.y; fr.rotation.y += atan2(sin(d), cos(d)) * minf(1.0, dt * 3.0)
		if gd > 0.3:
			spd = 1.5 if c.atMeeting and gd > 6.0 else 0.9; q.x += (gx / gd) * spd * dt; q.z += (gz / gd) * spd * dt
			var d := atan2(gx, gz) - fr.rotation.y; fr.rotation.y += atan2(sin(d), cos(d)) * minf(1.0, dt * 6.0)
		for o in civilians: # never inside one another
			if o == c or not o.fig.root.visible: continue
			var p2: Vector3 = o.fig.root.position; var dx := q.x - p2.x; var dz := q.z - p2.z; var dd := sqrt(dx * dx + dz * dz)
			if dd < 0.85 and dd > 1e-4: q.x += (dx / dd) * (0.85 - dd) * 0.5; q.z += (dz / dd) * (0.85 - dd) * 0.5
		fr.position = q
		c.note.position.x = q.x; c.note.position.z = q.z
		var can: bool = c.want != null and inv.get(c.want[0], 0) >= c.want[1] # (you're carrying what they want: the note turns to a tick)
		c.ready.visible = can and c.note.visible
		if c.ready.visible: c.note.visible = false
		if c.atMeeting: c.note.visible = false; c.ready.visible = false
		c.fig.update(dt, spd, null)
		if c.want == null and day >= c.day and c.day >= 0: c.want = WANTS[floori(row_rng.next() * WANTS.size())]; c.note.visible = true
		if c.want != null:
			c.note.position.y = y0 + 2.35 + sin(_t * 2.0 + i) * 0.06; c.note.rotation.y += dt * 0.8
			c.ready.position = c.note.position; c.ready.rotation = c.note.rotation

## Part two's frame: the Row, greetings, the lamplighter, snowmen, the can-can after dark.
func update_people(night: float, dt: float) -> void:
	var abed := bedtime or raining
	_civilians(dt, abed)
	_lamplighter(dt)
	_stage(dt)
	# snowmen: once the snow lies thick, the Row's children have been out; they fold back down when it goes
	if snowmen == null and snow_cover > 0.05 and make_snowman.is_valid():
		snowmen = []
		for e in [[-16.0, -4.4, 0.4], [-44.0, 4.0, -0.6]]:
			var hinge := Node3D.new(); var p: Vector3 = at + along * e[0] + toward * e[1]
			hinge.position = Vector3(p.x, y0, p.z); hinge.rotation_order = EULER_ORDER_YXZ; hinge.rotation.y = atan2(along.x, along.z) + e[2]
			hinge.add_child(make_snowman.call()); add_child(hinge); snowmen.append(hinge)
	if snowmen != null:
		var up := clampf((snow_cover - 0.55) * 4.0, 0.0, 1.0)
		for h in snowmen: h.visible = up > 0.01; h.rotation.x = -(1.0 - up) * PI / 2.0 # (rising on its hinge as the snow deepens)
	# a word of greeting the first time you pass each keeper each day
	if player_pos != null and not far:
		for k in folk:
			if String(k).contains("_") or not folk[k].fig.root.visible: continue
			var r: Node3D = folk[k].fig.root
			if greeted.get(k, -1) != day and Vector2(player_pos.x - r.position.x, player_pos.z - r.position.z).length() < 3.2: greeted[k] = day; say_hello(r); if on_gossip.is_valid(): on_gossip.call(k)
	_hello_tick(dt)
	# the Golden Garter's can-can revue: once the saloon is mended, after dark, three dancers high-kick on its boardwalk
	if tiers.get("saloon", 0) and night > 0.45 and not far:
		if revue == null:
			revue = []
			for i in 3:
				var nw: String = "" if ResourceLoader.exists("res://assets/models/props/bldg_saloon2_ruined.glb") else ["cgc_saloon_pink", "cgc_saloon_daisy", "cgc_saloon_orange"][i] # (the player's three dance on the hall's stage; the saloon's boardwalk has its own)
				var f := ModelFigure.new(nw if nw != "" and ModelFigure.has_folk(nw) else ["saloon_2", "saloon_3", "saloon_4"][i]); f.t = i * 0.35
				parts.saloon.add_child(f.root); f.root.position = Vector3(-2 + i * 2, 0.14, 1.1); revue.append(f)
		for f in revue: f.root.visible = true; f.update(dt, 0.0, "cancan")
	elif revue != null:
		for f in revue: if is_instance_valid(f.root): f.root.visible = false
	_hall_life(dt, night)

# ------------------------------------------------------------------ part three (16c): the stage, the opera, the dance
var PLAYBILL: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/town/playbill.json"))
const REEL := [62, 66, 69, 66, 62, 66, 69, 74, 73, 69, 71, 73, 74, 69, 66, 69, 67, 71, 74, 71, 67, 71, 74, 76, 74, 73, 71, 69, 66, 64, 62, 62]
var bill: Node3D
var bill_day := -1
var hall_dancers = null
var hall_floor := Vector3.ZERO
var hall_fiddler: ModelFigure
var hall_t := 0.0
var hall_beat := 0.0
var hall_note := 0
var queue = null
var coach = null
var rider = null          ## the stage's passenger, while the coach waits (her position), else null
var on_stage: Callable    ## the guard's horn as the stage comes in sight of town
var on_note: Callable     ## (freq, dur, vol): the dance hall's fiddler

static func hz(m: float) -> float: return 440.0 * pow(2.0, (m - 69.0) / 12.0)

func _street_b(id: String) -> Dictionary:
	var k := street_of(id)
	return {"b": find_b(id), "off": street_offs[k] if k >= 0 else 0.0}

## The opera house's playbill, on a post by its door: tonight's tall tale (the day picks it).
func set_playbill(today: int) -> void:
	if not doors.has("opera") or not tiers.get("opera", 0):
		if bill: bill.queue_free(); bill = null
		return
	if bill and bill_day == today: return
	if bill: bill.queue_free()
	bill_day = today
	var sb := _street_b("opera"); var ob: Dictionary = sb.b
	var p: Vector3 = at + along * (ob.s - 3.2) + toward * (sb.off + ob.side * (HALF - 1.2))
	var sheet := card([[-0.42, 0], [0.42, 0.02], [0.4, 0.86], [-0.43, 0.84]], "playbill_%d" % (today % 7), 0.02)
	var g := Node3D.new(); sheet.position = Vector3(0, 1.0, -0.15); sheet.rotation.z = -0.03; g.add_child(sheet); g.add_child(posts([0.0]))
	g.position = Vector3(p.x, y0, p.z); g.rotation.y = atan2(ob.side * toward.x, ob.side * toward.z) + PI; add_child(g); bill = g

## The dance hall's evening: from dusk till late, two couples swing round in the street before its doors, the
## fiddler sawing away on its boardwalk (a fourth above the barn dance's reel, and a shade quicker).
func dance_hall(evening: bool, dt: float) -> void:
	if far: return
	if not tiers.get("dance", 0) or not doors.has("dance"):
		if hall_dancers != null:
			for d in hall_dancers: d.fig.root.visible = false
		return
	var sb := _street_b("dance"); var b: Dictionary = sb.b
	if hall_dancers == null:
		hall_dancers = []
		var i := 0
		for pr in [["folk_farmhand_02", -1.0, "folk_calico_02", 1.3], ["folk_farmhand_03", 2.4, "folk_calico_03", -2.0]]:
			for e in [[pr[0], pr[1], -1.0], [pr[2], pr[3], 1.0]]:
				var nw: String = {"folk_calico_02": "cgc_woman_blueapron", "folk_calico_03": "cgc_woman_stripe"}.get(e[0], "")
				var fig := ModelFigure.new(nw, {}) if nw != "" and ModelFigure.has_folk(nw) else ModelFigure.new(e[0], {"hue": e[1]}); add_child(fig.root); fig.root.visible = false
				hall_dancers.append({"fig": fig, "pair": i, "sgn": e[2]})
			i += 1
		hall_floor = doors.dance - toward * b.side * 3.4 # (out in the street before the doors)
	hall_t += dt
	if hall_fiddler == null:
		hall_fiddler = ModelFigure.new("folk_fiddler", {"hue": 0.9}); var p: Vector3 = doors.dance - along * 2.2
		hall_fiddler.root.position = Vector3(p.x, y0 + 0.14, p.z); hall_fiddler.root.rotation.y = atan2(-b.side * toward.x, -b.side * toward.z); add_child(hall_fiddler.root)
	hall_fiddler.root.visible = evening
	if evening: hall_fiddler.update(dt, 0.0, null)
	var hd := Vector2(cam_pos.x - hall_floor.x, cam_pos.z - hall_floor.z).length() if cam_pos != null else 99.0
	if evening and hd < 30.0:
		hall_beat -= dt
		if hall_beat <= 0.0:
			hall_beat += 0.15; hall_note += 1
			if on_note.is_valid(): on_note.call(hz(REEL[hall_note % REEL.size()] + 5), 0.18, maxf(0.0, 1.0 - hd / 30.0) * 0.8)
	for d in hall_dancers:
		var r: Node3D = d.fig.root
		r.visible = evening
		if not evening: continue
		var a: float = hall_t * 0.5 + d.pair * PI; var spin: float = hall_t * 2.0 + d.pair
		var px: float = hall_floor.x + cos(a) * 2.2 * (1.0 if d.pair else 0.8); var pz: float = hall_floor.z + sin(a) * 1.6
		r.position = Vector3(px + cos(spin) * 0.32 * d.sgn, y0 + 0.03, pz + sin(spin) * 0.32 * d.sgn)
		r.rotation.y = -spin + (PI / 2.0 if d.sgn > 0 else -PI / 2.0)
		d.fig.update(dt, 0.0, "dance")

## Curtain time at the opera house: from sundown till the show's done, theatre-goers wait in a line by its doors.
func opera_queue(curtain: bool, dt: float) -> void:
	if far: return
	if not tiers.get("opera", 0) or not doors.has("opera"):
		if queue != null:
			for f in queue: f.root.visible = false
		return
	if queue == null:
		queue = []
		var ob: Dictionary = find_b("opera"); var i := 0
		for e in [["townsfolk_2", 1.1], ["folk_farmhand_01", -1.8], ["prospectors_2", 2.4], ["folk_calico_01", -0.7]]:
			var f := ModelFigure.new(e[0], {"hue": e[1]}); var p: Vector3 = doors.opera + along * (1.4 + i * 0.95) - toward * ob.side * 0.4
			f.root.position = Vector3(p.x, surface_at(p.x, p.z, "opera"), p.z); f.root.rotation.y = atan2(-along.x, -along.z) + (0.5 if i % 2 else -0.3) # (facing up the line, turned a little to talk)
			f.root.visible = false; add_child(f.root); queue.append(f); i += 1
	for f in queue:
		f.root.visible = curtain
		if curtain: f.update(dt, 0.0, null)

## The daily stage: once the boarding house is mended, the Overland stage drives in from the farm end of Main Street
## behind its pair about mid-morning, draws up before the boarding house and waits into the afternoon (a lady
## passenger stretching her legs beside it), then swings round and rattles off the way it came.
func _stage(dt: float) -> void:
	if not tiers.get("boarding", 0):
		if coach != null: coach.g.visible = false; for H in coach.horses: H.h.group.visible = false
		rider = null; return
	if coach == null:
		var g := Node3D.new(); var body := model("veh_stagecoach", 5.6, 0); g.add_child(body); g.visible = false; add_child(g)
		var horses := []
		for dz in [-0.75, 0.75]: var h := Puppet.new("horse", 1.7); add_child(h.group); horses.append({"h": h, "dz": dz})
		var r := ModelFigure.new("townsfolk_2", {"hue": 1.9}); r.root.visible = false; add_child(r.root)
		coach = {"g": g, "horses": horses, "s": -70.0, "face": 1, "phase": "away", "turn": 0.0, "horn": false, "rider": r}
	var C: Dictionary = coach; var t := clock
	var STOP := 13.5; var OUT := -70.0; var ACROSS := -0.3 # (down the crown of the street, clear of the carts)
	if C.phase == "away" and t > 0.4 and t < 0.55: C.phase = "in"; C.s = OUT; C.face = 1; C.turn = 0.0; C.horn = false
	if C.phase == "in" and not C.horn and C.s > -40.0:
		C.horn = true
		if on_stage.is_valid(): on_stage.call()
	if C.phase == "wait" and (t > 0.58 or t < 0.4): C.phase = "turn"
	var speed := 0.0
	if C.phase == "in":
		speed = 4.5 * minf(1.0, (STOP - C.s) / 6.0 + 0.25); C.s += speed * dt
		if C.s >= STOP: C.s = STOP; C.phase = "wait"
	elif C.phase == "turn":
		C.turn = minf(1.0, C.turn + dt / 2.5); speed = 1.0
		if C.turn >= 1.0: C.phase = "out"; C.face = -1
	elif C.phase == "out":
		speed = 4.5; C.s -= speed * dt
		if C.s <= OUT: C.phase = "away"
	var shown: bool = C.phase != "away" and not far
	C.g.visible = shown
	for H in C.horses: H.h.group.visible = shown
	var R: ModelFigure = C.rider
	var out: bool = C.phase == "wait" and not far
	R.root.visible = out; rider = R.root.position if out else null
	if out:
		var q: Vector3 = at + along * (C.s - 1.2) + toward * (1.2 - 2.1)
		R.root.position = Vector3(q.x, y0 + 0.02, q.z); R.root.rotation.y = atan2(-toward.x, -toward.z); R.update(dt, 0.0, null)
	if not shown: return
	var yaw: float = atan2(-along.z, along.x) + (C.turn * PI if C.phase == "turn" else (PI if C.face < 0 else 0.0)) # (its length along the street, nose the way it's going)
	var p: Vector3 = at + along * C.s + toward * ACROSS
	C.g.position = Vector3(p.x, y0, p.z); C.g.rotation.y = yaw
	var fwd := Vector3(cos(yaw), 0, -sin(yaw)); var side := Vector3(sin(yaw), 0, cos(yaw)) # (the pair in the traces, ahead of the coach)
	for H in C.horses:
		var q: Vector3 = p + fwd * 4.6 + side * H.dz
		H.h.group.position = Vector3(q.x, y0, q.z); H.h.update(dt, speed, "walk" if speed > 0.2 else "idle", false, 0.0)

## Who a TOWNSFOLK entry (or its company) is: [model, hue]. Their own new figure if it's in, else the old one re-dyed.
static func folk_of(T: Dictionary) -> Array:
	if T.has("new") and T.new is Array: # (a few in order of preference: the first that's in)
		for n in T.new: if ModelFigure.has_folk(n): return [n, 0.0]
		return [T.model, float(T.get("hue", 0.0))]
	if T.has("new") and ModelFigure.has_folk(T.new): return [T.new, 0.0]
	# Chinatown's folk are Chinese (the player: no one else standing about there): one not in from Meshy yet is stood
	# in for by another of them, a man for a man, a woman for a woman, re-dyed; a child waits for its own model
	if T.has("new") and String(T.new).contains("_cn"):
		var nm := String(T.new)
		if nm.begins_with("cgc_boy") or nm.begins_with("cgc_girl"): return []
		var kin := "cgc_woman_cn_" if nm.begins_with("cgc_woman") else "cgc_man_cn_"
		var have := CN_FOLK.filter(func(n): return n.begins_with(kin) and ModelFigure.has_folk(n))
		if have.is_empty(): return []
		return [have[absi(hash(nm)) % have.size()], 0.6 + float(absi(hash(nm)) % 5) * 0.4]
	return [T.model, float(T.get("hue", 0.0))]
const CN_FOLK := ["cgc_man_cn_elder", "cgc_man_cn_strong", "cgc_man_cn_young", "cgc_man_cn_rust", "cgc_man_cn_olive", "cgc_woman_cn_thin", "cgc_woman_cn_curvy",
	"cgc_woman_cn_sultry", "cgc_woman_cn_blue", "cgc_woman_cn_mulberry"]

## The bosses' trophies (the player's boss battles): each one beaten has his weapon nailed up over the assay office
## door, where the town can see who it owes: Jebediah's pick and Angus's axe crossed either side, Crane's dynamite
## (fuse cut) between. ids: the bosses whose prize is back.
var trophies: Node3D
func set_trophies(ids: Array) -> void:
	if trophies: trophies.queue_free()
	trophies = Node3D.new(); add_child(trophies)
	var b: Dictionary = BUILDINGS.filter(func(q): return q.id == "assay")[0]
	var outw: Vector3 = -toward * float(b.side) # (from the shopfront out into the street)
	var wall: Vector3 = doors.assay - outw * 1.6
	var base: Vector3 = wall - outw * 0.95 + Vector3.UP * (y0 + 3.45 - wall.y) # (on the false front, either side of the sign, above the porch roof)
	trophies.position = base; trophies.basis = Basis(along, Vector3.UP, outw).orthonormalized()
	var spots := {"jebediah": [-2.05, 0.35, 0.0], "angus": [2.05, -0.35, 0.0], "crane": [0.0, 0.0, 1.05]}
	for id in ids:
		if id == "cole": # (his Colt, hung level up by the dynamite, its barrel along the front)
			var colt := Boss._colt_mesh(1.1); colt.rotation = Vector3(0, PI / 2.0, 0.15); colt.position = Vector3(0.7, 0.42, 0.05); trophies.add_child(colt)
			continue
		if not spots.has(id): continue
		var w: Node3D = {"jebediah": Boss._pick_mesh, "angus": Boss._axe_mesh, "crane": Boss._dynamite_mesh}[id].call(1.5 if id != "crane" else 1.3)
		var tilt := Node3D.new(); tilt.position = Vector3(spots[id][0], spots[id][2], 0); tilt.rotation.z = spots[id][1]
		w.rotation.x = -PI / 2.0; w.position = Vector3(0, -0.65 if id != "crane" else -0.25, 0) # (the handle hangs down, the head up)
		tilt.add_child(w); trophies.add_child(tilt)

## Lettering for the shop signs the models left blank (the player saw bare boards): each board's centre, its facing and
## its size in the building's own frame, found by casting rays through the board's four edges on screen into the model
## (the centre is the midpoint of those edges)
## (tools/shot_facades.gd views; measured 2026-11-26), and the words painted on it.
const SIGN_BOARDS := {"bakery": [0.43, 3.55, -0.40, 1.85, 0.72, "BAKERY"], "bank": [0.03, 3.08, -0.42, 2.21, 0.60, "MINERS' BANK"],
	"barber": [0.27, 3.01, -0.37, 2.41, 0.44, "BARBER"], "cooper": [0.23, 2.36, 0.01, 1.62, 0.34, "COOPERAGE"],
	"hotel2": [-0.01, 5.40, -0.50, 2.41, 0.71, "GRAND HOTEL"], "opera": [0.30, 4.09, -0.71, 1.95, 0.50, "OPERA HOUSE"],
	"telegraph": [0.56, 2.41, -0.17, 1.16, 0.47, "TELEGRAPH"],
	"drygoods": [0.20, 3.52, -0.34, 2.42, 0.73, "DRY GOODS"], "jail": [0.10, 3.43, -0.63, 2.24, 0.54, "SHERIFF"]}
static var _sign_font: Font
func _sign(id: String, g: Node3D) -> void:
	if not SIGN_BOARDS.has(id): return
	var e: Array = SIGN_BOARDS[id]
	if _sign_font == null:
		var f := SystemFont.new(); f.font_names = PackedStringArray(["Rockwell", "Georgia", "Times New Roman", "serif"]); f.font_weight = 700; _sign_font = f
	var L := Label3D.new(); L.text = e[5]; L.font = _sign_font; L.modulate = Color("3a2418"); L.outline_size = 0
	L.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS; L.double_sided = false
	L.font_size = 96
	# (sized to the board: the lettering fills ~80% of its width and ~60% of its height, whichever is tighter)
	var text_w := _sign_font.get_string_size(e[5], HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x; var text_h := 96.0 * 1.15
	L.pixel_size = minf(float(e[3]) * 0.8 / text_w, float(e[4]) * 0.6 / text_h)
	L.position = Vector3(e[0], e[1], float(e[2]) + 0.025) # (just proud of the board, facing the street: the model's +z)
	g.add_child(L)

# ------------------------------------------------------------------ the dance hall (the player's open-fronted hall)
## The hall's layout in its own frame (a height map of the model, ray-cast every 0.4 m: tools notes in PORT.md): its
## front open to the street (z 0), the bar down the left (the counter at x -2.4, the bottle shelf at -3.4; z -3.4 to -10), tables on the right, the stage
## across the back (from z -11 to -15, 0.3 up), walls each side at x +-6.1. Walk in at the front.
const HALL_SINK := 0.06 # (just: its floor sits 0.16-0.26 up, the ground at the street; deeper and the ground shows through)
const HALL_STAGE_Y := 0.30 - HALL_SINK
## (the layout above was measured with the hall 11.4 m wide; at its size now everything scales by this)
static func hall_k() -> float: return (float(find_b("dance").w) + 0.4) / 11.4
func _hall_colliders(b: Dictionary, off: float) -> void:
	var o: Vector3 = at + along * float(b.s) + toward * (off + float(b.side) * HALF)
	var ry := atan2(-float(b.side) * toward.x, -float(b.side) * toward.z); var basis := Basis(Vector3.UP, ry)
	var k := hall_k()
	var add := func(x: float, z: float, r: float) -> void:
		var q: Vector3 = o + basis * Vector3(x * k, 0, z * k); world.colliders.append({"x": q.x, "z": q.z, "r": r * maxf(k, 0.8)})
	var z := -0.8
	while z > -15.4: add.call(-6.0, z, 0.35); add.call(6.0, z, 0.35); z -= 0.7 # (the side walls)
	for x in [-5.9, -5.3, -4.7, 4.7, 5.3, 5.9]: add.call(x, -0.7, 0.35) # (the front's corner rooms, the gates between open)
	z = -3.4
	while z > -10.4: add.call(-2.4, z, 0.4); z -= 0.6 # (the bar counter; the bottle shelf behind it at x -3.4, the aisle between)
	var x := -5.6
	while x < 5.7: add.call(x, -11.0, 0.4); x += 0.6 # (the stage's front edge: the stage is the girls')
	add.call(3.0, -3.4, 1.0); add.call(3.4, -8.0, 1.0) # (the two tables)

## Its people: the bartender behind the bar from mid-morning till late, and three girls kicking on the stage from dusk.
var hall_girls = null
var hall_barman = null
func _hall_life(dt: float, night: float) -> void:
	var g = parts.get("dance")
	if g == null or not tiers.get("dance", 0) or far or not ResourceLoader.exists("res://assets/models/props/bldg_saloon2_ruined.glb"):
		if hall_barman != null and is_instance_valid(hall_barman.root): hall_barman.root.visible = false
		if hall_girls != null: for f in hall_girls: if is_instance_valid(f.root): f.root.visible = false
		return
	if hall_barman == null or not is_instance_valid(hall_barman.root) or hall_barman.root.get_parent() != g:
		var nm := "townsfolk_3"
		hall_barman = ModelFigure.new(nm, {"hue": 0.8}); g.add_child(hall_barman.root)
		var k := hall_k(); hall_barman.root.position = Vector3(-2.85 * k, (0.16 - HALL_SINK) * k, -6.6 * k); hall_barman.root.rotation.y = PI / 2.0 # (behind the bar, facing the room)
		hall_girls = null
	var open := clock > 0.4 or clock < 0.08
	hall_barman.root.visible = open
	if open: hall_barman.update(dt, 0.0, null) # (standing to his bar: no hammer swing)
	var show := night > 0.3
	if hall_girls == null:
		hall_girls = []
		for i in 3:
			var nw: String = ["cgc_saloon_pink", "cgc_saloon_daisy", "cgc_saloon_orange"][i] # (the can-can three, on the hall's stage now)
			var f := ModelFigure.new(nw if ModelFigure.has_folk(nw) else ["saloon_2", "saloon_3", "saloon_4"][i]); f.t = i * 0.35
			var k := hall_k(); g.add_child(f.root); f.root.position = Vector3((-2.4 + i * 2.4) * k, HALL_STAGE_Y * k, -13.0 * k); hall_girls.append(f)
	for f in hall_girls:
		f.root.visible = show
		if show: f.update(dt, 0.0, "cancan")

# ------------------------------------------------------------------ the market row (the player's market stalls)
## Along the far side of the north cross street: stalls, tents and wagons of the market, each from its own model pair.
## Each is wrecked and bare till you pay to put it to rights (the player: anything with a ruined and a good model is
## yours to fix up); then it stands restored and stocked, a stallkeeper at it by day and baskets of food beside.
const MARKET_S := CROSS_N + CROSS_HW + 2.2 # (right at the street's edge: behind, the land is left as it lies, a terraced bank where there is one: the player liked it)
const MARKET_O := [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]
const MARKET := ["mkt_stall_green", "mkt_tent_ochre", "mkt_wagon_burgundy", "mkt_stall_red", "mkt_tent_blue", "mkt_wagon_ochre"]
const MARKET_NAMES := ["green produce stall", "ochre market tent", "burgundy market wagon", "red-striped food stall", "blue-trimmed market tent", "ochre market wagon"]
## (a model made turned from the rest, put square to the street: measured off its canopy)
const MARKET_TURN := {"mkt_tent_ochre_1": PI / 2.0, "mkt_stall_red_0": deg_to_rad(14.0)}
const MARKET_COST := [15, 12, 18, 15, 12, 18]
const MARKET_FOLK := ["cgc_woman_blueapron", "cgc_man_youth", "cgc_woman_greenapron", "cgc_man_suspenders", "cgc_woman_patched", "cgc_woman_calico"]
var market_tier := ""
var market_parts: Array = []
var market_cols := false
func market_refresh() -> void:
	var key := ""
	for i in MARKET.size(): key += str(tiers.get("mkt_%d" % i, 0))
	if key == market_tier or not ResourceLoader.exists("res://assets/models/props/bldg_mkt_stall_green_ruined.glb"): return
	market_tier = key
	for n in market_parts: if is_instance_valid(n): n.queue_free()
	market_parts = []
	for k in folk.keys(): if String(k).begins_with("mkt_"): folk[k].fig.root.queue_free(); folk.erase(k)
	var first := not market_cols
	var face := atan2(-along.x, -along.z) # (their fronts to the cross street)
	for i in MARKET.size():
		var tier: int = tiers.get("mkt_%d" % i, 0)
		var p: Vector3 = at + along * MARKET_S + toward * MARKET_O[i]
		var wagon: bool = String(MARKET[i]).contains("wagon")
		var g := model_building(MARKET[i], tier, 4.0 if wagon else 4.37, 3.42) # (a twentieth smaller: the player)
		g.position = Vector3(p.x, y0, p.z); g.rotation.y = face + float(MARKET_TURN.get("%s_%d" % [MARKET[i], tier], 0.0)); add_child(g); market_parts.append(g)
		if not market_cols: world.colliders.append({"x": p.x, "z": p.z, "r": 1.8})
		if tier:
			var bq: Vector3 = p + toward * (2.9 if i % 2 else -2.9) - along * 1.2
			var bk := model("prop_food_baskets", 1.3, 1)
			if bk: bk.position = Vector3(bq.x, y0, bq.z); bk.rotation.y = face + i; add_child(bk); market_parts.append(bk)
			var nm: String = MARKET_FOLK[i]
			if ModelFigure.has_folk(nm):
				var f := ModelFigure.new(nm, {"hue": 0.5 + i * 0.7}); f.t = i * 0.9
				var fp: Vector3 = p - along * 2.1 + toward * 0.6
				f.root.position = Vector3(fp.x, y0, fp.z); f.root.rotation.y = face; add_child(f.root) # (facing out to the street, the stall at their back)
				folk["mkt_%d" % i] = {"fig": f, "pose": null, "face": face}
	if first: market_cols = true # (their colliders laid once)
