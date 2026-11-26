extends Node3D
## The game's root, as main.js: builds the world, the lights and the camera, then runs every system each frame.
## (Grows step by step; see PORT.md.)

var rig: CameraRig
var sky: DaySky
var weather: Weather
var storm: Storm
var night_sky: NightSky
var ice := 0.0
var mist: Mist
var rainbow: Rainbow
var puddles: Puddles
var falling_stars: FallingStars
var night_rain := false
var expo := 1.4
var env: WorldEnvironment
var focus: Node3D
var input: GameInput
var player: Player
var post: ShaderMaterial
var keep_prefs := not OS.get_cmdline_args().has("--script") ## (tests leave the player's F3 and O settings alone)
const DEV_PATH := "user://paperfjord.dev" ## (F3 remembered, the page's localStorage 'paperfjord.dev')
var tear_logger: TearLogger
var tears := 0
var first_frame := false
var quality: Quality ## O: graphics quality, P: depth of field (scripts/core/quality.gd)
var hud: Hud
var build: BuildSystem
var place_cd := 0.0
var crafting: Crafting
var panel: CraftingPanel
var hunger_warned := 0
var inventory := {"wood": 0, "stone": 0, "berries": 0, "apples": 0, "applecrisp": 0, "fiber": 0, "rope": 0, "clay": 0, "mushrooms": 0, "honey": 0, "ore": 0, "iron": 0, "pelt": 0, "whiskers": 0, "milk": 0, "wool": 0, "biscuits": 0, "egg": 0, "flapjacks": 0, "fish": 0, "fishfry": 0, "corn": 0, "wheat": 0, "bread": 0, "ribbon": 0, "giantpumpkin": 0, "pumpkin": 0, "stew": 0, "cornbread": 0, "pie": 0, "honeycake": 0, "flour": 0, "applepie": 0, "bricks": 0, "sap": 0, "syrup": 0, "johnnycake": 0, "leather": 0, "charcoal": 0, "steel": 0, "gold": 0, "dollars": 0, "sang": 0, "silver": 0, "pearl": 0, "geode": 0, "amber": 0}
var tools := {}      ## (a Set in the web: tool id -> true)
var held := "axe"    ## the tool in hand, picked from the tool bar with 1-8
var wear := {"axe": 100.0, "pick": 100.0, "spear": 100.0}  ## how sharp each tool is (0 = dull: half strength)
var force_active := false ## (tests: play without the pointer captured)
var world: World
var homestead: Homestead
var extras: FarmExtras
var critters: Critters
var dog: Dog
var cat: Cat
var calf: Calf
var ambient: Ambient
var butterflies: Butterflies
var wade_rings: Wake
var ducks: Ducks
var tumbleweeds: Tumbleweeds
var frogs: Frogs
var beaver: Beaver
var songbirds: Songbirds
var crows: Crows
var owl: Owl
var eagle: Eagle
var geese: Geese
var dandelions: Dandelions
var johnny: Wanderer
var night_howl: NightHowl
var hunting: Hunting
var enemies: Enemies
var settlers: Settlers
var camp: NativeCamps
var town: Town
var railroad: Railroad
var train: Train
var claim: Claim
var rumours: Rumours
var prof = null   ## (a profiler run sets this to {} and _process stamps its sections into it)
var _pm_t := 0
func _pm(n: String) -> void:
	if prof == null: return
	var t := Time.get_ticks_usec(); prof[n] = prof.get(n, 0.0) + (t - _pm_t) / 1000.0; _pm_t = t
var sound: Sound
var water_near := 0.0
var water_t := 0.0
var land_here := "home"
var lands_found := {}
var bell_day := -1
var bell_t := -1.0
var hymn_t := 0.0
var hymn_i := 0
var piano_t := 0.0
var HYMN: Array = []
var next_t := 0.0
const FOODS := ["johnnycake", "applepie", "honeycake", "roast", "pie", "applecrisp", "flapjacks", "stew", "biscuits", "bread", "fishfry", "cornbread", "apples", "berries"]
var kite: Kite
var footprints: Footprints
var leaf_piles: LeafPiles
var fairy_ring: FairyRing
var shafts: Shafts
var wisp: Wisp
var hoof_dust: HoofDust
var ring_rain := false
var leaf_kicks := 0
var wisp_told := false
var rider_day := -1
var mill_pending := false
var mill_view_day := -1
var journal := Journal.new()   ## (journal.js: a tally of what you've done; the almanac reads the day back when you sleep)
var mail: Mail
var tales := Tales.new()
var story_kind := ""           ## which story card is up: "tale", "letter" or "almanac"
var almanac_t := 0.0
var cal_t := 0.0
var tinker: Tinker
var fair: Fair
var grandma: Grandma
var fair_told_day := -1
var dance_told_day := -1
var newcomers: Array = []
var newcomer_news := false
var glint: Node3D = null
var glint_t := 0.0
var glint_told := false
var opening_done := false
var rail_check_t := 2.0
var fortune := 0          ## dollars the assayer has paid you, all told (the farmhouse mends as it grows)
var pan_t := 0.0
var pan_mesh: MeshInstance3D
var bounty = null         ## the sheriff's posted bounty: {key, guards, x, z, name, pay}
var poster: Node3D
var hotel_night := false
var blessed_day := -1
var dolly_day := -1
var tips_heard := {}     ## (the saloon's tips already told, pencilled on the county map)
var stage_idx := 0
var stage_from = null
const MARKET := [["pelt", 5, "a furrier in St. Louis"], ["wool", 3, "a woollen mill in Lowell"], ["honey", 5, "a confectioner in Chicago"], ["venison", 3, "a chophouse in Denver"],
	["leather", 7, "a saddler in Kansas City"], ["syrup", 6, "a hotel in San Francisco"], ["charcoal", 2, "the smelter at Leadville"], ["egg", 1, "a bakery in Cheyenne"]]
const DIRS8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
var dance: BarnDance
var dance_t := 0.0
var fireworks: Fireworks
var quitting := false
var celebrate_day := -1   ## the night the town fires off rockets for a boss beaten and his prize brought home
var fire_smoke: FireSmoke
var fw_day := -1
var raid_day := 3 + randi() % 3
var raid_hooks := {}
var meeting_day := -1
var opera_day := -1
var landmarks: Landmarks
var climbs: Climbs
var jumpers: ClaimJumpers
var jumper_hooks := {}
var jumper_t = null
var forts: ArmyForts       ## the cavalry's posts out in the county (the player's ask)
var fort_hooks := {}
var soldier_t = null
var wayfarers: Wayfarers  ## travellers camped about the county (the player's new folk)
var boss: Boss            ## Mad Jebediah, who stole the townsite deed (the player's boss battles)
var bosses: Array = []    ## every boss, in street order (Boss.ORDER): Jebediah, then Big Angus
var boss_t = null
const JUMPER_LOOT := [{"dollars": 6}, {"dollars": 11}, {"gold": 1, "dollars": 3}, {"cartridges": 4, "dollars": 2}, {"silver": 1}, {"dollars": 4, "rope": 1}]
var camp_t = null        ## a warrior in front, this frame (for a blow)
var camp_hooks := {}
var arrivals: Array = []
var tales_heard := {}     ## the tall tales you've heard (tales.js): Old Cyrus wants three
var settlers_card: PanelContainer
var set_t := 0.0
var enemy_t = null       ## {enemy, dist}: the guardian in front, this frame
var death_timer := 0.0
var met_keepers := {}
## What the old folks say of the wild lands' treasures (shown the first time you find each).
const TREASURE_LORE := {
	"sang": "Wild sang! The forked root of the ginseng, dug from the Hollows. The tinker pays well for three.",
	"silver": "Silver, bright as a new dime in the red rock. Two of these and the tinker will hand over steel.",
	"pearl": "A pearl from the fen mussels, pale as the moon on black water. The tinker will want a pair.",
	"geode": "A thunder egg, cracked open on a heart of violet crystal. The tinker collects them.",
	"amber": "Pine amber, gold and warm, with a gnat sealed in it. The tinker takes three.",
}
const STONE_PIECES := ["stonewall", "campfire", "forge", "kiln", "brickwall"]
var piece_t = null       ## a built piece in front of you (struck like a resource: broken, its cost comes back)
const KEEPER_LORE := {
	"hodag": "The HODAG! Up out of the reeds it comes, horns and spikes and a grin full of teeth. It keeps the pearls.",
	"wampus": "A WAMPUS CAT drops out of the pines, all smoke and lamp-yellow eyes! Mind its pounce.",
	"gouger": "A sidehill gouger! It lists along on its short uphill legs, and it doesn't like company near its silver.",
	"hidebehind": "Something was behind you all along: the HIDEBEHIND, tall and grey as birch shadow!",
	"coyote": "Coyotes! A whole pack, out of the long grass. They keep the thunder eggs.",
}
const PEACE := {
	"coyote": {"cost": {"fish": 2}, "give": "Toss the coyotes 2 fish (a peace offering)", "hint": "The coyotes might doze off for 2 fish",
		"lore": "Folks say the dust-devil coyotes will doze off for a couple of fish.", "thanks": "The coyotes gulp the fish, circle three times and curl up in the sun. What they keep is yours till morning."},
	"boar": {"cost": {"apples": 3}, "give": "Toss the old boar 3 apples (a peace offering)", "hint": "The old boar might take kindly to 3 apples",
		"lore": "The old tales say a bramble boar can be bought off with three good apples.", "thanks": "The old boar snuffles up the apples, grunts, and settles down for a nap. Mind you don't wake him."},
	"gouger": {"cost": {"berries": 4}, "give": "Toss the gougers 4 berries (a peace offering)", "hint": "The gougers might nod off for 4 berries",
		"lore": "They say a sidehill gouger will nod off for a handful of berries (4).", "thanks": "The gougers lap up the berries, lean into the hillside on their short legs and nod off. The silver is yours till morning."},
	"hodag": {"cost": {"fish": 3}, "give": "Toss the Hodag 3 fish (a peace offering)", "hint": "The Hodag might be bought off with 3 fish",
		"lore": "Up north they say a Hodag will trade a night's peace for a mess of fish (3).", "thanks": "The Hodag crunches the fish bones and all, grins its awful grin, and sinks down in the reeds to sleep it off. The pearls are yours till morning."},
	"wampus": {"cost": {"milk": 2}, "give": "Set out 2 pails of milk for the wampus cat (a peace offering)", "hint": "The wampus cat might settle for 2 pails of milk",
		"lore": "Old-timers set out milk for the wampus cat, the way you would for any cat, only more of it (2 pails).", "thanks": "The wampus cat laps the milk, washes its whiskers, and curls up on the ridge with its tail over its nose. The amber is yours till morning."},
	"hidebehind": {"cost": {"honey": 2}, "give": "Leave 2 jars of honey behind you (a peace offering)", "hint": "The Hidebehind might leave you be for 2 jars of honey",
		"lore": "They say if you leave honey behind you (2 jars), the Hidebehind is too busy with it to follow.", "thanks": "You set the honey down and do not look back. Something behind you sighs, and sticky slurping follows. The sang is yours till morning."},
}
var fishing: Fishing
var guns := {"revolver": {"size": 6, "loaded": 6, "reload": 0.0, "time": 2.4}, "rifle": {"size": 1, "loaded": 1, "reload": 0.0, "time": 1.6}} ## (rounds in the gun; reload seconds)
var fish_r := {"engaged": false, "hint": ""}
var hunt_told := false
var jump_told := false
var dandelion_told_at := -1e9
var crows_warned := false
var jar_count := 0     ## lightning bugs in the jar (jar.js; the lantern in the hand: avatar.jar_update)
const JAR_MAX := 6
var horse: Horse        ## Biscuit, once bought at the livery (null till then)
var riding := false
var horse_saved := {"owned": false, "x": 0.0, "z": 0.0}
var crow_day := -1
var spawn := Vector3.ZERO
var world_seed := 20261120
var world_ring := Vector2(130, 210)
## The save (main.js saveAll / BuildSystem.save): one JSON in the same shape as the web's localStorage
## "paperfjord.builds.v1", in user://. A game run from a test script (--script) uses the original world and leaves
## the player's save alone unless the test sets save_path and saving itself.
var save_path := OS.get_environment("CGC_SAVE_PATH") if OS.get_environment("CGC_SAVE_PATH") != "" else "user://paperfjord.builds.v1.json"
var saving := not OS.get_cmdline_args().has("--script") or OS.get_environment("CGC_SAVE_PATH") != "" ## (CGC_SAVE_PATH: a test's own throwaway save)
var saved = null
var autosave_t := 0.0
var saved_fullness = null

func _ready() -> void:
	get_tree().auto_accept_quit = false # (closing the window goes through _quit_game: saved, and the model loads finished first)
	if OS.get_environment("CGC_QUIT_AT_MS") != "": get_tree().create_timer(float(OS.get_environment("CGC_QUIT_AT_MS")) / 1000.0).timeout.connect(_quit_game) # (a check: quit as the Quit button does, mid-load)
	saved = _read_save() if saving else null
	if saved == null and saving: world_seed = randi() & 0x7fffffff; world_ring = Vector2(60, 115) # (a new game: a county of its own, wild lands close by)
	if saved != null: _apply_early(saved)
	_make_environment()
	sky = DaySky.new(env.environment); add_child(sky)
	weather = Weather.new(); add_child(weather)
	sound = Sound.new(); add_child(sound) # (audio.js: the soundscape, baked from the web's own synth)
	HYMN = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/sound/hymn.json")).HYMN
	storm = Storm.new(); add_child(storm)
	storm.on_thunder = func(v: float) -> void: sound.thunder(v)
	night_sky = NightSky.new(); add_child(night_sky)
	mist = Mist.new(); add_child(mist)
	rainbow = Rainbow.new(); add_child(rainbow)
	puddles = Puddles.new(); add_child(puddles)
	falling_stars = FallingStars.new(); add_child(falling_stars)
	# after a daytime shower, a rainbow stands up out of the far fields, and a beat later the note
	weather.on_end = func() -> void:
		if weather.kind == "rain" and sky.night < 0.25:
			rainbow.show_at(player.pos, sky.sun_dir)
			get_tree().create_timer(2.5).timeout.connect(func() -> void: hud.toast("Look: a rainbow, standing up out of the far fields like a page in a pop-up book."))
	input = GameInput.new(); add_child(input)
	hud = Hud.new(); add_child(hud)
	# the title card: a click on it takes the mouse; letting the mouse go brings it back (main.js onLockChange)
	hud.on_overlay_click = func() -> void: input.lock()
	hud.on_newgame = _new_game
	hud.on_devcash = _dev_cash
	hud.on_save = func() -> void: save_all(); hud.flash_saved("Saved ✓" if saving else "Not saved (test run)")
	hud.on_quit = _quit_game
	hud.on_option = _cycle_option
	hud.option_value = _option_text
	_load_display()
	hud.on_time_preset = func(i: int) -> void: sky.time = Hud.TIME_PRESETS[i][1]; hud.set_time_chip(i); sound.click()
	if keep_prefs and FileAccess.file_exists(DEV_PATH): hud.set_dev(true)
	if OS.get_environment("CGC_NO_TEAR") == "": tear_logger = TearLogger.new(self); OS.add_logger(tear_logger)
	input.on_lock_change = func(locked: bool) -> void:
		lock_changed_at = Time.get_ticks_msec()
		hud.show_overlay(not locked and not panel.open); hud.show_peek(false); hud.cta.text = "Click to resume"
	confetti = Confetti.new(); add_child(confetti)
	_make_crafting()
	rig = CameraRig.new(); add_child(rig)
	_make_post()
	rig.height_at = func(x: float, z: float) -> float: return Terrain.get_height(x, z)
	# the world: the seed (old saves keep 20261120 and the far ring; a new game rolls its own), the farm's spot on a
	# level sheet, and the home valley's mountain rim round it (main.js)
	Terrain.set_seed(world_seed, world_ring)
	var center := Terrain.find_spawn()
	Terrain.set_flat_area(center.x, center.z, 24, 38)
	Terrain.set_range_center(center.x, center.z)
	world = World.new(); add_child(world)
	town = Town.new(world, center); add_child(town) # (Cold Glitter Creek, down the lane: lays its own level ground before chunks exist)
	town.on_stage = func() -> void:
		if Vector2(player.pos.x - town.at.x, player.pos.z - town.at.z).length() < 60.0: hud.toast("A horn sounds down the lane: the Overland stage is rattling into Cold Glitter Creek, and will wait by the boarding house till afternoon.")
	town.make_snowman = func() -> Node3D: return build.make_mesh("snowman")
	railroad = Railroad.new(world, town, center); add_child(railroad) # (its right-of-way surveyed and cleared before the county is built)
	train = Train.new(railroad); add_child(train)
	claim = Claim.new(railroad); add_child(claim) # (your own gold claim, once filed at the Redrock Breaks post)
	claim.on_thump = func(d: float) -> void: if d < 45.0: sound.stamp(maxf(0.1, 1.0 - d / 45.0))
	train.on_whistle = func(q: Vector3) -> void:
		var d := Vector2(q.x - player.pos.x, q.z - player.pos.z).length()
		if d < 220.0: sound.whistle(maxf(0.15, 1.0 - d / 220.0))
	train.on_chuff = func(q: Vector3) -> void:
		var d := Vector2(q.x - player.pos.x, q.z - player.pos.z).length()
		if d < 70.0: sound.chuff(maxf(0.1, 1.0 - d / 70.0))
	train.on_depart = func() -> void:
		var n := railroad.take_freight()
		if n and Vector2(player.pos.x - railroad.depot.x, player.pos.z - railroad.depot.z).length() < 80.0: hud.toast("The freight hands swing your %d crate%s into the boxcar, and the train pulls out for the East." % [n, "s" if n > 1 else ""])
	town.on_street = func(nm: String) -> void: hud.toast("Word spreads that Cold Glitter Creek is coming up in the world: folk are putting up %s beside the old street. Its buildings want mending too." % nm)
	enemies = Enemies.new(world); enemies.on_windup = func(_e) -> void: sound.growl()
	add_child(enemies) # (the guardians come with the world's sites: hooked up before the first chunks)
	# the wild lands' landmarks come and go with their chunks; the guardians' sites with theirs
	climbs = Climbs.new()
	landmarks = Landmarks.new(); landmarks.climbs = climbs; add_child(landmarks)
	Props.landmark_colliders = Landmarks.colliders
	world.on_site_load = func(st: Dictionary) -> void:
		if st.kind == "landmark": landmarks.spawn(st)
		else: enemies.spawn_site(st)
	world.on_site_unload = func(st: Dictionary) -> void:
		if st.kind == "landmark": landmarks.despawn(st)
		else: enemies.despawn_site(st)
	enemies.on_ambush = func(e: Dictionary) -> void:
		sound.growl(); sound.tear()
		if not met_keepers.has(e.kind): met_keepers[e.kind] = true; hud.toast(KEEPER_LORE.get(e.kind, "The %s springs up out of nowhere!" % String(e.spec.name).to_lower()))
	enemies.on_player_hit = func(dmg: int, e: Dictionary) -> void:
		var out := player.hurt(dmg, 0.33 if tools.has("coat") else 0.0)
		hud.hurt(); sound.knock()
		if out: death_timer = 3.0; hud.toast("The %s has the better of you…" % String(e.spec.name).to_lower())
	build = BuildSystem.new(rig.camera); add_child(build)
	world.on_resource_gone = func(res: Dictionary, fell: bool) -> void:
		var def: Dictionary = Res.TYPES[res.type]
		confetti.burst(Vector3(res.x, res.y + (0.5 if fell else 0.6 * res.scale), res.z), def.chips, 46 if fell else 32, 1.1)
		if not fell and res.type == "rock": sound.tear()
	world.regrow_blocked = func(r: Dictionary) -> bool: return build.nearby(r.x, r.z, 0.6).size() > 0
	homestead = Homestead.new(world, center); add_child(homestead) # (registers the farm's exclusions before any chunk exists)
	if saved != null: opening_done = bool(saved.get("opening", false)) or saved.get("fortune", 0) or saved.get("inventory", {}).get("gold", 0)
	if not opening_done: _make_glint()
	homestead.set_fortune(0.0)
	extras = FarmExtras.new(world, center); add_child(extras)
	critters = Critters.new(); add_child(critters)
	critters.on_spotted = func(_c) -> void: journal.record("deer")
	critters.on_gobble = func(d: float) -> void: sound.gobble(maxf(0.15, 1.0 - d / 35.0))
	critters.setup(Vector3(center.x - 20, 0, center.z - 1.5), Vector3(center.x - 5, 0, center.z + 17)) # hens by their coop round the far side of the barn (moved out of the way: the player), cow & sheep in the pasture
	critters.on_herd = func(_c) -> void: hud.toast("A herd of bison grazing the high prairie, shaggy as old haystacks! Folks say they once ran so thick the ground shook for a day. Best not crowd them.")
	critters.on_dressed = func(c: Dictionary) -> void:
		var T: Dictionary
		match c.type:
			"bison": T = {"meat": 5, "pelt": 2, "name": "buffalo"}
			"rabbit": T = {"meat": 1, "pelt": 1 if randf() < 0.4 else 0, "name": "rabbit"}
			"turkey": T = {"meat": 2, "pelt": 0, "name": "wild turkey"}
			_: T = {"meat": 2, "pelt": 1 if randf() < 0.6 else 0, "name": "deer"}
		inventory.venison = inventory.get("venison", 0) + T.meat; inventory.pelt = inventory.get("pelt", 0) + T.pelt
		settlers.discover("pelt")
		sound.pick(); hud.toast("You dress the %s: %d %s%s. Roast the meat at a campfire." % [T.name, T.meat, "cuts of turkey (kept with your venison)" if c.type == "turkey" else "venison", ((" and a buffalo robe (2 pelts)" if T.pelt > 1 else " and a hide (pelt)") if T.pelt else "")])
	# Old Blue and Marmalade (dog.js, cat.js)
	dog = Dog.new(homestead.spawn); add_child(dog)
	dog.on_bark = func() -> void: sound.woof()
	dog.on_track = func() -> void:
		if track_told == sky.day: return
		track_told = sky.day; hud.toast("Old Blue has the calf’s scent! He bounds off a way and barks back at you: follow where he points.")
	dog.on_fetched = func() -> void:
		journal.record("fetch")
		fetches += 1
		if fetches % 3 == 1: hud.toast(["Old Blue gallops back and drops the stick at your feet. Again! Again!", "Back he comes, ears flying, stick held high like a prize.", "He drops it, sits, and stares at the stick. Then at you. Then at the stick."][(fetches / 3) % 3])
	dog.on_dig = func(at: Vector3) -> void: confetti.burst(at, [0x8a6040, 0x6b4a30, 0xb08a5a], 22, 0.7)
	dog.on_find = func() -> void:
		var f: Array = DOG_FINDS[randi() % DOG_FINDS.size()]
		journal.record("dogfind"); sound.woof()
		for k in f[0]: inventory[k] = inventory.get(k, 0) + f[0][k]
		hud.toast("Old Blue trots back and drops %s at your feet." % f[1])
	cat = Cat.new(homestead.C, extras.seat, extras.seat_facing); add_child(cat)
	cat.on_purr = func() -> void: sound.purr()
	calf = Calf.new(Vector3(center.x - 5, 0, center.z + 17)); add_child(calf) # (Daisy's calf, now and then lost)
	calf.on_moo = func(v: float) -> void: sound.moo(v)
	ambient = Ambient.new(); add_child(ambient)
	butterflies = Butterflies.new(); add_child(butterflies)
	wade_rings = Wake.new(); add_child(wade_rings)
	ducks = Ducks.new(); add_child(ducks) # (a mallard and her ducklings on the nearest pond)
	ducks.on_quack = func(d: float) -> void: if d < 40.0: sound.quack(maxf(0.15, 1.0 - d / 40.0))
	ducks.on_ring = func(x: float, z: float, sz: float) -> void: wade_rings.ring(x, z, sz)
	tumbleweeds = Tumbleweeds.new(); add_child(tumbleweeds) # (dry brush bowling down the wind in town and the Breaks)
	frogs = Frogs.new(); add_child(frogs) # (on the lily pads)
	frogs.on_croak = func(v: float) -> void: sound.croak(v)
	frogs.on_plop = func() -> void: sound.plop()
	beaver = Beaver.new(); add_child(beaver) # (round its lodge on the nearest pond)
	beaver.on_slap = func() -> void: sound.plop(); sound.play("plop", 1.0, 0.12) # (the tail slap, and its echo off the water)
	songbirds = Songbirds.new(); add_child(songbirds) # (cardinals, bluebirds and chickadees at your feeders)
	crows = Crows.new(); add_child(crows)
	crows.on_caw = func() -> void: sound.caw()
	crows.on_land = func() -> void:
		if not crows_warned: crows_warned = true; hud.toast("Crows in the corn! Shoo them off, or build a scarecrow (B).")
	crows.on_scatter = func() -> void: journal.record("shoo"); hud.toast("The crows scatter, cawing indignantly.")
	crows.on_steal = func(r: Dictionary) -> void: world.hit(r, r.x, r.z, 99)
	owl = Owl.new(Vector3(center.x + 6, Terrain.get_height(center.x + 6, center.z + 10) + 1.02, center.z + 10)); add_child(owl) # (on the pen's corner post)
	owl.on_hoot = func() -> void: sound.hoot()
	eagle = Eagle.new(); add_child(eagle) # (soaring over the high country)
	# settlers and works: folk who join the farm and run a work, filling the storehouse a little at a time
	settlers = Settlers.new(center); add_child(settlers)
	settlers.bunk = extras
	settlers.town = town # (the folk live in town now, not camped in your yard)
	settlers.on_arrive = func(st: Dictionary) -> void: arrivals.append(st)
	# newcomers taking rooms at the mended boarding house: one note for them all (only when you mend it, not on a load)
	settlers.on_newcomer = func(st: Dictionary) -> void: if newcomer_news: newcomers.append(st)
	settlers.on_join = func(st: Dictionary) -> void:
		await get_tree().create_timer(1.8).timeout # (a beat after their own line, say plainly where they'll go)
		if not is_inside_tree(): return
		var first: String = String(st.S.name).split(" ")[0]; var work: String = Settlers.WORK_NAME[st.S.work]
		var built := build.pieces.any(func(q): return q.type == st.S.work); var store := build.pieces.any(func(q): return q.type == "storehouse")
		if not built: hud.toast("%s will wait by the camp fire till you build a %s (B, then the Works shelf). The moment it stands, %s walks over and gets to work." % [first, work, first])
		elif sky.night >= 0.45: hud.toast("%s will set off for your %s at first light." % [first, work])
		else: hud.toast("%s sets off for your %s.%s" % [first, work, "" if store else " (Build a storehouse too, or there's nowhere to bring what gets made.)"])
	for k in ["wood", "stone", "fish", "clay", "ore", "honey", "wheat", "sap", "pelt", "iron"]: if inventory.get(k, 0) > 0: settlers.discover(k) # (you've plainly gathered these already)
	build.discovered = settlers.discovered
	settlers_card = hud.settlers_card
	dandelions = Dandelions.new(); add_child(dandelions) # (seeded clocks in the meadows: brush through and they puff away)
	johnny = Wanderer.new(center); add_child(johnny) # (Johnny Appleseed, now and then, walking the lane)
	hunting = Hunting.new(); add_child(hunting); hud.add_child(hunting.reticle)
	hunting.on_thunk = func() -> void: sound.knock()
	hunting.targets = func() -> Array: # (the guardians and the camps' warriors)
		var out := camp.targets()
		if jumpers: out.append_array(jumpers.targets())
		for b in bosses: out.append_array(b.targets())
		if forts: out.append_array(forts.targets())
		for e in enemies.list: if not e.dying: out.append({"pos": Enemies.pos(e), "r": 0.65 * e.spec.scale, "h": e.spec.top * e.spec.scale, "enemy": e})
		return out
	hunting.on_target = func(t: Dictionary, a: Dictionary) -> void:
		if t.has("enemy"): guardian_hit(t.enemy, a.get("dmg", 6))
		elif t.has("w"): camp.damage(t.w, a.get("dmg", 6), camp_hooks, raid_hooks); sound.land()
		elif t.has("j"): jumpers.damage(t.j, a.get("dmg", 6), jumper_hooks); sound.land()
		elif t.has("boss"): t.boss.damage(a.get("dmg", 6), t.boss.hooks); sound.land()
		elif t.has("s"): forts.damage(t.s, a.get("dmg", 6), fort_hooks); sound.land()
	hunting.on_hit = func(c: Dictionary) -> void:
		if not hunt_told: hunt_told = true; hud.toast("A clean shot. The %s folds down in the grass: walk up to it to dress it." % c.type)
	hunting.on_wound = func(c: Dictionary) -> void:
		if c.type == "bison": hud.toast("The bull bellows and lumbers off, hit but still on his feet. It takes more than one shot to bring down a buffalo.")
	fishing = Fishing.new(); add_child(fishing); fishing.camera = rig.camera
	fishing.on_jump = func() -> void:
		if not jump_told and tools.has("rod"): jump_told = true; hud.toast("A fish jumped! Cast near the rings and they bite sooner.")
	fishing.on_cast = func() -> void: player.avatar.start_cast(); sound.splash()
	fishing.on_bite = func() -> void: sound.bite()
	fishing.on_miss = func() -> void: hud.toast("It nibbled the bait and swam off…")
	fishing.on_catch = func(fname: String, legend: bool) -> void:
		journal.record("legendfish" if legend else "gather:fish")
		if legend:
			inventory.whiskers = inventory.get("whiskers", 0) + 1; inventory.fish = inventory.get("fish", 0) + 4
			sound.craft(); hud.toast("The line goes taut, the pole bends double… and up comes OLD WHISKERS, the catfish of the tallest tale! (+4 fish, and a trophy to mount: B)")
			return
		inventory.fish = inventory.get("fish", 0) + 1; sound.pick()
		if settlers.discover("fish"): hud.toast("Your first fish! Now you can build a fish weir (B, Works shelf) for a settler to run.")
		hud.toast("You land %s! (+1 fish)" % fname)
	night_howl = NightHowl.new(); add_child(night_howl) # (a coyote howling on the rise, now and then of a dark night)
	geese = Geese.new(); add_child(geese) # (a skein going over in a V now and then by day)
	geese.on_honk = func() -> void: sound.honk()
	geese.on_first = func() -> void: hud.toast("Honk-honk! A skein of Canada geese goes over in a V, headed south. Folks say an early flight means an early frost.")
	# the people of the valleys: three camps, each in a valley of its own, in a clearing (before the chunks are built)
	camp = NativeCamps.new(center, world); add_child(camp)
	# claim jumpers (the player's addition): their ragged camps out in the county, clear of the town and the lodges
	jumpers = ClaimJumpers.new(); add_child(jumpers)
	jumpers.setup(center, [town.at] + camp.list.map(func(c): return c.at), world)
	jumpers.blocker = func(q: Vector3) -> Vector3: return build.collide(q, 0.4)
	jumper_hooks = {
		"on_hit": func(dmg: int) -> void:
			var out := player.hurt(dmg, 0.33 if tools.has("coat") else 0.0); hud.hurt(); sound.knock()
			if out: death_timer = 3.0; hud.toast("The claim jumpers leave you in the dirt and go through your pockets. You come to a long while later."),
		"on_fall": func(m: Dictionary) -> void:
			sound.knock(); var p: Vector3 = m.fig.root.position
			add_drop("prop_pouch", 0.45, Vector3(p.x + 0.5, 0, p.z + 0.3), "his poke", JUMPER_LOOT[randi() % JUMPER_LOOT.size()])
			hud.toast("The claim jumper goes down hard and stays down. His poke lies in the dirt."),
		"on_shoot": func(_at: Vector3) -> void: sound.bang(),
		"on_spotted": func(_c) -> void: hud.toast("Claim jumpers! A ragged camp of hard cases, and they've seen you. They come at you swinging. Fight, or run for it."),
	}
	_make_boss()
	_make_forts()
	wayfarers = Wayfarers.new(); add_child(wayfarers)
	wayfarers.setup(homestead.spawn, [homestead.spawn, town.at] + camp.list.map(func(c): return c.at) + jumpers.camps.map(func(c): return c.at) + bosses.map(func(b): return b.at) + forts.forts.map(func(f): return f.at), world)
	camp_hooks = {
		"on_warn": func() -> void: hud.toast("A warrior blocks your way and signals you back. This is their land: the painted poles mark it. An arrow thuds into the ground at your feet."),
		"on_fight": func() -> void: hud.toast("You stayed. The warriors come for you, bows drawn: get back over the poles!"),
		"on_leave": func() -> void: hud.toast("You're off their land. The warriors watch you go, then turn back to their camp."),
		"on_fall": func(w) -> void: sound.knock(); hud.toast("The warrior falls. The camp will not forget it. Something of his lies in the grass."); drop_native(w),
		"on_hit": func(dmg: int) -> void:
			var out := player.hurt(dmg, 0.33 if tools.has("coat") else 0.0); hud.hurt(); sound.knock()
			if out: death_timer = 3.0; hud.toast("The warriors drive you off their land, and you come to far from their camp."),
	}
	for st in ["store", "smithy", "bakery", "bank", "feed", "drygoods", "cooper"]:
		station_checks[st] = func() -> bool: return town.tiers.get(st, 0) and town.doors.has(st) and Vector2(player.pos.x - town.doors[st].x, player.pos.z - town.doors[st].z).length() < 3.2
	panel.store_open = station_checks.store; panel.smithy_open = station_checks.smithy; panel.bakery_open = station_checks.bakery; panel.bank_open = station_checks.bank
	panel.feed_open = station_checks.feed; panel.drygoods_open = station_checks.drygoods; panel.cooper_open = station_checks.cooper
	station_checks["depot"] = func() -> bool: return railroad.built and railroad.freight_at != null and Vector2(player.pos.x - railroad.freight_at.x, player.pos.z - railroad.freight_at.z).length() < 4.0
	for land in Railroad.LAND_KEYS:
		station_checks["post-" + land] = func() -> bool: var pst = railroad.post_at(player.pos.x, player.pos.z, 4.0); return pst != null and pst.land == land
	panel.depot_open = station_checks.depot
	panel.post_open = func(): return railroad.post_at(player.pos.x, player.pos.z, 4.0)
	station_checks["camp"] = func() -> bool: return camp.fire_at(player.pos.x, player.pos.z, 6.0) != null
	panel.camp_open = func() -> bool: return camp.fire_at(player.pos.x, player.pos.z, 6.0) != null # (trading at a camp fire, while at peace there)
	tinker = Tinker.new(world, town.spot(-19, -3.4)); add_child(tinker) # (at the head of Main Street)
	tinker.on_arrive = func() -> void:
		var q := crafting.new_request(sky.day, saved.get("request") if saved != null else null)
		if not q.get("done", false): hud.toast("A tinker's wagon rattles into Cold Glitter Creek and draws up at the head of Main Street. He has a request today: %s." % String(q.name).replace("Request: ", "").to_lower())
	tinker.on_leave = func() -> void: hud.toast("The tinker tips his hat and rattles off out of Cold Glitter Creek.")
	fair = Fair.new(world, homestead.roofs[0], town.spot(15, 0, 0, 0)); add_child(fair) # (up the street before the church, facing back down it)
	homestead.on_house_model = func(m: Node3D) -> void: fair.pin_to(m)
	if homestead.house_model: fair.pin_to.call_deferred(homestead.house_model)
	station_checks["tinker"] = func() -> bool: return tinker.near(player.pos)
	station_checks["fair"] = func() -> bool: return fair.near(player.pos, 3.2)
	panel.fair_today = func() -> bool: return fair.open(sky)
	crafting.fair_entered = func(id) -> bool: return fair.entered.has(id)
	crafting.on_fair_entry = func(id) -> void: fair.entered[id] = true
	fair.show_ribbons.call_deferred(inventory.get("ribbon", 0))
	mail = Mail.new(homestead.mail_flag, homestead.mailbox) # (RFD: a letter most mornings)
	rumours = Rumours.new(world)
	kite = Kite.new(); add_child(kite) # (the paper kite, G, once you've made one)
	footprints = Footprints.new(); add_child(footprints) # (a trail of prints across the snow)
	leaf_piles = LeafPiles.new(center); add_child(leaf_piles) # (raked heaps of leaves round the yard: run through them)
	fairy_ring = FairyRing.new(); add_child(fairy_ring) # (toadstools in a ring, the morning after a wet night)
	shafts = Shafts.new(); add_child(shafts) # (tissue-paper sunbeams slanting through the trees)
	wisp = Wisp.new(); add_child(wisp)
	wisp.on_appear = func() -> void:
		sound.lullaby()
		if not wisp_told: wisp_told = true; hud.toast("A will-o'-the-wisp bobs at the edge of the dark. Folks say they lead to lost things.")
	hoof_dust = HoofDust.new(); add_child(hoof_dust) # (dust kicked up behind a galloping horse)
	# the fingerpost at the farm end of the lane to town, a little to the side of it
	var tdir := Vector2(town.at.x - center.x, town.at.z - center.z).normalized()
	var sp := Vector3(center.x + tdir.x * 24.0 - tdir.y * 2.6, 0, center.z + tdir.y * 24.0 + tdir.x * 2.6)
	add_child(Signpost.new(sp)); world.colliders.append({"x": sp.x, "z": sp.z, "r": 0.3})
	tales_heard = tales.heard
	grandma = Grandma.new(homestead.front_window, float(homestead.roofs[0].rot), homestead.front_door); add_child(grandma) # (her shadow in the lamplit window)
	dance = BarnDance.new(town.spot(-1, 1.2, -1, -8)); add_child(dance) # (in the street before the livery barn)
	dance.on_note = func(f: float, d: float, v: float) -> void: sound.fiddle(f, d, v)
	town.on_note = func(f: float, d: float, v: float) -> void: sound.fiddle(f, d, v) # (the dance hall's fiddler, of an evening)
	fireworks = Fireworks.new(); add_child(fireworks)
	fire_smoke = FireSmoke.new(); add_child(fire_smoke)
	# raids: now and then a war party rides down on the town and falls on a mended building
	raid_hooks = {
		"on_sack": func(id: String) -> void:
			var nm := id
			for pr in town.projects(): if pr.id == id: nm = pr.name
			if town.unmend(id): hud.toast("The raiders wrecked the %s and rode off. It wants mending again (half the cost: the frame's sound)." % nm),
		"on_repelled": func() -> void: hud.toast("The war party breaks and wheels away into the hills. The town is safe, and folk come out to cheer you."); inventory.dollars = inventory.get("dollars", 0) + 10,
		"on_fall": func(w) -> void: sound.knock(); hud.toast("A raider tumbles from his horse, and something of his falls with him."); drop_native(w),
		"on_off": func() -> void: hud.toast("With nobody left in town to stand against them, the war party wheels about and rides back into the hills."),
		"on_hit": camp_hooks.on_hit,
	}
	world.fill_around(center.x, center.z)
	player = Player.new(self, rig, homestead.spawn) # (you start in the yard, by the porch)
	player.climbs = climbs
	# the gold pan, swirled in the shallows (in his right hand)
	var pcm := CylinderMesh.new(); pcm.top_radius = 0.3; pcm.bottom_radius = 0.22; pcm.height = 0.08; pcm.radial_segments = 14; pcm.rings = 1; pcm.cap_top = false
	pan_mesh = MeshInstance3D.new(); pan_mesh.mesh = pcm; pan_mesh.material_override = PaperMats.paper(Color.hex(0x8a8e90ff), false)
	pan_mesh.position = Vector3(0, -0.08, 0.32); pan_mesh.visible = false; player.avatar.fig.hands[1].add_child(pan_mesh)
	# the farm windmill: up the ladder on its south face (stepping round the stock tank) to the railed platform under the head
	climbs.add("windmill", homestead.mill_at.x, homestead.mill_at.y, homestead.mill_at.z, 0.0, {
		"decks": [{"x": 0, "z": 0, "hw": 0.75, "hd": 0.75, "y": 7.89, "rail": true}],
		"ladders": [{"foot": [1.4, 0, 0.45], "via": [[0.3, 0.65, 0.78], [0, 1.0, 0.76]], "top": [0, 7.89, 0.32], "land": [0.42, -0.35], "name": "the windmill"}]})
	player.avatar.root.position = player.pos
	rig.target_node = player.avatar.root
	focus = player.avatar.root
	spawn = center
	rig.snap()
	if saved != null: _apply_save(saved)
	world.prewarm()
	_preload_models()

