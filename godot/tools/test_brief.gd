extends SceneTree
## Hud.brief: long notes cut to one short line. Prints a sample of the game's own notes before and after. Headless.
func _initialize() -> void:
	for t in ["A tinker's wagon rattles into Cold Glitter Creek and draws up at the head of Main Street. He has a request today: half a dozen eggs.",
			"The assayer weighs it on his brass scales. \"$42, and not a cent more.\" Fortune so far: $120.",
			"Claim jumpers! A ragged camp of hard cases, and they've seen you. They come at you swinging. Fight, or run for it.",
			"A hot supper of stew and bread. An old-timer at the bar leans over: \"An iron vein the coyotes keep, 120 paces NE of town.\" He pencils it onto your map.",
			"Inside his poke: 6 dollars.", "+2 wood", "Snap! A postcard of the farm is in your Downloads folder.",
			"You came west chasing a gold rumour. Something glints by the cabin...",
			"Word spreads that Cold Glitter Creek is coming up in the world: folk are putting up Second Street beside the old street. Its buildings want mending too (B to see the costs)."]:
		var b := Hud.brief(t)
		print("%2d  %s" % [b.length(), b])
	quit()
