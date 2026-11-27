class_name Claim
extends Node3D
## claim.js: your own gold claim, filed for at the Redrock Breaks trading post and staked out a short walk back along
## the line from that whistle-stop. Four corner stakes with rag flags, the claim notice on a post, an adit timbered
## into the red rock with a windlass beside it, an ore cart on a few yards of plank track and a rack of tools. Once a
## day the vein gives up a few pinches of gold (more with a better pick), and now and then a nugget of silver.
## A hired hand works it for you each day (his takings pile up in the ore cart); a stamp mill thumps away by day.

var rr: Railroad
var stop = null
var group: Node3D = null
var dug_day := -1
var mill: Node3D = null
var thump_t := 0.0
var on_thump: Callable
var hand: ModelFigure = null
var stock := {"gold": 0, "silver": 0}
var hand_day := -1
var dig_at = null

func _init(railroad: Railroad) -> void:
	rr = railroad
	for s in rr.stops: if s.land == "breaks": stop = s

## Where the claim lies (worked out with the line).
func at():
	return stop.geo.get("claim") if stop != null else null

func _put(mname: String, size: float, x: float, z: float, turn := 0.0, by_height := false) -> Node3D:
	var path := "res://assets/models/props/%s.glb" % mname
	if not ResourceLoader.exists(path): return null
	var m := (load(path) as PackedScene).instantiate() as Node3D
	PaperMats.paperize(m, true)
	var bb := PaperMats._aabb(m, Transform3D.IDENTITY)
	m.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	var hold := Node3D.new(); hold.add_child(m)
	hold.scale = Vector3.ONE * (size / (bb.size.y if by_height else maxf(bb.size.x, bb.size.z)))
	hold.position = Vector3(x, 0, z); hold.rotation.y = turn; group.add_child(hold)
	if mname == "prop_tent": hold.add_to_group("tents") # (a twister can carry it off)
	return hold

static func _boxes(list: Array, hex: int) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in list:
		var bm := BoxMesh.new(); bm.size = b[0]
		st.append_from(bm, 0, Transform3D(Basis(), b[1]))
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	mi.material_override = PaperMats.paper(Color.hex((hex << 8) | 0xff))
	return mi

## Stake it out (once it's filed, and the line is down).
func build() -> void:
	if group != null or at() == null or not rr.built: return
	var a: Vector3 = at(); var side: Vector3 = stop.geo.side
	group = Node3D.new(); group.position = Vector3(a.x, Terrain.get_height(a.x, a.z), a.z); group.rotation.y = atan2(-side.x, -side.z)
	add_child(group)
	_build_mine()
	_put("mine_windlass", 2.2, -3.6, -1.2, 0.3)
	_put("mine_orecart", 1.7, 2.6, 0.2, PI / 2)
	_put("mine_toolrack", 1.5, -3.4, 2.2, 0.5, true)
	# a few yards of plank track from the adit to the cart's tip
	var bits := []
	for k in 7: bits.append([Vector3(1.2, 0.06, 0.22), Vector3(2.6, 0.03, -2.2 + k * 0.62)])
	for x in [2.15, 3.05]: bits.append([Vector3(0.06, 0.06, 4.2), Vector3(x, 0.08, -0.4)])
	group.add_child(_boxes(bits, 0x6a4a30))
	# the four corner stakes, each with a strip of red rag
	var stakes := []; var rags := []
	for c in [[-6.6, -6.2], [5.5, -5.0], [-5.5, 4.5], [5.5, 4.5]]:
		stakes.append([Vector3(0.1, 1.2, 0.1), Vector3(c[0], 0.6, c[1])])
		rags.append([Vector3(0.34, 0.16, 0.02), Vector3(c[0] + 0.2, 1.08, c[1])])
	group.add_child(_boxes(stakes, 0x6a4a30)); group.add_child(_boxes(rags, 0xb5473a))
	# the claim notice, nailed to a post by the front stake
	var notice := Town.card([[-0.55, 0], [0.55, 0.02], [0.56, 0.72], [-0.54, 0.7]], "res://assets/baked/rail/claim_notice", 0.03)
	notice.position = Vector3(-1.6, 0.9, 4.6); group.add_child(notice)
	group.add_child(_boxes([[Vector3(0.1, 1.5, 0.1), Vector3(-1.6, 0.75, 4.55)]], 0x6a4a30))
	dig_at = group.transform * Vector3(0, 0, -1.2) # (at the mouth of the adit)
	if vein_rich: dig_at = group.transform * MINE_DIG # (at the face, in the drift)