func _process(dt: float) -> void:
	if prof != null: _pm_t = Time.get_ticks_usec()
	if quality == null: quality = Quality.new(self, keep_prefs); quality.apply(quality.level) # (once the sky, the post pass and the environment are made)
	if not first_frame:
		for n in get_tree().get_nodes_in_group("newgame_card"): n.queue_free() # (a new game's card: the county is laid out)
	first_frame = true
	var qt := quality.tick()
	if qt != "": hud.toast(qt)
	if hud.dev: hud.set_backend("%s · %d fps · %s%s" % [_renderer_name(), quality.fps_rate, "auto " if quality.mode == "auto" else "", quality.level])
	autosave_t += dt
	_pm("autosave_t")
	if autosave_t > 30.0: autosave_t = 0.0; save_all() # (the clock moves on, so the almanac is saved now and then)
	dt = clampf(dt, 0.0, 0.05)
	_pm("dt")
	if force_active and hud.overlay_on: hud.show_overlay(false, true) # (tests play without the title card)
	var active := (force_active or input.locked) and not panel.open
	_pm("var")
	_crafting_keys()
	_pm("_crafting_keys")
	player.build = build
	_pm("player.build")
	_building(dt, active)
	_pm("_building")
	_map_pan(dt) # (before the player: an open map takes the mouse and the wheel)
	var step: Dictionary = player.update(dt, input, world, active and not extras.sitting and not train.passenger) # (aboard the train you ride, not walk)
	_pm("player.update")
	extras.porch_update(dt, player)
	_pm("extras.porch_update")
	_extras(dt, active)
	_pm("_extras")
	_night_prowlers(dt)
	enemies.update(dt, player, rig.camera, sky.day + sky.time)
	_pm("enemies.update")
	_knocked_out(dt)
	_pm("_knocked_out")
	_rail(dt)
	_pm("_rail")
	homestead.set_fortune(float(fortune))
	_pm("homestead.set_fortune")
	_pan(dt)
	_pm("_pan")
	town.day = sky.day; town.bedtime = sky.time > 0.9 or sky.time < 0.22; town.cam_pos = rig.camera.global_position; town.player_pos = player.pos
	_pm("town.day")
	town.clock = sky.time; town.raining = weather.kind == "rain" and weather.rain > 0.5
	_pm("town.clock")
	town.snow_cover = weather.snow; town.sunday = sky.day % 7 == 0 and sky.time > 0.27 and sky.time < 0.45; town.inv = inventory
	_pm("town.snow_cover")
	town.update(sky.night, dt)
	_pm("town.update")
	town.set_playbill(sky.day); town.dance_hall(sky.time > 0.76 or sky.time < 0.04, dt); town.opera_queue(sky.time > 0.74 and sky.time < 0.86, dt)
	_pm("town.set_playbill")
	if town.tiers.get("church", 0) and town.sunday and meeting_day != sky.day:
		meeting_day = sky.day
		if not town.far: hud.toast("Sunday morning. The bell has rung, and the families from Squatters’ Row walk up Main Street in their Sunday best for meeting at the church.")
	landmarks.update(dt, rig.camera)
	_pm("landmarks.update")
	_landmark_reached()
	_pm("_landmark_reached")
	NativeCamps.set_lodge_glow(sky.night, Time.get_ticks_msec() / 1000.0, sky.time > 0.9 or sky.time < 0.22 or (weather.kind == "rain" and weather.rain > 0.5), sky.day) # (camp folk abed late at night, and in their lodges out of a downpour)
	_pm("NativeCamps.set_lodge_glow")
	NativeCamps.player_armed = tools.has("bow") or tools.has("revolver") or tools.has("rifle")
	camp.update(dt, player, rig.camera, camp_hooks, raid_hooks)
	jumpers.update(dt, sky.day, player, jumper_hooks)
	forts.update(dt, sky.day, player, fort_hooks)
	forts.patrols_update(dt, sky.time, player)
	_escort_update(dt)
	wayfarers.update(dt, player, sky.day)
	var fb = null
	for b in bosses:
		b.day_now = sky.day
		if sky.time > 0.25 and b.maybe_return(sky.day): _boss_board(); hud.toast("Word from the hills: %s is back, and meaner than ever." % b.title())
		b.update(dt, player, b.hooks)
		if fb == null and b.fighting(): fb = b
	hud.set_boss(fb.title() if fb != null else "", fb.hp_frac() if fb != null else 0.0)
	_boss_tune(dt, fb)
	hud.set_town_rank(town_rank())
	_pm("camp.update")
	_raid_tick()
	_pm("_raid_tick")
	dance.update(dt, sky.day, sky.time, sky.night, player)
	if dance.live(sky.day, sky.time) and dance_told_day != BarnDance.dance_night_of(sky.day, sky.time):
		dance_told_day = BarnDance.dance_night_of(sky.day, sky.time)
		hud.toast("Fiddle music drifts up the lane from Cold Glitter Creek: a barn dance has started in the street before the livery barn! It runs till three in the morning.")
	_pm("dance.update")
	if dance_t > 0.0: # swinging round on the floor
		dance_t -= dt; player.facing += dt * 7.0
		player.stamina = minf(player.max_stamina, player.stamina + dt * 30.0); player.health = minf(player.max_health, player.health + dt * 3.0)
	_fires_and_fireworks(dt)
	_pm("_fires_and_fireworks")
	settlers.wet = weather.kind == "rain" and weather.rain > 0.5 # (a downpour sends the hands in)
	_pm("settlers.wet")
	settlers.cap = 45 if tools.has("casks") else 30
	_pm("settlers.cap")
	settlers.update(dt, build.pieces, sky.day, sky.time, sky.night, rig.camera)
	_pm("settlers.update")
	_announce_arrivals()
	_pm("_announce_arrivals")
	_settlers_card(dt)
	_pm("_settlers_card")
	_livestock(dt, active)
	_pm("_livestock")
	_pets(dt, active)
	_pm("_pets")
	ambient.update(dt, player.pos, sky.night)
	_pm("ambient.update")
	butterflies.update(dt, player.pos, sky.night, weather.rain)
	_pm("butterflies.update")
	# footfalls in the water: a ring from the shins and a flick of paper spray with the step sound under you
	if player.avatar.stepped:
		player.avatar.stepped = false
		var on_wood: bool = build.surface_at(player.pos.x, player.pos.z, player.pos.y) >= Terrain.get_height(player.pos.x, player.pos.z) - 0.01
		sound.step("wood" if on_wood else ("water" if player.wading else ("snow" if weather.snow > 0.5 else "grass"))) # (a muffled crunch once the snow lies)
		if player.wading:
			wade_rings.ring(player.pos.x, player.pos.z)
			confetti.burst(Vector3(player.pos.x, 0.1, player.pos.z), [0xd6e6e8, 0xf3ead6, 0x9cc4d0], 4, 0.35)
	wade_rings.update(dt, player.pos, player.wading, Vector2(player.vel.x, player.vel.z).length())
	_pm("wade_rings.update")
	ducks.update(dt, player, rig.camera, sky.night < 0.4 and weather.rain < 0.5, dog.pos)
	_pm("ducks.update")
	tumbleweeds.update(dt, player, weather.rain < 0.1 and sky.night < 0.4 and (Vector2(player.pos.x - town.at.x, player.pos.z - town.at.z).length() < 75.0 or Tumbleweeds.dry_at(player.pos.x, player.pos.z)), world.colliders) # (in the dry country, and down Main Street)
	_pm("tumbleweeds.update")
	frogs.update(dt, world, player, rig.camera, sky.night, weather.snow)
	_pm("frogs.update")
	beaver.update(dt, world, player.pos)
	_pm("beaver.update")
	owl.update(dt, sky.night, player, rig.camera)
	_pm("owl.update")
	geese.update(dt, player.pos, sky.night)
	_pm("geese.update")
	eagle.update(dt, player.pos, sky.night)
	_pm("eagle.update")
	crows.update(dt, world, player, sky.night, func(r) -> bool:
		for q in build.pieces: if q.type == "scarecrow" and Vector2(q.x - r.x, q.z - r.z).length() < 16.0: return true
		return false, kite.pos if kite.flying else null) # (a kite over the garden spooks them)
	# the feeders with seed in them and the bakery's doorstep (nearest first); they roost at night
	var spots := []
	_pm("var")
	if sky.night < 0.4:
		for q in build.pieces: if q.type == "feeder" and q.get("stock", 0) and Vector2(q.x - player.pos.x, q.z - player.pos.z).length() < 45.0: spots.append(q)
		# the mended bakery's doorstep: birds come for the crumbs on the boardwalk (not in a downpour, nor with the town asleep)
		var bk = town.doors.get("bakery") if town.tiers.get("bakery", 0) else null
		if bk != null and not town.raining and not town.far and Vector2(bk.x - player.pos.x, bk.z - player.pos.z).length() < 45.0: spots.append({"x": bk.x, "y": town.y0, "z": bk.z, "ground": true})
		spots.sort_custom(func(a, b) -> bool: return Vector2(a.x - player.pos.x, a.z - player.pos.z).length() < Vector2(b.x - player.pos.x, b.z - player.pos.z).length())
	songbirds.update(dt, spots, player, rig.camera)
	_pm("songbirds.update")
	if johnny.update(dt, sky.day, sky.time, player, world.colliders) == "arrived": hud.toast("A barefoot old fellow with a tin pot for a hat is coming along the lane. Johnny Appleseed, by the look of him!")
	var puffs := dandelions.update(dt, sky.day, player.pos, [{"pos": player.pos, "speed": Vector2(player.vel.x, player.vel.z).length()}, {"pos": dog.pos, "speed": dog.speed}])
	_pm("dandelions.update")
	if puffs: sound.rustle(); journal.record("dandelion")
	if puffs and Time.get_ticks_msec() - dandelion_told_at > 90000:
		dandelion_told_at = Time.get_ticks_msec()
		var n := 1 + randi() % 12; var hr := floori(sky.time * 24.0) % 12
		if hr == 0: hr = 12
		hud.toast(("Away go the dandelion seeds! Folks say count the puffs to tell the hour: %d o'clock, and right on the dot. Make a wish!" if n == hr else "Away go the dandelion seeds! Folks say count the puffs to tell the hour: %d o'clock, says the dandelion. (The sun says otherwise.)") % n)
	night_howl.update(dt, player, rig.camera, sky.night > 0.7 and weather.rain < 0.1 and Vector2(player.pos.x - town.at.x, player.pos.z - town.at.z).length() > 90.0 and Vector2(player.pos.x, player.pos.z).length() > 45.0, func(v: float, ans: bool) -> void: sound.howl(v, ans))
	_pm("night_howl.update")
	_yard(dt, active)
	_pm("_yard")
	_gather(active, step.connected)
	_pm("_gather")
	confetti.update(dt)
	_pm("confetti.update")
	world.rain = weather.rain
	_pm("world.rain")
	world.update(player.pos.x, player.pos.z, dt)
	_pm("world.update")
	# the weather: showers, snow lying, ice on the ponds, the sky greying (snow light is soft but brighter)
	weather.update(dt, player.pos, func(x: float, z: float) -> bool: return homestead.covers(x, z))
	_pm("weather.update")
	homestead.update(dt, sky.night, rig.camera)
	_pm("homestead.update")
	storm.update(dt, rig.camera, player.pos, weather.storm and weather.rain > 0.6)
	_pm("storm.update")
	sky.rain = weather.rain * 0.45 if weather.kind == "snow" else weather.rain
	_pm("sky.rain")
	sky.update(dt, player.pos, rig.camera)
	_pm("sky.update")
	puddles.update(dt, player.pos, weather.rain if weather.kind == "rain" else 0.0, weather.kind == "snow")
	_pm("puddles.update")
	if weather.rain > 0.3 and (sky.time > 0.75 or sky.time < 0.2): night_rain = true
	Terrain.land_at(player.pos.x, player.pos.z)
	_pm("Terrain.land_at")
	mist.update(dt, player.pos, sky, night_rain, Terrain.L_w.fen)
	_pm("mist.update")
	if sky.time > 0.45: night_rain = false
	rainbow.update(dt)
	_pm("rainbow.update")
	var fell := falling_stars.update(dt, player.pos, rig.camera, sky.night, weather.rain)
	if fell != "": hud.toast("A falling star! It came down off to the %s, not far. Folk say a fallen star brings luck." % fell)
	_pm("falling_stars.update")
	night_sky.update(dt, rig.camera, sky.sun_dir, sky.night, (sky.day + 1) % 7 == 0 and sky.night > 0.5) # (the harvest moon, on the eve of the fair)
	_pm("night_sky.update")
	RenderingServer.global_shader_parameter_set("paper_snow", weather.snow)
	_pm("RenderingServer.global_shader_parameter_set")
	_pond_ice(dt)
	_pm("_pond_ice")
	RenderingServer.global_shader_parameter_set("paper_cloud_shade", (1.0 - sky.night) * (1.0 - minf(1.0, weather.rain * 1.5))) # (fair days only)
	_pm("RenderingServer.global_shader_parameter_set")
	rig.update_camera(dt)
	_pm("rig.update_camera")
	world.update_occlusion(rig.camera.global_position, player.pos, dt)
	_pm("world.update_occlusion")
	_update_post()
	_pm("_update_post")
	_update_hud(dt)
	_pm("_update_hud")
	input.end_frame()
	_pm("input.end_frame")

func _make_environment() -> void:
	# NeutralToneMapping at exposure 1.4 in the web version; a warm hemisphere ambient (0xf3dcb8 sky, 0x8a6d4a ground)
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("cfe0e8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9b08a")
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR # (the post pass owns the tone curve: Neutral at exposure 1.4)
	e.tonemap_exposure = 1.0
	# warm contact occlusion and the bloom on lit panes (post.js's GTAO and bloom passes)
	e.ssao_enabled = true; e.ssao_radius = 0.7; e.ssao_intensity = 1.2; e.ssao_detail = 0.5
	e.glow_enabled = true; e.glow_hdr_threshold = 0.85; e.glow_intensity = 0.22; e.glow_bloom = 0.0; e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = e
	add_child(env)

## Click the farm to play (the mouse captured); Escape lets it go and the title card comes back; Escape again folds
## the card into the small pause note (and back), as main.js does it.
var lock_changed_at := 0
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not input.locked and not panel.open: input.lock()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if input.locked: input.unlock()
		elif not panel.open and Time.get_ticks_msec() - lock_changed_at >= 400:
			var showing := hud.overlay_on
			hud.show_overlay(not showing); hud.show_peek(showing)

## The ponds freeze while snow lies thick (over half a minute) and thaw slowly after, but never melt under your boots;
## the first freeze is announced, gliding counts for the almanac, and the blades score the ice: a pair of pale
## scratches every 0.42 m (a ring of 240), gone when it thaws (main.js).
const TRACKS := 240
var tracks: MultiMeshInstance3D
var _track_next := 0
var _track_dist := 0.0
var _skate_t := 0.0
var _last_track := Vector3.ZERO
func _pond_ice(dt: float) -> void:
	var on_pond := Terrain.is_water(player.pos.x, player.pos.z)
	ice += ((1.0 if weather.snow > 0.6 or (player.ice_on and on_pond) else 0.0) - ice) * minf(1.0, dt * (0.06 if weather.snow > 0.6 else 0.02))
	RenderingServer.global_shader_parameter_set("paper_ice", ice)
	var was_ice := player.ice_on
	player.ice_on = ice > 0.8 or (was_ice and on_pond)
	if player.ice_on and not was_ice: hud.toast("The ponds have frozen over! Step out onto the ice and glide.")
	var glide := Vector2(player.vel.x, player.vel.z).length()
	if player.on_ice and glide > 2.2:
		_skate_t += dt
		if _skate_t > 1.0: _skate_t = 0.0; journal.record("skate")
	if tracks == null:
		tracks = MultiMeshInstance3D.new()
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
		var q := PlaneMesh.new(); q.size = Vector2(0.035, 0.55); mm.mesh = q
		mm.instance_count = TRACKS
		for i in TRACKS: mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(Color("f3f6f4"), 0.7); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.render_priority = 1; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		tracks.material_override = m; tracks.multimesh = mm; tracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracks.extra_cull_margin = 16384.0; tracks.visible = false
		add_child(tracks)
	if player.on_ice and player.on_ground:
		_track_dist += Vector2(player.pos.x - _last_track.x, player.pos.z - _last_track.z).length()
		if _track_dist > 0.42:
			_track_dist = 0.0; tracks.visible = true
			var yaw := atan2(player.vel.x, player.vel.z)
			for side in [-0.11, 0.11]: # (both blades, overlapping a little so the scratch runs on unbroken)
				var at := Vector3(player.pos.x + cos(yaw) * side, player.pos.y + 0.012, player.pos.z - sin(yaw) * side)
				tracks.multimesh.set_instance_transform(_track_next, Transform3D(Basis(Vector3.UP, yaw), at))
				_track_next = (_track_next + 1) % TRACKS
	_last_track = player.pos
	if tracks.visible and ice < 0.3:
		tracks.visible = false
		for i in TRACKS: tracks.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))

## Display settings (the port's own; on the page the browser owns the window): full screen or a window, vertical
## sync, and the interface's size against the 1600x900 it's laid out for (the HUD scales with the window: stretch mode
## canvas_items). Kept in user://display.json; full screen by default. Tests leave the window alone.
const DISPLAY_PATH := "user://display.json"
const UI_SIZES := [1.0, 1.25, 0.8]
const UI_BASE := 0.855 ## the whole interface ~15% smaller than its 1600x900 layout (the player's ask); "Interface size" scales from here
var display := {"fullscreen": true, "vsync": true, "ui": 1.0}
func _load_display() -> void:
	if not keep_prefs: return
	if FileAccess.file_exists(DISPLAY_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(DISPLAY_PATH))
		if d is Dictionary: display.merge(d, true)
	_apply_display()
