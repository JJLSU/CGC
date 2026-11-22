class_name Journal
extends RefCounted
## journal.js: the farmer's journal, retired as a goal chain (there are no chores, just things to do): it keeps a
## tally of what you've done. Every event also lands in the day's log, which the almanac reads back when you sleep
## (main.js's almanacLines). The old goals stay for saves.

const GOALS := [
	{"id": "wood", "text": "Fell five trees for the woodpile", "event": "chop", "need": 5, "reward": {"stone": 4}},
	{"id": "berries", "text": "Pick three berry bushes", "event": "pick", "need": 3, "reward": {"wood": 6}},
	{"id": "hammer", "text": "Whittle yourself a hammer (C)", "event": "craft:hammer", "need": 1, "reward": {"wood": 5}},
	{"id": "fiber", "text": "Pull six armfuls of tall grass", "event": "gather:fiber", "need": 6, "reward": {"berries": 4}},
	{"id": "rope", "text": "Twist a length of rope", "event": "craft:rope", "need": 1, "reward": {"stone": 4}},
	{"id": "pat", "text": "Give Old Blue a good scratch behind the ears (E)", "event": "pat", "need": 1, "reward": {"berries": 2}},
	{"id": "bench", "text": "Build a workbench (B)", "event": "build:workbench", "need": 1, "reward": {"stone": 4}},
	{"id": "fire", "text": "Light a campfire to sit by", "event": "build:campfire", "need": 1, "reward": {"berries": 4}},
	{"id": "deer", "text": "Spot three deer in the woods", "event": "deer", "need": 3, "reward": {"berries": 5}},
	{"id": "clay", "text": "Dig clay from the riverbank", "event": "gather:clay", "need": 6, "reward": {"wood": 6}},
	{"id": "eggs", "text": "Gather eggs from the nesting box", "event": "gather:egg", "need": 4, "reward": {"corn": 3}},
	{"id": "milk", "text": "Milk the cow and shear a sheep", "event": "livestock", "need": 2, "reward": {"berries": 4}},
	{"id": "shoo", "text": "Shoo the crows out of the corn", "event": "shoo", "need": 1, "reward": {"corn": 3}},
	{"id": "scarecrow", "text": "Stand a scarecrow by the garden", "event": "build:scarecrow", "need": 1, "reward": {"pumpkin": 1}},
	{"id": "wheat", "text": "Gather wheat from the stooks in a field", "event": "gather:wheat", "need": 6, "reward": {"egg": 2}},
	{"id": "apples", "text": "Gather windfall apples in an old orchard", "event": "gather:apples", "need": 6, "reward": {"honey": 1}},
	{"id": "fish", "text": "Catch three fish from the bank", "event": "gather:fish", "need": 3, "reward": {"berries": 4}},
	{"id": "pick", "text": "Make a pickaxe at the workbench", "event": "craft:pickaxe", "need": 1, "reward": {"rope": 1}},
	{"id": "forge", "text": "Raise a forge of stone and clay", "event": "build:forge", "need": 1, "reward": {"wood": 8}},
	{"id": "spear", "text": "Make an ash spear, just in case", "event": "craft:spear", "need": 1, "reward": {"berries": 4}},
	{"id": "slay", "text": "Drive off a treasure guardian", "event": "slay", "need": 1, "reward": {"stone": 8}},
	{"id": "ore", "text": "Dig iron from a guarded vein", "event": "gather:ore", "need": 4, "reward": {"wood": 8}},
	{"id": "iron", "text": "Smelt iron at your forge", "event": "craft:iron", "need": 2, "reward": {"rope": 2}},
	{"id": "honey", "text": "Win honey from a wild hive", "event": "gather:honey", "need": 2, "reward": {"berries": 6}},
	{"id": "cake", "text": "Bake a honey cake by the fire", "event": "craft:honeycake", "need": 1, "reward": {"wood": 6}},
	{"id": "walls", "text": "Raise four walls of a cabin", "event": "build:wall", "need": 4, "reward": {"wood": 8}},
	{"id": "roof", "text": "Put a roof over your head", "event": "build:roof", "need": 2, "reward": {"stone": 6}},
	{"id": "bed", "text": "Sew a quilt and build a bed", "event": "build:bed", "need": 1, "reward": {"berries": 4}},
	{"id": "sleep", "text": "Sleep the night through", "event": "sleep", "need": 1, "reward": {"wood": 6}},
	{"id": "tinker", "text": "Trade with the travelling tinker", "event": "tinker", "need": 1, "reward": {"rope": 1}},
	{"id": "tales", "text": "Hear three tall tales by the campfire", "event": "tale", "need": 3, "reward": {"honey": 1}},
	{"id": "satchel", "text": "Find a lost satchel out in the wilds", "event": "satchel", "need": 1, "reward": {"berries": 4}},
	{"id": "skep", "text": "Keep bees: build a skep and take its honey", "event": "skep", "need": 1, "reward": {"berries": 4}},
	{"id": "snowman", "text": "Build a snowman on a snow day", "event": "build:snowman", "need": 1, "reward": {"honey": 1}},
	{"id": "request", "text": "Fill one of the tinker's special requests", "event": "request", "need": 1, "reward": {"iron": 1}},
	{"id": "growtree", "text": "Plant an apple sapling and see it grow", "event": "growtree", "need": 1, "reward": {"honey": 1}},
	{"id": "letter", "text": "Read a letter from the mailbox", "event": "letter", "need": 1, "reward": {"rope": 1}},
	{"id": "jar", "text": "Catch a jarful of lightning bugs (craft the jar at a workbench)", "event": "firefly", "need": 6, "reward": {"honey": 2}},
	{"id": "cat", "text": "Make friends with Marmalade, the barn cat", "event": "cat", "need": 3, "reward": {"fish": 1}},
	{"id": "star", "text": "Find a fallen star (watch the sky on a clear night)", "event": "star", "need": 1, "reward": {"honey": 1}},
	{"id": "ribbon", "text": "Win a ribbon at the County Fair (every seventh day)", "event": "ribbon", "need": 1, "reward": {"honeycake": 1}},
	{"id": "dance", "text": "Dance a reel at the barn dance (fair night and midweek, from 5:30 pm)", "event": "dance", "need": 1, "reward": {"pie": 1}},
	{"id": "peace", "text": "Make peace with a guardian (3 apples for a boar, 2 fish for coyotes)", "event": "peace", "need": 1, "reward": {"honey": 2}},
	{"id": "kite", "text": "Fly a paper kite (make one at a workbench, then G)", "event": "kite", "need": 1, "reward": {"apples": 3}},
	{"id": "leaves", "text": "Run through a pile of autumn leaves", "event": "leaves", "need": 1, "reward": {"berries": 4}},
	{"id": "dandelion", "text": "Set a dandelion clock a-flying (walk through them in a meadow)", "event": "dandelion", "need": 3, "reward": {"honey": 1}},
	{"id": "cider", "text": "Build a cider press and press a mug of cider", "event": "cider", "need": 1, "reward": {"iron": 1}},
	{"id": "fetch", "text": "Play fetch with Old Blue (scratch him, and he may bring a stick)", "event": "fetch", "need": 3, "reward": {"pelt": 1}},
	{"id": "johnny", "text": "Pass the time of day with Johnny Appleseed when he comes by", "event": "johnny", "need": 1, "reward": {"honey": 1}},
	{"id": "feeder", "text": "Build a bird feeder and fill it (corn or berries)", "event": "feeder", "need": 1, "reward": {"rope": 1}},
	{"id": "skate", "text": "Go skating on a frozen pond (after a good snow)", "event": "skate", "need": 8, "reward": {"honeycake": 1}},
	{"id": "calf", "text": "Find the lost calf and lead it home (when it wanders)", "event": "calf", "need": 1, "reward": {"biscuits": 1}},
	{"id": "woodpile", "text": "Build a woodpile and stack a dozen logs on it", "event": "stack", "need": 12, "reward": {"honey": 1}},
	{"id": "giant", "text": "Grow a giant pumpkin on a patch (tend it each day) and cut it", "event": "giant", "need": 1, "reward": {"honeycake": 1}},
	{"id": "grandma", "text": "Knock at the farmhouse door of an evening (Grandma is up till half past ten)", "event": "grandma", "need": 1, "reward": {"wool": 2}},
	{"id": "ring", "text": "Find a fairy ring of toadstools (the morning after a rainy night)", "event": "ring", "need": 1, "reward": {"honey": 1}},
	{"id": "wish", "text": "Bring Grandma what she's wishing for (knock of an evening)", "event": "wish", "need": 1, "reward": {"honey": 1}},
	{"id": "night", "text": "Watch the fireflies come out", "event": "night", "need": 1, "reward": {"berries": 4}},
	{"id": "ironaxe", "text": "Forge an iron axe", "event": "craft:ironaxe", "need": 1, "reward": {"stone": 10}},
	{"id": "coat", "text": "Sew a sheepskin coat from pelts", "event": "craft:coat", "need": 1, "reward": {"honey": 2}},
	{"id": "whiskers", "text": "Land Old Whiskers, the night-time catfish of legend", "event": "legendfish", "need": 1, "reward": {"honeycake": 2}},
	{"id": "legend", "text": "Drive off five guardians — a tall tale!", "event": "slay", "need": 5, "reward": {"iron": 4}},
]

