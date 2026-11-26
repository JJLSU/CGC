class_name Wayfarers
extends Node3D
## Wayfarers (the player's ask: the new townsfolk out in the county "as random site campers, task doers and story
## elements"): six travellers camped about the county, placed by its seed, each with a tent or a bedroll, a fire and
## a story, and something to do with you once a day at E:
##   the surveyor inks the country for 300 m round onto your map; the peddler sells rope; the circuit preacher's
##   blessing mends you; Edwin Pell buys gold dearer than the assayer; the drover trades a pelt for jerky (venison);
##   Widow Lowell, going west, asks for a meal for her and the children, and gives her late husband's silver for it.
## They wear the player's new folk, their clothes re-dyed so they don't twin the townsfolk in town.

const NEAR := 150.0
const MOVE_DAYS := 4      ## every few days each breaks camp and pitches somewhere new (they're travellers)
const FAR := 180.0
const KINDS := [
	{"id": "surveyor", "who": "Josiah Abernathy, a surveyor", "model": "cgc_man_glasses", "hue": 1.4, "pose": "work", "tent": true,
		"hello": "Chaining off the county for the territorial map. Care to see what I've drawn?", "act": "[E] Look over the surveyor's map"},
	{"id": "peddler", "who": "Ike Sorrel, a peddler", "model": "cgc_man_suspenders", "hue": 2.4, "pose": null, "tent": false, "cart": true,
		"hello": "Needles, pins, rope and patent liniment!", "act": "[E] Buy a coil of rope from the peddler ($3)"},
	{"id": "preacher", "who": "Brother Amos, a circuit preacher", "model": "cgc_man_elder", "hue": 3.1, "pose": "clipboard", "tent": false,
		"hello": "Sit a spell, friend. The Lord's in no hurry, and neither am I.", "act": "[E] Take the preacher's blessing"},
	{"id": "buyer", "who": "Edwin Pell, a gold buyer from the city", "model": "cgc_man_gent", "hue": 2.0, "pose": null, "tent": true,
		"hello": "Six dollars the pinch, cash money. Better than your assayer.", "act": "[E] Sell Pell a pinch of gold ($6)"},
	{"id": "drover", "who": "Tom Blevins, a drover", "model": "cgc_man_bandana", "hue": 1.0, "pose": null, "tent": false, "fire_only": true,
		"hello": "Bringing the herd up from Texas. Got any hides? I'll trade you jerky.", "act": "[E] Trade the drover a pelt for jerky"},
	{"id": "widow", "who": "Widow Lowell, going west", "model": "cgc_woman_pinafore", "hue": 2.7, "pose": null, "tent": true, "child": true,
		"hello": "We've been on the road since Independence. The children are so hungry.", "act": "[E] Give the widow a meal for the children"},
]
const STAND_IN := {"cgc_man_glasses": "trades_7", "cgc_man_suspenders": "prospectors_1", "cgc_man_elder": "townsfolk_3", "cgc_man_gent": "prospectors_4",
	"cgc_man_bandana": "folk_farmhand_02", "cgc_woman_pinafore": "folk_calico_01"}
const MEALS := ["bread", "biscuits", "cornbread", "pie", "applepie", "honeycake", "stew", "fishfry", "flapjacks", "applecrisp", "johnnycake", "roast"]

var camps: Array = []        ## {at, kind, seed, built, nodes, fig, day}
var spots: Array = []        ## every good campsite found for the county; camp i is at spots[(i * stride + epoch * 5) % n]
var epoch := -1

func setup(home: Vector3, avoid: Array, world: World = null) -> void:
	var rng := PNoise.Mulberry32.new(PNoise.hash2(41, 19, Terrain.SEED + 6060))
	for tries in 1400:
		if spots.size() >= 24: break
		var a := rng.next() * TAU; var r := 110.0 + rng.next() * 520.0
		var x := home.x + cos(a) * r; var z := home.z + sin(a) * r
		if Terrain.is_water(x, z) or Terrain.impassable(x, z) or Terrain.range_at(x, z) > 0.02: continue
		var dry := true
		for j in 8:
			var b := j * TAU / 8.0
			if Terrain.is_water(x + cos(b) * 7.0, z + sin(b) * 7.0): dry = false; break
		if not dry: continue
		if avoid.any(func(q): return Vector2(q.x - x, q.z - z).length() < 90.0): continue
		if spots.any(func(q): return Vector2(q.x - x, q.z - z).length() < 110.0): continue
		spots.append(Vector3(x, Terrain.get_height(x, z), z))
		if world: world.exclusions.append({"x": x, "z": z, "r": 8.0})
	var kinds := KINDS.duplicate()
	for i in mini(kinds.size(), spots.size()):
		camps.append({"at": spots[i], "kind": kinds[i], "seed": int(rng.next() * 1e6), "built": false, "nodes": [], "fig": null, "day": -1, "met": false})
	move_to(0)

