class_name Crafting
extends RefCounted
## crafting.js: the tech tree's recipes (all 130, pulled from the web into assets/baked/data/crafting.json), the
## station names, canAfford/blocked/craft exactly as the web's CraftingPanel, the tinker's per-visit request and
## the telegraph's rush orders (newRequest/requestState, newOrder/orderState/clearOrder). The panel UI is
## scripts/ui/crafting_panel.gd.

var recipes: Array = []
var by_id := {}
var requests: Array = []
var orders: Array = []
var station_name := {}
var land_name := {}
var inventory: Dictionary
var tools: Dictionary
var station_near: Callable          ## (station) -> bool
var on_craft: Callable              ## (recipe)
var fair_entered: Callable          ## (id) -> bool
var on_fair_entry: Callable         ## (id)

func _init(inv: Dictionary, tool_set: Dictionary) -> void:
	inventory = inv; tools = tool_set
	var d: Dictionary = JSON.parse_string(FileAccess.open("res://assets/baked/data/crafting.json", FileAccess.READ).get_as_text())
	recipes = d.RECIPES; requests = d.REQUESTS; orders = d.ORDERS; station_name = d.STATION_NAME; land_name = d.LAND_NAME
	for r in recipes:
		# (JSON numbers come back as floats: costs and gifts are counts)
		for f in ["cost", "gives"]:
			if r.has(f): for k in r[f]: r[f][k] = int(r[f][k])
		by_id[r.id] = r

static func can_afford(inv: Dictionary, cost: Dictionary) -> bool:
	for k in cost:
		if inv.get(k, 0) < cost[k]: return false
	return true

static func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in cost: parts.append("%d %s" % [cost[k], k])
	return ", ".join(parts)

## Why a recipe can't be made now ("" when it can): Done, Away, Made, Owned, File a claim first, Needs <station>, Need more.
func blocked(r: Dictionary) -> String:
	if r.get("request", false) and (r.get("done", false) or not r.get("ready", false)): return "Done" if r.get("done", false) else "Away"
	if r.get("wire", false) and (r.get("done", false) or not r.get("ready", false)): return "Done" if r.get("done", false) else "Away"
	if r.get("fair", false) and fair_entered.is_valid() and fair_entered.call(r.id): return "Done"
	if r.kind == "tool" and tools.has(r.get("tool", r.id)): return "Owned" if r.has("tool") else "Made"
	if r.has("needs") and not tools.has(r.needs): return "File a claim first" if r.needs == "claim" else ("Bring your buffalo rifle in trade" if r.needs == "rifle" else "Hire a hand first")
	if r.get("station") != null and not (station_near.is_valid() and station_near.call(r.station)): return "Needs " + String(station_name.get(r.station, r.station))
	if not can_afford(inventory, r.cost): return "Need more"
	return ""

func craft(id: String) -> bool:
	var r = by_id.get(id)
	if r == null or blocked(r) != "": return false
	for k in r.cost: inventory[k] = inventory.get(k, 0) - r.cost[k]
	if r.get("request", false) or r.get("wire", false): r.done = true
	if r.get("fair", false) and on_fair_entry.is_valid(): on_fair_entry.call(r.id)
	if r.kind == "tool":
		tools[r.get("tool", id)] = true
		if r.has("gives"): for k in r.gives: inventory[k] = inventory.get(k, 0) + r.gives[k]
	elif r.has("gives"):
		for k in r.gives: inventory[k] = inventory.get(k, 0) + r.gives[k]
	else: inventory[id] = inventory.get(id, 0) + 1
	if on_craft.is_valid(): on_craft.call(r)
	return true

# ------------------------------------------------------------------ the tinker's request (one per visit)
func new_request(day: int, saved = null) -> Dictionary:
	var r: Dictionary = by_id["t-request"]
	var same: bool = saved != null and saved.day == day and int(saved.idx) < requests.size()
	var idx: int = int(saved.idx) if same else randi() % requests.size()
	var q: Dictionary = requests[idx]
	r.merge({"cost": _ints(q.cost), "gives": _ints(q.gives), "name": "Request: " + q.name, "desc": q.desc, "done": bool(saved.done) if same else false, "ready": true, "day": day, "idx": idx}, true)
	return r
func request_state():
	var r: Dictionary = by_id["t-request"]
	return {"day": r.day, "idx": r.idx, "done": r.get("done", false)} if r.get("ready", false) else null

# ------------------------------------------------------------------ the telegraph's rush order
func new_order(day: int, saved = null) -> Dictionary:
	var r: Dictionary = by_id["tg-order"]
	var idx: int = int(saved.idx) if saved != null else randi() % orders.size()
	var q: Dictionary = orders[idx]
	var due: int = int(saved.due) if saved != null else day + 3
	r.merge({"station": "post-" + q.land, "cost": _ints(q.cost), "gives": {"dollars": int(q.pay)}, "name": "Telegram: " + q.name, "desc": "[i]%s[/i] Deliver here by day %d." % [q.desc, due],
		"done": bool(saved.done) if saved != null else false, "ready": true, "day": int(saved.day) if saved != null else day, "due": due, "idx": idx, "where": land_name[q.land], "pay": int(q.pay)}, true)
	return r
func order_state():
	var r: Dictionary = by_id["tg-order"]
	return {"day": r.day, "due": r.due, "idx": r.idx, "done": r.get("done", false), "where": r.where, "pay": r.pay, "name": String(r.name).replace("Telegram: ", "")} if r.get("ready", false) else null
func clear_order() -> void:
	var r: Dictionary = by_id["tg-order"]; r.ready = false; r.done = false

static func _ints(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d: o[k] = int(d[k])
	return o
