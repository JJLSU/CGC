class_name Settlers
extends Node3D
## settlers.js: settlers and works. Folk you meet can be won over to join the farm, each their own way (a fair wage,
## a chore, an arm-wrestle, a tall-tale contest, courting, a brave deed); each runs a work (a woodlot, a quarry...)
## by day, fills a crate on their back (three) and carries it to the storehouse; E there takes it all. It's only a
## trickle. A larder of plain food (R) feeds them a ration each morning; unfed, they work at half pace. With no town
## (with no town) they camp at the edge of the farm; hired hands bed down by the bunkhouse once it's built.

const LOAD := 3
const CAP := 30
const LARDER_CAP := 60
const GOODS := {"gold": 0xe8b830, "wood": 0x8a5a34, "stone": 0x9a968c, "fish": 0x7a9ab0, "clay": 0xa8603a, "ore": 0x5a5450, "honey": 0xe0a83a, "flour": 0xf3ead6, "syrup": 0xb8702a, "leather": 0xb08048, "charcoal": 0x2e2a28, "bricks": 0xb5473a}
## what each work makes, and what it's called (the first time you gather a thing yourself, its work unlocks)
const WORKS := {"wood": ["woodlot", "woodcutter's lot"], "stone": ["quarry", "stone quarry"], "fish": ["weir", "fish weir"], "clay": ["claypit", "clay pit"], "ore": ["diggings", "ore diggings"], "honey": ["beeyard", "bee yard"], "wheat": ["mill", "grist mill"], "sap": ["shack", "sugar shack"], "pelt": ["tannery", "tannery"], "iron": ["charpit", "charcoal pit"], "gold": ["sluice", "sluice box"]}
const WORK_NAME := {"woodlot": "woodcutter's lot", "quarry": "stone quarry", "weir": "fish weir", "claypit": "clay pit", "diggings": "ore diggings", "beeyard": "bee yard", "mill": "grist mill", "shack": "sugar shack", "tannery": "tannery", "charpit": "charcoal pit", "sluice": "sluice box", "kiln": "brick kiln"}
## the larder: [item, how many make one ration]
const RATIONS := [["fish", 1], ["corn", 1], ["apples", 1], ["berries", 2], ["egg", 1], ["bread", 1]]
const SETTLERS := [
	{"id": "silas", "model": "folk_silas", "how": "hire", "name": "Silas Crane", "trade": "woodcutter", "work": "woodlot", "item": "wood", "every": 45, "camp": [-16, 14],
		"wage": {"apples": 4, "berries": 6}, "pitch": "a lanky woodcutter with a two-bit axe, down on his luck",
		"ask": "\"A sack of apples and a few handfuls of berries, and I'll cut your cordwood as long as you'll have me.\"", "hired": "Silas shoulders his axe. \"Point me at your woodlot, boss.\""},
	{"id": "hattie", "new": "cgc_woman_greenapron", "model": "trades_6", "how": "hire", "name": "Hattie Boone", "trade": "quarrywoman", "work": "quarry", "item": "stone", "every": 60, "camp": [-19, 10],
		"wage": {"wood": 8, "berries": 6}, "pitch": "a broad-shouldered quarrywoman who can split granite with a look",
		"ask": "\"Eight sticks of wood for my lean-to and something sweet. Then I'll cut your stone.\"", "hired": "Hattie spits on her palms. \"Where's this quarry, then?\""},
	{"id": "ada", "new": "cgc_woman_calico", "model": "townsfolk_2", "how": "help", "name": "Ada Hale", "trade": "fisherwoman", "work": "weir", "item": "fish", "every": 70, "camp": [-13, 18],
		"wage": {"wood": 10, "rope": 1}, "pitch": "a widow from down the creek whose lean-to blew in with the last storm",
		"ask": "\"If you could spare ten sticks and a coil of rope to mend my lean-to, I'd keep you in fish till the creek runs dry.\"", "hired": "Ada ties off the last knot. \"There. Now, where's a good bend in the creek for a weir?\""},
	{"id": "jim", "model": "folk_player", "how": "wrestle", "name": "Big Jim Tuttle", "trade": "clay digger", "work": "claypit", "item": "clay", "every": 60, "camp": [-22, 15],
		"pitch": "a mountain of a teamster with arms like stovepipes, sitting on an upturned crate",
		"ask": "\"Work for a farmer? I'll work for any man who can put my arm down. Care to try?\"", "hired": "Big Jim rubs his elbow and laughs till he coughs. \"Fair's fair. Show me your clay bank.\""},
	{"id": "cyrus", "model": "prospectors_6", "how": "tale", "name": "Old Cyrus Pike", "trade": "prospector", "work": "diggings", "item": "ore", "every": 120, "camp": [-10, 21], "tales": 3,
		"pitch": "a grizzled prospector with a burro's patience and a beard you could lose a pickaxe in",
		"ask": "\"I've told tales from here to Sutter's Mill. Out-tell me by my fire some evening and I'll dig your ore.\"", "hired": "Cyrus slaps his knee. \"Blamed if that ain't the tallest one I ever heard! All right, I'm your man.\"",
		"lost": "Cyrus yawns. \"Heard that one. Go listen by your own fire a while; come back with three tales worth the telling.\""},
	{"id": "clem", "new": "cgc_woman_plumstripe", "model": "prospectors_3", "how": "court", "name": "Clementine Rowe", "trade": "beekeeper", "work": "beeyard", "item": "honey", "every": 150, "camp": [-25, 11],
		"gift": {"pie": 1}, "pitch": "a merry beekeeper's daughter with a laugh like a dinner bell and a straw hat full of daisies",
		"ask": "\"A body likes to be courted proper: a reel at the barn dance, and a pie, if you can bake one. Then we'll see.\"", "hired": "Clementine blushes to her ears and takes the pie. \"Well! I suppose a farm like this could use some bees.\""},
	{"id": "ezra", "model": "folk_ezra", "how": "help", "chore": "cut him a new millstone", "name": "Ezra Fenn", "trade": "miller", "work": "mill", "item": "flour", "every": 80, "camp": [-28, 18],
		"wage": {"stone": 12, "wood": 4}, "pitch": "a dusty miller whose old millstone cracked clean in two last spring",
		"ask": "\"Twelve good stones and a bit of timber, and I'll dress you a new millstone. Then put me by a stream and you'll never want for flour.\"", "hired": "Ezra runs a floury thumb round the new stone. \"She'll grind. Now find me running water.\""},
	{"id": "luther", "model": "folk_luther", "how": "hire", "name": "Luther Odom", "trade": "brickmaker", "work": "kiln", "item": "bricks", "every": 90, "camp": [-31, 13],
		"wage": {"fishfry": 2, "rope": 2}, "pitch": "a soft-spoken brickmaker with kiln-scorched forearms and a mason's pencil behind his ear",
		"ask": "\"Two hot suppers of fried fish and a couple coils of rope, and I'll fire you bricks enough for a proper chimney.\"", "hired": "Luther tucks his pencil away. \"Clay and a good draught. Show me where to build the kiln.\""},
	{"id": "abel", "model": "folk_abel", "how": "help", "chore": "patch his leaky sap buckets", "name": "Abel Whitcomb", "trade": "sugar-maker", "work": "shack", "item": "syrup", "every": 110, "camp": [-34, 17],
		"wage": {"iron": 1, "wood": 6}, "pitch": "an old sugar-maker from up north, with a sweet tooth and a cough from forty springs of woodsmoke",
		"ask": "\"My sap buckets leak like a sieve, son. A bar of iron for new hoops and a bit of wood for staves, and I'll boil you syrup fit for a parson.\"", "hired": "Abel sniffs the air. \"Maples a-plenty hereabouts. Build me a shack with a good draught and I'll get boiling.\""},
	{"id": "mose", "model": "folk_mose", "how": "hire", "name": "Mose Hartwell", "trade": "tanner", "work": "tannery", "item": "leather", "every": 130, "camp": [-37, 12],
		"wage": {"pelt": 2, "honeycake": 1}, "pitch": "a leathery old tanner with oak-bark stains to the elbow and a nose that gave up complaining years ago",
		"ask": "\"Two good pelts to start me off and a honey cake for my trouble. Then I'll tan you leather supple as a glove.\"", "hired": "Mose pats the pelts like old friends. \"Oak bark, a couple of vats and a good stretch of time. Downwind of the house, mind.\""},
	{"id": "patience", "model": "prospectors_2", "how": "deed", "name": "Patience Ewing", "trade": "collier", "work": "charpit", "item": "charcoal", "every": 120, "camp": [-40, 16],
		"pitch": "a soot-smudged collier who has burned charcoal alone in the hills for twenty years and fears nothing on four legs",
		"ask": "\"I don't work for folk who hide from coyotes. Drive off one of those treasure-guardians, and then we'll talk.\"", "hired": "Patience looks you up and down and nods once. \"Word is you saw off a guardian. That'll do. Where do you want your charcoal?\"",
		"lost": "\"Still hiding from the coyotes, are we? Come back when you've driven one off.\""},
	{"id": "gus", "model": "prospectors_1", "how": "hire", "name": "Gus Tolliver", "trade": "placer miner", "work": "sluice", "item": "gold", "every": 150, "camp": [-43, 12],
		"wage": {"fish": 3, "apples": 4}, "pitch": "a stooped old placer miner who swears the creeks were never played out, just the men",
		"ask": "\"Three fish and a sack of apples a week, and I'll rock your sluice from sunup to sundown. Gold's in them creeks yet, mark me.\"", "hired": "Gus spits, grins and shoulders his shovel. \"Build me a sluice box down by the water and I'll make it pay.\""},
	{"id": "nell", "new": "cgc_woman_greenbustle", "model": "prospectors_5", "how": "hire", "needs": "boarding", "name": "Nell Harper", "trade": "placer miner", "work": "sluice", "item": "gold", "every": 150, "camp": [-46, 16],
		"wage": {"bread": 2, "honey": 1}, "pitch": "a hard-bitten freighter who drove mule wagons up the canyon road for ten years and has decided to get rich instead",
		"ask": "\"Two loaves and a jar of honey, and I'll work any sluice you build like it owes me money.\"", "hired": "Nell rolls up her sleeves. \"Show me the water. I've washed more gravel than you've walked on.\""},
	{"id": "otis", "model": "folk_otis", "how": "hire", "needs": "boarding", "name": "Otis Bell", "trade": "woodcutter", "work": "woodlot", "item": "wood", "every": 45, "camp": [-49, 12],
		"wage": {"apples": 4, "fish": 2}, "pitch": "a big, quiet woodcutter down from the north woods, who says about three words a day",
		"ask": "\"Apples. Fish.\" He holds up four fingers, then two.", "hired": "Otis nods once and picks up his axe. That's all."},
]