var progress := {}      ## goal id -> count
var done := {}          ## goal id -> true
var day_log := {}       ## event -> count, today

func load_state(data) -> void:
	if data == null: return
	progress = (data.get("progress", {}) as Dictionary).duplicate()
	done = {}
	for id in data.get("done", []): done[id] = true

func save() -> Dictionary: return {"progress": progress, "done": done.keys()}

## Record something that happened: into the day's log, and toward every goal still to do.
func record(event: String, n := 1) -> bool:
	day_log[event] = int(day_log.get(event, 0)) + n
	var changed := false
	for g in GOALS:
		if g.event != event or done.has(g.id): continue
		var before: int = progress.get(g.id, 0)
		progress[g.id] = mini(g.need, before + n)
		changed = changed or progress[g.id] != before
	return changed

## Raise progress to at least count (for things the save can vouch for).
func at_least(id: String, count: int) -> void:
	for g in GOALS:
		if g.id == id and not done.has(id): progress[id] = maxi(int(progress.get(id, 0)), mini(g.need, count))

static func plural(n: int, one: String, many: String) -> String: return "%d %s" % [n, one if n == 1 else many]

## The day as the almanac tells it (main.js almanacLines): up to nine lines.
func almanac_lines(recipe_name: Callable, piece_name: Callable) -> Array:
	var out := []; var L := day_log
	if L.has("chop"): out.append("felled " + plural(L.chop, "tree", "trees"))
	if L.has("mine"): out.append("broke %s with the pick" % plural(L.mine, "rock", "rocks"))
	if L.has("pick"): out.append("picked %s clean" % plural(L.pick, "berry bush", "berry bushes"))
	for k in L:
		var n: int = L[k]
		if k == "gather:fish": out.append("caught " + plural(n, "fish", "fish"))
		elif k.begins_with("gather:") and not (k.substr(7) in ["wood", "stone", "berries"]): out.append("gathered %d %s" % [n, k.substr(7)])
	var made := []
	for k in L: if k.begins_with("craft:") and not k.begins_with("craft:t-"): made.append(String(recipe_name.call(k.substr(6))).to_lower())
	if made.size(): out.append("made %s%s" % [", ".join(made.slice(0, 4)), " and more" if made.size() > 4 else ""])
	var built := []
	for k in L:
		if not k.begins_with("build:"): continue
		var nm := String(piece_name.call(k.substr(6))).to_lower(); var n: int = L[k]
		built.append(("a " + nm) if n == 1 else "%d %s%s" % [n, nm, "es" if nm.ends_with("s") else "s"])
	if built.size(): out.append("raised " + ", ".join(built.slice(0, 4)))
	if L.has("slay"): out.append("drove off " + plural(L.slay, "treasure guardian", "treasure guardians"))
	if L.has("deer"): out.append("spotted %s in the woods" % plural(L.deer, "deer", "deer"))
	for pair in [["livestock", "did the milking and the shearing"], ["shoo", "shooed the crows out of the corn"], ["skep", "took honey from the bees"],
			["letter", "read a letter from the mailbox"], ["star", "found a fallen star in the grass"], ["peace", "made peace with a guardian, with a gift"],
			["johnny", "talked with Johnny Appleseed, who planted you a tree"], ["calf", "found the lost calf and led it home"], ["dance", "danced a reel at the barn dance"]]:
		if L.has(pair[0]): out.append(pair[1])
	if L.has("ribbon"): out.append("won %s at the County Fair" % plural(L.ribbon, "ribbon", "ribbons"))
	if L.has("tinker"): out.append("traded with the tinker")
	if L.has("request"): out.append("filled the tinker's special request")
	if L.has("dogfind"): out.append("took whatever Old Blue dug up, with thanks")
	if L.has("tale"): out.append("told %s by the fire" % plural(L.tale, "tall tale", "tall tales"))
	if L.has("satchel"): out.append("found a lost satchel out in the wilds")
	if L.has("legendfish"): out.append("landed OLD WHISKERS himself, and nobody will believe it")
	return out.slice(0, 9)