func _apply_display() -> void:
	if display.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var scr := DisplayServer.screen_get_usable_rect()
		var sz := Vector2i(mini(1600, scr.size.x - 40), mini(900, scr.size.y - 60))
		DisplayServer.window_set_size(sz); DisplayServer.window_set_position(scr.position + (scr.size - sz) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if display.vsync else DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_factor = float(display.ui) * UI_BASE
	if keep_prefs:
		var f := FileAccess.open(DISPLAY_PATH, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(display)); f.close()

func _option_text(id: String) -> String:
	match id:
		"window": return "Full screen" if display.fullscreen else "In a window"
		"vsync": return "On" if display.vsync else "Off"
		"ui": return "%d%%" % roundi(float(display.ui) * 100.0)
		"quality": return ("Auto (%s)" % quality.level if quality.mode == "auto" else String(quality.level).capitalize()) if quality else "Auto"
		"dof": return "On" if quality == null or quality.dof_on else "Off"
		"sound": return "Off" if sound.muted else "On"
	return ""

func _cycle_option(id: String) -> String:
	match id:
		"window": display.fullscreen = not display.fullscreen; _apply_display()
		"vsync": display.vsync = not display.vsync; _apply_display()
		"ui": display.ui = UI_SIZES[(UI_SIZES.find(float(display.ui)) + 1) % UI_SIZES.size()]; _apply_display()
		"quality": if quality: quality.cycle()
		"dof": if quality: quality.toggle_dof()
		"sound": sound.toggle_mute()
	sound.click()
	return _option_text(id)

## Quit (the title card's button): save, then out to the desktop.
func _quit_game() -> void:
	save_all()
	_finish_loads()
	if quitting: return
	quitting = true
	Shutdown.quit(get_tree()) # (see core/shutdown.gd: an exported game skips the engine's broken teardown)


## Dev: $500 at a click (the +$500 button, or F4).
func _dev_cash() -> void:
	inventory.dollars = inventory.get("dollars", 0) + 500; hud.toast("Dev: +$500 in your poke."); sound.pick(); save_all()

## The renderer's name for the dev badge (the page shows WebGPU or WebGL 2).
func _renderer_name() -> String:
	match RenderingServer.get_current_rendering_driver_name():
		"vulkan": return "Vulkan"
		"d3d12": return "Direct3D 12"
		"metal": return "Metal"
		"opengl3", "opengl3_es", "opengl3_angle": return "OpenGL"
	return RenderingServer.get_current_rendering_driver_name()

## A script error somewhere (TearLogger): before the first frame the red card says the game could not start; after,
## the toast once ("a little tear in the paper"), and the game carries on.
func _tear(msg: String) -> void:
	if not first_frame: hud.show_error("Could not start: " + msg)
	elif tears == 0: hud.toast("A little tear in the paper: something went wrong, but the game carries on.")
	tears += 1

func _exit_tree() -> void:
	if tear_logger: OS.remove_logger(tear_logger)

## New game (the title card's button, confirmed): the save is wiped and the game starts over on a fresh page.
## (Started over in place, not by quitting and relaunching: a relaunch can't happen at all when the game was run from
## the editor, and from the exe it left a blank screen for the ~9 s a new county takes to lay out.)
func _new_game() -> void:
	saving = false # (so the running game can't write the old state back)
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	# a paper card over everything while the new county is laid out (it outlives this scene; the next one takes it away)
	var layer := CanvasLayer.new(); layer.layer = 100; layer.add_to_group("newgame_card")
	var bg := ColorRect.new(); bg.color = Color("efe3c4"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var l := Label.new(); l.text = "Laying out a new county…"; l.add_theme_font_override("font", hud.font); l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Hud.INK); l.set_anchors_preset(Control.PRESET_CENTER); l.grow_horizontal = Control.GROW_DIRECTION_BOTH; l.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.add_child(l)
	get_tree().root.add_child(layer)
	input.unlock()
	for i in 3: await get_tree().process_frame # (the card drawn before the long lay-out)
	_finish_loads()
	reset_world()
	get_tree().reload_current_scene()

## Forget the old county: what the terrain, the props and the farm's garden keep between scenes (statics).
static func reset_world() -> void:
	Terrain.flat = null; Terrain.extra_flats.clear(); Terrain.RC = Vector2.ZERO
	Terrain.e_memo.clear(); Terrain.lat_cache.clear(); Terrain.full_cache.clear(); Terrain.h_cache.clear(); Terrain.r_cache.clear()
	Props.site_cache.clear(); Props.garden = null; Props._uniques = null; Props._uniques_seed = -1; Props._starter = []; Props._starter_seed = -1

## post.js: the full-screen lens and grade pass, riding on the camera.
func _make_post() -> void:
	post = ShaderMaterial.new(); post.shader = preload("res://shaders/post.gdshader")
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(1, 1); q.mesh = qm
	q.material_override = post
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.camera.add_child(q)

## The lens focuses on the hero: kD turns relative depth into frame heights, 1 / (fovY * cot(pitch)).
var lens_z := 15.0
func _update_post() -> void:
	var hero_z := rig.camera.global_position.distance_to(rig.anchor + rig.focus_offset)
	lens_z += (hero_z - lens_z) * minf(1.0, get_process_delta_time() * 4.0)
	var lens_far := smoothstep(1.3, 3.0, lens_z / hero_z)
	post.set_shader_parameter("focus_z", lens_z)
	post.set_shader_parameter("depth_weight", lerpf(0.8, 1.0, lens_far))
	post.set_shader_parameter("near_gain", lerpf(1.55, 1.1, lens_far))
	post.set_shader_parameter("night", sky.night)
	post.set_shader_parameter("shadow_warmth", 0.7 * (1.0 - 0.75 * sky.night))
	# exposure follows the time of day (EXPOSURE base 1.4, lifting gently after dark), easing like an eye
	var expo_target := 1.4 * (1.0 + 0.25 * sky.night)
	if weather.storm: expo_target *= 1.0 - 0.22 * weather.rain # a storm's gloom, dark as a stovepipe
	if storm.flash > 0.0: expo = maxf(expo, expo_target * (1.0 + storm.flash * 0.35)) # the lightning's pale flash
	expo += (expo_target - expo) * (1.0 - exp(-get_process_delta_time() * 2.5))
	post.set_shader_parameter("exposure", expo)
	post.set_shader_parameter("k_d", maxf(0.25, tan(maxf(0.05, rig.pitch))) / deg_to_rad(rig.camera.fov))

## The HUD each frame (main.js: setInventory, setTools, setStamina, setFullness, setHealth, the calm fade, the clock).
func _update_hud(dt: float) -> void:
	hud.set_clock(sky.clock_text())
	hud.set_inventory(inventory)
	hud.set_tools(tools, held, func(id: String) -> bool: return owns(id), wear)
	hud.set_stamina(player.stamina, player.max_stamina, player.stamina_boost > 0.0)
	hud.set_fullness(player.fullness)
	hud.set_health(player.health, player.max_health)
	var all_well := player.health >= player.max_health * 0.98 and player.stamina >= player.max_stamina * 0.97 and player.fullness >= 50.0 and not player.chilled and not player.dead
	hud.set_calm(all_well, dt)
	if input.hit("KeyI"): hud.pack.visible = not hud.pack.visible; sound.tear()
	if input.hit("KeyN"): hud.toast("Sound off" if sound.toggle_mute() else "Sound on") # (N: sound on/off)
	if input.hit("F4"): _dev_cash()
	if input.hit("F3"):
		hud.set_dev(not hud.dev)
		if keep_prefs:
			if hud.dev: FileAccess.open(DEV_PATH, FileAccess.WRITE).store_string("1")
			elif FileAccess.file_exists(DEV_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(DEV_PATH))
	if input.hit("KeyO"): hud.toast("Graphics: " + quality.cycle()) # (O: auto, high, medium, low)
	if input.hit("KeyP"): hud.toast("Depth of field on" if quality.toggle_dof() else "Depth of field off")
	_ambience(dt)
	hud.county_map.update_at(player.pos.x, player.pos.z)
	_paper_weather(dt)
	_rumour_note()
	_update_next(dt)
	_update_homeward()
	_update_boss_chip()
	hud.set_fortune("$%d in your poke" % inventory.get("dollars", 0) if fortune or inventory.get("dollars", 0) else "")
	if input.hit("KeyM") or input.hit("Tab"):
		if hud.map_card.visible: hud.map_card.visible = false
		else: hud.county_map.recenter(); _open_map()
		sound.tear()
	if player.fullness < 30.0 and hunger_warned < 1: hunger_warned = 1; hud.toast("Hungry! Eat something (F).")
	if player.fullness < 10.0 and hunger_warned < 2: hunger_warned = 2; hud.toast("STARVING! Eat now (F).")

## The open map pans with the mouse and zooms with the wheel (the camera and its zoom held meanwhile); right-click or
## R puts it back on you. A moment after it comes to rest it's washed afresh and its marks gathered for where it looks.
var _map_rest := 0.0
func _map_pan(dt: float) -> void:
	if not hud.map_card.visible: return
	var M := hud.county_map
	if (force_active or input.locked):
		var was := M.center(); var ws := M.span
		M.pan(Vector2(input.dx, input.dy)); M.zoom(input.wheel)
		if input.right_clicked or input.hit("KeyR"): M.recenter()
		if M.center() != was or M.span != ws: _map_rest = 0.3
		input.dx = 0.0; input.dy = 0.0; input.wheel = 0.0 # (the map has them, not the camera)
	if _map_rest > 0.0:
		_map_rest -= dt
		if _map_rest <= 0.0 and M.moved(): _open_map()

## Whether a tool-bar slot is yours (main.js owns()).
func owns(id: String) -> bool:
	match id:
		"hands", "axe": return true
		"pick": return tools.has("pickaxe") or tools.has("ironpick") or tools.has("steelpick")
	return tools.has(id)

# ------------------------------------------------------------------ gathering (main.js: the swing, the hit, the loot)
var confetti: Confetti
var e_free := true       ## nothing but gathering wants E right now (from last frame's prompt)
var dull_warned := false
var tapped := {}        ## maple "x,z" -> the day it was last tapped
var target = null

## A tool's bite: half (at least 1) once it's gone dull.
func edge(type: String) -> int:
	var d := GatherRules.damage_for(type, tools, held)
	return maxi(1, floori(d / 2.0)) if d > 0 and wear.has(held) and wear[held] <= 0 else d

## Every hit wears the edge a little.
func blow() -> void:
	if not wear.has(held): return
	var was: float = wear[held]
	wear[held] = maxf(0.0, wear[held] - GatherRules.wear_per_hit(held, tools))
	if was > 0.0 and wear[held] <= 0.0 and not dull_warned:
		dull_warned = true
		hud.toast("Your %s has gone dull: it bites at half strength now. Sharpen it on the grindstone at a workbench or forge (E, 1 stone)." % ("axe" if held == "axe" else ("pickaxe" if held == "pick" else "spear")))

func pick_tool(id: String) -> void:
	if not owns(id):
		match id:
			"pick": hud.toast("No pickaxe yet: make one at a workbench (C).")
			"spear": hud.toast("No spear yet: whittle an ash spear at a workbench (C).")
			"bow": hud.toast("No bow yet: make a hunting bow at a workbench (C).")
			"revolver": hud.toast("No six-shooter yet: the general store in town sells one.")
			"rifle": hud.toast("No rifle yet: the general store in town sells one.")
			"rod": hud.toast("No fishing pole yet: make one at a workbench (C).")
		sound.denied(); return
	if held != id: sound.click()
	held = id

## Fishing takes the click when there's water ahead and a pole in hand; the bow and the guns: hold to draw (or raise
## and steady), let go to loose. The six-shooter holds six, the buffalo rifle one; empty, it reloads from cartridges.
func _hunt_and_fish(active: bool) -> void:
	var dt := get_process_delta_time()
	var can_act := active and not build.active and not player.dead
	fishing.rain = weather.rain; fishing.night = sky.night
	fish_r = fishing.update(dt, player, input, can_act, fishing.spot(player, held == "rod" and tools.has("rod")) if can_act and not player.ice_on else null) # (no fishing through the ice)
	var W: Dictionary = Hunting.REVOLVER if held == "revolver" else (Hunting.RIFLE if held == "rifle" else Hunting.BOW)
	var gun := W != Hunting.BOW
	if gun:
		var g: Dictionary = guns[held]
		if g.reload > 0.0:
			g.reload -= dt
			if g.reload <= 0.0: var n := mini(g.size - g.loaded, inventory.get("cartridges", 0)); g.loaded += n; inventory.cartridges = inventory.get("cartridges", 0) - n; sound.knock()
		if active and input.hit("KeyR") and g.loaded < g.size and g.reload <= 0.0 and inventory.get("cartridges", 0) > 0: g.reload = g.time
	var gun_ready: bool = not gun or (guns[held].loaded > 0 and guns[held].reload <= 0.0)
	var bow_up: bool = not build.active and active and not fish_r.engaged and (held == "bow" or gun) and not player.dead and (held != "bow" or tools.has("bow")) # (from the saddle too)
	if bow_up and gun and not gun_ready and input.clicked and guns[held].reload <= 0.0 and inventory.get("cartridges", 0) <= 0: sound.denied(); hud.toast("Click. Out of cartridges: buy a box at the general store.")
	var h := 2.7 if riding else 1.45
	if bow_up and gun_ready and input.mouse_down:
		var f := -rig.camera.global_transform.basis.z; f.y = 0; f = f.normalized(); player.aiming = true
		hunting.aim(dt, rig.camera, Vector3(player.pos.x + f.x * 0.5, player.pos.y + h, player.pos.z + f.z * 0.5), critters, world, W)
	elif hunting.charge > 0.0:
		var ad: Vector3 = hunting.aim_dir if hunting.aim_dir != null else player.forward()
		player.aiming = false
		if bow_up and gun_ready and hunting.loose(Vector3(player.pos.x + ad.x * 0.5, player.pos.y + h, player.pos.z + ad.z * 0.5), critters, W):
			player.avatar.start_cast()
			if gun:
				var g: Dictionary = guns[held]; g.loaded -= 1; sound.bang(held == "rifle")
				if g.loaded == 0:
					if inventory.get("cartridges", 0) > 0: g.reload = g.time
					else: hud.toast("That was your last cartridge: buy a box at the general store." if held == "rifle" else "The cylinder's empty and so is your cartridge box: buy more at the general store.")
		else: hunting.ease()
	else: player.aiming = false
	hunting.update(dt, critters, world)

## Folk arriving: one at a time, a note introducing them; several at once (a new storehouse), a single note.
func _announce_arrivals() -> void:
	if not newcomers.is_empty():
		hud.toast("Word has got round that the boarding house has rooms again. New folk have come to Cold Glitter Creek looking for work: %s." % "; and ".join(newcomers.map(func(st): return "%s, %s" % [st.S.name, st.S.pitch])))
		newcomers.clear()
	if arrivals.is_empty(): return
	if arrivals.size() == 1: var a: Dictionary = arrivals[0]; hud.toast("%s, %s, has made camp at the edge of the farm. %s" % [a.S.name, a.S.pitch, a.S.ask])
	else: hud.toast("Word of your storehouse has got round: %d folk looking for work have made camp at the edge of the farm. Go and meet them, or press J to see who's who." % arrivals.size())
	arrivals = []

## The settlers card (J): the storehouse, the larder, and a line for each of them.
func _settlers_card(dt: float) -> void:
	if (force_active or input.locked) and input.hit("KeyJ"): settlers_card.visible = not settlers_card.visible; set_t = 1.0; sound.tear()
	if not settlers_card.visible: return
	set_t += dt
	if set_t < 1.0: return
	set_t = 0.0
	var stock := settlers.stock_text()
	var store_line := ("In the storehouse: " + stock if stock != "" else "The storehouse is empty for now.") if build.pieces.any(func(q): return q.type == "storehouse") else "No storehouse yet: build one (B, Works shelf) and folk will come looking for work."
	hud.set_settlers(store_line, settlers.larder_text(), settlers.rows(build.pieces))

## The guarded sites within r chunks of (cx, cz): those of every chunk already laid out (the world, the map and the
## rumours keep them in Props.site_cache), and at most `budget` more laid out now, nearest first. (The saloon's tip and
## the sheriff's bounty laid out every chunk in reach at the press of E: 289 and 441 chunks, up to ~14 s frozen.)
func _sites_near(cx: int, cz: int, r: int, budget := 3) -> Array:
	var cells := []
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1): cells.append(Vector2i(dx, dz))
	cells.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
	var out := []; var made := 0
	for c in cells:
		var k := "%d,%d" % [cx + c.x, cz + c.y]
		if Props.site_cache.has(k): out.append_array(Props.site_cache[k].sites)
		elif made < budget: out.append_array(Props.sites_for(cx + c.x, cz + c.y, world.exclusions).sites); made += 1
	return out

## Reaching a landmark for the first time: what you find there (the lookout's view and the hermit's inking go onto the
## county map).
func _landmark_reached() -> void:
	var hit = landmarks.reached(player.pos, inventory)
	if hit == null: return
	var inf: Dictionary = landmarks.info[hit.site.mark]
	if hit.get("hint", false): hud.toast(inf.found); return
	for k in inf.get("needs", {}): inventory[k] = inventory.get(k, 0) - inf.needs[k]
	if inf.get("blessing", false): landmarks.blessed = true
	for k in inf.gift: inventory[k] = inventory.get(k, 0) + inf.gift[k]
	if inf.has("reveal"): hud.county_map.reveal(hit.site.x, hit.site.z, float(inf.reveal), 0.1, 12.0) # (the lookout's view)
	if inf.get("mapAll", false): # (the hermit inks every strange corner of the county onto your map)
		for u in Props.unique_encounters(): hud.county_map.reveal(u.x, u.z, 14.0, 0.6)
	if inf.get("mend", false): player.health = player.max_health; player.stamina = player.max_stamina
	hud.toast(inf.thanks if inf.has("thanks") else "%s %s." % [inf.found, Settlers.list_text(inf.gift)])
	journal.record("landmark"); sound.craft(); save_all()

## A war party on the town, every few days, by day, while you're near enough to ride to the rescue.
const RAID_IN_TOWN := 60.0
func _raid_tick() -> void:
	if camp.raid.on or sky.day < raid_day or sky.time < 0.3 or sky.time > 0.7 or player.dead: return
	if not NativeCamps.player_armed: return # (no raids till you've a bow or a gun to meet them with: the player's ask)
	if Vector2(player.pos.x - town.at.x, player.pos.z - town.at.z).length() > RAID_IN_TOWN: return # (only while you're in town: the player's ask; the page raids within 220 m)
	var targets := town.raidable(); raid_day = sky.day + 3 + randi() % 4
	if targets.is_empty(): return
	var tg: Dictionary = targets[randi() % targets.size()]
	if camp.start_raid(town.at, tg): hud.toast("Riders! A war party is coming down out of the hills on the town, making for the %s. Drive them off before they wreck it!" % tg.name)

## Smoke over the nearest fires (yours, the camps', the bunkhouse supper fire, the town's stovepipes) and Saturday
## night's fireworks once every street is mended.
func _fires_and_fireworks(dt: float) -> void:
	var fires := []
	var add := func(x: float, y: float, z: float, top: float, sparks: bool) -> void:
		var d := (x - player.pos.x) ** 2 + (z - player.pos.z) ** 2
		if d < 55.0 * 55.0: fires.append({"x": x, "y": y, "z": z, "top": top, "sparks": sparks, "d": d})
	for p in build.pieces:
		if p.type == "campfire": add.call(p.x, p.y, p.z, 0.9, true)
		elif p.type == "forge":
			var ra := float(p.get("rot", 0)) * PI / 2.0; var c := cos(ra); var sn := sin(ra) # (build rotations are quarter turns)
			add.call(p.x + 0.45 * c - 0.25 * sn, p.y, p.z - 0.45 * sn - 0.25 * c, 2.35, false)
	for c in camp.list: add.call(c.at.x, c.at.y, c.at.z, 0.8, true)
	if extras.bunk_built and sky.time > 0.76 and sky.time < 0.88: add.call(extras.fire_at.x, Terrain.get_height(extras.fire_at.x, extras.fire_at.z), extras.fire_at.z, 0.7, true)
	var tm := sky.time; var day_fire := tm > 0.24 and tm < 0.8; var meals := (tm > 0.24 and tm < 0.36) or (tm > 0.7 and tm < 0.84)
	if not town.far:
		for c in town.chimneys: if (day_fire if c.when == "day" else meals): add.call(c.x, c.y, c.z, c.top, false)
	fires.sort_custom(func(a, b): return a.d < b.d)
	fire_smoke.update(dt, fires, rig.camera, sky.night, weather.rain)
	var all_done := town.street_done(-1) and town.street_done(0) and town.street_done(1)
	var party := sky.day == celebrate_day # (a boss beaten and his prize home: the town celebrates that night, mended or not)
	var show := not town.far and (sky.day % 7 == 6 and all_done or party) and sky.time > 0.79 and sky.time < 0.9
	town.fireworks_on = (sky.day % 7 == 6 and all_done or party) and sky.time > 0.7 and sky.time < 0.9 # (the Row walks over after supper)
	if show and fw_day != sky.day:
		fw_day = sky.day
		hud.toast("The town celebrates tonight: from the field behind the church the first rocket goes up!" if party else "Saturday night, and the whole town is mended. From the field behind the church the first rocket goes up: fireworks!")
	if show or fireworks.mm.visible_instance_count: fireworks.update(dt, show, Vector3(town.church_at.x + town.along.x * 14.0, town.y0, town.church_at.z + town.along.z * 14.0), rig.camera, func(q: Vector3) -> void:
		var d := Vector2(q.x - player.pos.x, q.z - player.pos.z).length()
		if d < 140.0: sound.pop(maxf(0.05, 1.0 - d / 140.0)))

## The pan's swirl: 2.6 s, then colour or black sand. Richer in the Breaks and the pines (and blessed at the church).
func _pan(dt: float) -> void:
	if pan_t <= 0.0: return
	pan_t -= dt; pan_mesh.visible = true; pan_mesh.rotation.y += dt * 9.0; pan_mesh.position.y = -0.08 + sin(pan_t * 14.0) * 0.03
	if pan_t > 0.0: return
	pan_mesh.visible = false
	Terrain.land_at(player.pos.x, player.pos.z)
	var W: Dictionary = Terrain.L_w
	var rich: float = 0.22 + 0.4 * (W.breaks + W.pines) + 0.15 * W.hollows + (0.15 if blessed_day == sky.day else 0.0); var r := randf()
	if r < rich:
		var n := 2 if r < rich * 0.25 else 1; inventory.gold = inventory.get("gold", 0) + n
		if settlers.discover("gold"): hud.toast("COLOUR! Bright flakes in the black sand at the bottom of the pan. Gold. Take it to the assay office in Cold Glitter Creek. And now you can build a sluice box by the water (B, Works shelf) for a placer miner to run.")
		else: hud.toast("+%d pinch%s of gold" % [n, "es" if n > 1 else ""])
		confetti.burst(player.pos + Vector3(0, 0.9, 0), [0xf0c840, 0xffe08a, 0xd8a830], 8, 0.5); sound.pick()
	else: hud.toast(["Nothing but black sand.", "Gravel and a crawdad. No colour.", "Sand, sand and more sand."][randi() % 3])

func _at_door(id: String, any := false) -> bool:
	return (any or town.tiers.get(id, 0)) and town.doors.has(id) and Vector2(player.pos.x - town.doors[id].x, player.pos.z - town.doors[id].z).length() < 2.3

## The stage line's stops: every landmark you've found.
func _stage_stops() -> Array:
	var out := []
	for key in landmarks.found:
		var parts: PackedStringArray = String(key).split(",")
		var placed := Props.place(int(parts[0]), int(parts[1]), world.exclusions)
		for st in placed.sites: if st.key == key and landmarks.info.has(st.mark): out.append({"name": landmarks.info[st.mark].name, "x": st.x, "z": st.z})
	return out

## The sheriff's WANTED poster on its post by the jail door (null takes it down): the web's printed card, its text set
## in Georgia on a little offscreen sheet (a SubViewport drawn once) and laid on the card's face.
func _set_poster(b) -> void:
	if poster: poster.queue_free(); poster = null
	if b == null or not town.doors.has("jail"): return
	var jb := Town.find_b("jail"); var off: float = town.street_offs[Town.street_of("jail")]
	var p: Vector3 = town.at + town.along * (jb.s + 2.6) + town.toward * (off + jb.side * (Town.HALF - 1.2))
	var g := Node3D.new(); g.add_child(Town.posts([0.0]))
	var sheet := _wanted_sheet(g, [["WANTED", 0.53, 40, 0x2a201a, true, false], [b.name, 0.36, 21, 0x2a201a, false, true], ["DEAD OR DRIVEN OFF", 0.2, 22, 0x2a201a, true, false], ["$%d REWARD" % b.pay, 0.08, 30, 0x8a2a1e, true, false]])
	sheet.position = Vector3(0, 1.15, -0.15); sheet.rotation.z = 0.03
	g.position = Vector3(p.x, town.y0, p.z); g.rotation.y = atan2(jb.side * town.toward.x, jb.side * town.toward.z) + PI
	town.add_child(g); poster = g

## A printed poster sheet (parented to g, which holds its little viewport): lines [text, height 0-0.65, size, ink,
## bold, italic], as the sheriff's WANTED bill is laid out.
func _wanted_sheet(g: Node3D, lines: Array) -> MeshInstance3D:
	var vp := SubViewport.new(); vp.size = Vector2i(256, 192); vp.render_target_update_mode = SubViewport.UPDATE_ONCE; vp.transparent_bg = false
	var bg := ColorRect.new(); bg.color = Color.hex(0xe8d8a8ff); bg.size = Vector2(256, 192); vp.add_child(bg)
	var font := SystemFont.new(); font.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	for L in lines:
		var lab := Label.new(); lab.text = L[0]; lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var f := font.duplicate() as SystemFont; f.font_weight = 700 if L[4] else 400; f.font_italic = L[5]
		lab.add_theme_font_override("font", f); lab.add_theme_font_size_override("font_size", L[2]); lab.add_theme_color_override("font_color", Color.hex((L[3] << 8) | 0xff))
		lab.size = Vector2(256, 48); lab.position = Vector2(0, (1.0 - (L[1] + 0.02) / 0.65) * 192 - 24); vp.add_child(lab)
	g.add_child(vp)
	var pts := PackedVector2Array([Vector2(-0.42, 0), Vector2(0.4, 0.03), Vector2(0.43, 0.62), Vector2(0.02, 0.6), Vector2(-0.41, 0.63)])
	var sheet := MeshInstance3D.new(); sheet.mesh = CardMesh.build(pts, 0.02)
	var mat := PaperMats.card(vp.get_texture(), {"flip": true, "snow": 0.0}); sheet.material_override = mat
	g.add_child(sheet)
	return sheet

## The bosses' wanted board on Main Street, by the assay office: a poster for each boss still at large (his name,
## what he holds, the sheriff's reward), torn down as each falls. Remade on load and whenever one falls.
var boss_board: Node3D
func _boss_board() -> void:
	if boss_board: boss_board.queue_free(); boss_board = null
	var left: Array = bosses.filter(func(b): return not b.beaten or b.back)
	if left.is_empty() or not town.doors.has("assay"): return
	var ab := Town.find_b("assay")
	var outw: Vector3 = -town.toward * float(ab.side)
	var q: Vector3 = town.doors.assay + town.along * 3.6 - outw * 0.2 # (on the boardwalk past the scales, against the shopfront: the placard has the other side)
	var g := Node3D.new(); g.add_child(Town.posts([-1.25, 1.25]))
	var plank := Town.box(2.9, 0.9, 0.06, 0x7a5a3a); plank.position = Vector3(0, 1.2, -0.08); g.add_child(plank)
	var i := 0
	for b in left:
		var sh := _wanted_sheet(g, [["WANTED", 0.55, 38, 0x2a201a, true, false], [b.title(), 0.38, 22, 0x2a201a, false, true],
			["for %s" % b.spec.prize, 0.22, 18, 0x2a201a, false, false], ["$%d REWARD" % b.spec.bounty, 0.07, 28, 0x8a2a1e, true, false]])
		sh.scale = Vector3.ONE * 0.95; sh.position = Vector3((i - (left.size() - 1) / 2.0) * 0.88, 0.95, -0.03); sh.rotation.z = [0.04, -0.03, 0.02][i % 3]
		i += 1
	g.position = Vector3(q.x, town.y0, q.z); g.rotation.y = atan2(outw.x, outw.z) # (its posters toward the street)
	town.add_child(g); boss_board = g

## The depot's freight office, a whistle-stop's trading post, and the train: board her where she stands ($1; from
## the depot she leaves at once), ride on the back platform, step off at any stop she draws up at.
func _rail_doors() -> bool:
	var stop = train.stopped_at()
	if train.passenger:
		beast_prompt = ("[E] Get off at %s" % stop.name) if stop != null else ("Riding the Overland & Western · next stop %s" % train.next_stop_name())
		if stop != null and input.hit("KeyE"):
			train.passenger = false; player.pos = stop.platform; player.pos.y = Terrain.get_height(stop.platform.x, stop.platform.z) + 0.3
			hud.toast("You step down onto the platform at %s. The conductor tips his cap." % stop.name)
		return true
	if riding or not railroad.built: return false
	if railroad.freight_at != null and Vector2(player.pos.x - railroad.freight_at.x, player.pos.z - railroad.freight_at.z).length() < 2.6:
		beast_prompt = ("[E] The freight office (%d crate%s waiting for the train)" % [railroad.freight, "s" if railroad.freight > 1 else ""]) if railroad.freight else "[E] The freight office: ship your goods East"
		if input.hit("KeyE"): _open_craft()
		return true
	if claim.group != null and claim.near(player.pos.x, player.pos.z):
		var inv := inventory
		beast_prompt = ("[E] Empty the ore cart (%d gold%s)" % [claim.stock.gold, (", %d silver" % claim.stock.silver) if claim.stock.silver else ""]) if claim.stock.gold or claim.stock.silver else ("Your claim: worked today" if claim.dug_day == sky.day else "[E] Work your claim")
		if input.hit("KeyE"):
			var cart := claim.collect()
			if cart.gold or cart.silver:
				inv.gold = inv.get("gold", 0) + cart.gold; inv.silver = inv.get("silver", 0) + cart.silver
				hud.toast("Your hand tips out the ore cart for you: %d pinches of gold%s. \"She's a fair vein, boss.\"" % [cart.gold, (" and %d nugget%s of silver" % [cart.silver, "s" if cart.silver > 1 else ""]) if cart.silver else ""])
			elif not owns("pick"): hud.toast("You need a pickaxe to work the vein.")
			else:
				var got = claim.dig(sky.day, tools)
				if got == null: hud.toast("You have worked the vein today, and the cart is empty. Your hand will have more for you tomorrow." if claim.hand else "You have worked the vein today. Come back tomorrow: it gives up a little each day.")
				else:
					inv.gold = inv.get("gold", 0) + got.gold
					if got.silver: inv.silver = inv.get("silver", 0) + got.silver
					hud.toast("You work the vein by lantern light and come out with %d pinches of gold%s. (The assayer in town buys it.)" % [got.gold, " and a nugget of silver" if got.silver else ""])
		return true
	var pst = railroad.post_at(player.pos.x, player.pos.z, 2.6)
	if pst != null:
		beast_prompt = "[E] Trade at the %s trading post" % pst.name
		if input.hit("KeyE"): _open_craft()
		return true
	if stop != null and Vector2(player.pos.x - train.cars[3].position.x, player.pos.z - train.cars[3].position.z).length() < 5.0:
		beast_prompt = "[E] Board the train ($1): she leaves at once" if stop.depot else "[E] Board the train at %s ($1)" % stop.name
		if input.hit("KeyE"):
			if inventory.get("dollars", 0) < 1: hud.toast("The fare is a dollar, and your poke is empty.")
			else:
				inventory.dollars -= 1; train.passenger = true
				if stop.depot: train.depart()
				hud.toast("You pay the conductor a dollar and climb up onto the coach's back platform. All aboard for %s!" % train.next_stop_name())
		return true
	return false