var home: Vector3
var discovered := {}     ## resources you've gathered at least once (works unlock from these)
var hired: Array = []    ## settler ids, in the order they joined
var stock := {}          ## what's waiting in the storehouse
var larder := 0
var fed_day := -1
var hungry := {}
var list: Array = []
var danced := false
var wet := false
var cap := CAP
var town = null          ## the town: folk live there; null, they camp by the farm
var bunk: FarmExtras     ## the bunkhouse (hired hands bed down there once it's built)
var bout = null         ## the arm-wrestle under way: {k, s}
var on_arrive: Callable
var on_join: Callable
var on_newcomer: Callable
var on_deliver: Callable
static var _mats := {}

static func _pm(c: int) -> Material:
	if not _mats.has(c): _mats[c] = PaperMats.paper(Color.hex((c << 8) | 0xff), false)
	return _mats[c]

static func _box(size: Vector3, c: int) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	var m := MeshInstance3D.new(); m.mesh = b; m.material_override = _pm(c); return m

## The crate on a settler's back, heaped with what they make: logs for wood, lumps for everything else.
static func crate(item: String) -> Node3D:
	var g := Node3D.new()
	g.add_child(_box(Vector3(0.46, 0.28, 0.3), 0xc99a5e))
	for y in [-0.08, 0.08]: var sl := _box(Vector3(0.48, 0.05, 0.32), 0x8a5a34); sl.position.y = y; g.add_child(sl)
	for x in [-0.22, 0.22]: var po := _box(Vector3(0.05, 0.3, 0.32), 0x7a4e2c); po.position.x = x; g.add_child(po)
	var c: int = GOODS.get(item, 0x8a7a64)
	if item == "wood":
		var cm := CylinderMesh.new(); cm.top_radius = 0.065; cm.bottom_radius = 0.065; cm.height = 0.4; cm.radial_segments = 7; cm.rings = 1
		for q in [[0.01, 0.2, -0.07], [-0.02, 0.2, 0.07], [0.02, 0.31, 0]]:
			var l := MeshInstance3D.new(); l.mesh = cm; l.material_override = _pm(c); l.rotation.z = PI / 2.0; l.position = Vector3(q[0], q[1], q[2]); g.add_child(l)
	else:
		var sm := SphereMesh.new(); sm.radius = 0.085; sm.height = 0.17; sm.radial_segments = 5; sm.rings = 3
		var i := 0
		for q in [[-0.12, 0.17, 0.05], [0.1, 0.17, -0.05], [0.0, 0.2, 0.06], [0.03, 0.27, -0.02]]:
			var l := MeshInstance3D.new(); l.mesh = sm; l.material_override = _pm(c); l.position = Vector3(q[0], q[1], q[2]); l.rotation = Vector3(i, i * 2, 0); g.add_child(l); i += 1
	g.position = Vector3(0, 1.0, -0.4); g.visible = false
	return g