## Where each camps for this stretch of days (day / MOVE_DAYS): all move on together, each to its own spot.
func move_to(day: int) -> bool:
	var e := day / MOVE_DAYS
	if e == epoch or spots.size() < camps.size(): return false
	epoch = e
	for i in camps.size():
		var c: Dictionary = camps[i]
		var stride := maxi(1, spots.size() / camps.size()) # (spread evenly round the list, never two on one spot)
		var nat: Vector3 = spots[(i * stride + e * 5) % spots.size()]
		if c.at != nat:
			if c.built: _unbuild(c)
			c.at = nat
	return true

func save() -> Array: return camps.map(func(c): return [c.day, c.met])
func load_state(d) -> void:
	if d == null: return
	for i in mini(d.size(), camps.size()):
		if d[i] is Array: camps[i].day = int(d[i][0]); camps[i].met = bool(d[i][1])

## The camper within reach of the farmer (for E), or null.
func near_camper(p: Vector3, r := 3.2):
	for c in camps:
		if c.fig != null and Vector2(c.fig.root.position.x - p.x, c.fig.root.position.z - p.z).length() < r: return c
	return null

func update(dt: float, player: Player, today := 0) -> void:
	move_to(today)
	var p := player.pos
	for c in camps:
		var d := Vector2(c.at.x - p.x, c.at.z - p.z).length()
		if not c.built and d < NEAR: _build(c)
		elif c.built and d > FAR: _unbuild(c)
		if c.built and c.fig != null:
			var fig: ModelFigure = c.fig; var r := fig.root
			var to := Vector3(p.x - r.position.x, 0, p.z - r.position.z)
			if to.length() < 9.0: r.rotation.y = lerp_angle(r.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 3.0)) # (looks up as you come)
			fig.update(dt, 0.0, c.kind.get("pose") if to.length() > 9.0 else null)
			if c.has("kid"): (c.kid as ModelFigure).update(dt, 0.0, null)

func _build(c: Dictionary) -> void:
	c.built = true
	var rng := PNoise.Mulberry32.new(c.seed); var at: Vector3 = c.at; var k: Dictionary = c.kind
	var turn := rng.next() * TAU
	var place := func(model: String, length: float, dx: float, dz: float, yaw := 0.0) -> Node3D:
		var n := NativeCamps.prop(model, length)
		if n == null: return null
		var o := Vector2(dx, dz).rotated(turn); var q := Vector3(at.x + o.x, 0, at.z + o.y)
		n.position = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z); n.rotation.y = turn + yaw; add_child(n); c.nodes.append(n); return n
	place.call("prop_cookfire", 1.0, 0.0, 0.0)
	if k.get("tent", false): place.call("prop_tent", 3.0, 0.0, -4.0, PI)
	else: place.call("prop_bedroll", 1.2, -1.8, -1.2, 0.6)
	if k.get("cart", false): place.call("veh_handcart", 2.2, 3.2, -1.5, 1.2)
	if k.id == "surveyor": place.call("prop_toolbench", 1.6, 2.6, 1.6, -0.8)
	if k.id == "drover": place.call("prop_barrel", 0.8, 2.2, -1.8)
	if k.id == "buyer": place.call("prop_crates", 1.2, 2.4, -2.2, 0.3)
	var nm: String = k.model
	var own := ModelFigure.has_folk(nm)
	if not own: nm = STAND_IN.get(nm, "folk_farmhand_01")
	var fig := ModelFigure.new(nm, {"hue": float(k.hue)})
	var o := Vector2(1.6, 1.4).rotated(turn); var fp := Vector3(at.x + o.x, 0, at.z + o.y)
	fig.root.position = Vector3(fp.x, Terrain.get_height(fp.x, fp.z), fp.z); fig.root.rotation.y = atan2(at.x - fp.x, at.z - fp.z)
	add_child(fig.root); c.fig = fig
	if k.get("child", false) and ModelFigure.has_folk("townsfolk_4"): # (one of her children, by the fire)
		var kid := ModelFigure.new("townsfolk_4", {"hue": 1.7}); var ko := Vector2(-1.4, 1.2).rotated(turn)
		kid.root.position = Vector3(at.x + ko.x, Terrain.get_height(at.x + ko.x, at.z + ko.y), at.z + ko.y); kid.root.rotation.y = atan2(-ko.x, -ko.y)
		add_child(kid.root); c.kid = kid

func _unbuild(c: Dictionary) -> void:
	c.built = false
	for n in c.nodes: if is_instance_valid(n): (n as Node).queue_free()
	if c.fig: (c.fig as ModelFigure).root.queue_free()
	if c.has("kid"): (c.kid as ModelFigure).root.queue_free(); c.erase("kid")
	c.nodes = []; c.fig = null