## The town's trade doors (main.js): the assayer, panning, the shops, the sheriff, the barber, the hotel, the
## telegraph, the dance hall, the stage line, the church, the saloon and Miss Dolly, the livery. Returns true if
## one of them has the E key this frame.
func _town_doors() -> bool:
	var inv := inventory
	# the assay office: gold dust at $4 the pinch, silver at $5 the lump (a tenth more for a well-groomed man)
	if town.near_assay(player.pos) and _prize_held() != null:
		var pb: Boss = _prize_held()
		beast_prompt = "[E] Hand %s to the assayer" % pb.spec.prize
		if input.hit("KeyE"): _hand_in(pb)
		return true
	if town.near_assay(player.pos):
		var g: int = inv.get("gold", 0); var sv: int = inv.get("silver", 0)
		beast_prompt = ("[E] Sell to the assayer: %s (about $%d)" % [", ".join(PackedStringArray([("%d gold" % g) if g else "", ("%d silver" % sv) if sv else ""].filter(func(x): return x != ""))), g * 4 + sv * 5]) if g > 0 or sv > 0 else "The assay office: bring gold here to be weighed"
		if input.hit("KeyE"):
			if g > 0 or sv > 0:
				var pay := roundi((g * 4 + sv * 5) * (1.1 if inv.get("groomedDay", -1) == sky.day else 1.0)); inv.dollars = inv.get("dollars", 0) + pay; fortune += pay; inv.gold = 0; inv.silver = 0; journal.record("assay")
				sound.craft(); hud.toast("The assayer weighs it on his brass scales%s. \"$%d, and not a cent more.\" Fortune so far: $%d." % [" and assays the silver with a drop of acid" if sv else "", pay, fortune])
			else: hud.toast("\"Bring me colour, friend, and I'll weigh it,\" says the assayer, not looking up.")
		return true
	# panning the shallows
	# (not while the ducks are paddling near and you've corn for them: that E is theirs, as the web's toss comes first)
	if player.wading and pan_t <= 0.0 and not (inventory.get("corn", 0) >= 1 and ducks.fam != null and ducks.fam.come == null and ducks.toss_spot(player.pos.x, player.pos.z) != null): # (no family on the pond: fam is null, and panning must still work)
		beast_prompt = "[E] Pan the shallows for colour"
		if input.hit("KeyE"): pan_t = 2.6; sound.step("water")
		return true
	# the shops: E opens the crafting panel at their shelves
	for e in [["store", "[E] Shop at the general store ($%d in your poke)"], ["bakery", "[E] Step into the bakery ($%d in your poke)"], ["feed", "[E] Step into the feed & grain ($%d in your poke)"],
			["drygoods", "[E] Step into the dry goods ($%d in your poke)"], ["cooper", "[E] Step into the cooperage ($%d in your poke)"], ["smithy", "[E] The blacksmith's: tools, and every edge ground sharp ($%d in your poke)"]]:
		if _at_door(e[0]):
			beast_prompt = e[1] % inv.get("dollars", 0)
			if input.hit("KeyE"):
				_open_craft()
				if e[0] in ["store", "smithy"]: journal.record(e[0])
			return true
	if _at_door("bank"):
		beast_prompt = "[E] Step up to the teller's window ($%d in your poke, $%d in the bank)" % [inv.get("dollars", 0), inv.get("savings", 0)]
		if input.hit("KeyE"): _open_craft()
		return true
	# the sheriff: a price on one guarded den out in the county; beat every guardian there and come back for the reward
	if _at_door("jail"):
		# the bosses: a reward on each one's head, paid once he's beaten (on top of the assayer's fee for his prize)
		var owed = null
		for bo in bosses: if bo.beaten and not bo.back and not bo.bounty_paid: owed = bo; break
		if owed != null:
			var due: int = roundi(float(owed.spec.bounty) * (1.0 + 0.25 * owed.returns))
			beast_prompt = "[E] Claim the sheriff's $%d reward for %s" % [due, owed.title()]
			if input.hit("KeyE"):
				owed.bounty_paid = true; inv.dollars = inv.get("dollars", 0) + due; sound.craft(); journal.record("bounty")
				hud.toast(("The sheriff whistles low. \"%s? Folks'll sleep easier.\" +$%d" if owed.returns == 0 else "\"%s again? You're making a habit of it.\" +$%d") % [owed.title(), due])
			return true
		beast_prompt = ("[E] See the sheriff about the $%d bounty" % bounty.pay) if bounty != null else "[E] Ask the sheriff if there's a bounty posted"
		if input.hit("KeyE"):
			var beaten := func(b) -> bool:
				for i in int(b.guards): if not world.destroyed.has("%s:g%d" % [b.key, i]): return false
				return true
			var dir_to := func(x: float, z: float) -> String: return DIRS8[posmod(roundi(atan2(z - town.at.z, x - town.at.x) / (PI / 4.0) + 8), 8)]
			if bounty != null and beaten.call(bounty):
				inv.dollars = inv.get("dollars", 0) + bounty.pay; sound.craft(); journal.record("bounty"); hud.toast("The sheriff tears down the poster and counts out $%d. \"Much obliged. The county's that much safer.\"" % bounty.pay)
				bounty = null; _set_poster(null)
			elif bounty != null: hud.toast("\"That %s is still out there, about %d paces %s of town. It's on your map.\"" % [String(bounty.name).to_lower(), roundi(Vector2(bounty.x - town.at.x, bounty.z - town.at.z).length() * 1.3 / 10.0) * 10, dir_to.call(bounty.x, bounty.z)])
			else:
				var tcx := floori(town.at.x / Terrain.CHUNK); var tcz := floori(town.at.z / Terrain.CHUNK); var best = null; var bd := INF
				for st in _sites_near(tcx, tcz, 10):
					if not st.get("guards", 0) or st.kind == "landmark": continue
					var d := Vector2(st.x - town.at.x, st.z - town.at.z).length()
					if d < 60.0 or d > 320.0 or beaten.call({"key": st.key, "guards": st.guards}): continue
					if d < bd: bd = d; best = st
				if best == null: hud.toast("\"Quiet as a churchyard out there, thanks to you. Nothing on the board today.\"")
				else:
					var kind: String = best.get("guard", "") if best.get("guard", "") != "" else ("boar" if best.kind == "grove" else "coyote")
					var spec: Dictionary = Enemies.GUARDS[kind]
					bounty = {"key": best.key, "guards": best.guards, "x": best.x, "z": best.z, "name": spec.name, "pay": maxi(12, roundi(spec.hp * best.guards * 1.4))}
					_set_poster(bounty); sound.place(); hud.county_map.reveal(best.x, best.z, 14.0) # (marked on your county map)
					var who: String = ("%d %ss" % [best.guards, String(spec.name).to_lower()]) if best.guards > 1 else "the " + String(spec.name).to_lower()
					hud.toast("The sheriff tacks up a fresh poster: WANTED, %s, $%d reward. \"Their den's about %d paces %s of town. I've marked your map.\"" % [who, bounty.pay, roundi(bd * 1.3 / 10.0) * 10, dir_to.call(best.x, best.z)])
		return true
	# the barber: spruced up till tomorrow (the assayer pays a tenth more, the Row a dollar more)
	if _at_door("barber"):
		beast_prompt = "[E] The barber (you're spruced up for today)" if inv.get("groomedDay", -1) == sky.day else "[E] A shave and a haircut: $2"
		if input.hit("KeyE"):
			if inv.get("groomedDay", -1) == sky.day: hud.toast("\"Any shorter and you'll catch cold, friend.\" You're as dapper as you'll get today.")
			elif inv.get("dollars", 0) < 2: hud.toast("\"Shave and a haircut: two dollars.\" You're short.")
			else: inv.dollars -= 2; inv.groomedDay = sky.day; sound.craft(); hud.toast("Snip, snip, a hot towel and a close shave with bay rum. You step out spruced up: till tomorrow the assayer pays a tenth more, and the folk on the Row a dollar more.")
		return true
	# the Grand Hotel: a room for the night ($4), a feather bed and breakfast
	if _at_door("hotel2"):
		var sleepy := sky.time > 0.8 or sky.time < 0.24
		beast_prompt = "[E] Take a room for the night at the Grand Hotel: $4, breakfast included" if sleepy else "[E] The Grand Hotel (rooms from sundown)"
		if input.hit("KeyE") and sleep_timer == 0.0:
			if not sleepy: hud.toast("\"Rooms are let from sundown, sir. The dining room serves supper at six.\"")
			elif inv.get("dollars", 0) < 4: hud.toast("\"A room is four dollars the night, sir, breakfast included.\" You're short.")
			else: inv.dollars -= 4; hotel_night = true; sleep_timer = 2.6; hud.sleep_show = true; sound.lullaby()
		return true
	# the telegraph office: the morning wire names a buyer back East; sell all you have of it, once a day
	if _at_door("telegraph"):
		var wire: Array = MARKET[(sky.day * 5 + 3) % MARKET.size()]; var item: String = wire[0]; var n: int = inv.get(item, 0)
		beast_prompt = "[E] The telegraph office (today's order is filled)" if inv.get("wireDay", -1) == sky.day else "[E] Today's wire: %s wants %s, $%d each (you have %d)" % [wire[2], item, wire[1], n]
		if input.hit("KeyE"):
			if inv.get("wireDay", -1) == sky.day: hud.toast("\"The order's filled for today. Tomorrow's wire comes in at seven.\"")
			elif n == 0: hud.toast("The telegrapher taps the morning's wire: \"%s WANTS %s STOP $%d EACH STOP\". Bring some today." % [String(wire[2]).to_upper(), item.to_upper(), wire[1]])
			else: inv[item] = 0; inv.dollars = inv.get("dollars", 0) + n * wire[1]; inv.wireDay = sky.day; sound.craft(); journal.record("wire"); hud.toast("Click-clack: %d %s crated and billed to %s. The telegrapher counts out $%d." % [n, item, wire[2], n * wire[1]])
		return true
	# the dance hall: a reel once a night, and a long spring in your step
	if _at_door("dance"):
		var open := sky.time > 0.76 or sky.time < 0.04
		beast_prompt = ("[E] The dance hall (you've danced tonight)" if inv.get("hallDay", -1) == sky.day else "[E] Step in and dance a reel") if open else "[E] The dance hall (opens at dusk)"
		if input.hit("KeyE"):
			if not open: hud.toast("\"Doors open at dusk, friend. Bring your dancing boots.\"")
			elif inv.get("hallDay", -1) == sky.day: hud.toast("Your feet have had all the reels they can take tonight.")
			else:
				inv.hallDay = sky.day; sound.craft(); player.stamina_boost = maxf(player.stamina_boost, 360.0); player.stamina = maxf(player.stamina, player.max_stamina); player.fullness = maxf(0.0, player.fullness - 8.0); sky.time = fmod(sky.time + 0.02, 1.0)
				hud.toast(["You swing through a Virginia reel with the calico girls, the fiddle sawing away. You come out light as a feather.", "A stomping schottische, then a waltz. You step out into the night with a spring in your step.", "The caller hollers \"Promenade!\" and you do. Breathless and grinning, you come out ready to run all night."][sky.day % 3])
		return true
	# the stage line: to any landmark you've found ($3; Q picks the stop), and the coach home from where it set you down
	if not riding and _at_door("stable2"):
		var stops := _stage_stops(); var stop = stops[stage_idx % stops.size()] if stops.size() else null
		beast_prompt = ("[E] Take the stage to %s: $3%s" % [stop.name, " · [Q] next stop" if stops.size() > 1 else ""]) if stop != null else "[E] The stage line (runs to landmarks you've found)"
		if input.hit("KeyQ") and stops.size(): stage_idx = (stage_idx + 1) % stops.size(); sound.click()
		if input.hit("KeyE"):
			if stop == null: hud.toast("\"The stage runs to any landmark you've found out in the county, friend. Go find some, and I'll take you back any time.\"")
			elif inv.get("dollars", 0) < 3: hud.toast("\"Three dollars the fare.\" You're short.")
			else:
				inv.dollars -= 3; var a := atan2(town.at.z - stop.z, town.at.x - stop.x); var x: float = stop.x + cos(a) * 9.0; var z: float = stop.z + sin(a) * 9.0
				player.pos = Vector3(x, Terrain.get_height(x, z), z); stage_from = {"x": x, "z": z}; sky.time = fmod(sky.time + 0.03, 1.0); sound.craft(); journal.record("stage")
				hud.toast("The coach rattles out of Cold Glitter Creek and over the passes, and sets you down by %s. The driver tips his hat: \"Wait here when you're done and I'll carry you home.\" (E at this spot rides the coach back, $3.)" % stop.name)
		return true
	if stage_from != null and not riding and Vector2(player.pos.x - stage_from.x, player.pos.z - stage_from.z).length() < 4.0:
		beast_prompt = "[E] Wave down the coach home to Cold Glitter Creek: $3"
		if input.hit("KeyE"):
			if inv.get("dollars", 0) < 3: hud.toast("\"Three dollars the fare home.\" You're short; it's a long walk.")
			else:
				inv.dollars -= 3; var d: Vector3 = town.doors.stable2 + town.toward * 2.5
				player.pos = Vector3(d.x, Terrain.get_height(d.x, d.z), d.z); stage_from = null; sky.time = fmod(sky.time + 0.03, 1.0); sound.craft()
				hud.toast("The coach comes rattling up the trail. You ride home over the passes and step down at the stage stables in Cold Glitter Creek.")
		return true
	# the mended church: once a day the parson's kind words mend you, and your pans run richer till sundown
	if _at_door("church") and blessed_day != sky.day:
		beast_prompt = "[E] A word with the parson (mends you; richer pans today)"
		if input.hit("KeyE"):
			blessed_day = sky.day; player.health = player.max_health; player.stamina = player.max_stamina; journal.record("church")
			confetti.burst(player.pos + Vector3(0, 1.6, 0), [0xf6efe0, 0xf0c840, 0xfff2b0], 10, 0.5)
			hud.toast(["\"Bless you, prospector. The Lord keeps the gold where the honest can find it.\"", "\"Go gently today, friend. Luck favours the patient pan.\"", "\"May your riffles fill and your back hold out.\""][sky.day % 3] + " Mended, and blessed: richer pans today.")
		return true
	# the saloon: a hot supper, and an old-timer's tip about a guarded treasure (pencilled onto the county map)
	if town.tiers.get("saloon", 0) and dolly_day != sky.day and Vector2(player.pos.x - town.doors.saloon.x, player.pos.z - town.doors.saloon.z).length() < 6.0:
		dolly_day = sky.day; hud.toast(["\"Buy a girl a drink, sugar?\" Miss Dolly winks.", "\"Lookin' lucky tonight, prospector.\"", "\"Come on in, the piano's warm.\""][sky.day % 3])
	if _at_door("saloon"):
		beast_prompt = "[E] Hot supper at the saloon, and the old-timers' talk ($3; you have $%d)" % inv.get("dollars", 0)
		if input.hit("KeyE"):
			if inv.get("dollars", 0) >= 3:
				inv.dollars -= 3; player.fullness = 100.0; player.health = minf(player.max_health, player.health + 20.0)
				var pcx := floori(player.pos.x / Terrain.CHUNK); var pcz := floori(player.pos.z / Terrain.CHUNK); var tip = null; var td := INF
				for st in _sites_near(pcx, pcz, 8):
					if st.kind == "landmark" or tips_heard.has(st.key): continue
					var d := Vector2(st.x - player.pos.x, st.z - player.pos.z).length()
					if d < td: td = d; tip = st
				var said := "The stew is hot and the bread is fresh. An old-timer at the bar has nothing new to tell you tonight."
				if tip != null:
					tips_heard[tip.key] = true; hud.county_map.reveal(tip.x, tip.z, 14.0) # (pencilled onto your map)
					var dir: String = DIRS8[posmod(roundi(atan2(tip.z - player.pos.z, tip.x - player.pos.x) / (PI / 4.0) + 8), 8)]
					var what: String = {"vein": "an iron vein the coyotes keep", "grove": "a wild-hive grove an old boar watches", "thicket": "a berry thicket full of coyotes", "sang": "wild sang in the Hollows (and something that walks behind you)", "silver": "silver in the red rock, where the gougers graze", "pearl": "pearls in the fen, if the Hodag lets you", "geode": "thunder eggs on the prairie, coyote country", "amber": "amber on the old pines, wampus cat country"}.get(tip.kind, "something worth the walk")
					said = "A hot supper of stew and bread. An old-timer at the bar leans over: \"%s, %d paces %s of town.\" He pencils it onto your map." % [what.left(1).to_upper() + what.substr(1), roundi(td * 1.3 / 10.0) * 10, dir]
				hud.toast(said); sound.craft(); journal.record("saloon")
			else: hud.toast("\"Supper's three dollars, friend.\" The barkeep goes back to polishing a glass.")
		return true
	# the livery: a saddle horse
	if horse == null and _at_door("livery"):
		beast_prompt = "[E] Buy a saddle horse at the livery: $35 (you have $%d)" % inv.get("dollars", 0)
		if input.hit("KeyE"):
			if inv.get("dollars", 0) >= 35:
				inv.dollars -= 35; var d: Vector3 = town.doors.livery + town.toward * 2.5; make_horse(d.x, d.z); sound.craft(); journal.record("horse")
				hud.toast("The liveryman leads out a chestnut mare with a white blaze and a red saddle blanket. \"Her name's Biscuit. She's steady.\" Press X beside her to get up, and X again to get down. From anywhere else, X whistles her over.")
			else: hud.toast("\"A good saddle horse is thirty-five dollars, and she's worth every cent.\" You've $%d." % inv.get("dollars", 0))
		return true
	return false

## The railroad comes the day every street in town stands mended; the train's timetable; riding on the coach's back
## platform; a rush order wired down the line each morning there isn't one standing; the bank's morning interest.
func _rail(dt: float) -> void:
	if not railroad.built:
		rail_check_t -= dt
		if rail_check_t <= 0.0:
			rail_check_t = 3.0
			if town.street_done(-1) and town.street_done(0) and town.street_done(1):
				railroad.build(); hud.toast("Cold Glitter Creek has come up in the world: the Overland & Western has laid a rail line out past the church, with a depot at its head and a whistle-stop in each of the wild lands.")
	train.update(dt, sky.time, rig.camera, player)
	railroad.update(dt, player, sky.time > 0.24 and sky.time < 0.86) # (the trading-post keepers: out front by day)
	if train.passenger: player.pos = train.ride_point(); player.vel = Vector3.ZERO # (standing on the coach's back platform)
	if claim.group == null and railroad.built and tools.has("claim"): claim.build() # (staked out once it's filed)
	if claim.group != null and claim.hand == null and tools.has("claimhand"): claim.hire(sky.day) # (and the hired hand, once he's taken on)
	if claim.group != null and claim.mill == null and tools.has("stampmill"): claim.add_mill() # (and the stamp mill)
	claim.update(dt, sky.day, sky.time > 0.24 and sky.time < 0.86, player)
	tinker.update(dt, sky)
	if fair.update(dt, sky) and fair_told_day != sky.day: fair_told_day = sky.day; hud.toast("It's County Fair day! Mrs. Pruitt's judging table is up just south of the farm lane, past the fence.")
	grandma.update(dt, sky)
	if mail.update(dt, sky) and Vector2(player.pos.x - mail.at.x, player.pos.z - mail.at.z).length() < 45.0: hud.toast("The mail carrier's been by: the red flag is up on the mailbox.")
	if story_kind == "almanac":
		almanac_t -= dt
		if almanac_t <= 0.0 or input.hit("KeyE"): story_kind = ""; hud.story_hide()
	if (force_active or input.locked) and input.hit("KeyH"):
		sound.tear()
		if hud.calendar.visible: hud.calendar_hide()
		else: _render_calendar()
	elif hud.calendar.visible:
		cal_t += dt
		if cal_t > 1.0: cal_t = 0.0; _render_calendar() # (kept current while open)
	if sky.night > 0.85: journal.record("night")
	if railroad.built and sky.time > 0.3 and sky.time < 0.8:
		var o = crafting.order_state()
		if o == null or (o.day != sky.day and (o.done or sky.day > o.due)):
			if o != null and not o.done: hud.toast("The rush order for the %s trading post has lapsed: they found it elsewhere." % o.where)
			crafting.clear_order(); var q := crafting.new_order(sky.day)
			if Vector2(player.pos.x - railroad.depot.x, player.pos.z - railroad.depot.z).length() < 150.0 or train.passenger:
				hud.toast("The telegraph at the depot clatters: a rush order from %s, %s, by day %d, $%d on delivery. (Almanac, H)" % [q.where, String(q.name).replace("Telegram: ", "").to_lower(), q.due, q.pay])
	if town.tiers.get("bank", 0) and sky.time > 0.25 and inventory.get("bankDay", -1) != sky.day: # the morning's interest, three cents on the dollar
		var due := maxi(1, floori(inventory.get("savings", 0) * 0.03)) if inventory.has("bankDay") and inventory.get("savings", 0) >= 10 else 0
		inventory.bankDay = sky.day
		if due: inventory.savings += due; hud.toast("The Miners' bank has written $%d interest into your account. $%d in the safe." % [due, inventory.savings])

## Knocked out: a few seconds of quiet, then you wake by the farmhouse.
func _knocked_out(dt: float) -> void:
	if death_timer <= 0.0: return
	death_timer -= dt
	if death_timer <= 0.0:
		player.pos = homestead.spawn; player.health = 60.0; player.dead = false; player.hurt_timer = 0.0
		hud.toast("You wake by the farmhouse, a little worse for wear.")

## A guardian struck (a blow, an arrow, a bullet): it turns on you; beaten, it slinks off for good with its pelts.
## Something on the prowl after dark (the player's ask: some enemies at night, not too hard): away from the farm and
## the town, now and then a pair of night coyotes settles a little ahead of you and comes for you once you're near.
## Weaker than the guardians' (4 health, 6 a bite), they go at dawn; beaten ones aren't kept in the save's "gone" list.
var _night_t := 40.0
var _night_sites: Array = []
var _night_n := 0
var _night_told := false
func _night_prowlers(dt: float) -> void:
	var dark := sky.night > 0.6
	if not dark:
		if not _night_sites.is_empty():
			for st in _night_sites: enemies.despawn_site(st)
			_night_sites.clear()
		for k in world.destroyed.keys(): if String(k).begins_with("night:"): world.destroyed.erase(k)
		_night_t = 40.0
		return
	if not (force_active or input.locked) or player.dead: return
	var p := player.pos
	var home_d := Vector2(p.x - homestead.spawn.x, p.z - homestead.spawn.z).length(); var town_d := Vector2(p.x - town.at.x, p.z - town.at.z).length()
	if home_d < 45.0 or town_d < 70.0: return
	_night_t -= dt
	var live := enemies.list.any(func(e): return String(e.key).begins_with("night:") and not e.dying)
	if _night_t > 0.0 or live: return
	var at := Vector3.INF
	for k in 8: # (ahead of you, or a little to one side: on land)
		var f := player.forward().rotated(Vector3.UP, (k - 3.5) * 0.35); var q := p + Vector3(f.x, 0, f.z).normalized() * (22.0 + randf() * 8.0)
		if not Terrain.is_water(q.x, q.z) and not Terrain.impassable(q.x, q.z): at = q; break
	if at == Vector3.INF: _night_t = 5.0; return
	_night_t = 70.0 + randf() * 60.0
	_night_n += 1
	var site := {"key": "night:%d:%d" % [sky.day, _night_n], "kind": "den", "guard": "coyote", "guards": 2, "x": at.x, "z": at.z}
	enemies.spawn_site(site); _night_sites.append(site)
	for e in enemies.list:
		if String(e.key).begins_with(site.key):
			var sp: Dictionary = e.spec.duplicate(); sp.name = "Night coyote"; sp.hp = 4; sp.dmg = 6; sp.aggro = 12.0; sp.leash = 25.0; sp.pelt = [1, 1]
			e.spec = sp; e.hp = 4
	if not _night_told: _night_told = true; hud.toast("Coyotes yip in the dark ahead. Keep your axe handy.")

func guardian_hit(e: Dictionary, amount: int) -> void:
	var r := enemies.damage(e, amount, player.pos)
	confetti.burst(Enemies.pos(e) + Vector3(0, 0.6, 0), [0xa8865c, 0x7d6448, 0xefe5cc], 36 if r.killed else 8, 1.0 if r.killed else 0.6)
	sound.chop()
	if r.killed:
		journal.record("slay")
		inventory.pelt = inventory.get("pelt", 0) + r.loot
		if settlers.discover("pelt"): hud.toast("Your first pelt! Now you can build a tannery (B, Works shelf) for a settler to run.")
		hud.toast("The %s is beaten and slinks off for good (+%d pelt)" % [String(e.spec.name).to_lower(), r.loot]); sound.tear()

## One frame of gathering: aim, swing on click (or hold), E picks soft things whole, the hit, the chips, the loot.
func _gather(active: bool, connected: bool) -> void:
	for i in hud.data.TOOLBAR.size():
		if input.hit("Digit%d" % (i + 1)) and not build.active: pick_tool(hud.data.TOOLBAR[i].id)
	enemy_t = enemies.find_target(player, Player.REACH + (0.9 if held == "spear" else 0.0)) if active and not player.dead and not build.active else null
	camp_t = camp.find_target(player, Player.REACH + (0.9 if held == "spear" else 0.0)) if enemy_t == null and active and not player.dead and not build.active else null
	jumper_t = jumpers.find_target(player, Player.REACH + (0.9 if held == "spear" else 0.0)) if enemy_t == null and camp_t == null and active and not player.dead and not build.active else null
	boss_t = null
	soldier_t = forts.find_target(player, Player.REACH + (0.9 if held == "spear" else 0.0)) if enemy_t == null and camp_t == null and jumper_t == null and active and not player.dead and not build.active else null
	if enemy_t == null and camp_t == null and jumper_t == null and soldier_t == null and active and not player.dead and not build.active:
		for b in bosses:
			boss_t = b.find_target(player, Player.REACH + (0.9 if held == "spear" else 0.0))
			if boss_t != null: break
	target = player.find_target(world) if active and not player.dead and enemy_t == null and jumper_t == null and boss_t == null and soldier_t == null else null
	piece_t = null
	if active and not player.dead and enemy_t == null and not build.active:
		var f := player.forward(); piece_t = build.find_target(player.pos, f.x, f.z, Player.REACH)
		if piece_t != null and target != null:
			var td := Vector2(target.x - player.pos.x, target.z - player.pos.z).length() - float(Res.TYPES[target.type].radius) * float(target.scale)
			if piece_t.dist < td: target = null
			else: piece_t = null
	player.avatar.tool = "hammer" if build.active else ("none" if held == "hands" else held) # (the hammer while building)
	player.avatar.has_bow = tools.has("bow"); player.avatar.aiming = player.aiming # (his quiver; a gun comes up level while he aims)
	player.avatar.jar_update(get_process_delta_time(), tools.has("jar"), jar_count, sky.night)
	_hunt_and_fish(active)
	if active and not player.dead and not build.active and not fish_r.engaged and held != "rod" and held != "bow" and held != "revolver" and held != "rifle" and (input.clicked or input.mouse_down):
		player.avatar.start_swing() # (hold to keep swinging; never with the pole)
	elif active and not player.dead and not build.active and not fish_r.engaged and held == "rod" and input.clicked:
		hud.toast("Stand on the bank facing open water to cast (or pick up another tool with the number keys).")
	# tapping a maple for sap: E at a maple, once a tree a day
	if target != null and target.type == "maple" and e_free and input.hit("KeyE"):
		var tk := "%d,%d" % [roundi(target.x), roundi(target.z)]
		if tapped.get(tk) == sky.day: hud.toast("This maple has given its sap today. Try another, or come back tomorrow.")
		else:
			tapped[tk] = sky.day; inventory.sap = inventory.get("sap", 0) + 1; sound.plop()
			hud.toast("You knock in a spile and hang a bucket: drip, drip... your first sap! Now you can build a sugar shack (B, Works shelf) for a settler to run." if settlers.discover("sap") else "Drip, drip: a bucket of maple sap (+1 sap).")
	var e_pick: bool = target != null and target.type in GatherRules.SOFT and e_free and input.hit("KeyE")
	if e_pick: connected = true
	if connected and enemy_t != null:
		guardian_hit(enemy_t.enemy, edge("enemy")); blow()
	elif connected and boss_t != null:
		blow(); sound.chop(); boss_t.damage(maxi(2, edge("enemy")), boss_t.hooks)
		confetti.burst(boss_t.pos() + Vector3(0, 2.6, 0), [0xa8352a, 0xefe2c4], 10, 0.9)
	elif connected and soldier_t != null:
		blow(); sound.chop(); forts.damage(soldier_t, maxi(2, edge("enemy")), fort_hooks)
		confetti.burst(soldier_t.fig.root.position + Vector3(0, 1.1, 0), [0xa8352a, 0xefe2c4], 8, 0.6)
	elif connected and jumper_t != null:
		blow(); sound.chop(); jumpers.damage(jumper_t, maxi(2, edge("enemy")), jumper_hooks)
		confetti.burst(jumper_t.fig.root.position + Vector3(0, 1.1, 0), [0xa8352a, 0xefe2c4], 8, 0.6)
	elif connected and camp_t != null:
		blow(); sound.chop(); camp.damage(camp_t, maxi(2, edge("enemy")), camp_hooks, raid_hooks)
		confetti.burst(NativeCamps.Camp.wpos(camp_t) + Vector3(0, 1.1, 0), [0xa8352a, 0xefe2c4], 8, 0.6)
	elif connected and piece_t != null and target == null:
		var pc: Dictionary = piece_t.piece; var stone: bool = pc.type in STONE_PIECES
		var pr := build.damage(pc, maxi(1, edge("stonepiece" if stone else "tree")), inventory)
		var at := Vector3(pc.x, pc.y + 1.0, pc.z).lerp(player.pos, 0.4); at.y = player.pos.y + 1.1
		confetti.burst(at, build.chips_for(pc.type), 40 if pr.destroyed else 7, 1.1 if pr.destroyed else 0.6)
		if stone: sound.mine()
		else: sound.knock()
		if pr.destroyed:
			sound.tear()
			var parts := []
			for k in pr.refund: parts.append("%d %s" % [pr.refund[k], k])
			hud.toast("Broke %s (+%s)" % [String(BuildSystem.PIECES[pc.type].name).to_lower(), ", ".join(parts)])
	elif connected and target != null and GatherRules.damage_for(target.type, tools, held) == 0:
		hud.toast(GatherRules.wrong_tool(target.type, tools, owns("pick"))); sound.denied()
	elif connected and target != null:
		var def: Dictionary = Res.TYPES[target.type]
		var r := world.hit(target, player.pos.x, player.pos.z, target.hp if e_pick else edge(target.type))
		if not e_pick and not (target.type in GatherRules.SOFT): blow()
		var at := Vector3(target.x, target.y + 1.0, target.z).lerp(player.pos, 0.35)
		at.y = player.pos.y + 1.1
		confetti.burst(at, def.chips, 7, 0.6)
		if target.type in ["rock", "ore", "quartz", "silver", "geode"]: sound.mine() # (silver and thunder eggs ring like gold quartz: the player)
		elif target.type in ["bush", "grass", "mushroom", "hive", "clay", "corn", "pumpkin", "apples", "stook"]: sound.pick()
		else: sound.chop()
		if r.destroyed:
			if def.get("falls", false): sound.tree_fall()
			var ev := "mine" if target.type in ["rock", "ore", "quartz"] else ("pick" if target.type == "bush" else ("chop" if def.item == "wood" else ""))
			if ev != "": journal.record(ev)
			journal.record("satchel" if def.item == "satchel" else "gather:" + def.item)
			if def.item == "satchel":
				var pickd: Array = GatherRules.SATCHELS[randi() % GatherRules.SATCHELS.size()]
				for k in pickd[0]: inventory[k] = inventory.get(k, 0) + pickd[0][k]
				sound.craft(); hud.toast("Inside the old satchel: %s." % pickd[1])
			else:
				var amount: int = r.amount + (1 if r.item == "wood" and landmarks.blessed else 0) + (1 if r.item == "berries" and tools.has("basket") else 0) + (1 if (sky.day + 1) % 7 == 0 and sky.night > 0.5 else 0)
				inventory[r.item] = inventory.get(r.item, 0) + amount
				var first_find := settlers.discover(r.item)
				if first_find and TREASURE_LORE.has(r.item): hud.toast(TREASURE_LORE[r.item]); sound.craft()
				if first_find and Settlers.WORKS.has(r.item): hud.toast("Your first %s! Now you can build a %s (B, Works shelf) for a settler to run." % [r.item, Settlers.WORKS[r.item][1]])
				hud.toast("+%d %s" % [amount, r.item])
	# the two hint lines: what E does here, above what the mouse does
	var e_prompt := beast_prompt if beast_prompt != "" else (extras_prompt if extras_prompt != "" else yard_prompt)
	if e_prompt == "" and target != null and target.type == "maple": e_prompt = "[E] Tap the maple for sap"
	if e_prompt == "" and target != null and target.type in GatherRules.SOFT:
		e_prompt = "[E] " + GatherRules.E_PICK.get(target.type, "Pick up the %s" % String(Res.TYPES[target.type].name).to_lower())
	e_free = not yard_prompt.begins_with("[E]") and not extras_prompt.begins_with("[E]")
	var lmb := ""
	if target != null:
		var def: Dictionary = Res.TYPES[target.type]
		var needs := ""
		if GatherRules.damage_for(target.type, tools, held) == 0:
			needs = "  (%s)" % ("needs the pickaxe: 3" if GatherRules.tool_for(target.type) == "pick" else "needs the axe: 2")
		lmb = "[LMB] %s %s  %s%s%s" % [GatherRules.verb(target.type), String(def.name).to_lower(), "■".repeat(target.hp), "□".repeat(int(def.hp) - target.hp), needs]
	elif piece_t != null:
		var pc: Dictionary = piece_t.piece; var mx: int = int(BuildSystem.DATA.PIECE_HP.get(pc.type, 3)); var php: int = maxi(0, int(pc.get("hp", mx)))
		lmb = "[LMB] Break %s  %s%s" % [String(BuildSystem.PIECES[pc.type].name).to_lower(), "■".repeat(php), "□".repeat(maxi(0, mx - php))]
	if enemy_t != null:
		var e: Dictionary = enemy_t.enemy; var hp := maxi(0, ceili(e.hp))
		lmb = "[LMB] Fight the %s  %s%s" % [String(e.spec.name).to_lower(), "■".repeat(hp), "□".repeat(maxi(0, int(e.spec.hp) - hp))]
	if boss_t != null: lmb = "[LMB] Fight %s" % boss_t.title()
	if fish_r.engaged: lmb = fish_r.hint
	var lines := PackedStringArray()
	if build.active: return # (in build mode the build bar and its reasons speak instead)
	if e_prompt != "": lines.append(e_prompt)
	if lmb != "": lines.append(lmb)
	hud.set_hint("\n".join(lines))