func _init(center: Vector3) -> void:
	home = center
	for S in SETTLERS:
		var folk := ModelFigure.new(S.new if S.has("new") and ModelFigure.has_folk(S.new) else S.model) # (the player's new folk, once made)
		folk.work_tool = {"woodlot": "axe", "charpit": "axe", "quarry": "pick", "claypit": "pick", "diggings": "pick", "sluice": "pick"}.get(S.get("work", ""), "hammer") # (the tool of his trade)
		folk.work_ual = {"weir": "Fixing_Kneeling", "kiln": "Fixing_Kneeling", "tannery": "Fixing_Kneeling", "beeyard": "Interact", "shack": "Interact", "mill": "Push"}.get(S.get("work", ""), "") # (their own motion at work, from the library: not every trade swings a hammer)
		folk.root.visible = false; add_child(folk.root)
		# their camp: a little ring of stones and a tiny flame
		var fire := Node3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.26; tm.outer_radius = 0.44; tm.rings = 9; tm.ring_segments = 5
		var stones := MeshInstance3D.new(); stones.mesh = tm; stones.material_override = _pm(0x8a8278); fire.add_child(stones)
		var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.16; cone.height = 0.45; cone.radial_segments = 5; cone.rings = 1
		var flame := MeshInstance3D.new(); flame.mesh = cone; flame.position.y = 0.22
		var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_color = Color.hex(0xff9a48ff); flame.material_override = fm
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire.add_child(flame); fire.visible = false; add_child(fire)
		var load := crate(S.item); folk.body.add_child(load)
		list.append({"S": S, "folk": folk, "fire": fire, "state": "away", "made": 0.0, "steer": Steer.new(0.4), "dir": Vector3(1, 0, 0), "work": null, "load": 0, "crate": load, "hauling": false, "asleep": false, "tired": 0.0})

