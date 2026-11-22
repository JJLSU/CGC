class_name GatherRules
## crafting.js's damageFor / toolFor / SOFT and main.js's WEAR_PER_HIT, wrongTool, E_PICK, SATCHELS and the hint verbs.

const SOFT := ["bush", "grass", "mushroom", "hive", "corn", "pumpkin", "apples", "stook", "satchel", "sang", "pearl"]
const E_PICK := {"bush": "Pick the berries", "mushroom": "Pick the toadstools", "grass": "Pull an armful of tall grass", "apples": "Pick up the windfall apples", "stook": "Gather the wheat sheaves", "corn": "Pick the sweet corn", "pumpkin": "Pick the pumpkin", "hive": "Take honey from the wild hive", "satchel": "Open the lost satchel"}
const SATCHELS := [
	[{"iron": 2}, "two bars of iron wrapped in a note: \"For the next fellow. —Amos\""],
	[{"honey": 2, "berries": 4}, "a jar of honey, a twist of berries and a pressed clover"],
	[{"pelt": 2}, "two good pelts and a tally of coyotes, crossed out"],
	[{"rope": 3}, "three coils of rope and a map of the creek, mostly wrong"],
	[{"ore": 3}, "a sack of ore and a pick-handle with no pick"],
	[{"honeycake": 1, "egg": 2}, "a honey cake in a handkerchief and two eggs, still whole"],
]

static func damage_for(type: String, tools: Dictionary, held := "axe") -> int:
	var axe := 4 if tools.has("steelaxe") else (3 if tools.has("ironaxe") else (2 if tools.has("stoneaxe") else 1))
	var pick := 4 if tools.has("steelpick") else (3 if tools.has("ironpick") else (2 if tools.has("pickaxe") else 0))
	if type == "enemy": return 4 if held == "spear" else (axe if held == "axe" else (maxi(1, pick) if held == "pick" else 1))
	if type == "ore" or type == "geode": return pick if held == "pick" else 0
	if type == "silver" or type == "quartz": return pick - 1 if held == "pick" and pick >= 3 else 0
	if type == "rock" or type == "stonepiece": return pick + 1 if held == "pick" and pick > 0 else 1
	if type == "clay": return 2 if held == "pick" else 1
	if type in SOFT: return 1
	return axe if held == "axe" else 0

static func tool_for(type: String):
	if type in ["ore", "silver", "quartz", "geode"]: return "pick"
	if type in ["rock", "stonepiece", "clay"] or type in SOFT: return null
	return "axe"

static func wear_per_hit(held: String, tools: Dictionary) -> float:
	if held == "axe": return 0.35 if tools.has("steelaxe") else (0.6 if tools.has("ironaxe") else (1.0 if tools.has("stoneaxe") else 1.25))
	if held == "pick": return 0.35 if tools.has("steelpick") else (0.6 if tools.has("ironpick") else 1.0)
	return 0.8 if held == "spear" else 0.0

static func wrong_tool(type: String, tools: Dictionary, owns_pick: bool) -> String:
	var want = tool_for(type); var nm := String(Res.TYPES[type].name).to_lower()
	if want == "pick" and (type == "quartz" or type == "silver") and not tools.has("ironpick") and not tools.has("steelpick"): return "Too hard! Needs an IRON pickaxe"
	if want == "pick": return "That %s wants the pickaxe: press 3" % nm if owns_pick else "Your tools just bounce off the %s. Make a pickaxe at a workbench (C)." % nm
	return "You'll want the axe for the %s: press 2" % nm

static func verb(type: String) -> String:
	if type == "satchel": return "Open the"
	if type == "stook": return "Gather the"
	if type in ["bush", "mushroom", "grass", "corn", "pumpkin", "apples"]: return "Pick"
	if type == "hive": return "Take honey from"
	if type == "clay": return "Dig"
	if type in ["rock", "ore", "quartz"]: return "Mine"
	return "Chop"