# ------------------------------------------------------------------ crafting, eating (main.js)
const FOOD := [["johnnycake", 40, 120, "Maple johnnycakes, dripping with syrup"], ["applepie", 55, 110, "A slice of apple pie, the crust just so"], ["honeycake", 60, 120, "Honey cake — sweet as a summer fair"], ["roast", 50, 110, "Venison roast with pan gravy, a hunter's supper"], ["pie", 50, 100, "Pumpkin pie, like Grandma made"], ["applecrisp", 45, 90, "Warm apple crisp with a drizzle of honey"], ["flapjacks", 40, 90, "A stack of flapjacks, hot off the skillet"], ["stew", 40, 60, "Toadstool stew warms you through"], ["biscuits", 35, 60, "Buttermilk biscuits, light as a feather"], ["bread", 35, 60, "A thick slice of farmhouse bread and butter"], ["fishfry", 35, 60, "Pan-fried fish, crisp at the edges"], ["cornbread", 30, 45, "Skillet cornbread, warm and crumbly"], ["apples", 6, 40, "A crisp, tart apple"], ["berries", 8, 90, "A handful of berries"]]
## Stations other systems answer for (the built workbench/campfire/forge, the town's shops, the rail's posts and
## depot): station -> Callable() -> bool.
var station_checks := {}

func _make_crafting() -> void:
	crafting = Crafting.new(inventory, tools)
	crafting.station_near = func(st: String) -> bool:
		if st in ["workbench", "campfire", "forge"]: return build.station_near(st, player.pos)
		return station_checks.has(st) and station_checks[st].call()
	crafting.on_craft = func(r: Dictionary) -> void:
		journal.record("craft:" + String(r.id))
		if r.id == "iron" and settlers.discover("iron"): hud.toast("Your first iron! Now you can build a charcoal pit (B, Works shelf), and with charcoal, smelt steel.")
		if not r.get("fair", false): sound.craft()
		if r.get("request", false): journal.record("request")
		if r.get("station") == "depot": railroad.add_freight() # (a crate on the platform for the next train)
		if r.get("wire", false):
			hud.toast("The keeper reads the telegram twice, counts your goods and pays out $%d. \"That's a load off. Much obliged, neighbor.\"" % r.pay); return
		if r.get("fair", false):
			journal.record("ribbon"); sound.lullaby()
			fair.show_ribbons(inventory.get("ribbon", 0))
			hud.toast("Mrs. Pruitt tastes, pokes and peers, and pins a blue ribbon on your entry. (%s)" % r.name); return
		if r.get("sharpen", false):
			for k in wear: wear[k] = 100.0
			dull_warned = false
		var nm := String(r.name).to_lower()
		var msg: String
		if r.get("request", false): msg = "The tinker beams and pays you well for it. \"Much obliged, neighbor!\""
		elif r.get("sharpen", false): msg = "Skrrrr... the smith works every edge on his wheel. Sharp as new."
		elif r.get("station") == "smithy": msg = "The smith hands over a %s, still warm from the quench." % nm
		elif r.get("station") == "store": msg = "Bought: " + nm
		elif r.has("gives"): msg = "Traded with the tinker: " + nm
		else: msg = "Crafted " + nm
		hud.toast(msg)
	panel = CraftingPanel.new(hud, crafting)
	panel.on_close = func() -> void: _close_craft()
	hud.register_panel(panel.card) # (one centre panel at a time)

func _open_craft() -> void:
	panel.set_open(true); input.unlock()
func _close_craft() -> void:
	panel.set_open(false); input.lock()

func _crafting_keys() -> void:
	if input.hit("KeyC"):
		if panel.open: _close_craft()
		else: _open_craft()
	elif panel.open and input.hit("Escape"): _close_craft()
	if panel.open: return
	if (force_active or input.locked) and input.hit("KeyF"): _eat()
	if (force_active or input.locked) and input.hit("KeyK"): _snap()

## K: a postcard of the view (scripts/ui/postcard.gd), saved to the Downloads folder.
var _snapping := false
var postcard_dir := "" ## (tests: where postcards go)
var last_postcard := ""
func _snap() -> void:
	if _snapping: return
	_snapping = true
	last_postcard = await Postcard.snap(self, postcard_dir)
	_snapping = false
	if last_postcard != "": hud.toast("Snap! A postcard of the farm is in your Downloads folder."); sound.click()

## F: eat the best thing you're carrying.
func _eat() -> void:
	for f in FOOD:
		if inventory.get(f[0], 0) > 0:
			inventory[f[0]] -= 1
			player.health = minf(player.max_health, player.health + f[1])
			player.stamina_boost = maxf(player.stamina_boost, f[2])
			player.stamina = 300.0 # (clamped to whatever the belly allows)
			var fill := roundi(f[1] * 0.8)
			player.fullness = minf(100.0, player.fullness + fill)
			hunger_warned = 0 if player.fullness >= 30.0 else hunger_warned
			hud.toast("%s (+%d health, +%d fullness)" % [f[3], f[1], fill]); sound.eat()
			return
	hud.toast("Nothing to eat")

# ------------------------------------------------------------------ build mode (main.js)
func _building(dt: float, active: bool) -> void:
	if active and input.hit("KeyB"):
		if not tools.has("hammer"): hud.toast("Craft a hammer first (C)")
		else: build.active = not build.active
	build.snow = weather.snow
	hud.set_crosshair(build.active)
	if build.active and active:
		var groups: Array = BuildSystem.DATA.PIECE_GROUPS
		for i in groups.size():
			if input.hit("Digit%d" % (i + 1)): build.selected = BuildSystem.ORDER.find(groups[i][1][0]); build.roof_manual = false
		if input.hit("KeyQ"): build.selected = (build.selected + BuildSystem.ORDER.size() - 1) % BuildSystem.ORDER.size(); build.roof_manual = false
		if input.hit("KeyE"): build.selected = (build.selected + 1) % BuildSystem.ORDER.size(); build.roof_manual = false
		if input.hit("KeyR"):
			if build.type == "roof" and build.preview != null: build.rot = build.preview.rot
			build.rot = (build.rot + 1) % 4
			if build.type == "roof": build.roof_manual = true
		place_cd -= dt
		if input.clicked or (input.mouse_down and place_cd <= 0.0):
			place_cd = 0.3
			var ok: bool = build.preview != null and build.preview.valid
			var placed_type: String = build.type
			var msg := build.place(inventory)
			if ok: journal.record("build:" + placed_type)
			if msg != "" and (input.clicked or ok): hud.toast(msg)
			if ok: player.avatar.start_swing(); sound.place()
			elif msg != "" and input.clicked: sound.denied()
		if input.right_clicked or (input.right_down and place_cd <= 0.0):
			place_cd = 0.3
			var msg := build.remove_hovered(inventory)
			if msg != "": hud.toast(msg); sound.tear()
	build.update(dt, inventory, player.pos, sky.night)
	var built := {}
	if build.active: for q in build.pieces: built[q.type] = built.get(q.type, 0) + 1
	hud.set_buildbar(build.active, build.selected, BuildSystem.ORDER, BuildSystem.DATA.PIECE_GROUPS, BuildSystem.PIECES, inventory, built)
	if build.active and build.preview != null and not build.preview.valid: hud.set_hint(build.preview.reason)

# ------------------------------------------------------------------ the yard's E actions (main.js)
const PILE_MAX := 24
const GIANT_STAGES := 5
var yard_prompt := ""
var sleep_timer := 0.0
var cider_t := 0.0

func _yard(dt: float, active: bool) -> void:
	yard_prompt = ""
	build.tend_skeps(sky.day, sky.time)
	build.tend_producers(sky.day, sky.time)
	build.tend_feeders(sky.day, sky.time)
	build.tend_trees(sky.day, sky.time, func(_t: Dictionary) -> void: journal.record("growtree"); hud.toast("Your apple sapling has grown into a fine young apple tree!"))
	if weather.snow < 0.15:
		for q in build.pieces:
			if q.type == "snowman":
				build.melt_snowmen(); hud.toast("The thaw comes, and your snowman slumps quietly into the grass."); break
	var can := active and not build.active and not player.dead
	var e := input.hit("KeyE")
	var sleepy := sky.time > 0.8 or sky.time < 0.24
	var evening := sky.time > 0.78 or sky.time < 0.22
	var bed = build.bed_near(player.pos) if can else null
	var ex = build.extra_near(player.pos) if can else null # (a Homestead piece: coop, hay barn, shaft, well, lean-to)
	if bed == null and ex != null and BuildSystem.EXTRA[ex.type].get("use") == "sleep": bed = ex
	if ex != null and e and beast_prompt == "":
		var xd: Dictionary = BuildSystem.EXTRA[ex.type]
		if xd.has("makes"):
			if int(ex.stock if ex.stock != null else 0) > 0:
				var got := []
				for k in xd.makes: var n: int = int(xd.makes[k]) * int(ex.stock); inventory[k] = inventory.get(k, 0) + n; got.append("%d %s" % [n, k])
				ex.stock = 0; sound.pick(); hud.toast("%s: %s." % [xd.name, ", ".join(got)]); e = false
			else: hud.toast("Nothing yet at the %s. Come back in the morning." % String(xd.name).to_lower()); e = false
		elif xd.get("use") == "drink":
			player.stamina = player.max_stamina; player.health = minf(player.max_health, player.health + 10.0); sound.plop()
			hud.toast("A cold dipper from the well. Fresh as morning."); e = false
	var at_fire: bool = can and bed == null and build.fire_distance(player.pos) < 3.0
	# tall tales: sit by a campfire after dark; an hour slips by and the fire mends you
	if story_kind == "tale" and (e or not at_fire): story_kind = ""; hud.story_hide(); e = false
	elif at_fire and e and beast_prompt == "":
		if not evening: hud.toast("Tall tales keep till after dark. Come back when the stars are out.")
		else:
			var tl := tales.tell()
			hud.story_show(tl.title, [tl.text], [], "%d of %d tall tales heard · E to stir the fire and close" % [tales.heard.size(), Tales.TALES.size()]); story_kind = "tale"
			sky.time = fmod(sky.time + 1.0 / 24.0, 1.0); player.health = minf(player.max_health, player.health + 20.0)
			sound.lullaby()
			if tl.new: journal.record("tale")
		e = false
	# a fallen star: take it home (and a little something with it)
	var at_star: bool = can and falling_stars.near(player.pos)
	if at_star and e:
		var g: Array = FallingStars.STAR_GIFTS[randi() % FallingStars.STAR_GIFTS.size()]
		for k in g[0]: inventory[k] = inventory.get(k, 0) + g[0][k]
		confetti.burst(falling_stars.at + Vector3(0, 1, 0), [0xf6e8b0, 0xe8c870, 0xfffaf0], 22, 0.9)
		falling_stars.take(); journal.record("star"); sound.lullaby()
		hud.toast("You pick up the fallen star. It's warm, and it leaves you %s." % g[1])
	# your own apple tree: shake it
	var my_tree = build.apple_tree_near(player.pos) if can else null
	if my_tree != null and e:
		if my_tree.stock > 0:
			var n: int = my_tree.stock; my_tree.stock = 0; inventory.apples += n; sound.pick()
			confetti.burst(Vector3(my_tree.x, my_tree.y + 2.5, my_tree.z), [0xc4362f, 0xe0a03a, 0x7d9a4e], 18, 0.8)
			hud.toast("You give your apple tree a shake: %d apples come thumping down." % n)
		else: hud.toast("Not a ripe apple left. They come on again in the morning.")
	# the bee skep
	var skep = build.skep_near(player.pos) if can else null
	if skep != null and e:
		if skep.stock > 0:
			var n: int = skep.stock; skep.stock = 0; inventory.honey += n
			journal.record("skep"); sound.pick(); hud.toast("Smoke, lift, and %s of golden honey. (+%d honey)" % ["a comb" if n == 1 else "%d combs" % n, n])
		else: hud.toast("The bees are still at work. Come back in the morning.")
	# the cider press: four apples for a mug that keeps your legs fresh two minutes
	var press = build.press_near(player.pos) if can else null
	if press != null and e:
		if inventory.apples >= 4:
			inventory.apples -= 4; journal.record("cider"); sound.pick(); cider_t = 120.0; player.stamina = player.max_stamina
			confetti.burst(Vector3(press.x, press.y + 1.2, press.z), [0xd9a441, 0xc4362f, 0xe8c070], 16, 0.7)
			hud.toast("You crank the screw down and sweet cider runs into the crock. A warm mugful, and your legs feel fresh as morning.")
		else: hud.toast("The press wants 4 apples for a mugful of cider.")
	if cider_t > 0.0:
		cider_t -= dt; player.stamina = minf(player.max_stamina, player.stamina + dt * 30.0)
		if cider_t <= 0.0: hud.toast("The cider warmth wears off.")
	# the giant-pumpkin patch: tend it once a day and the prize pumpkin swells; at full size, cut it for the fair
	var gp = build.patch_near(player.pos) if can else null
	if gp != null and e:
		if gp.stage == null: gp.stage = 0
		if gp.stage >= GIANT_STAGES:
			gp.stage = 0; gp.tendDay = sky.day; inventory.giantpumpkin = inventory.get("giantpumpkin", 0) + 1
			journal.record("giant"); sound.chop(); hud.toast("You cut the stem and roll your prize pumpkin onto the cart. Mrs. Pruitt will want to see this at the fair.")
		elif gp.tendDay == sky.day: hud.toast("Tended already today. It grows overnight, they say, while nobody is looking.")
		else:
			gp.tendDay = sky.day; gp.stage += 1; sound.pick(); journal.record("tend")
			hud.toast("Water, a dollop of manure, a kind word: your pumpkin is a whopper now! Cut it for the fair." if gp.stage >= GIANT_STAGES else "You water it, pinch back the vine and say something encouraging. It swells a size bigger (%d/%d)." % [gp.stage, GIANT_STAGES])
	# the woodpile: E stacks your firewood (four at a go); with empty arms, E takes four back
	var pile = build.woodpile_near(player.pos) if can else null
	if pile != null and e:
		if pile.stock == null: pile.stock = 0
		if inventory.wood > 0 and pile.stock < PILE_MAX:
			var n: int = mini(4, mini(inventory.wood, PILE_MAX - pile.stock)); inventory.wood -= n; pile.stock += n
			sound.chop(); journal.record("stack", n)
			if pile.stock >= 12 and pile.stock - n < 12: hud.toast("A good stack of firewood. With that near the house, the stove will keep you warm all night.")
		elif inventory.wood == 0 and pile.stock > 0:
			var n: int = mini(4, pile.stock); pile.stock -= n; inventory.wood += n
		else: hud.toast("The woodpile is stacked to the top.")
	# the bird feeder
	var feeder = build.feeder_near(player.pos) if can else null
	if feeder != null and e:
		var food = ["corn", 1, "a cob of corn"] if inventory.corn >= 1 else (["berries", 2, "two handfuls of berries"] if inventory.berries >= 2 else null)
		if feeder.stock == null: feeder.stock = 0
		if food != null and feeder.stock < 3:
			inventory[food[0]] -= food[1]; feeder.stock = mini(3, feeder.stock + 2)
			if feeder.day == null: feeder.day = sky.day
			journal.record("feeder"); sound.pick(); hud.toast("You fill the feeder with %s. Step back and wait: the birds will come." % food[2])
		else: hud.toast("The feeder is full to the brim." if food != null else "The feeder takes a cob of corn or two handfuls of berries.")
	# the grindstone at a workbench or forge
	var dull := false
	for k in wear: dull = dull or wear[k] < 70.0
	var grind: bool = can and not at_fire and dull and (build.station_near("workbench", player.pos) or build.station_near("forge", player.pos))
	if grind and e and bed == null and skep == null and pile == null and feeder == null and press == null:
		if inventory.stone >= 1:
			inventory.stone -= 1
			for k in wear: wear[k] = 100.0
			dull_warned = false
			sound.mine(); hud.toast("Skrrrr... you work every edge on the grindstone till it shines. Sharp as new.")
		else: hud.toast("The grindstone wants a stone to dress it with.")
	# the bed: sleep through to morning
	if bed != null and e:
		if not sleepy: hud.toast("Not sleepy yet; the bed will keep till nightfall.")
		elif sleep_timer == 0.0: sleep_timer = 2.6; hud.sleep_show = true; sound.lullaby()
	if sleep_timer > 0.0:
		sleep_timer -= dt
		if sleep_timer < 1.3 and hud.sleep_show:
			var ended_day := sky.day if sky.time > 0.5 else sky.day - 1
			if sky.time > 0.5: sky.day += 1
			journal.record("sleep"); _show_almanac(ended_day); save_all.call_deferred()
			sky.time = 0.27
			player.health = player.max_health; player.stamina = player.max_stamina
			hud.sleep_show = false
			player.fullness = maxf(0.0, player.fullness - 15.0) # (you wake up hungry)
			var inn := hotel_night; hotel_night = false
			if inn: # a feather bed at the Grand Hotel: you wake fed and warm, a spring in your step
				player.fullness = maxf(player.fullness, 80.0); player.stamina_boost = maxf(player.stamina_boost, 200.0)
				hud.toast("Day %d: you wake in a feather bed at the Grand Hotel, sun through lace curtains. Ham, eggs and hot coffee in the dining room, and out into the street fed and rested." % sky.day)
			var stove = null
			for q in build.pieces:
				if q.type == "woodpile" and (q.stock if q.stock != null else 0) >= 2 and Vector2(q.x - player.pos.x, q.z - player.pos.z).length() < 30.0: stove = q; break
			if inn: pass
			elif stove != null:
				stove.stock -= 2; player.stamina_boost = maxf(player.stamina_boost, 300.0); player.stamina = 300.0; journal.record("warmnight")
				hud.toast("Day %d: the stove burned two logs from the woodpile all night. You wake warm as toast, ready for anything." % sky.day)
			else: hud.toast("Day %d: the rooster crows and you wake well rested." % sky.day)
		if sleep_timer <= 0.0: sleep_timer = 0.0
	# the prompts, in the web's order
	if at_star: yard_prompt = "[E] Pick up the fallen star"
	elif my_tree != null: yard_prompt = ("[E] Shake your apple tree (%d ripe)" % my_tree.stock) if my_tree.stock else "Your apple tree: fresh apples by morning"
	elif bed != null: yard_prompt = "[E] Sleep till morning" if sleepy else "A quilted bed: sleep here once night falls"
	elif at_fire: yard_prompt = "[E] Sit by the fire and tell a tall tale" if evening else "A good fire. Tall tales are for after dark."
	elif skep != null: yard_prompt = ("[E] Take %d honey from the bee skep" % skep.stock) if skep.stock else "The bees are busy filling the comb"
	elif ex != null:
		var xd: Dictionary = BuildSystem.EXTRA[ex.type]
		if xd.has("makes"): yard_prompt = ("[E] %s" % xd.verb) if int(ex.stock if ex.stock != null else 0) > 0 else "%s: more in the morning" % xd.name
		elif xd.get("use") == "drink": yard_prompt = "[E] Draw a drink from the well"
		elif xd.get("use") == "sleep": yard_prompt = "[E] Sleep in the lean-to till morning" if (sky.time > 0.8 or sky.time < 0.24) else "A lean-to: shelter for the night"
	elif gp != null: yard_prompt = "[E] Cut your prize giant pumpkin" if (gp.stage if gp.stage != null else 0) >= GIANT_STAGES else ("Your giant pumpkin (%d/%d): tended today" % [gp.stage if gp.stage != null else 0, GIANT_STAGES] if gp.tendDay == sky.day else "[E] Tend the giant pumpkin (%d/%d)" % [gp.stage if gp.stage != null else 0, GIANT_STAGES])
	elif pile != null:
		var st: int = pile.stock if pile.stock != null else 0
		yard_prompt = "[E] Stack firewood on the woodpile (%d/%d)" % [st, PILE_MAX] if inventory.wood > 0 and st < PILE_MAX else ("[E] Take 4 logs from the woodpile (%d stacked)" % st if st > 0 and inventory.wood == 0 else "The woodpile (%d/%d)" % [st, PILE_MAX])
	elif feeder != null: yard_prompt = ("[E] Top up the bird feeder (%d day%s of seed left)" % [feeder.stock, "s" if feeder.stock > 1 else ""]) if feeder.stock else "[E] Fill the bird feeder (a cob of corn or 2 handfuls of berries)"
	elif press != null: yard_prompt = "[E] Press 4 apples into a mug of warm cider" if inventory.apples >= 4 else "The cider press: bring 4 apples"
	elif grind: yard_prompt = "[E] Sharpen your tools on the grindstone (1 stone)"

# ------------------------------------------------------------------ the homestead extras' E actions (main.js)
var extras_prompt := ""
func _extras(dt: float, active: bool) -> void:
	extras_prompt = ""
	var can := active and not build.active and not player.dead
	var e := input.hit("KeyE")
	extras.coop_update(sky.day, sky.time, inventory)
	extras.laundry_update(dt, player.pos, weather.rain)
	extras.bunk_supper(sky.time > 0.76 and sky.time < 0.88)
	extras.bunk_update(sky.night)
	extras.piles_update(build.pieces, player.pos)
	extras.pumpkins_update(dt, build.pieces, player.pos)
	var omen := extras.vane_update(dt, weather)
	var vp := extras.node("vane", "group").global_position
	if omen != "" and Vector2(player.pos.x - vp.x, player.pos.z - vp.z).length() < 60.0:
		hud.toast("The rooster on the barn has swung round to the east, and the air's gone sharp. Snow's coming." if omen == "snow" else ("The rooster on the barn has swung hard to the east and the air's gone close and heavy. A thunderstorm's brewing." if weather.next_storm else "The rooster on the barn has swung round to the east. Wind from the east: rain's on the way."))
	# the rocker: sit and let the day drift by (E again, a step, or letting go of the game gets you up)
	var move_keys := input.down("KeyW") or input.down("KeyA") or input.down("KeyS") or input.down("KeyD")
	if extras.sitting and (e or move_keys or not active):
		extras.sitting = false; hud.toast("You stretch, and get up from the rocker."); e = false
	elif not extras.sitting and can and extras.porch_near(player.pos) and e:
		extras.sitting = true; hud.toast("You settle into the rocker and watch the day drift by."); e = false
	if extras.sitting: sky.time += (dt * (FarmExtras.WARP - 1.0)) / DaySky.DAY_LENGTH
	player.avatar.seated = extras.sitting
	# the root cellar: dig it at its stake, then food every morning
	var at_cellar: bool = can and extras.cellar_near(player.pos) and (not extras.cellar_built or extras.cellar_stocked(sky.day))
	if at_cellar and e:
		if not extras.cellar_built:
			if inventory.dollars >= FarmExtras.CELLAR_COST:
				inventory.dollars -= FarmExtras.CELLAR_COST; extras.build_cellar(); sound.craft()
				confetti.burst(extras.cellar_pos + Vector3(0, 1, 0), [0x8a9a5a, 0x8a5a34, 0xefe3c4], 14, 0.7)
				hud.toast("Root cellar dug! Food every morning.")
			else: hud.toast("A root cellar costs $%d. You have $%d." % [FarmExtras.CELLAR_COST, inventory.dollars])
		else:
			extras.cellar_day = sky.day; inventory.apples += 2; inventory.bread += 1
			sound.pick(); hud.toast("+2 apples, +1 bread from the cellar")
	# the bunkhouse: buy it at its stake in the old camp ground west of the yard
	var at_bunk: bool = can and not at_cellar and not extras.bunk_built and extras.bunk_near(player.pos)
	if at_bunk and e:
		if inventory.dollars >= FarmExtras.BUNK_COST:
			inventory.dollars -= FarmExtras.BUNK_COST; extras.build_bunk(); sound.craft()
			confetti.burst(extras.bunk_pos + Vector3(0, 1.5, 0), [0x8a6038, 0xd8c8a0, 0xefe3c4], 18, 0.8)
			hud.toast("Bunkhouse built! Your hands sleep on the farm now: a quarter more work from every one.")
		else: hud.toast("A bunkhouse costs $%d. You have $%d." % [FarmExtras.BUNK_COST, inventory.dollars])
	# the nesting box
	var at_coop: bool = can and extras.coop_near(player.pos)
	if at_coop and e:
		var n := extras.coop_collect()
		if n > 0:
			inventory.egg += n; journal.record("gather:egg", n); sound.pick()
			hud.toast("One warm egg from the straw." if n == 1 else "%s warm eggs from the nesting box!" % ["", "", "Two", "Three", "Four", "Five", "Six"][mini(n, 6)])
		else: hud.toast("The hens haven't laid since this morning. Check back tomorrow.")
	if extras.sitting: extras_prompt = "[E] Get up from the rocker (time is drifting by)"
	elif can and extras.porch_near(player.pos): extras_prompt = "[E] Sit in the rocking chair and watch the day go by"
	elif at_coop: extras_prompt = ("[E] Gather %d egg%s from the nesting box" % [extras.eggs, "s" if extras.eggs > 1 else ""]) if extras.eggs else "The nesting box is empty till morning"
	elif at_cellar: extras_prompt = "[E] Take food from the root cellar" if extras.cellar_built else "[E] Dig a root cellar: $%d (you have $%d)" % [FarmExtras.CELLAR_COST, inventory.dollars]
	elif at_bunk: extras_prompt = "[E] Build a bunkhouse for your hands: $%d (you have $%d)" % [FarmExtras.BUNK_COST, inventory.dollars]

# ------------------------------------------------------------------ the critters (main.js)
const DOG_FINDS := [[{"iron": 1}, "an old horseshoe, rusty but good iron"], [{"rope": 1}, "a coil of somebody's lost rope"], [{"honey": 1}, "a jar of honey, lid still on. Nobody asks where from"], [{"mushrooms": 2}, "a mouthful of toadstools, a little chewed"], [{"pelt": 1}, "an old fur cap. It might make a pelt"], [{}, "a very fine stick. He is extremely proud of it"]]
const CAT_PURRS := ["Marmalade purrs like a little engine.", "She butts her head against your hand and purrs.", "A slow blink. From a cat, that means a great deal."]
var fetches := 0
var track_told := -1
func make_horse(x: float, z: float) -> void:
	horse = Horse.new(x, z); add_child(horse)