static func spos(s: Dictionary) -> Vector3: return (s.folk.root as Node3D).position

## Where they live: by the bunkhouse once hired and it's built; in town; else a camp at the farm's edge.
func camp_at(s: Dictionary) -> Vector3:
	if bunk != null and bunk.bunk_built and s.S.id in hired:
		var p := bunk.home_for(hired.find(s.S.id)); return Vector3(p.x, Terrain.get_height(p.x, p.z), p.z)
	if town != null:
		var p: Vector3 = town.home_for(list.find(s), s.S.get("needs", "")); return Vector3(p.x, Terrain.get_height(p.x, p.z), p.z)
	var x: float = home.x + s.S.camp[0]; var z: float = home.z + s.S.camp[1]
	return Vector3(x, Terrain.get_height(x, z), z)

## Remember a resource the farmer has gathered (the first time, its work unlocks). True if it's new.
func discover(item: String) -> bool:
	var fresh := not discovered.has(item); discovered[item] = true; return fresh

func near(p: Vector3, r := 2.2):
	for s in list:
		if s.state != "away" and not s.asleep and Vector2(p.x - spos(s).x, p.z - spos(s).z).length() < r: return s
	return null

func can_afford(inv: Dictionary, s: Dictionary) -> bool:
	for k in s.S.get("wage", {}): if inv.get(k, 0) < s.S.wage[k]: return false
	return true

## Arm-wrestling: every E press pushes his arm a little way down, and he pushes back steadily. "won" | "lost" | "".
func wrestle(dt: float, s: Dictionary, pressed: bool) -> String:
	if bout == null: bout = {"k": 0.5, "s": s}
	if pressed: bout.k += 0.09 # (about five presses a second to gain on him)
	bout.k -= dt * 0.33
	if bout.k >= 1.0: bout = null; join(s); return "won"
	if bout.k <= 0.0: bout = null; s.tired = 20.0; return "lost"
	return ""