# ------------------------------------------------------------------ the mine (the player's mine kit)
## Your claim's workings, cut into the bench beside the windlass and laid open like a diorama: a timbered portal, a
## drift in to a T-junction, straight on another drift to the face (the gold vein: rich while there's a day's gold in
## it, worked out once you've dug it), off to the side a drift fallen in, and the shaft head down to the lower workings
## with the lift cage up top by the windlass. Its walls stop you (worked out from the pieces themselves), and a rail of
## posts runs along each drift's open side. Claim-local: +z toward the line, the drifts along -x.
const MF := 3.0            ## the kit's pieces at 3x (a tunnel 2.4 m high, 2.6 m wide)
const MINE_DIG := Vector3(-22.4, 0, 0)
var vein_rich: Node3D = null
var vein_worked: Node3D = null
var mine_cols: Array = []
func _build_mine() -> void:
	if not ResourceLoader.exists("res://assets/models/props/mine_tunnel_straight.glb"):
		_put("mine_entrance", 4.2, 0, -3.4); return
	var L := 1.9 * MF
	var piece := func(nm: String, size: float, x: float, z: float, turn := 0.0, y := 0.0) -> Node3D:
		var n := _put(nm, size, x, z, turn); if n: n.position.y = y
		return n
	piece.call("mine_support_frame", 2.9, -6.9, 0.0, PI / 2.0)          # the portal
	var s1: Node3D = piece.call("mine_tunnel_straight", L, -6.9 - L / 2.0, 0.0)
	var t: Node3D = piece.call("mine_tunnel_t", L, -6.9 - L * 1.5, 1.4)
	var s2: Node3D = piece.call("mine_tunnel_straight", L, -6.9 - L * 2.5, 0.0)
	if s2: s2.scale.x = -s2.scale.x # (mirrored end for end: its loose roof planks over the junction end, the face left open to see)
	vein_rich = piece.call("mine_vein_rich", 2.6, -6.9 - L * 3.0 + 0.4, 0.0, PI / 2.0)
	vein_worked = piece.call("mine_vein_depleted", 2.6, -6.9 - L * 3.0 + 0.4, 0.0, PI / 2.0)
	var fall: Node3D = piece.call("mine_collapsed", 3.7, -6.9 - L * 1.5 - 0.2, 1.4 + L * 0.5 + 1.85) # (scaled to the drifts' height)
	piece.call("mine_ladder_shaft", 2.7, -6.9 - L * 2.4, -2.9, 0.0, -2.6) # (the shaft head: its lower storey down in the ground)
	_put("mine_lift_cage", 2.6, -4.8, -3.6, 0.3, true) # (by its height: a man's head clear)
	# the walls (laid by hand: the pieces' own posts and fallen timbers stand in the walkway): a back wall the length
	# of the drifts, a rail along their open side but for the side branch, the branch's own two walls, and the face and
	# the cave-in closing the ends
	var x0 := -6.9; var x1 := -6.9 - L * 3.0; var bx := -6.9 - L * 1.5 - 0.2
	var x := x0 - 0.3
	while x > x1:
		_col(Vector3(x, 0, -1.55))
		if absf(x - bx) > 1.5: _col(Vector3(x, 0, 1.55))
		x -= 0.6
	var z := 1.6
	while z < 1.4 + L * 0.5 + 0.4: _col(Vector3(bx - 1.55, 0, z)); _col(Vector3(bx + 1.55, 0, z)); z += 0.6
	for k in 5: _col(Vector3(bx - 1.2 + k * 0.6, 0, 1.4 + L * 0.5 + 0.6)) # (the cave-in)
	for k in 5: _col(Vector3(x1 + 0.2, 0, -1.2 + k * 0.6)) # (the face)
func _col(q: Vector3) -> void:
	var w := group.transform * q
	var c := {"x": w.x, "z": w.z, "r": 0.4}; rr.world_ref.colliders.append(c); mine_cols.append(c)
## Take on a hand: his tent goes up by the cart and he starts in at the adit tomorrow.
func hire(day: int) -> void:
	if hand != null or group == null: return
	_put("prop_tent", 2.3, -0.2, 2.0, 0.3)
	var nm := "prospectors_6" if ModelFigure.has_folk("prospectors_6") else "prospectors_1"
	hand = ModelFigure.new(nm, {"hue": 0.8}); hand.root.position = Vector3(-0.7, 0, -1.4); hand.root.rotation.y = PI - 0.3
	if vein_rich: hand.root.position = MINE_DIG + Vector3(0.6, 0, -0.6); hand.root.rotation.y = -PI / 2.0 # (at the face, swinging at the vein)
	group.add_child(hand.root)
	if hand_day < 0: hand_day = day

## Each new day the hand works, his takings go in the cart (five days' worth at most); by day he swings his pick at
## the adit (animated only while you're near); after dark he's in his tent. The stamps thump away by day.
func update(dt: float, day: int, is_day: bool, player: Player) -> void:
	if vein_rich: vein_rich.visible = dug_day != day
	if vein_worked: vein_worked.visible = dug_day == day
	if hand == null: return
	while hand_day < day:
		hand_day += 1
		if stock.gold < (25 if mill else 15):
			stock.gold += 2 + (2 if mill else 0) + (1 if randf() < 0.4 else 0)
			if randf() < 0.25: stock.silver += 1
	var a: Vector3 = at(); var d := Vector2(a.x - player.pos.x, a.z - player.pos.z).length()
	var near := d < 60.0
	hand.root.visible = is_day and near
	if hand.root.visible: hand.update(dt, 0.0, "work")
	if mill:
		if is_day and near:
			thump_t -= dt
			if thump_t <= 0.0:
				thump_t = 0.85
				if on_thump.is_valid(): on_thump.call(d)
		mill.position.y = maxf(0.0, 0.03 - (0.85 - thump_t) * 0.12) if is_day and near else 0.0

## Put up the stamp mill beside the adit.
func add_mill() -> void:
	if mill == null and group != null: mill = _put("mine_stampmill", 3.4, -4.1, -4.2, 0.35)

## Empty the cart: whatever the hand has dug since you were last out.
func collect() -> Dictionary:
	var s := stock; stock = {"gold": 0, "silver": 0}; return s

func save() -> Dictionary: return {"dug": dug_day, "stock": stock, "handDay": hand_day}

## Standing at the adit mouth?
func near(x: float, z: float, r := 2.4) -> bool:
	return dig_at != null and Vector2(dig_at.x - x, dig_at.z - z).length() < r

## Work the vein: a few pinches of gold (more with a better pick), sometimes silver. Once a day.
func dig(day: int, tools: Dictionary):
	if dug_day == day: return null
	dug_day = day
	var gold := 2 + (1 if mill else 0) + (1 if tools.has("ironpick") else 0) + (1 if tools.has("steelpick") else 0) + (1 if randf() < 0.3 else 0)
	return {"gold": gold, "silver": 1 if randf() < 0.35 else 0}