## Biscuit: X beside her to get up, X again to get down; from anywhere else X whistles her over (main.js).
func _horse(dt: float, active: bool) -> void:
	if horse == null: return
	if active and not player.dead and not build.active and input.hit("KeyX"):
		var d := Vector2(player.pos.x - horse.pos.x, player.pos.z - horse.pos.z).length()
		if riding:
			riding = false; player.riding = false; player.avatar.riding = false; sound.place()
			horse.pos = Vector3(player.pos.x + cos(player.facing) * 1.2, player.pos.y, player.pos.z - sin(player.facing) * 1.2)
		elif d < 2.6:
			riding = true; player.riding = true; player.avatar.riding = true; horse.called = false; sound.place()
			player.pos.x = horse.pos.x; player.pos.z = horse.pos.z
		else:
			horse.called = true; sound.horse_call()
			if d > 140.0: # (from out of earshot she comes up over the rise)
				for k in 12:
					var a := randf() * TAU; var x := player.pos.x + cos(a) * 30.0; var z := player.pos.z + sin(a) * 30.0
					if not Terrain.impassable(x, z) and not Terrain.is_water(x, z): horse.pos = Vector3(x, 0, z); break
	horse.update(dt, player, rig.camera, riding, homestead.barn_box, sky.time)
	if riding and not horse.seat_rider(player.avatar): player.avatar.root.position.y += 1.05 # (after her step, so he sits on this frame's back)
	# oats from the feed & grain: the first ride each day she gets a feed, and runs a quarter faster all day
	if riding and inventory.get("oatsDay", -1) != sky.day and inventory.get("oats", 0) > 0:
		inventory.oats -= 1; inventory.oatsDay = sky.day
		hud.toast("Biscuit noses the feed bag and eats her oats. She tosses her head and is raring to go: a quarter faster all day.")
	player.oats_fed = inventory.get("oatsDay", -1) == sky.day
	if beast_prompt == "" and not riding and Vector2(player.pos.x - horse.pos.x, player.pos.z - horse.pos.z).length() < 2.6: beast_prompt = "[X] Get up on Biscuit"
## The kite (G), snow footprints, leaf piles, the fairy ring, sunbeams through the trees, the will-o'-the-wisp and
## hoof dust (main.js).
func _paper_weather(dt: float) -> void:
	var act := force_active or input.locked
	if act and input.hit("KeyG"):
		if not tools.has("kite"): hud.toast("Make a paper kite at a workbench first (C).")
		elif not kite.flying and weather.rain > 0.3: hud.toast("Too wet for kite-flying. Wait for the shower to pass.")
		else:
			kite.toggle(); sound.tear()
			if kite.flying: journal.record("kite"); hud.toast("Up she goes! The kite climbs away on the west wind.")
	if kite.update(dt, player, rig.camera, weather.rain) == "rain": hud.toast("The rain brings your kite fluttering down. You reel it in.")
	if leaf_piles.update(dt, [{"pos": player.pos, "speed": Vector2(player.vel.x, player.vel.z).length()}, {"pos": dog.pos, "speed": dog.speed}]) >= 0:
		journal.record("leaves"); leaf_kicks += 1; sound.rustle()
		if leaf_kicks == 1: hud.toast("Whoosh! Leaves everywhere. The breeze will sweep them back into a heap by and by.")
	footprints.dog_track(weather.snow, dog.pos); footprints.update(dt, weather.snow, player.pos, riding)
	# fairy rings: rain in the night brings one up by morning
	if weather.rain > 0.3 and weather.kind == "rain" and (sky.time > 0.8 or sky.time < 0.25): ring_rain = true
	if ring_rain and sky.time >= 0.25 and sky.time < 0.5 and fairy_ring.day != sky.day:
		ring_rain = false
		var dir := fairy_ring.sprout(sky.day, player.pos)
		if dir != "": hud.toast("After the wet night, a ring of toadstools has come up in a meadow off to the %s. Old folks say it's lucky to find one." % dir)
	fairy_ring.update(dt, sky)
	wisp.update(dt, world, player, rig.camera, sky.night)
	shafts.update(dt, rig.camera, player.pos, sky, weather.rain, world, 1.0 if Terrain.region_at(player.pos.x, player.pos.z) == "forest" else 0.4)
	Terrain.land_at(player.pos.x, player.pos.z)
	hoof_dust.update(dt, player.pos, player.vel, riding and not player.swimming and weather.rain < 0.2 and Terrain.L_w.get("fen", 0.0) < 0.5, rig.camera)

## NEXT: one short line saying the most useful thing to do now. Hunger first, then the gold road: workbench ->
## pickaxe -> iron ore -> forge -> iron -> iron pickaxe -> gold quartz, with the assayer between; then today's doings.
func _update_next(dt: float) -> void:
	next_t -= dt
	if next_t > 0.0: return
	next_t = 0.5
	var I := inventory
	var has := func(t: String) -> bool: return build.pieces.any(func(q): return q.type == t)
	var iron := tools.has("ironpick") or tools.has("steelpick")
	var say := ""; var urgent := false; var mend = null
	var affordable: Array = town.projects().filter(func(q): return not town.tiers.get(q.id, 0) and I.get("dollars", 0) >= q.cost)
	affordable.sort_custom(func(a, b): return a.cost < b.cost)
	if affordable.size(): mend = affordable[0]
	if player.fullness < 25.0:
		urgent = true
		say = "Hungry! Press F to eat" if FOODS.any(func(k): return I.get(k, 0) > 0) else ("Hungry! Get food from the root cellar" if extras.cellar_stocked(sky.day) else "Hungry! Pick berries or apples")
	elif glint != null: say = "Pick up the gold glint by the cabin (E)"
	elif _prize_held() != null: say = "Take %s to the assay office" % _prize_held().spec.prize
	elif (I.get("gold", 0) > 0 or I.get("silver", 0) > 0) and not town.near_assay(player.pos, 20.0): say = "Sell your gold at the assay office" if I.get("gold", 0) > 0 else "Sell your silver at the assay office"
	elif not extras.cellar_built and I.get("dollars", 0) >= FarmExtras.CELLAR_COST: say = "Buy a root cellar by the house ($%d)" % FarmExtras.CELLAR_COST
	elif extras.cellar_built and not extras.bunk_built and settlers.hired.size() and I.get("dollars", 0) >= FarmExtras.BUNK_COST: say = "Build a bunkhouse for your hands ($%d)" % FarmExtras.BUNK_COST
	elif mend != null: say = "Mend the %s in town ($%d)" % [mend.name, mend.cost]
	elif _boss_holding() != null: var hb: Boss = _boss_holding(); say = ("Beat %s for %s (see M)" % [hb.title(), hb.spec.prize]) if not hb.beaten else ("Pick up %s where %s fell" % [hb.spec.prize, hb.title()])
	elif not owns("pick") and not has.call("workbench"): say = "Build a workbench (B)"
	elif not owns("pick"): say = "Make a pickaxe at the workbench (C)"
	elif not iron and I.get("iron", 0) >= 3: say = "Make an iron pickaxe at the forge (C)" if has.call("forge") else "Build a forge (B): 10 stone, 6 clay"
	elif not iron and I.get("ore", 0) >= 2: say = "Smelt iron at the forge (C)" if has.call("forge") else "Build a forge (B): 10 stone, 6 clay"
	elif not iron: say = "Find iron ore (rusty grey rocks), for an iron pickaxe"
	elif sky.day % 7 == 0 and town.tiers.get("church", 0) and sky.time < 0.45: say = "Sunday meeting at the church this morning"
	elif Fair.is_fair_day(sky.day) and sky.time < 0.8: say = "County Fair today, by the farm lane: enter your best"
	elif sky.day % 7 == 6 and town.street_done(-1) and town.street_done(0) and town.street_done(1) and sky.time > 0.6 and sky.time < 0.9: say = "Fireworks over Cold Glitter Creek tonight, after supper"
	elif BarnDance.is_dance_night(sky.day) and sky.time > 0.6 and sky.time < 0.95: say = "Barn dance tonight: follow the fiddle"
	else: say = "Mine gold quartz in the Redrock Breaks or Bluepine Highlands"
	hud.set_next(say, urgent)

## The way home: once you're well out (90 m), a chip by the clock with an arrow that turns with your view; carrying
## gold, it points to the assayer instead (once you're out of sight of his door).
func _update_homeward() -> void:
	var ad: Vector3 = town.doors.assay
	var to_assay: bool = (inventory.get("gold", 0) > 0 or _prize_held() != null) and Vector2(ad.x - player.pos.x, ad.z - player.pos.z).length() > 20.0
	var goal: Vector3 = ad if to_assay else homestead.spawn
	var h := Vector2(goal.x - player.pos.x, goal.z - player.pos.z); var d := h.length()
	var show := (to_assay or d > 90.0) and not player.dead
	if not show: hud.set_homeward(false); return
	var cam := rig.camera; var a := cam.unproject_position(player.pos); var b := cam.unproject_position(player.pos + Vector3(h.x / d, 0, h.y / d) * 4.0)
	var g: int = inventory.get("gold", 0)
	var text := "%s, %d paces" % [(("Assay office (%d pinch%s)" % [g, "es" if g > 1 else ""]) if g > 0 else "Assay office (%s)" % _prize_held().spec.prize.trim_prefix("the ")) if to_assay else "Home", roundi(d * 1.3 / 10.0) * 10]
	hud.set_homeward(true, "gold" if to_assay else "home", rad_to_deg(atan2(b.x - a.x, -(b.y - a.y))), text)

## The soundscape each frame (main.js): how much water lies round you, how near a fire is, rain (muffled under a
## roof), the land you're in; and the land's name the first time you cross into it. The dawn bell, Sunday's hymn,
## the saloon piano after dark and the rooster at sunup.
func _ambience(dt: float) -> void:
	water_t -= dt
	if water_t <= 0.0:
		water_t = 0.5; var wet := 0
		for k in 8: if Terrain.is_water(player.pos.x + cos(k * TAU / 8.0) * 12.0, player.pos.z + sin(k * TAU / 8.0) * 12.0): wet += 1
		water_near = wet / 8.0
	# crossing into a land: its name, and the first time, what the old folks say of it
	Terrain.land_at(player.pos.x, player.pos.z)
	var id: String = Terrain.L_id if Terrain.L_wild > 0.6 else ("home" if Terrain.L_wild < 0.35 else land_here)
	if id != land_here:
		land_here = id
		if id == "home": hud.toast("Back in the home county. The fields and fences look like old friends.")
		elif not lands_found.has(id):
			lands_found[id] = true; journal.record("land"); hud.toast("You've come into %s. %s" % [Terrain.LANDS[id].name, Terrain.LANDS[id].lore]); sound.craft()
		else: hud.toast("Back in %s." % Terrain.LANDS[id].name)
	var sheltered: bool = weather.rain > 0.2 and (homestead.covers(player.pos.x, player.pos.z) or build.roof_at(player.pos.x, player.pos.z))
	sound.update(dt, sky.night, maxf(0.0, 1.0 - build.fire_distance(player.pos) / 10.0), water_near, weather.rain if weather.kind == "rain" else 0.0, sheltered, sky.time, land_here)
	# the dawn bell: three slow tolls when the sun comes up, heard across the county
	if town.tiers.get("church", 0) and sky.time > 0.25 and sky.time < 0.3 and bell_day != sky.day: bell_day = sky.day; bell_t = 0.0
	if bell_t >= 0.0:
		var before := bell_t; bell_t += dt
		for k in [0.0, 2.2, 4.4]:
			if before < k and bell_t >= k: sound.bell(0.12 * maxf(0.25, 1.0 - Vector2(player.pos.x - town.church_at.x, player.pos.z - town.church_at.z).length() / 200.0))
		if bell_t > 5.0: bell_t = -1.0
	# the meeting's hymn, once the families stand in the churchyard, heard within about 40 m of the church door
	var gathered: bool = town.sunday and town.tiers.get("church", 0) and town.civilians.any(func(c): return c.atMeeting and (c.fig.root.position as Vector3).distance_to(c.goal) < 0.6)
	if gathered:
		var vol := maxf(0.0, 1.0 - Vector2(player.pos.x - town.doors.church.x, player.pos.z - town.doors.church.z).length() / 40.0)
		hymn_t -= dt
		if hymn_t <= 0.0:
			var h: Array = HYMN[hymn_i % HYMN.size()]; hymn_i += 1
			if h[0]: sound.hymn(int(h[0]), int(h[1]), int(h[2]) if h.size() > 2 else 0, vol)
			hymn_t = h[1] * 0.62
	else: hymn_i = 0; hymn_t = 0.0
	# a honky-tonk piano drifting out of the mended saloon after dark, louder as you come up the street
	if town.tiers.get("saloon", 0) and sky.night > 0.45:
		var sd := Vector2(player.pos.x - town.doors.saloon.x, player.pos.z - town.doors.saloon.z).length()
		piano_t -= dt
		if sd < 30.0 and piano_t <= 0.0:
			piano_t = 0.18 + randf() * 0.22
			var m: int = [60, 62, 64, 67, 69, 72, 74, 76][randi() % 8]; var v := 0.07 * (1.0 - sd / 30.0)
			sound.piano(m, v)
			if randf() < 0.3: sound.piano(m - 12, v * 0.8) # (the left hand, an octave down)

# ------------------------------------------------------------------ loading ahead (as the web's loadFolk/loadAnimals/loadProps)
## Every model the county can bring on (folk, animals, props, the landmarks, the train) is asked for on background
## threads at startup and kept, so a guardian's site, a landmark or a herd coming into range never waits on a disk
## read and import (~100 ms each the first time otherwise).
var _models := []
var _loading: Array = [] ## model loads in flight on worker threads (quitting must wait for them: see _finish_loads)
var _quitting := false
## Let the background model loads finish before the game goes: quitting with a GLB half-loaded on a worker thread
## crashed the exported game (a segfault at exit, in its first seconds). Blocks briefly; then no more are started.
func _finish_loads() -> void:
	_quitting = true
	for q in _loading.duplicate(): ResourceLoader.load_threaded_get(q)
	_loading.clear()
func _preload_models() -> void:
	var paths := []
	for d in ["res://assets/models/folk/", "res://assets/models/animals/", "res://assets/models/props/", "res://assets/baked/landmarks/", "res://assets/baked/rail/"]:
		for f in DirAccess.get_files_at(d):
			var g := f.trim_suffix(".import").trim_suffix(".remap")
			if g.ends_with(".glb") and not paths.has(d + g): paths.append(d + g)
	# (a few at a time and no sub-threads: a model the game asks for on the main thread meanwhile then only waits on
	# its own load, never on a pile of others; with every request in at once the main thread could stall for good)
	var live := _loading
	while paths.size() or live.size():
		if _quitting: return
		while live.size() < 4 and paths.size():
			var q: String = paths.pop_front()
			if ResourceLoader.has_cached(q): continue
			if ResourceLoader.load_threaded_request(q, "", false) == OK: live.append(q)
		for q in live.duplicate():
			var st := ResourceLoader.load_threaded_get_status(q)
			if st == ResourceLoader.THREAD_LOAD_LOADED: _models.append(ResourceLoader.load_threaded_get(q)); live.erase(q)
			elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS: live.erase(q)
		if not is_inside_tree(): return # (a new game took over)
		await get_tree().process_frame

# ------------------------------------------------------------------ the save (main.js saveAll and the load)
func _read_save():
	if not FileAccess.file_exists(save_path): return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return d if d is Dictionary else null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _quit_game() # (the window's close: saved, the loads let finish, then out; auto-accept is off)
	elif what == NOTIFICATION_APPLICATION_PAUSED: save_all()

## What has to be known before the world is built: its seed, what you carry, what's gone for good, the clock.
func _apply_early(d: Dictionary) -> void:
	var w: Dictionary = d.get("world", {"seed": 20261120, "ring": [130, 210]})
	world_seed = int(w.get("seed", 20261120)); var rg: Array = w.get("ring", [130, 210]); world_ring = Vector2(rg[0], rg[1])
	for k in d.get("inventory", {}): inventory[k] = d.inventory[k]
	for t in d.get("tools", []): tools[t] = true
	if d.has("held"): held = d.held
	if d.get("fullness") is float or d.get("fullness") is int: saved_fullness = float(d.fullness)
	fortune = int(d.get("fortune", 0))
	if d.has("horse") and d.horse != null: horse_saved.merge(d.horse, true)
	for k in d.get("wear", {}): wear[k] = float(d.wear[k])
	for k in d.get("lands", []): lands_found[k] = true

## Everything else, once the systems exist (main.js's load, in its order).
func _apply_save(d: Dictionary) -> void:
	for k in d.get("beaten", []): world.destroyed[k] = true # (beaten guardians, found satchels and the road's trees stay gone)
	road_kept.clear(); for k in d.get("beaten", []): if not String(k).contains(":g") and not String(k).contains(",satchel,"): road_kept[k] = true
	var al = d.get("almanac")
	if al != null:
		sky.day = int(al.get("day", 1)); sky.time = float(al.get("time", sky.time))
		extras.eggs = int(al.get("eggs", extras.eggs)); extras.laid_day = int(al.get("laidDay", sky.day))
	var on_street := town.on_street; town.on_street = Callable() # (the streets reopen quietly: the web hooks its toast up after the load)
	town.load_state(d.get("town"))
	town.on_street = on_street
	if d.get("bounty") != null: bounty = d.bounty; _set_poster(bounty)
	var ce = d.get("cellar")
	if ce != null:
		if ce.get("built", false): extras.build_cellar()
		extras.cellar_day = int(ce.get("day", -1))
	if d.get("bunkhouse") != null and d.bunkhouse.get("built", false): extras.build_bunk()
	landmarks.load_state(d.get("landmarks"))
	hud.county_map.load_state(d.get("explored"))
	tales.load_state(d.get("tales")); tales_heard = tales.heard
	mail.load_state(d.get("mail"))
	if d.get("fair") != null:
		fair.entered_day = int(d.fair.get("day", 0))
		for id in d.fair.get("entered", []): fair.entered[id] = true
	var herd: Array = critters.list.filter(func(c): return c.type == "cow" or c.type == "sheep")
	var chores: Array = d.get("chores", [])
	for i in mini(chores.size(), herd.size()):
		if chores[i][0]: herd[i].milkedDay = int(chores[i][0])
		if chores[i][1]: herd[i].shornDay = int(chores[i][1]); critters.set_shorn(herd[i], true)
	grandma.pie_day = int(d.get("grandmaPie", -1)); grandma.wish_day = int(d.get("grandmaWish", -1))
	johnny.talked_day = int(d.get("johnnyTalked", -1))
	calf.load_state(d.get("calf"), sky.day)
	journal.load_state(d.get("journal")); journal.day_log = (d.get("dayLog", {}) as Dictionary).duplicate()
	enemies.calm_by_site = (d.get("calm", {}) as Dictionary).duplicate() # (dozing guardians stay dozing across a reload)
	settlers.load_state(d.get("settlers"))
	dog.found_day = int(d.get("dogDay", 0)) # (he's already been digging today, if the save says so)
	camp.load_state(d.get("campPeace")) # (days of peace bought with gifts)
	jumpers.load_state(d.get("jumpers")) # (camps cleared, and when)
	forts.load_state(d.get("forts"))
	wayfarers.load_state(d.get("wayfarers"))
	celebrate_day = int(d.get("celebrateDay", -1))
	var bs = d.get("bosses")
	if bs is Dictionary:
		for b in bosses: b.load_state(bs.get(b.id))
	else: boss.load_state(d.get("boss")) # (a save from before Big Angus: Jebediah's alone)
	_trophies()
	for b in bosses:
		if b.beaten and not b.delivered and inventory.get(b.spec.prize_key, 0) <= 0: _drop_prize(b, b.mouth + (b.at - b.mouth).normalized() * 3.0) # (left lying at his lair)
	var rr = d.get("railroad")
	if rr != null and rr.get("built", false):
		railroad.build()
		for i in int(rr.get("freight", 0)): railroad.add_freight()
		if d.get("wire") != null: crafting.new_order(sky.day, d.wire)
	claim.dug_day = int(d.get("claimDay", -1))
	if d.get("claim") != null: claim.stock = d.claim.get("stock", claim.stock); claim.hand_day = int(d.claim.get("handDay", -1))
	if saved_fullness != null: player.fullness = saved_fullness
	build.load_pieces(d.get("pieces", []))
	fair.show_ribbons(inventory.get("ribbon", 0))
	if horse_saved.get("owned", false) and horse == null: make_horse(float(horse_saved.x), float(horse_saved.z))

## The way to town: trees felled in a strip between the farmhouse and Cold Glitter Creek stay felled, so the track you
## clear stays clear (the rest of the woods grows back as ever).
const ROAD_TREES := ["pine", "maple", "snag", "birch", "goldtree", "sagetree", "appletree"]
var road_kept := {}
func _road_felled(k: String) -> bool:
	if road_kept.has(k): return true
	var g = world.regrow.get(k)
	if g == null or not (g.res.type in ROAD_TREES): return false
	var a := homestead.C; var b := town.at; var dx := b.x - a.x; var dz := b.z - a.z; var L2 := dx * dx + dz * dz
	var t := clampf(((g.res.x - a.x) * dx + (g.res.z - a.z) * dz) / L2, 0.0, 1.0)
	var qx: float = a.x + dx * t - g.res.x; var qz: float = a.z + dz * t - g.res.z
	return qx * qx + qz * qz < 49.0

func save_all() -> void:
	if not saving or sky == null or player == null: return
	var herd: Array = critters.list.filter(func(c): return c.type == "cow" or c.type == "sheep")
	var calm := {}
	for k in enemies.calm_by_site: if enemies.calm_by_site[k] > sky.day + sky.time: calm[k] = enemies.calm_by_site[k]
	var d := {
		"pieces": build.save_pieces(), "inventory": inventory,
		"settlers": settlers.save(), "world": {"seed": world_seed, "ring": [world_ring.x, world_ring.y]}, "opening": opening_done, "fortune": fortune,
		"horse": {"owned": true, "x": horse.pos.x, "z": horse.pos.z} if horse != null else horse_saved, # (Horse.pos: the web's horse.group is the node itself here; reading .group failed every save once you owned her)
		"town": town.save(), "cellar": {"built": extras.cellar_built, "day": extras.cellar_day}, "bunkhouse": {"built": extras.bunk_built},
		"tools": tools.keys(), "held": held, "fullness": roundi(player.fullness), "lands": lands_found.keys(), "landmarks": landmarks.save(), "wear": wear.duplicate(),
		"journal": journal.save(), "dayLog": journal.day_log,
		"beaten": world.destroyed.keys().filter(func(k): return String(k).contains(":g") or String(k).contains(",satchel,") or _road_felled(k)),
		"explored": hud.county_map.save(), "tales": tales.save(), "mail": mail.save(), "fair": {"day": fair.entered_day, "entered": fair.entered.keys()},
		"grandmaPie": grandma.pie_day, "grandmaWish": grandma.wish_day, "johnnyTalked": johnny.talked_day, "calf": calf.save(),
		"campPeace": camp.save(), "jumpers": jumpers.save(), "forts": forts.save(), "wayfarers": wayfarers.save(), "bosses": _bosses_save(), "celebrateDay": celebrate_day, "railroad": railroad.save(), "wire": crafting.order_state(), "claimDay": claim.dug_day, "claim": claim.save(), "bounty": bounty,
		"calm": calm, "dogDay": dog.found_day, "request": crafting.request_state(),
		"almanac": {"day": sky.day, "time": sky.time, "eggs": extras.eggs, "laidDay": extras.laid_day},
		"chores": herd.map(func(c): return [c.get("milkedDay", 0) if c.get("milkedDay", 0) > 0 else 0, c.get("shornDay", 0)]),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d))

## The rumour note under NEXT: the nearest landmark you haven't seen, and an arrow that turns with your view.
func _rumour_note() -> void:
	var r = rumours.update(player.pos, journal.GOALS.filter(func(_g): return false), func(k) -> bool: return landmarks.found.has(k))
	if r == null: hud.set_rumour(null, 0.0); return
	var cam := rig.camera; var a := cam.unproject_position(player.pos); var b := cam.unproject_position(player.pos + r.dir * 4.0)
	hud.set_rumour(r, rad_to_deg(atan2(b.x - a.x, -(b.y - a.y))))

## The county map (M or Tab): the sites in explored country (laid out deterministically, so they can be looked up),
## the iron veins the assayer has heard of (inked faint), old orchards, the camps' lands, and the rest (main.js).
## (Chunks already laid out come from Props.site_cache; an explored chunk not laid out yet is laid out now. Unexplored
## country not yet laid out is laid out while the map is open, nearest first, ~20 ms of it a frame (a layout is 16-25
## ms of GDScript, and Terrain's shared state rules out a worker thread), the ink redrawn as the faint iron comes in.)
func _layout(cx: int, cz: int, must: bool):
	var k := "%d,%d" % [cx, cz]
	if Props.site_cache.has(k): return Props.site_cache[k]
	return Props.sites_for(cx, cz, world.exclusions) if must else null

static func _cap(t: String) -> String: return t.left(1).to_upper() + t.substr(1)

var _map_filling := false
func _open_map(rewash := true) -> void:
	var M := hud.county_map
	var sites := []; var orchards := []
	# round the sheet's centre (it pans and zooms), only what's laid out already: the rest comes in from _fill_map,
	# a slice at a time (laying out every seen chunk at once here stalled the opening ~250 ms)
	if M.ctx.is_empty(): M.ctx = {"player": player.pos}
	var vc := M.center()
	var r := clampi(ceili(M.span / 2.0 / Terrain.CHUNK) + 1, 6, 26); var pcx := floori(vc.x / Terrain.CHUNK); var pcz := floori(vc.y / Terrain.CHUNK)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x0 := (pcx + dx) * Terrain.CHUNK + Terrain.CHUNK / 2.0; var z0 := (pcz + dz) * Terrain.CHUNK + Terrain.CHUNK / 2.0
			var seen_it := M.seen(x0, z0)
			var L = _layout(pcx + dx, pcz + dz, false)
			if L == null: continue
			if not seen_it:
				for s in L.sites: if s.kind == "vein": var q: Dictionary = s.duplicate(); q.rumour = true; sites.append(q)
			else:
				for s in L.sites:
					var q: Dictionary = s.duplicate()
					if s.kind == "landmark": q.foundName = _cap(String(landmarks.info[s.mark].name).trim_prefix("the ")) if landmarks.found.has(s.key) and landmarks.info.has(s.mark) else null
					sites.append(q)
				var o = L.orchard
				if o != null and not orchards.any(func(q): return Vector2(q.x - o.x, q.z - o.y).length() < 25.0): orchards.append({"x": o.x, "z": o.y})
	for c in camp.list: sites.append({"kind": "camp", "x": c.at.x, "z": c.at.z, "rumour": true, "r": NativeCamps.R, "peace": maxi(0, c.peace_until - sky.day)})
	for b in bosses: sites.append({"kind": "boss", "x": b.at.x, "z": b.at.z, "rumour": true, "name": b.title(), "beaten": b.beaten})
	for w in wayfarers.camps: sites.append({"kind": "wayfarer", "x": w.at.x, "z": w.at.z, "rumour": w.met, "name": String(w.kind.who).get_slice(",", 0)})
	for f in forts.forts: sites.append({"kind": "fort", "x": f.at.x, "z": f.at.z, "rumour": true, "name": f.name, "angry": f.angry})
	for c in jumpers.camps: sites.append({"kind": "jumpers", "x": c.at.x, "z": c.at.z, "rumour": true, "cleared": sky.day < c.cleared_day + ClaimJumpers.RESPAWN_DAYS})
	var mended := 0
	for k in town.tiers: if town.tiers[k]: mended += 1
	var offs := [0.0]
	for k in town.opened: offs.append(town.street_offs[k])
	M.paint({"player": player.pos, "fwd": player.forward(), "home": homestead.spawn, "sites": sites, "tinker": tinker.pos if tinker.here else null, "orchards": orchards,
		"pieces": build.pieces, "fair": fair.at if fair.open(sky) else null, "star": falling_stars.at if falling_stars.state == "landed" else null,
		"town": {"at": town.at, "along": town.along, "toward": town.toward, "offs": offs, "mended": mended}}, rewash)
	hud.map_card.visible = true
	if rewash and not _map_filling: _fill_map(pcx, pcz)

## Can this chunk hold an iron vein at all? (Props._place puts a site 8-24 m into its chunk and makes it a vein only on
## highland or peak ground: no such ground in that square, no vein, so no need to lay the chunk out for the map.)
func _may_hold_vein(cx: int, cz: int) -> bool:
	for j in 5:
		for i in 5:
			var r := Terrain.region_at(cx * Terrain.CHUNK + 8.0 + i * 4.0, cz * Terrain.CHUNK + 8.0 + j * 4.0)
			if r == "highland" or r == "peak": return true
	return false

## While the map's open: lay out the chunks round the sheet's centre that aren't yet (the seen ones, for their marks,
## and unexplored ones that may hold iron), nearest first, each a slice at a time (Props.place_sliced, ~5 ms a frame:
## a whole layout at once is 17-50 ms, which was the lag), and
## redraw the ink every half second as their faint iron comes in (and once at the end). Folding the map stops it.
func _fill_map(pcx: int, pcz: int) -> void:
	var todo := []
	for dz in range(-9, 10):
		for dx in range(-9, 10):
			var cx0 := pcx + dx; var cz0 := pcz + dz
			if Props.site_cache.has("%d,%d" % [cx0, cz0]): continue
			if hud.county_map.seen(cx0 * Terrain.CHUNK + Terrain.CHUNK / 2.0, cz0 * Terrain.CHUNK + Terrain.CHUNK / 2.0) or _may_hold_vein(cx0, cz0): todo.append(Vector2i(cx0, cz0))
	if todo.is_empty(): return
	todo.sort_custom(func(a, b): return (a - Vector2i(pcx, pcz)).length_squared() < (b - Vector2i(pcx, pcz)).length_squared())
	_map_filling = true
	var last_paint := Time.get_ticks_msec(); var dirty := false
	while todo.size() and hud.map_card.visible:
		var c: Vector2i = todo.pop_front()
		if not Props.site_cache.has("%d,%d" % [c.x, c.y]): await Props.place_sliced(c.x, c.y, world.exclusions, 5000); dirty = true
		if not is_inside_tree(): return
		if dirty and (Time.get_ticks_msec() - last_paint > 500 or todo.is_empty()): _open_map(false); last_paint = Time.get_ticks_msec(); dirty = false
		if not is_inside_tree(): return
		await get_tree().process_frame
	_map_filling = false

## The almanac: the day as it tells it, read back when you sleep (main.js showAlmanac).
func _show_almanac(day: int) -> void:
	var lines := journal.almanac_lines(func(id: String) -> String: return crafting.by_id[id].name if crafting.by_id.has(id) else id,
		func(t: String) -> String: return BuildSystem.PIECES[t].name if BuildSystem.PIECES.has(t) else t)
	if lines.size(): hud.story_show("Day %d, as the almanac tells it" % day, ["On this day the farmer…"], lines, "E to close")
	else: hud.story_show("Day %d, as the almanac tells it" % day, ["A quiet day. Sometimes that's the best kind."], [], "E to close")
	story_kind = "almanac"; almanac_t = 12.0; journal.day_log = {}