func match_bar() -> String:
	var n := roundi((bout.k if bout != null else 0.5) * 12.0)
	return "█".repeat(n) + "░".repeat(12 - n)

func join(s: Dictionary) -> void:
	if not s.S.id in hired: hired.append(s.S.id)
	s.state = "hired"; s.fire.visible = false
	if on_join.is_valid(): on_join.call(s)

func hire(inv: Dictionary, s: Dictionary) -> bool:
	if not can_afford(inv, s): return false
	for k in s.S.wage: inv[k] -= s.S.wage[k]
	join(s)
	return true

## Take everything waiting in the storehouse into the pack. Returns what was taken.
func collect(inv: Dictionary) -> Dictionary:
	var got := {}
	for k in stock: if stock[k] > 0: inv[k] = inv.get(k, 0) + stock[k]; got[k] = stock[k]
	stock = {}
	return got

static func list_text(d: Dictionary, sep := ", ") -> String:
	var parts := PackedStringArray()
	for k in d: if d[k] > 0: parts.append("%d %s" % [d[k], k])
	return sep.join(parts)
func stock_text() -> String: return list_text(stock)

## Stock the larder from the pack with plain food. {taken, rations}, or {} if there was nothing to give.
func stock_larder(inv: Dictionary) -> Dictionary:
	var taken := {}; var added := 0
	for r in RATIONS:
		var k: String = r[0]; var per: int = r[1]
		while inv.get(k, 0) >= per and larder + added < LARDER_CAP: inv[k] -= per; taken[k] = taken.get(k, 0) + per; added += 1
	if added == 0: return {}
	larder += added
	hungry.clear() # (a full larder: anyone who went without gets a bite now)
	return {"taken": taken, "rations": added}

## Each morning every settler with you eats a ration; anyone who can't works at half pace that day.
func breakfast(day: int) -> void:
	if day == fed_day: return
	fed_day = day; hungry.clear()
	for s in list:
		if s.state != "hired": continue
		if larder > 0: larder -= 1
		else: hungry[s.S.id] = true

func larder_text() -> String:
	var n := 0
	for s in list: if s.state == "hired": n += 1
	if n == 0: return "Larder: %d rations" % larder
	var days := floori(larder / float(n))
	return "Larder: %d ration%s (%d to feed: %d day%s)" % [larder, "" if larder == 1 else "s", n, days, "" if days == 1 else "s"]

func save() -> Dictionary:
	var loads := {}
	for s in list: if s.load: loads[s.S.id] = s.load
	return {"discovered": discovered.keys(), "hired": hired, "stock": stock, "danced": danced, "larder": larder, "fedDay": fed_day, "hungry": hungry.keys(), "loads": loads}
func load_state(d) -> void:
	if d == null: return
	for k in d.get("discovered", []): discovered[k] = true
	for id in d.get("hired", []): if not id in hired: hired.append(id)
	stock = d.get("stock", {}).duplicate(); danced = d.get("danced", false)
	larder = int(d.get("larder", 0)); fed_day = int(d.get("fedDay", -1))
	for id in d.get("hungry", []): hungry[id] = true
	for s in list:
		if s.S.id in hired: s.state = "hired"; s.folk.root.position = camp_at(s); s.load = int(d.get("loads", {}).get(s.S.id, 0))
	_to_work = true

## A game loaded in working hours: the hired hands start at their work, not at home a minute's walk off (the player:
## loading in, nobody seemed to be doing any work). Done once, on the first frame the pieces are in.
var _to_work := false
func _start_at_work(pieces: Array, night: float) -> void:
	_to_work = false
	if night >= 0.45 or pieces.is_empty(): return
	for s in list:
		if s.state != "hired" or s.load >= LOAD: continue
		var best = null; var bd := INF; var p0: Vector3 = s.folk.root.position
		for p in pieces:
			if p.type == s.S.work and p.get("risen", true) != false:
				var d0 := Vector2(p.x - p0.x, p.z - p0.z).length()
				if d0 < bd: bd = d0; best = p
		if best == null: continue
		var w := work_spot(best)
		s.folk.root.position = Vector3(w.x, Terrain.get_height(w.x, w.z), w.z)

