class_name Mail
extends RefCounted
## mail.js: rural free delivery. Each morning from Day 2 the mail carrier comes up the lane (from 09:00) and the red
## flag on the farm mailbox springs up when there's a letter waiting. E at the box reads it: a page in a kin's or
## neighbour's hand with a little something folded in. The letters come in order, then small notes at random.

const LETTERS := [
	{"from": "Aunt Ida, over in Clay County", "text": "Dear one, the frost took my tomatoes but not my good humour. I am sending a length of the rope your uncle swore he would use to fix the porch swing in 1911. He never did. Maybe you will.", "gift": {"rope": 2}, "note": "2 rope folded in brown paper"},
	{"from": "Miss Larkin, at the schoolhouse", "text": "The children drew pictures of every farm on the route and voted yours \"most likely to have a friendly dog.\" They took up a collection of what was in their pockets. I am afraid most of it is string.", "gift": {"fiber": 4, "apples": 2}, "note": "4 fibre and 2 slightly pocket-warm apples"},
	{"from": "Cousin Wendell, down at the mill", "text": "Found this horseshoe in the millrace and figured a farmer could use the luck more than a miller. Hang it points up so the luck stays in, or melt it down. Your call, but I know which my grandpa would say.", "gift": {"iron": 1}, "note": "an old horseshoe (1 iron)"},
	{"from": "The Ladies of the Grange Hall", "text": "Our honey cake took second at the fair, behind Mrs. Abernathy, who we suspect of using store-bought butter. Please enjoy this piece as proof of our superior recipe, and say nothing to Mrs. Abernathy.", "gift": {"honeycake": 1}, "note": "a honey cake wrapped in waxed paper"},
	{"from": "The County Extension Agent", "text": "Circular No. 14: rotate your crops, mend your fences, and do not let the crows see you sad. Enclosed please find seed corn. The agent apologises for the smell of the envelope; it rode with a goat.", "gift": {"corn": 3}, "note": "3 ears of seed corn"},
	{"from": "Grandpa Asa, who never writes", "text": "Writing. Fish are biting on the north bend if you go before the sun is high. Use a bit of corn. Your grandmother says eat something. That is all the news.", "gift": {"fish": 1}, "note": "a trout, wrapped in newspaper (how?)"},
	{"from": "The tinker, posted from somewhere west", "text": "Friend, the roads are long and the coffee is worse. If you see a thunderhead hanging about, tell it I said hello and that I owe it nothing. A little wax and wick enclosed for your trouble.", "gift": {"honey": 1}, "note": "a jar of honey (the tinker said wax)"},
	{"from": "Aunt Ida again", "text": "I knitted you mittens but the cat had opinions about them. Here is the wool that survived. Make something warm before the snow comes, and write your poor aunt back once in a while.", "gift": {"wool": 3}, "note": "3 wool, slightly chewed"}]
const SMALL := [
	{"from": "A neighbour", "text": "Saw your lamp burning late. Thought you could use these. No need to thank me.", "gift": {"egg": 2}, "note": "2 eggs in a nest of straw"},
	{"from": "The mail carrier", "text": "No letters today, but the apple tree by the creek dropped more than I could carry.", "gift": {"apples": 3}, "note": "3 apples"},
	{"from": "Aunt Ida", "text": "Still waiting on that letter. Here is some rope in case your pen broke and you need to tie it together.", "gift": {"rope": 1}, "note": "1 rope"}]

var flag: Node3D
var at: Vector3
var read := 0
var last_day := 1
var waiting := false
var up := false
var flag_t := 10.0
var _rest := Basis()

func _init(flag_node: Node3D, mailbox: Vector3) -> void:
	flag = flag_node; at = mailbox
	if flag: _rest = flag.basis

func load_state(s) -> void:
	if s == null: return
	read = s.get("read", 0); last_day = s.get("lastDay", 1); waiting = bool(s.get("waiting", false)); up = waiting; flag_t = 10.0

func save() -> Dictionary: return {"read": read, "lastDay": last_day, "waiting": waiting}

func near(p: Vector3, r := 1.8) -> bool: return Vector2(p.x - at.x, p.z - at.z).length() < r

## The carrier comes by mid-morning. Returns true the moment a letter lands.
func update(dt: float, sky: DaySky) -> bool:
	var arrived := false
	if not waiting and sky.day > last_day and sky.time >= 0.375 and sky.time < 0.9:
		waiting = true; last_day = sky.day; up = true; flag_t = 0.0; arrived = true
	# the flag swings up on its pin with a springy overshoot, and drops back with a soft slap
	flag_t += dt
	var k: float = Props.spring_rise(flag_t * 1.4) if up else 1.0 - minf(1.0, pow(flag_t / 0.35, 2))
	if flag: flag.basis = _rest * Basis(Vector3.RIGHT, -(1.0 - k) * (PI / 2))
	return arrived

## Take the letter out: {from, text, gift, note}, or null if the box is empty.
func take():
	if not waiting: return null
	var L: Dictionary = LETTERS[read] if read < LETTERS.size() else SMALL[randi() % SMALL.size()]
	read += 1; waiting = false; up = false; flag_t = 0.0
	return L