## The almanac card (H): this week at a glance, and what's ready around the farm today (main.js renderCalendar).
func _render_calendar() -> void:
	var d0 := sky.day
	var week := []
	for i in 7:
		var d := d0 + i; var bits := []
		if d % 7 == 0: bits.append(["County Fair", "#b5473a", true])
		if BarnDance.is_dance_night(d): bits.append(["Barn dance", "#8a5a1e", false])
		if d % 2 == 0: bits.append(["Tinker", "#4f6f96", false])
		if d % 7 == 0 and town.tiers.get("church", 0): bits.append(["Sunday meeting", "#5a6a3a", false])
		if d % 7 == 6 and town.street_done(-1) and town.street_done(0) and town.street_done(1): bits.append(["Fireworks", "#a0306a", true])
		week.append({"label": "Today" if i == 0 else "Day %d" % d, "today": i == 0, "bits": bits})
	var cows := critters.list.filter(func(c): return c.type == "cow"); var sheep := critters.list.filter(func(c): return c.type == "sheep")
	var to_milk := cows.filter(func(c): return c.milkedDay != d0).size(); var to_shear := sheep.filter(func(c): return not (c.shornDay and d0 - c.shornDay < 2)).size()
	var honey := 0; var apples := 0
	for q in build.pieces:
		if q.type == "skep": honey += int(q.get("stock", 0) if q.get("stock") != null else 0)
		if q.type == "homeapple": apples += int(q.get("stock", 0) if q.get("stock") != null else 0)
	var req = crafting.request_state(); var order = crafting.order_state()
	var days_to_fair := (7 - (d0 % 7)) % 7
	var days_to_dance := 0
	while not BarnDance.is_dance_night(d0 + days_to_dance): days_to_dance += 1
	var wish := Grandma.wish_for(d0)
	var notes := [
		("%d egg%s waiting in the nesting box" % [extras.eggs, "s" if extras.eggs > 1 else ""]) if extras.eggs else "No eggs till the hens lay again tomorrow morning",
		((("%d cow%s to milk" % [to_milk, "s" if to_milk > 1 else ""]) if to_milk else "The cows are milked") + ((" · %s" % (("%d sheep ready to shear" % to_shear) if to_shear else "the sheep are shorn")) if sheep.size() else "")) if cows.size() else null,
		"The red flag is up: a letter in the mailbox" if mail.waiting else ("The mail carrier comes by mid-morning" if d0 >= 1 else null),
		("%d comb%s of honey in your skeps" % [honey, "s" if honey > 1 else ""]) if honey else null,
		("%d ripe apple%s on your own trees" % [apples, "s" if apples > 1 else ""]) if apples else null,
		("Telegram at the depot: %s wanted at the %s trading post by day %d ($%d)" % [String(order.name).to_lower(), order.where, order.due, order.pay]) if order != null and not order.done else null,
		("The tinker's wagon is on Main Street in Cold Glitter Creek%s" % (" (he has a special request)" if req != null and not req.done else "")) if tinker.visiting(sky) else null,
		("Grandma could use %s (knock of an evening)" % wish.ask) if grandma.wish_day != d0 else null,
		"Daisy’s calf is lost out in the meadows: listen for it bawling" if calf.state == "lost" or calf.state == "follow" else null,
		"Tonight the harvest moon rises: whatever you gather after dark comes in one extra" if (d0 + 1) % 7 == 0 else null,
		"The barn dance is on in the street before the livery barn, till three in the morning" if dance.live(sky.day, sky.time) else ("Barn dance tonight, from half past five till three, in the street before the livery barn" if days_to_dance == 0 else "The next barn dance is %s (5:30 pm till 3 am)" % ("tomorrow night" if days_to_dance == 1 else "in %d days" % days_to_dance)),
		"It's County Fair day: Mrs. Pruitt is judging south of the lane" if fair.open(sky) else "The County Fair is %s" % ("tomorrow" if days_to_fair == 1 else "in %d days" % days_to_fair),
		("The barn rooster has swung east: %s on the way" % ("snow" if weather.next_kind == "snow" else "rain")) if weather.target == 0 and weather.next < 45.0 else null,
		"A fallen star is glowing somewhere out in the grass" if falling_stars.state == "landed" else null,
	].filter(func(n): return n != null)
	var rb: int = inventory.get("ribbon", 0)
	hud.calendar_show("The Farmer's Almanac · " + sky.clock_text(), week, notes, "%d ribbon%s won at the fair · H to fold it away" % [rb, "" if rb == 1 else "s"])

## The opening: a new game starts with a glint of gold in the gravel a few steps from the cabin, so the very first
## thing you do is pick up a nugget and learn what this country is about (main.js).
func _make_glint() -> void:
	var sp: Vector3 = homestead.spawn; var gx: float = sp.x + town.along.x * 3.2 + town.toward.x * 1.2; var gz: float = sp.z + town.along.z * 3.2 + town.toward.z * 1.2
	glint = Node3D.new(); glint.position = Vector3(gx, Terrain.get_height(gx, gz), gz); add_child(glint)
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color.hex(0xf0c840ff); gm.emission_enabled = true; gm.emission = Color.hex(0x5a3c00ff)
	gm.roughness = 1.0; gm.metallic_specular = 0.0; gm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for n in [[0.0, 0.0, 0.13], [0.16, 0.06, 0.07], [-0.1, 0.12, 0.06]]:
		var r: float = n[2]; var m := MeshInstance3D.new(); m.mesh = _dodeca(r); m.material_override = gm
		m.position = Vector3(n[0], r * 0.6, n[1]); m.rotation = Vector3(n[0] * 5.0, n[1] * 7.0, 0.3); m.scale.y = 0.6; glint.add_child(m)

## A dodecahedron of radius r (three's DodecahedronGeometry(r, 0)), flat-shaded.
static func _dodeca(r: float) -> ArrayMesh:
	var f := (1.0 + sqrt(5.0)) / 2.0; var V: Array[Vector3] = []
	for a in [-1.0, 1.0]: for b in [-1.0, 1.0]:
		for c in [-1.0, 1.0]: V.append(Vector3(a, b, c))
		V.append(Vector3(0, a / f, b * f)); V.append(Vector3(a / f, b * f, 0)); V.append(Vector3(a * f, 0, b / f))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [-1.0, 1.0]: for b in [-1.0, 1.0]: # (the 12 face normals: an icosahedron's corners)
		for nn in [Vector3(0, a * f, b), Vector3(a * f, b, 0), Vector3(b, 0, a * f)]:
			var n: Vector3 = nn.normalized(); var ring: Array = V.duplicate(); ring.sort_custom(func(p, q): return p.dot(n) > q.dot(n)); ring = ring.slice(0, 5)
			var c := Vector3.ZERO
			for q in ring: c += q / 5.0
			var r0: Vector3 = ring[0]; var u: Vector3 = (r0 - c).normalized(); var w: Vector3 = n.cross(u)
			ring.sort_custom(func(p, q): return atan2((p - c).dot(w), (p - c).dot(u)) < atan2((q - c).dot(w), (q - c).dot(u)))
			for k in range(1, 4): # (Godot's front faces wind clockwise)
				for q in [ring[0], ring[k + 1], ring[k]]: st.set_normal(n); st.add_vertex(q.normalized() * r)
	return st.commit()

## The glint: a twinkle every second or so, hopping clear of anything built on top of it; E picks it up.
func _glint(dt: float, active: bool) -> void:
	var gp := glint.position
	if glint_t <= 0.0 and build.nearby(gp.x, gp.z, 1.8).size() > 0:
		var done := false; var r := 2.5
		while r < 12.0 and not done:
			var a := 0.0
			while a < TAU and not done:
				var x := gp.x + cos(a) * r; var z := gp.z + sin(a) * r
				if not Terrain.is_water(x, z) and build.nearby(x, z, 1.8).is_empty(): glint.position = Vector3(x, Terrain.get_height(x, z), z); done = true
				a += 0.6
			r += 1.5
	glint_t -= dt
	if glint_t <= 0.0: glint_t = 0.9 + randf() * 0.6; confetti.burst(glint.position + Vector3(0, 0.25, 0), [0xfff2b0, 0xf0c840], 3, 0.25) # a twinkle in the gravel
	if not glint_told and active: glint_told = true; hud.toast("You came west chasing a gold rumour. Something glints by the cabin...")
	if beast_prompt != "" or not active or build.active or player.dead or riding: return
	if Vector2(player.pos.x - glint.position.x, player.pos.z - glint.position.z).length() < 2.3:
		beast_prompt = "[E] Pick up the glint in the gravel"
		if input.hit("KeyE"):
			glint.queue_free(); glint = null; opening_done = true; inventory.gold = inventory.get("gold", 0) + 2; settlers.discover("gold"); journal.record("gather:gold")
			confetti.burst(player.pos + Vector3(0, 0.9, 0), [0xf0c840, 0xffe08a, 0xd8a830], 14, 0.6)
			sound.craft(); hud.toast("GOLD! The rumour was true. Sell it at the assay office in town: $4 a pinch. Pan creeks (E in shallow water) for more.")

## The tinker's wagon, the fair's judging table, and Grandma's door of an evening (main.js).
func _visitors() -> bool:
	if fairy_ring.near(player.pos):
		beast_prompt = "[E] Gather the fairy ring of toadstools"
		if input.hit("KeyE"):
			fairy_ring.gather(); inventory.mushrooms = inventory.get("mushrooms", 0) + 6; journal.record("ring"); sound.pick()
			var lucky := randf() < 0.35
			if lucky: inventory.honey = inventory.get("honey", 0) + 1; inventory.iron = inventory.get("iron", 0) + 1
			hud.toast("You gather the whole ring (+6 toadstools), and tucked in the grass at its middle there is a little clay jar of honey and an old iron key. Lucky indeed!" if lucky else "You gather the whole ring into your hat: six fine toadstools for a stew.")
		return true
	# up on the windmill platform: the whole home place laid out below, inked onto your map
	if mill_pending and player.climbing == null:
		mill_pending = false
		if mill_view_day != sky.day:
			mill_view_day = sky.day; hud.county_map.reveal(homestead.mill_at.x, homestead.mill_at.z, 110.0, 0.12, 12.0)
			sound.craft(); hud.toast("Up on the windmill platform, with the fan clattering over your head, the whole home place is laid out below: the house, the barn, the fields, the lane to Cold Glitter Creek and the creek beyond. You ink it all onto your map.")
	# the stage's passenger, while the coach waits: news of a landmark, sketched onto your map
	if town.rider != null and not riding and Vector2(player.pos.x - town.rider.x, player.pos.z - town.rider.z).length() < 2.4:
		beast_prompt = "The lady off the stage, stretching her legs" if rider_day == sky.day else "[E] Ask the stage passenger for news"
		if input.hit("KeyE"):
			if rider_day == sky.day: hud.toast("\"That’s all the news I carry, friend. Ask me again when the stage comes through tomorrow.\"")
			else:
				var best = null; var bd := INF
				for st in rumours.found.values():
					if st.kind != "landmark" or landmarks.found.has(st.key) or not landmarks.info.has(st.mark): continue
					var d := Vector2(st.x - player.pos.x, st.z - player.pos.z).length()
					if d < bd: bd = d; best = st
				rider_day = sky.day
				if best == null: hud.toast("The lady laughs. \"You’ve seen more of this county than I have, friend. Nothing I can tell you.\"")
				else:
					for i in range(-2, 3):
						for j in range(-2, 3): hud.county_map.explored["%d,%d" % [floori(best.x / 16.0) + i, floori(best.z / 16.0) + j]] = true
					sound.craft(); hud.toast("A lady in a feathered hat steps down off the stage, glad of someone to talk to. \"We came by %s on the way in. Quite a sight.\" She sketches the way for you on the back of a handbill. (It’s marked on your county map, Tab.)" % landmarks.info[best.mark].name)
		return true
	if story_kind == "letter":
		if input.hit("KeyE") or not mail.near(player.pos, 3.5): story_kind = ""; hud.story_hide()
		beast_prompt = "[E] Fold the letter away"
		return true
	if mail.near(player.pos):
		beast_prompt = "[E] The flag is up: take the letter from the mailbox" if mail.waiting else "The mailbox: the carrier comes by mid-morning"
		if input.hit("KeyE"):
			var L = mail.take()
			if L != null:
				for k in L.gift: inventory[k] = inventory.get(k, 0) + int(L.gift[k])
				journal.record("letter"); story_kind = "letter"; sound.pick()
				hud.story_show("A letter from " + L.from, [L.text], [], "Folded inside: %s · E to fold it away" % L.note)
			else: hud.toast("Nothing in the box. The carrier comes by mid-morning.")
		return true
	if tinker.near(player.pos, 4.2):
		beast_prompt = "[E] Trade with the tinker"
		if input.hit("KeyE"): _open_craft(); journal.record("tinker")
		return true
	if fair.near(player.pos, 3.2):
		beast_prompt = "[E] Enter your goods at the County Fair"
		if input.hit("KeyE"): _open_craft(); journal.record("fair")
		return true
	if not extras.sitting and grandma.at_door(player.pos):
		var inv := inventory; var wish := Grandma.wish_for(sky.day)
		var have := true
		for k in wish.cost: if inv.get(k, 0) < wish.cost[k]: have = false
		if grandma.home(sky): beast_prompt = ("[E] Knock and give Grandma %s" % String(wish.ask).split(" for ")[0]) if have and grandma.wish_day != sky.day else ("[E] Knock at the door (Grandma is up)" if grandma.pie_day != sky.day else "")
		if input.hit("KeyE"):
			if not grandma.home(sky): hud.toast("The house is dark. Grandma has gone up to bed; best not wake her." if sky.time >= 0.94 or sky.time < 0.25 else "Grandma is out visiting till evening. The door is on the latch.")
			elif have and grandma.wish_day != sky.day: # her wish for today: bring it and she bakes you something in return
				for k in wish.cost: inv[k] -= wish.cost[k]
				for k in wish.gives: inv[k] = inv.get(k, 0) + wish.gives[k]
				grandma.wish_day = sky.day; journal.record("wish"); sound.lullaby(); hud.toast("\"%s\"" % wish.thanks)
			elif grandma.pie_day == sky.day: hud.toast("\"One slice is plenty, young man. There will be more tomorrow.\"" if grandma.wish_day == sky.day else "\"One slice is plenty. But if you're passing, I could use %s.\"" % wish.ask)
			else:
				grandma.pie_day = sky.day; journal.record("grandma"); sound.lullaby(); inv.pie = inv.get("pie", 0) + 1
				hud.toast("Grandma opens the door in a warm wash of lamplight. %s (+1 pumpkin pie)%s" % [Grandma.PIE_WORDS[randi() % Grandma.PIE_WORDS.size()], "" if grandma.wish_day == sky.day else " \"And if you've a moment tomorrow or tonight, I could use %s.\"" % wish.ask])
		return beast_prompt != ""
	return false

func _pets(dt: float, active: bool) -> void:
	if _drops_tick(active): return
	if _boss_spoils(active): return
	if _wayfarer(active): return
	if _fort_officer(active): return
	if jar_count and sky.night < 0.15: jar_count = 0; hud.toast("First light: you unscrew the lid and the lightning bugs drift off home.") # (the jar let go at dawn)
	dog.day = sky.day
	dog.update(dt, player, rig.camera, {"rocker": {"seat": extras.seat, "facing": extras.seat_facing} if extras.sitting else null, "colliders": world.colliders, "track": calf.pos if calf.state == "lost" else null, "prey": tumbleweeds.list[0].mesh if tumbleweeds.list.size() else ducks.lead_group(), "danger": enemies.list.any(func(e): return not e.dying and not enemies.is_calm(e, sky.day + sky.time) and Vector2(Enemies.pos(e).x - player.pos.x, Enemies.pos(e).z - player.pos.z).length() < 14.0) or crows.state == "pecking" and Vector2(crows.birds[0].to.x - player.pos.x, crows.birds[0].to.z - player.pos.z).length() < 25.0})
	cat.update(dt, player, rig.camera, dog, sky.night, world.colliders)
	var calf_r := calf.update(dt, sky.day, sky.time, player, rig.camera, world.colliders)
	if calf_r.has("lost"): hud.toast("Daisy's calf slipped through the pasture rails in the night! Folks saw it heading off to the %s. Listen for it bawling." % calf_r.lost)
	if calf_r.has("home"): journal.record("calf"); sound.lullaby(); inventory.milk = inventory.get("milk", 0) + 2; hud.toast("The calf scampers through the rails to Daisy, who lows and licks it all over. She gives you two pails of milk, she is that glad.")
	_horse(dt, active)
	if glint != null: _glint(dt, active)
	if beast_prompt != "" or not active or build.active or player.dead: return
	if _visitors(): return
	# lightning bugs: with the jar, after dark, catch the fireflies drifting about (E)
	var bug_at := ambient.firefly_near(player.pos) if tools.has("jar") and jar_count < JAR_MAX else -1
	if bug_at >= 0:
		beast_prompt = "[E] Catch the lightning bug in your jar (%d/%d)" % [jar_count, JAR_MAX]
		if input.hit("KeyE"):
			ambient.catch_firefly(bug_at); jar_count += 1; sound.pick(); journal.record("firefly")
			if jar_count == 1: hud.toast("Got one! It blinks away in the jar, warm as a coal.")
			elif jar_count == JAR_MAX: hud.toast("A jar full of lightning bugs: a lantern that hums.")
		return
	# a peace offering for a guardian: each keeper has the thing the old tales say will settle it (no prompt while one lies in wait)
	var gn = enemies.awake_near(player.pos, sky.day + sky.time)
	if gn != null and gn.state != "lurk":
		var peace: Dictionary = PEACE.get(gn.kind, PEACE.coyote)
		var can_offer := true
		for k in peace.cost: if inventory.get(k, 0) < peace.cost[k]: can_offer = false
		beast_prompt = "[E] " + (peace.give if can_offer else peace.hint)
		if input.hit("KeyE"):
			if can_offer:
				for k in peace.cost: inventory[k] -= peace.cost[k]
				enemies.calm(gn, sky.day + sky.time); journal.record("peace"); sound.lullaby(); hud.toast(peace.thanks)
			else: hud.toast(peace.lore)
		return
	# mending the town: at a run-down building's door, E pays to have it put right (the assay office's own door
	# weighs your gold first, if you've any)
	var project = town.project_at(player.pos)
	if project != null and not (project.id == "assay" and (inventory.get("gold", 0) > 0 or inventory.get("silver", 0) > 0)):
		beast_prompt = "[E] Mend the %s: $%d (you have $%d)" % [project.name, project.cost, inventory.get("dollars", 0)]
		if input.hit("KeyE"):
			if inventory.get("dollars", 0) >= project.cost:
				inventory.dollars -= project.cost; town.mend(project.id); sound.craft(); journal.record("mend")
				if project.id == "boarding": newcomer_news = true
				hud.toast(Town.MEND_TEXT.get(project.id, "The %s is mended." % project.name))
				confetti.burst(Vector3(project.door.x, player.pos.y + 1.6, project.door.z), [0xefe3c4, 0xb5473a, 0xe8c84a], 30, 0.9)
			else: hud.toast("Putting the %s to rights takes $%d; you've $%d. Pan some more colour." % [project.name, project.cost, inventory.get("dollars", 0)])
		return
	# the barn dance: stand by the floor and press E to join in
	if dance.near(player.pos) and dance_t <= 0.0:
		beast_prompt = "[E] Join the barn dance"
		if input.hit("KeyE"):
			dance_t = 5.0; journal.record("dance"); settlers.danced = true # (Clementine hears of it)
			hud.toast(["You swing your partner round and round. The fiddler grins and plays faster.", "A reel, a jig and a do-si-do. Your boots have never been so happy.", "Round the floor you go, under the lanterns. The whole county is clapping."][randi() % 3])
		return
	# the opera house, once it's mended: from sundown a touring company plays a tall tale; a $3 seat and an hour passes
	if town.tiers.get("opera", 0) and Vector2(player.pos.x - town.doors.opera.x, player.pos.z - town.doors.opera.z).length() < 2.3:
		var curtain := sky.time > 0.74 or sky.time < 0.02
		beast_prompt = ("[E] The opera house (seen tonight's show)" if opera_day == sky.day else "[E] A seat for tonight's show: $3") if curtain else "[E] Read the playbill (curtain at sundown)"
		if input.hit("KeyE"):
			var pb: Array = town.PLAYBILL[sky.day % town.PLAYBILL.size()]
			var title: String = String(pb[0]).capitalize()
			if not curtain: hud.toast("The doors are shut till sundown. Tonight: %s %s." % [title, pb[1]])
			elif opera_day == sky.day: hud.toast("You've seen tonight's bill. The company plays something new tomorrow.")
			elif inventory.get("dollars", 0) < 3: hud.toast("\"Three dollars a seat, friend.\" You're short.")
			else:
				inventory.dollars -= 3; opera_day = sky.day; sound.craft(); journal.record("opera"); sky.time = fmod(sky.time + 0.045, 1.0) # (an hour in the dark, the footlights hissing)
				player.health = player.max_health; player.stamina = player.max_stamina; player.fullness = maxf(player.fullness, 60.0)
				hud.toast("The gaslights dim and the curtain rises on %s %s. %s You come out into the night rested and smiling." % [title, pb[1], pb[2]])
		return
	if _rail_doors(): return
	if _town_doors(): return
	# a tent-dweller on Squatters' Row who wants something
	var wanter = town.want_at(player.pos)
	if wanter != null:
		beast_prompt = "[E] %s wants %d %s ($%d): you have %d" % [wanter.name, wanter.want[1], wanter.want[0], wanter.want[2], inventory.get(wanter.want[0], 0)]
		if input.hit("KeyE"):
			var fr: Dictionary = town.fill(wanter, inventory, sky.day, 1 if inventory.get("groomedDay", -1) == sky.day else 0); hud.toast(fr.text)
			if fr.get("ok", false): sound.craft()
			else: sound.click()
		return
	# a ladder (or a scramble): E at its foot climbs, E at its head on the deck climbs down
	var ladder = climbs.ladder_at(player.pos) if player.climbing == null and not riding else null
	if ladder != null:
		beast_prompt = ("[E] Climb " + ladder.ladder.name) if ladder.up else "[E] Climb down"
		if input.hit("KeyE"):
			player.climbing = climbs.path(ladder, player.pos); sound.place()
			if ladder.up and ladder.ladder.name == "the windmill": mill_pending = true
		return
	# settlers: each won over their own way
	var sn = settlers.near(player.pos)
	var hireable = sn if sn != null and sn.state == "camp" else null
	if settlers.bout != null and settlers.bout.s != hireable: settlers.bout = null # (walked off mid-match)
	if hireable != null:
		var S: Dictionary = hireable.S
		var e := input.hit("KeyE")
		match S.how:
			"deed": # the collier: only for someone who's driven off a treasure guardian
				var did := world.destroyed.keys().any(func(k): return String(k).contains(":g"))
				beast_prompt = "[E] Tell %s how you drove off the guardian" % S.name if did else "%s won't work for anyone who hasn't driven off a treasure guardian" % S.name
				if e:
					if did: settlers.join(hireable); hud.toast(S.hired); sound.craft()
					else: hud.toast(S.lost)
			"court": # a reel at the barn dance, and a pumpkin pie brought to her camp
				beast_prompt = "[E] Court %s: %s · %s" % [S.name, "a reel danced ✓" if settlers.danced else "dance a reel at the barn dance", "give her a pumpkin pie" if inventory.get("pie", 0) >= 1 else "bring a pumpkin pie"]
				if e:
					if settlers.danced and inventory.get("pie", 0) >= 1: inventory.pie -= 1; settlers.join(hireable); hud.toast(S.hired); sound.craft()
					elif not settlers.danced: hud.toast("\"You haven't so much as asked me to dance. There's a dance in front of the livery barn the night of every County Fair, you know.\"")
					else: hud.toast("\"That reel was lovely. A pumpkin pie wouldn't go amiss, either.\"")
			"tale": # the tall-tale contest: by his fire after dark, with tales of your own to tell
				beast_prompt = "%s trades tall tales by his fire after dark" % S.name if sky.night < 0.45 else "[E] Sit by %s's fire and out-tell him (%d/%d tales of your own)" % [S.name, tales_heard.size(), S.tales]
				if e:
					if sky.night < 0.45: hud.toast("\"Tales are for after dark, friend. Come by my fire this evening.\"")
					elif tales_heard.size() >= S.tales: settlers.join(hireable); hud.toast(S.hired); sound.craft()
					else: hud.toast(S.lost)
			"wrestle": # E starts it, then every E press pushes his arm down
				if settlers.bout == null and hireable.tired <= 0.0 and e: settlers.bout = {"k": 0.5, "s": hireable}; sound.knock(); hud.toast("You sit down across the crate and clasp hands. Press E as fast as you can!")
				elif settlers.bout != null:
					var r := settlers.wrestle(get_process_delta_time(), hireable, e)
					if r == "won": hud.toast(S.hired); sound.craft()
					elif r == "lost": sound.knock(); hud.toast("Thump! Big Jim pins your arm to the crate. \"Come back when you've had your oats.\"")
				beast_prompt = ("[E E E!] Arm-wrestling Big Jim  " + settlers.match_bar()) if settlers.bout != null else ("Big Jim is still flexing his arm. Give it a little while." if hireable.tired > 0.0 else "[E] Arm-wrestle %s (win, and he'll dig your clay)" % S.name)
			_:
				beast_prompt = "[E] Help %s %s (%s)" % [S.name, S.get("chore", "mend her lean-to"), Settlers.list_text(S.wage, " + ")] if S.how == "help" else "[E] Hire %s, %s (%s)" % [S.name, S.trade, Settlers.list_text(S.wage, " + ")]
				if e:
					if settlers.hire(inventory, hireable): hud.toast(S.hired); sound.craft()
					elif S.how == "help": hud.toast("%s needs %s to %s." % [S.name, Settlers.list_text(S.wage, " and "), S.get("chore", "mend her lean-to")])
					else: hud.toast("%s would join for %s." % [S.name, Settlers.list_text(S.wage, " and ")])
		return
	# the storehouse: E takes what the settlers brought, R stocks the larder
	var store_near = null
	for q in build.pieces: if q.type == "storehouse" and Vector2(q.x - player.pos.x, q.z - player.pos.z).length() < 2.8: store_near = q; break
	if store_near != null:
		var st := settlers.stock_text()
		beast_prompt = "%s   [R] Stock the larder (%d rations)" % ["[E] Take from the storehouse: " + st if st != "" else "The storehouse: your settlers fill it a little at a time", settlers.larder]
		if input.hit("KeyR"):
			var r := settlers.stock_larder(inventory)
			if not r.is_empty(): sound.pick(); hud.toast("Into the larder: %s (+%d rations). %s." % [Settlers.list_text(r.taken), r.rations, settlers.larder_text()])
			else: hud.toast("Nothing plain to put by: fish, corn, apples, eggs, bread or berries (two to a ration) feed your settlers.")
		if input.hit("KeyE"):
			var got := Settlers.list_text(settlers.collect(inventory))
			sound.pick(); hud.toast("From the storehouse: %s." % got if got != "" else "The storehouse is empty for now. Your settlers bring what they make a little at a time.")
		return
	# a gift at a camp's poles: two venison, a jar of honey or a hide buys three days' peace on their land (and the
	# girl brings you a little something back); striking one of them ends it
	var poles = camp.at_poles(player.pos.x, player.pos.z) if not riding else null
	if poles != null and poles.alarm != "fight":
		var gift_of = (["venison", 2, "two cuts of venison"] if inventory.get("venison", 0) >= 2 else (["honey", 1, "a jar of honey"] if inventory.get("honey", 0) >= 1 else (["pelt", 1, "a good hide"] if inventory.get("pelt", 0) >= 1 else null)))
		var left: int = poles.peace_until - sky.day
		beast_prompt = ("Their land: welcome for %d more day%s" % [left, "s" if left > 1 else ""]) if left > 0 else ("[E] Leave a gift at the poles (%s): three days' peace" % gift_of[2] if gift_of != null else "A gift left at the poles would be welcome (venison, honey or a hide)")
		if input.hit("KeyE"):
			if left > 0: hud.toast("You are welcome on their land for %d more day%s." % [left, "s" if left > 1 else ""])
			elif gift_of == null: hud.toast("A gift left at the poles would be welcome: two cuts of venison, a jar of honey or a good hide.")
			else:
				inventory[gift_of[0]] -= gift_of[1]; poles.gift(3); inventory.rope = inventory.get("rope", 0) + 2; journal.record("peace"); sound.craft()
				hud.toast("You leave %s at the foot of a painted pole and step back. Before long the elder comes out, looks at it a long while, and raises a hand. You are welcome on their land for three days. The girl runs out with a coil of braided rawhide (+2 rope)." % gift_of[2])
		return
	# trading at a camp's fire, while at peace there
	if not riding and camp.fire_at(player.pos.x, player.pos.z) != null:
		beast_prompt = "[E] Sit at their fire and trade"
		if input.hit("KeyE"): _open_craft()
		return
	# Johnny Appleseed
	if johnny.near(player.pos):
		beast_prompt = "[E] Say so long to Johnny Appleseed" if johnny.talked else "[E] Pass the time of day with Johnny Appleseed"
		if input.hit("KeyE"):
			if not johnny.talked:
				johnny.talked = true; johnny.talked_day = sky.day; inventory.apples = inventory.get("apples", 0) + 3; journal.record("johnny")
				# and he plants a sapling just off the lane, at the edge of the yard
				var sx := johnny.pos.x; var sz := johnny.pos.z - 2.6
				var clear := true
				for q in build.pieces: if Vector2(q.x - sx, q.z - sz).length() < 2.0: clear = false; break
				if not Terrain.is_water(sx, sz) and clear: build.add({"type": "sapling", "x": sx, "y": Terrain.get_height(sx, sz), "z": sz, "rot": randf() * 6.0, "day": sky.day})
				sound.pick(); hud.toast("%s He hands you 3 apples and plants a sapling by the lane." % Wanderer.SAYINGS[randi() % Wanderer.SAYINGS.size()])
			else: hud.toast("\"Mind that sapling now. Water it with patience.\" He tips his pot and wanders on.")
		return
	# corn for the ducks
	var duck_spot = ducks.toss_spot(player.pos.x, player.pos.z) if not riding and inventory.get("corn", 0) >= 1 else null
	if duck_spot != null and ducks.fam.come == null:
		beast_prompt = "[E] Toss the ducks some corn"
		if input.hit("KeyE"):
			inventory.corn -= 1; ducks.feed(duck_spot); wade_rings.ring(duck_spot.x, duck_spot.y, 0.8)
			hud.toast("You shuck a cob and toss the kernels out on the water. The duck turns, quacks to her brood, and they come paddling over in a line.")
		return
	if calf.near(player.pos):
		beast_prompt = "[E] Lead the lost calf home"
		if input.hit("KeyE") and calf.lead(): hud.toast("The calf gives a little bawl and trots after you. Lead it home to the pasture.")
		return
	if dog.stick_near(player.pos):
		beast_prompt = "[E] Throw the stick for Old Blue"
		if input.hit("KeyE"): dog.throw_stick(player); sound.tear()
	elif dog.near(player.pos) and build.extra_near(player.pos) == null and build.bed_near(player.pos) == null: # (at a well or coop, E is for that, not the dog at your heel)
		beast_prompt = "[E] Give Old Blue a scratch behind the ears"
		if input.hit("KeyE"):
			dog.pat(); journal.record("pat")
			if randf() < 0.5 and dog.offer_stick(player): hud.toast("Old Blue drops a slobbery stick at your feet and looks up at you, hopeful.")
			else: hud.toast(["Old Blue thumps his tail on the ground.", "A good scratch behind the ears. Old Blue leans into it.", "Old Blue licks your hand and grins his dog grin."][randi() % 3])
	elif cat.near(player.pos):
		beast_prompt = "[E] Give Marmalade a scratch under the chin"
		if input.hit("KeyE"): cat.pat(); journal.record("cat"); hud.toast(CAT_PURRS[randi() % CAT_PURRS.size()])