## Where a hand stands at a piece of work: off its corner as always, but clear of the piece itself, however big it's
## built (the player saw the brickmaker at work inside his kiln once the kiln was made its proper size).
static func work_spot(p) -> Vector3:
	var f: Array = BuildSystem.DATA.get("FOOT", {}).get(p.type, [1.0, 1.0, 1.0])
	var r := maxf(1.58, maxf(float(f[0]), float(f[1])) + 0.7)
	return Vector3(p.x + 0.822 * r, 0, p.z + 0.569 * r) # (along (1.3, 0.9), as it always stood)

func update(dt: float, pieces: Array, day: int, time: float, night: float, camera: Camera3D) -> void:
	if _to_work and not pieces.is_empty(): _start_at_work(pieces, night)
	var storehouse = null
	for p in pieces: if p.type == "storehouse" and p.get("risen", true) != false: storehouse = p; break
	if time > 0.25 and time < 0.5: breakfast(day)
	var cam := camera.global_position
	var ms := Time.get_ticks_msec()
	for s in list:
		var S: Dictionary = s.S
		var root: Node3D = s.folk.root
		# not met yet: they turn up and make camp at the farm's edge once there's a storehouse to work for
		if s.state == "away":
			if S.has("needs") and (town == null or not town.tiers.get(S.needs, false)) and not S.id in hired: root.visible = false; continue # (no rooms to be had yet)
			if town != null: # in town they're already living there, scraping by
				if S.id in hired: continue
				if S.has("needs") and on_newcomer.is_valid(): on_newcomer.call(s)
				s.state = "camp"; root.position = camp_at(s); root.visible = true; s.fire.visible = false
			else:
				if storehouse == null or S.id in hired: continue
				s.state = "camp"; root.position = camp_at(s); s.fire.position = root.position + Vector3(0.9, 0, 0.4)
				root.visible = true; s.fire.visible = true
				if on_arrive.is_valid(): on_arrive.call(s)
		root.visible = true
		var bedtime := time > 0.88 or time < 0.22 or wet # (folk are abed from late evening till first light, and in out of a downpour)
		var speed := 0.0; var goal = null; var pose = null
		var pos := root.position
		if s.tired > 0.0: s.tired -= dt
		if s.state == "camp":
			if bedtime: root.visible = false; s.asleep = true; continue # (turned in for the night, in their tent)
			s.asleep = false
			s.fire.get_child(1).scale.y = 0.85 + sin(ms * 0.012 + S.camp[0]) * 0.15 # (the little flame flickers)
		else:
			# hired: by day to the nearest work of their trade; by night (or with no work built yet) home
			s.work = null; var wd := INF
			for p in pieces:
				if p.type == S.work and p.get("risen", true) != false:
					var d0 := Vector2(p.x - pos.x, p.z - pos.z).length()
					if d0 < wd: wd = d0; s.work = p
			var daytime := night < 0.45 and not wet # (no work in a downpour)
			# a full crate (or any at all, come dusk) goes to the storehouse first
			if s.load and storehouse != null and (s.load >= LOAD or not daytime): s.hauling = true
			if storehouse == null: s.hauling = false
			# supper at dusk: hired hands with a bunkhouse sit round its fire a while before they turn in
			var supper: bool = not wet and bunk != null and bunk.bunk_built and time > 0.76 and time < 0.88 and S.id in hired
			if s.hauling:
				var away := Vector3(pos.x - storehouse.x, 0, pos.z - storehouse.z); away *= 1.9 / maxf(0.01, away.length())
				goal = Vector3(storehouse.x + away.x, 0, storehouse.z + away.z)
			elif supper: goal = bunk.fire_spot(hired.find(S.id))
			else: goal = work_spot(s.work) if s.work != null and daytime else camp_at(s)
			var to := Vector3(goal.x - pos.x, 0, goal.z - pos.z); var d := to.length()
			if s.hauling and d <= 0.8: # tip the crate into the storehouse (what won't fit stays in the crate)
				var room := maxi(0, cap - int(stock.get(S.item, 0))); var put := mini(room, s.load)
				if put: stock[S.item] = stock.get(S.item, 0) + put
				s.load -= put; s.hauling = false
				if on_deliver.is_valid(): on_deliver.call(s, put)
			s.asleep = bedtime and not s.hauling and d <= 0.8 # (home and abed till morning)
			if s.asleep: root.visible = false; s.crate.visible = false; continue
			if d > 0.8:
				s.dir = to.normalized(); speed = 1.6 if d > 6.0 else 1.1; pos.x += s.dir.x * speed * dt; pos.z += s.dir.z * speed * dt
			elif supper:
				pose = "sit"; var k := minf(1.0, dt * 4.0); pos.x += (goal.x - pos.x) * k; pos.z += (goal.z - pos.z) * k
				s.dir = Vector3(bunk.fire_at.x - pos.x, 0, bunk.fire_at.z - pos.z).normalized() # (on a log by the fire, facing it)
			elif s.work != null and daytime:
				pose = "work"; s.dir = Vector3(s.work.x - pos.x, 0, s.work.z - pos.z).normalized()
				# the trickle: one unit every so often into the crate
				if storehouse != null and s.load < LOAD:
					s.made += dt * (0.5 if hungry.has(S.id) else 1.0) * (1.25 if bunk != null and bunk.bunk_built else 1.0)
					if s.made >= S.every: s.made = 0.0; s.load += 1; discovered[S.item] = true
			pos.y = Terrain.get_height(pos.x, pos.z)
			root.position = pos
		# face the way they're going (or the camera, idling at camp)
		var yaw := atan2(s.dir.x, s.dir.z) if (speed > 0.0 or pose != null) else atan2(cam.x - pos.x, cam.z - pos.z)
		var dy := yaw - root.rotation.y; dy = atan2(sin(dy), cos(dy)); root.rotation.y += dy * minf(1.0, dt * 6.0)
		s.crate.visible = s.load > 0
		# far off (130 m or more from the lens) a settler is a speck: hidden, not animated, though still at work
		if Vector2(cam.x - pos.x, cam.z - pos.z).length() > 130.0: root.visible = false
		else: s.folk.update(dt, speed, pose)
	# nobody stands inside anybody else: folk closer than an arm's length ease apart
	var up := list.filter(func(q): return q.folk.root.visible and q.state != "away")
	for i in up.size():
		for j in range(i + 1, up.size()):
			var a: Vector3 = up[i].folk.root.position; var b: Vector3 = up[j].folk.root.position
			var dx := b.x - a.x; var dz := b.z - a.z; var d := sqrt(dx * dx + dz * dz)
			if d >= 0.95: continue
			var k := minf(0.5, (0.95 - d) * 0.5) * minf(1.0, dt * 8.0)
			var nx := dx / d if d > 1e-4 else 1.0; var nz := dz / d if d > 1e-4 else 0.0
			up[i].folk.root.position = Vector3(a.x - nx * k, a.y, a.z - nz * k); up[j].folk.root.position = Vector3(b.x + nx * k, b.y, b.z + nz * k)

