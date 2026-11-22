class_name Tales
extends RefCounted
## tales.js: tall tales by the fire. Sit at a campfire after dark (E) and the farmer tells himself one of the old
## county stories, printed on a paper card; an hour slips by and the fire mends you. Original tellings.

const TALES := [
	{"title": "The Summer the Corn Grew Too Tall", "text": "Old Mabry planted his corn the week of the big thunder, and by July the stalks were brushing the clouds. He sent his boy up one to fetch an ear for supper, and the boy came down in October with a beard, a sack of ears, and a story about the moon being mostly cheese rind after all."},
	{"title": "The Crow Who Kept Accounts", "text": "There was a crow down by the mill who could count to a hundred and never forgot a debt. Every kernel you took from his field he wrote on a birch leaf, and every autumn he came to collect. Folks say that is why we leave the last row standing: it squares the ledger."},
	{"title": "How the River Learned to Bend", "text": "Back when the river ran straight as a fence rail, it was in such a hurry that the fish got dizzy. A heron stood in the middle of it one whole summer and would not budge, so the water had to go around. It liked the scenery so much it has been taking the long way ever since."},
	{"title": "The Tinker and the Thunderhead", "text": "One spring a thunderhead parked over the county and would not move along. The tinker sold it a tin bucket, a length of rope and a jar of honey, and talked so long about the roads to the west that the storm packed up and followed him, raining polite little showers the whole way."},
	{"title": "The Boar Who Guarded Nothing", "text": "Deep in the woods an old bramble boar guarded a hollow log for forty years. When a farmer finally peeked inside, there was only a note in a careful hand: \"Keep watching.\" Nobody knows who wrote it, but the boars out there still take the job seriously."},
	{"title": "The Quilt That Kept the Frost Away", "text": "Grandmother Pell stitched a quilt from every patch of every shirt the family ever wore out. The first cold night she spread it over the garden instead of the bed, and Jack Frost took one look, recognised his own old mittens in the corner square, and went home ashamed."}]

var heard := {}   ## index -> true

func load_state(list) -> void:
	for i in (list if list != null else []): heard[int(i)] = true
func save() -> Array: return heard.keys()

## The next tale: one not heard yet if any remain, else any.
func next() -> int:
	var pool := []
	for i in TALES.size(): if not heard.has(i): pool.append(i)
	if pool.is_empty(): pool = range(TALES.size())
	return pool[randi() % pool.size()]

## Tell one: {i, new, title, text}.
func tell() -> Dictionary:
	var i := next(); var is_new := not heard.has(i); heard[i] = true
	return {"i": i, "new": is_new, "title": TALES[i].title, "text": TALES[i].text}