var beast_prompt := ""

# ------------------------------------------------------------------ things left lying where someone fell (the player's ask)
## A pickup: a fallen warrior's painted parfleche, a claim jumper's poke. It lies where he fell, bobbing a little till
## you come by; E beside it takes what's inside. Gone at the next dawn if left. [{node, pos, what, loot, day}]
var drops: Array = []
const NATIVE_LOOT := [{"pelt": 2}, {"leather": 1, "rope": 1}, {"venison": 2}, {"amber": 1, "pelt": 1}, {"cartridges": 3}, {"honey": 1, "berries": 4}]
func drop_native(w: Dictionary) -> void:
	var p: Vector3 = w.fig.root.position
	add_drop("prop_parfleche", 0.7, Vector3(p.x + 0.6, 0, p.z + 0.4), "his painted parfleche", NATIVE_LOOT[randi() % NATIVE_LOOT.size()])
func add_drop(model: String, length: float, at: Vector3, what: String, loot: Dictionary, keep := false) -> void:
	var n: Node3D = NativeCamps.prop(model, length)
	if n == null: var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.4, 0.25, 0.3); b.mesh = bm; b.material_override = PaperMats.paper(Color("8a5a30")); n = b
	at.y = Terrain.get_height(at.x, at.z); n.position = at; n.rotation.y = randf() * TAU
	add_child(n)
	drops.append({"node": n, "pos": at, "what": what, "loot": loot, "day": sky.day, "t": randf() * 6.0, "keep": keep})
func _drops_tick(active: bool) -> bool:
	var near = null
	for d in drops.duplicate():
		if not d.keep and (sky.day > d.day + 1 or (sky.day > d.day and sky.time > 0.25)): (d.node as Node3D).queue_free(); drops.erase(d); continue
		d.t += get_process_delta_time(); (d.node as Node3D).position.y = d.pos.y + 0.04 + sin(d.t * 2.2) * 0.03
		if near == null and Vector2(player.pos.x - d.pos.x, player.pos.z - d.pos.z).length() < 1.8: near = d
	if near == null or not active or player.dead or build.active: return false
	beast_prompt = "[E] Pick up %s" % near.what
	if input.hit("KeyE"):
		var got := []
		for k in near.loot: inventory[k] = inventory.get(k, 0) + int(near.loot[k]); got.append("%d %s" % [near.loot[k], k])
		hud.toast("Inside %s: %s." % [near.what, ", ".join(got)]); sound.pick()
		(near.node as Node3D).queue_free(); drops.erase(near)
	return true
func _livestock(dt: float, active: bool) -> void:
	beast_prompt = ""
	if critters.barn == null:
		var b := homestead.model_root.find_child("barn", true, false) as Node3D
		if b: critters.barn = b.global_transform.basis * Vector3(1, 0, 0) * 5.4 / b.global_transform.basis.get_scale().x + b.global_position # (just outside its big doors)
	critters.roost = extras.roost_at
	critters.abed = sky.time > 0.86 or sky.time < 0.23 or (weather.kind == "rain" and weather.rain > 0.5)
	critters.update(dt, player.pos, rig.camera)
	# the rooster crows at sunup
	if sky.time > 0.245 and sky.time < 0.3 and crow_day != sky.day and critters.rooster != null:
		crow_day = sky.day; critters.rooster.crowT = 1.8
		var rp: Vector3 = critters.rooster.puppet.group.position; var rd := Vector2(player.pos.x - rp.x, player.pos.z - rp.z).length()
		if rd < 90.0: sound.crow(maxf(0.1, 1.0 - rd / 90.0))
	# milking the cow, shearing the sheep
	var beast = critters.livestock_near(player.pos) if active and not build.active and not player.dead else null
	var ready: bool = beast != null and (beast.milkedDay != sky.day if beast.type == "cow" else not (beast.shornDay and sky.day - beast.shornDay < 2))
	if beast != null and input.hit("KeyE"):
		critters.hold(beast)
		if not ready: hud.toast("She's been milked today; she'll have more tomorrow." if beast.type == "cow" else "Her fleece is still growing back.")
		elif beast.type == "cow":
			beast.milkedDay = sky.day; journal.record("livestock"); sound.pick(); inventory.milk += 1; hud.toast("A pail of warm, frothy milk. (+1 milk)")
		else:
			beast.shornDay = sky.day; journal.record("livestock"); sound.tear(); critters.set_shorn(beast, true)
			var n := 2 + randi() % 2; inventory.wool += n
			hud.toast("Snip, snip: an armful of fleece. (+%d wool)" % n)
	for c in critters.list:
		if c.shornDay and sky.day - c.shornDay >= 2: c.shornDay = 0; critters.set_shorn(c, false)
	if beast != null: beast_prompt = ("[E] Milk the cow" if beast.type == "cow" else "[E] Shear the sheep") if ready else ("Already milked today" if beast.type == "cow" else "Fleece still growing back")

# ------------------------------------------------------------------ the bosses (the player's ask)
## Each boss (Boss.SPECS): his lair out in the county, his hooks, and the gate he holds on the town. Second Street
## won't go up till Mad Jebediah's stolen deed is back at the assay office, Third Street till Big Angus's timber rights are.
func _make_boss() -> void:
	var avoid: Array = [homestead.spawn] + camp.list.map(func(c): return c.at) + jumpers.camps.map(func(c): return c.at)
	for id in Boss.ORDER:
		var b := Boss.new(id); add_child(b)
		b.setup(town.at, avoid, world); avoid.append(b.at)
		b.hooks = _boss_hooks(b)
		b.blocker = func(q: Vector3) -> Vector3: return build.collide(q, 1.1)
		bosses.append(b)
	boss = bosses[0]
	_boss_board.call_deferred() # (the wanted board up from the first day; remade on load)
	town.gate = func(n: int) -> bool: return not bosses.any(func(b): return b.spec.street == n and not b.delivered)
	town.on_gossip = func(_k) -> void: _boss_gossip()
	town.on_gate = func(n: int) -> void:
		for b in bosses:
			if b.spec.street == n:
				hud.toast("%s holds %s. The town can't grow till you win it back." % [b.title(), b.spec.prize])

func _boss_hooks(b: Boss) -> Dictionary:
	var nm := b.title()
	return {
		"on_hit": func(dmg: int) -> void:
			var out := player.hurt(dmg, 0.33 if tools.has("coat") else 0.0); hud.hurt(); sound.knock()
			if out: death_timer = 3.0; hud.toast("%s laughs over you. You come to a long while later, far from his camp." % nm),
		"on_throw": func() -> void: sound.tear(),
		"on_land": func(at: Vector3) -> void:
			if b.spec.weapon == "dynamite": sound.bang(true); confetti.burst(at + Vector3(0, 0.4, 0), [0xe8a030, 0xc4362f, 0x6b5b49], 22, 1.8) # (a blast of dirt and sparks)
			else: sound.chop(),
		"on_slam": func(at: Vector3) -> void:
			sound.land(); confetti.burst(at + Vector3(0, 0.3, 0), [0x8a6a48, 0xc8b48a], 14, 1.2)
			var dd := Vector2(at.x - player.pos.x, at.z - player.pos.z).length()
			if dd < 12.0: rig.shake = maxf(rig.shake, 0.12 * (1.0 - dd / 12.0)), # (felt underfoot close by)
		"on_spotted": func() -> void:
			hud.toast({"pick": "%s! The giant roars and hefts a pickaxe. Watch where they land.", "axe": "%s! The giant lumberjack grins and spins a hand axe. They fly fast and flat.",
				"dynamite": "%s! The baron strikes a match. Lit dynamite: get clear of the mark."}[b.spec.weapon] % nm.to_upper()),
		"on_fall": func(at: Vector3) -> void:
			sound.tear(); journal.record("boss")
			# he comes down like a felled pine: the ground shakes, dust flies, and the fiddle runs up in triumph
			sound.bang(true); rig.shake = 0.35
			confetti.burst(at + Vector3(0, 0.5, 0), [0x8a6a48, 0xc8b48a, 0xe8dcc0], 40, 2.6)
			var fl := [64, 67, 71, 76, 79, 76, 81]
			for i in fl.size(): sound.play("fiddle_%d" % fl[i], 0.45, 0.55 + i * 0.11)
			if b.returns > 0 and b.delivered: # (a rematch: nothing more to take home but the sheriff's reward)
				_boss_board(); hud.toast("%s goes down again. The sheriff will want to hear of it." % nm); return
			_drop_prize(b, at + Vector3(1.2, 0, 0.6)); _boss_board() # (his poster comes down)
			hud.toast("%s crashes down like a felled pine. %s spills from his coat." % [nm, b.spec.prize.capitalize()]),
	}

func _bosses_save() -> Dictionary:
	var out := {}
	for b in bosses: out[b.id] = b.save()
	return out
## The boss whose prize you're carrying, if any.
func _prize_held():
	for b in bosses: if inventory.get(b.spec.prize_key, 0) > 0: return b
	return null
## The boss holding back the next street the town is ready for, if any.
func _boss_holding():
	for b in bosses:
		var n: int = b.spec.street
		if town.street_done(n - 1) and not n in town.opened and not b.delivered: return b
	return null

## A boss's prize: a roll of parchment tied with a red ribbon, lying in the dirt (it never spoils like a poke does).
func _drop_prize(b: Boss, at: Vector3) -> void:
	var n := Node3D.new()
	var roll := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.07; cm.height = 0.62; cm.radial_segments = 10
	roll.mesh = cm; roll.material_override = PaperMats.paper(Color("efe0b8")); roll.rotation.z = PI / 2.0; roll.position.y = 0.08; n.add_child(roll)
	var rib := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 0.075; rm.bottom_radius = 0.075; rm.height = 0.06; rm.radial_segments = 10
	rib.mesh = rm; rib.material_override = PaperMats.paper(Color("a8352a") if b.id == "jebediah" else Color("3a6a3a")); rib.rotation.z = PI / 2.0; rib.position.y = 0.08; n.add_child(rib)
	at.y = Terrain.get_height(at.x, at.z); n.position = at; n.rotation.y = randf() * TAU; n.scale = Vector3.ONE * 1.4
	add_child(n)
	drops.append({"node": n, "pos": at, "what": b.spec.prize, "loot": {b.spec.prize_key: 1}, "day": sky.day, "t": randf() * 6.0, "keep": true})

## A prize back at the assay office: his street goes up for good (and the assayer pays a finder's fee).
func _hand_in(b: Boss) -> void:
	var pay: int = b.spec.get("reward", 40)
	inventory[b.spec.prize_key] = 0; b.delivered = true; inventory.dollars = inventory.get("dollars", 0) + pay
	sound.craft(); journal.record("deed")
	if b.id == "crane": hud.toast("The assayer burns the mortgage in the stove. \"Cold Glitter Creek owes no man.\" +$%d" % pay)
	else: hud.toast("The assayer files %s. \"Cold Glitter Creek grows again.\" +$%d" % [b.spec.prize, pay])
	town.grow()
	_trophies()
	celebrate_day = sky.day if sky.time < 0.85 else sky.day + 1
	hud.toast("Folks are saying there'll be fireworks tonight.")

func _trophies() -> void:
	town.set_trophies(bosses.filter(func(b): return b.delivered).map(func(b): return b.id))
	_boss_board()

## While a boss holds the town back (or his prize lies where he fell, not yet picked up), the rumour note tells where
## his lair is, with the arrow and the paces; gone once you're at the lair or carrying the prize.
const BOSS_TALK := {"jebediah": "Folks say Mad Jebediah sits on the town's deed at his diggings", "angus": "Loggers say Big Angus keeps the timber rights at his camp in the pines",
	"crane": "The bank clerk says Thaddeus Crane keeps the mortgage in his fenced house"}
func _boss_rumour():
	var b = _boss_holding()
	if b == null or _prize_held() != null: return null
	var to := Vector3(b.at.x - player.pos.x, 0, b.at.z - player.pos.z); var d := to.length()
	if d < 40.0: return null
	var text: String = ("%s lies where %s fell" % [b.spec.prize.capitalize(), b.title()]) if b.beaten else BOSS_TALK.get(b.id, b.title())
	return {"key": "boss:" + b.id, "text": text, "paces": roundi(d * 1.3 / 10.0) * 10, "dir": to / d}

## A beaten boss's lair is yours to work, a go a day: Jebediah's old diggings give up gold (and now and then silver),
## Angus's woodpile an armload of split wood, Crane's company stores a few bars of iron. E at the lair's "mouth" (the
## mine, the chopping block, the porch).
const SPOILS := {"jebediah": ["Work Jebediah's old diggings", {"gold": 2}], "angus": ["Take wood from Angus's pile", {"wood": 8}],
	"crane": ["Help yourself to Crane's company stores", {"iron": 3}]}
func _boss_spoils(active: bool) -> bool:
	if not active or player.dead or build.active: return false
	for b in bosses:
		if not b.beaten or b.back or Vector2(player.pos.x - b.mouth.x, player.pos.z - b.mouth.z).length() > 4.0: continue
		var sp: Array = SPOILS[b.id]
		if b.spoils_day == sky.day: beast_prompt = "Nothing more here today: come back tomorrow"; return true
		beast_prompt = "[E] %s" % sp[0]
		if input.hit("KeyE"):
			b.spoils_day = sky.day
			var got: Dictionary = sp[1].duplicate()
			if b.id == "jebediah" and randf() < 0.35: got.silver = 1
			var bits := []
			for k in got: inventory[k] = inventory.get(k, 0) + int(got[k]); bits.append("+%d %s" % [got[k], k])
			sound.pick(); hud.toast("%s: %s." % [sp[0].replace("Work ", "You work ").replace("Take ", "You take ").replace("Help yourself to", "You help yourself to"), ", ".join(bits)])
			if b.id == "jebediah": settlers.discover("gold")
		return true
	return false

## Where the town stands (shown beside its name; it rises as the bosses fall and their prizes come home).
func town_rank() -> String:
	if bosses.size() > 2 and bosses[2].delivered: return "a free town"
	if 1 in town.opened: return "the county seat"
	if 0 in town.opened: return "a boom town"
	return "a mining camp"

## Now and then a keeper you pass has a word about the boss holding the town back (one a day at most, a third of the
## time), or, once they're all beaten, about how the town's coming up.
const GOSSIP := {"jebediah": ["\"Jebediah's dug that mine since before the town.\"", "\"Jebediah? Throws picks like other men throw stones.\"",
	"\"Without that deed, Second Street's just a dream.\""], "angus": ["\"Angus cut every tree this side of the river.\"",
	"\"Not a plank in town while Angus has the rights.\"", "\"Keep your head down round Angus: his axes fly flat.\""],
	"crane": ["\"Crane's paper's on every roof in town.\"", "\"Crane keeps blasting powder like folk keep flour.\"",
	"\"Pay off Crane? Better to burn his mortgage, I say.\""], "done": ["\"Free and clear, thanks to you!\"", "\"Hardly know the place, it's grown so.\""]}
var gossip_day := -1
func _boss_gossip() -> void:
	if gossip_day == sky.day or randf() > 0.35: return
	var b = _boss_holding()
	var key: String = b.id if b != null else ("done" if bosses.all(func(q): return q.delivered) else "")
	if key == "": return
	gossip_day = sky.day
	var lines: Array = GOSSIP[key]
	hud.toast(lines[randi() % lines.size()])

## A fight's fiddle: while a boss is on you, a low driving E-minor figure, bowed softly under everything; once he's
## riled, quicker and harder bowed. (The baked reel notes, D4 to A5.)
const BOSS_TUNE := [64, 64, 67, 64, 71, 69, 67, 66, 64, 64, 67, 69, 71, 72, 71, 67]
var tune_t := 0.0
var tune_i := 0
func _boss_tune(dt: float, fb) -> void:
	if fb == null: tune_i = 0; tune_t = 0.0; return
	var riled: bool = fb.hp_frac() < 0.5
	tune_t -= dt
	if tune_t > 0.0: return
	tune_t = 0.2 if riled else 0.28
	var n: int = BOSS_TUNE[tune_i % BOSS_TUNE.size()]
	sound.play("fiddle_%d" % n, (0.4 if riled else 0.32) if tune_i % 4 == 0 else (0.3 if riled else 0.22))
	tune_i += 1

# ------------------------------------------------------------------ the army's forts (the player's ask)
## Two or three forts a county, clear of home, the town, the lodges, the jumpers and the bosses. The troopers let
## you be; strike one and the fort turns out.
func _make_forts() -> void:
	forts = ArmyForts.new(); add_child(forts)
	var avoid: Array = [homestead.spawn, town.at] + camp.list.map(func(c): return c.at) + jumpers.camps.map(func(c): return c.at) + bosses.map(func(b): return b.at)
	forts.setup(homestead.spawn, avoid, world)
	forts.blocker = func(q: Vector3) -> Vector3: return build.collide(q, 0.4)
	forts.setup_patrols(town.at)
	fort_hooks = {
		"on_hit": func(dmg: int) -> void:
			var out := player.hurt(dmg, 0.33 if tools.has("coat") else 0.0); hud.hurt(); sound.knock()
			if out: death_timer = 3.0; hud.toast("The troopers drag you out past the gate and leave you there. You come to a long while later."),
		"on_shoot": func(_at: Vector3) -> void: sound.bang(),
		"on_fall": func(m: Dictionary) -> void:
			sound.knock(); var p: Vector3 = m.fig.root.position
			add_drop("prop_pouch", 0.45, Vector3(p.x + 0.5, 0, p.z + 0.3), "his haversack", [{"cartridges": 6}, {"cartridges": 4, "dollars": 3}, {"dollars": 7}, {"cartridges": 8}][randi() % 4])
			hud.toast("The trooper goes down. His haversack lies in the dirt."),
		"on_angry": func(f: Dictionary) -> void: hud.toast("You've struck a trooper! %s turns out, rifles up. Get clear!" % f.name),
		"on_first": func(f: Dictionary) -> void: hud.toast("%s: the colours over the stockade, a sentry at the gate. The troopers nod you by." % f.name),
	}

## A wayfarer at his fire: the first time, who he is and what he says; then E for what he offers, once a day.
func _wayfarer(active: bool) -> bool:
	if not active or player.dead or build.active: return false
	var c = wayfarers.near_camper(player.pos)
	if c == null: return false
	var k: Dictionary = c.kind
	if not c.met:
		c.met = true; hud.toast("%s: \"%s\"" % [String(k.who).get_slice(",", 0), k.hello])
	if c.day == sky.day: beast_prompt = "%s: \"Come by again tomorrow.\"" % String(k.who).get_slice(",", 0); return true
	beast_prompt = k.act
	if not input.hit("KeyE"): return true
	var inv := inventory; var done := true
	match k.id:
		"surveyor":
			hud.county_map.reveal(c.at.x, c.at.z, 300.0); sound.tear()
			hud.toast("He unrolls his map and you copy out the country for a good way round (M).")
		"peddler":
			if inv.get("dollars", 0) < 3: hud.toast("\"Three dollars, friend. Come back when you're flush.\""); done = false
			else: inv.dollars -= 3; inv.rope = inv.get("rope", 0) + 1; sound.craft(); hud.toast("A good coil of hemp rope (+1 rope).")
		"preacher":
			player.health = player.max_health; player.stamina = player.max_stamina; sound.lullaby()
			hud.toast("He lays a hand on your shoulder and says a few plain words. You feel mended.")
		"buyer":
			if inv.get("gold", 0) <= 0: hud.toast("\"No colour? Then we've no business today.\""); done = false
			else: inv.gold -= 1; inv.dollars = inv.get("dollars", 0) + 6; fortune += 6; sound.craft(); hud.toast("He weighs your pinch and counts out six silver dollars (+$6).")
		"drover":
			if inv.get("pelt", 0) <= 0: hud.toast("\"No hides on you? Bring me one and the jerky's yours.\""); done = false
			else: inv.pelt -= 1; inv.venison = inv.get("venison", 0) + 3; sound.pick(); hud.toast("A hide for three strips of jerky (+3 venison).")
		"widow":
			var meal = null
			for m in Wayfarers.MEALS: if inv.get(m, 0) > 0: meal = m; break
			if meal == null: hud.toast("You've nothing cooked to give. Bread, biscuits, pie: anything would do."); done = false
			else:
				inv[meal] -= 1; inv.silver = inv.get("silver", 0) + 1; sound.lullaby()
				hud.toast("The children fall on it. She presses her late husband's silver into your hand (+1 silver).")
	if done: c.day = sky.day
	return true

## The fort's officer (the player's ask: the forts' troopers as task givers): he'll pay to have the nearest claim
## jumpers' camp cleared out (marked on your map); back at the fort once it's done, $30 and a box of cartridges; in
## between, the sutler's cartridges through him, six for $3.
func _fort_officer(active: bool) -> bool:
	if not active or player.dead or build.active: return false
	var f = forts.officer_near(player.pos)
	if f == null: return false
	var inv := inventory
	if f.job >= 0 and f.job < jumpers.camps.size():
		var jc: Dictionary = jumpers.camps[f.job]
		if jc.cleared_day >= f.job_day:
			beast_prompt = "[E] Report the claim jumpers cleared out"
			if input.hit("KeyE"):
				f.job = -1; inv.dollars = inv.get("dollars", 0) + 30; inv.cartridges = inv.get("cartridges", 0) + 10; sound.craft(); journal.record("bounty")
				hud.toast("\"Good work. The territory's obliged to you.\" +$30, +10 cartridges")
			return true
		if escort_day != sky.day and input.hit("KeyR"):
			if inv.get("dollars", 0) < ESCORT_COST: hud.toast("\"A detail's $%d a day, citizen.\"" % ESCORT_COST)
			else: inv.dollars -= ESCORT_COST; _hire_escort(f); sound.craft(); hud.toast("Two troopers fall in behind you. They'll ride with you till sundown.")
			return true
		beast_prompt = "[E] Buy six cartridges from the sutler ($3)" + ("   [R] Hire an escort ($%d)" % ESCORT_COST if escort_day != sky.day else "")
		if input.hit("KeyE"):
			if inv.get("dollars", 0) < 3: hud.toast("\"Three dollars, citizen. Army doesn't give credit.\"")
			else: inv.dollars -= 3; inv.cartridges = inv.get("cartridges", 0) + 6; sound.pick(); hud.toast("Six rounds in a paper box (+6 cartridges). Those jumpers are still out there.")
		return true
	if escort_day != sky.day and input.hit("KeyR"):
		if inv.get("dollars", 0) < ESCORT_COST: hud.toast("\"A detail's $%d a day, citizen.\"" % ESCORT_COST)
		else: inv.dollars -= ESCORT_COST; _hire_escort(f); sound.craft(); hud.toast("Two troopers fall in behind you. They'll ride with you till sundown.")
		return true
	beast_prompt = "[E] Ask the officer if there's work   [R] Hire an escort ($%d)" % ESCORT_COST if escort_day != sky.day else "[E] Ask the officer if there's work"
	if input.hit("KeyE"):
		var best := -1; var bd := INF
		for i in jumpers.camps.size():
			var c: Dictionary = jumpers.camps[i]
			if sky.day < c.cleared_day + ClaimJumpers.RESPAWN_DAYS: continue
			var d := Vector2(c.at.x - f.at.x, c.at.z - f.at.z).length()
			if d < bd: bd = d; best = i
		if best < 0: hud.toast("\"Quiet out there just now. Come back in a few days.\"")
		else:
			f.job = best; f.job_day = sky.day; var jc: Dictionary = jumpers.camps[best]
			hud.county_map.reveal(jc.at.x, jc.at.z, 30.0); sound.place()
			hud.toast("\"Claim jumpers, %d paces off. Clear 'em out and there's $30 in it.\" (marked on your map)" % (roundi(bd * 1.3 / 10.0) * 10))
	return true

## The boss chip: the next boss to beat (or one back for a rematch, or a fallen one whose prize still lies at his camp),
## always on the top bar till that's done, whatever else NEXT or the rumour note is saying; hidden in his fight, near
## his camp, or while you carry his prize (the homeward chip points you to the assay office then).
func _update_boss_chip() -> void:
	var b = null
	for q in bosses:
		if q.back or not q.beaten or (q.beaten and not q.delivered and inventory.get(q.spec.prize_key, 0) <= 0): b = q; break
	if b == null or player.dead or b.fighting(): hud.set_boss_chip(false); return
	var h := Vector2(b.at.x - player.pos.x, b.at.z - player.pos.z); var d := h.length()
	if d < 35.0: hud.set_boss_chip(false); return
	var cam := rig.camera; var a := cam.unproject_position(player.pos); var e := cam.unproject_position(player.pos + Vector3(h.x / d, 0, h.y / d) * 4.0)
	var what: String = ("%s's camp (%s)" % [b.title(), b.spec.prize.trim_prefix("the ")]) if b.beaten and not b.back else b.title()
	hud.set_boss_chip(true, rad_to_deg(atan2(e.x - a.x, -(e.y - a.y))), "%s, %d paces" % [what, roundi(d * 1.3 / 10.0) * 10])

# ------------------------------------------------------------------ an escort (the fort's troopers, for hire)
## Two of the fort's troopers for the day, $20: they keep a few paces behind you at whatever pace you go and fire on
## what's fighting you (a boss, claim jumpers, a treasure guardian or a night prowler): a rifle ball (6) every couple of
## seconds within 25 m. They don't fire on the native camps' people. At sundown (or if you strike one) they ride home.
const ESCORT_COST := 20
var escort: Array = []
var escort_day := -1
func _hire_escort(f: Dictionary) -> void:
	_dismiss_escort()
	escort_day = sky.day
	for i in 2:
		var nm: String = ArmyForts.SOLDIERS[(i + 2) % ArmyForts.SOLDIERS.size()]
		if not ModelFigure.has_folk(nm): nm = ArmyForts.STAND_INS[i]
		var fig := ModelFigure.new(nm); fig.borrow_clip("run", "folk_native_warrior")
		var rifle := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(0.05, 0.06, 1.05); rifle.mesh = rm
		rifle.material_override = PaperMats.paper(Color("4a3a2c")); rifle.rotation.x = PI / 2.0; rifle.position = Vector3(0, 0.05, 0.1); fig.hands[1].add_child(rifle)
		var p0: Vector3 = player.pos + Vector3((i - 0.5) * 2.0, 0, 2.0); p0.y = Terrain.get_height(p0.x, p0.z)
		fig.root.position = p0; add_child(fig.root)
		escort.append({"fig": fig, "cool": 1.0 + i * 0.8, "speed": 0.0, "side": (i - 0.5) * 2.4})
func _dismiss_escort() -> void:
	for m in escort: (m.fig as ModelFigure).root.queue_free()
	escort = []
## What the escort will fire on: anything fighting you, never the native camps.
func _escort_targets() -> Array:
	var out := []
	for b in bosses: if b.fighting(): out.append_array(b.targets())
	for c in jumpers.camps:
		for m in c.men: if not m.dead and m.state == "chase": out.append({"pos": m.fig.root.position, "j": m})
	for e in enemies.list: if not e.dying and Enemies.pos(e).distance_to(player.pos) < 20.0: out.append({"pos": Enemies.pos(e), "enemy": e})
	return out
func _escort_update(dt: float) -> void:
	if escort.is_empty(): return
	if sky.day != escort_day or sky.time > 0.8 or sky.time < 0.2:
		_dismiss_escort(); hud.toast("Your escort tips their hats and rides back to the fort."); return
	var tg := _escort_targets()
	var f := player.forward()
	for m in escort:
		var fig: ModelFigure = m.fig; var r := fig.root; var pos := r.position
		var want: Vector3 = player.pos - f * 3.0 + Vector3(-f.z, 0, f.x) * m.side
		var to := Vector3(want.x - pos.x, 0, want.z - pos.z); var d := to.length()
		var spd := 0.0
		if d > 0.6: spd = clampf(d * 2.2, 1.5, 12.0); var stp := to / d * minf(d, spd * dt); pos.x += stp.x; pos.z += stp.z
		if d > 60.0: pos = want # (left far behind: they catch up off-screen)
		pos.y = Terrain.get_height(pos.x, pos.z); r.position = pos
		m.speed = lerpf(m.speed, spd, minf(1.0, dt * 8.0))
		m.cool -= dt
		var best = null; var bd := 25.0
		for t in tg: var dd: float = (t.pos as Vector3).distance_to(pos); if dd < bd: bd = dd; best = t
		if best != null:
			r.rotation.y = lerp_angle(r.rotation.y, atan2(best.pos.x - pos.x, best.pos.z - pos.z), minf(1.0, dt * 8.0))
			if m.cool <= 0.0:
				m.cool = 2.0 + randf() * 0.8; sound.bang()
				if randf() < 0.75: hunting.on_target.call(best, {"dmg": 6})
		elif spd > 0.3: r.rotation.y = lerp_angle(r.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 6.0))
		fig.update(dt, m.speed, null)