## One line per settler for the settlers card.
func rows(pieces: Array) -> Array:
	var out := []
	for s in list:
		var S: Dictionary = s.S
		var terms := ""
		match S.how:
			"deed": terms = "would join once you've driven off a treasure guardian"
			"court": terms = "would join if courted: %s, and bring a pumpkin pie" % ("you've danced a reel (✓)" if danced else "dance a reel at the barn dance")
			"tale": terms = "would join if you out-tell him by his fire after dark (you need %d tall tales of your own)" % S.tales
			"wrestle": terms = "would join if you beat him at arm-wrestling"
			"help": terms = "would join if you bring %s to %s" % [list_text(S.wage, " and "), S.get("chore", "mend her lean-to")]
			_: terms = "would join for %s" % list_text(S.wage, " + ")
		var built := pieces.any(func(p): return p.type == S.work)
		var status := ""
		if s.state == "away": status = "not in town yet: will come once the boarding house has rooms to let (mend it)" if S.get("needs", "") == "boarding" and town != null else "not met yet (build a storehouse)"
		elif s.state == "camp": status = "%s; %s" % [("rooms at the boarding house" if S.has("needs") else "lives on Squatters' Row") if town != null else "camped at the edge of the farm", terms]
		elif not built: status = "with you; waiting for you to build a %s" % WORK_NAME[S.work]
		elif s.hauling: status = "carrying %d %s to the storehouse" % [s.load, S.item]
		else:
			var h := hungry.has(S.id)
			status = "working the %s (%d/%d in the crate): about 1 %s every %d s by day%s" % [WORK_NAME[S.work], s.load, LOAD, S.item, S.every * (2 if h else 1), " (hungry: no breakfast, so half pace; stock the larder)" if h else ""]
		out.append({"name": S.name, "trade": S.trade, "status": status})
	return out
