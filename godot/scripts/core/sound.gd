class_name Sound
extends Node
## audio.js, the cozy soundscape. The web synthesises everything with WebAudio; here every one-shot, every land's
## voice, the town's hymn, reel and piano notes and the four banjo tunes are the web's own graph rendered offline
## (an OfflineAudioContext running audio.js's Sound, reverb and limiter included: assets/baked/sound/*.wav, several
## random variants of each), played at the web's levels. The beds that never stop (wind, water lapping, rain) are
## white noise through filter buses, steered every frame the way audio.js steers its BiquadFilters.
##   ambience: wind (each land its own), water near shore, rain (a muffled patter under a roof), birdsong by day,
##             a cricket now and then by night, fire crackle, each wild land's own creatures
##   music:    a lone clawhammer banjo, one of four tunes by the time of day, then a quiet spell
##   sfx:      chop, mine, pick, tree fall, paper footsteps, jump/land, build, tear, craft, eat, and the creatures

const LAND_WIND := {"home": [1.0, 320.0], "hollows": [1.1, 360.0], "breaks": [1.9, 620.0], "fen": [0.6, 300.0], "prairie": [1.7, 260.0], "pines": [1.6, 200.0]}
const AMB := 0.55 * 0.85   ## (the ambience bus and the master, which the baked one-shots already carry)
const TUNES := [["tune_sunup", 0.2, 0.42], ["tune_hayfield", 0.42, 0.7], ["tune_porch", 0.7, 0.82]] ## (else the lullaby)

var bank := {}             ## name -> [AudioStream] (variants)
var pool: Array = []
var queue: Array = []      ## [[t, name, vol]] one-shots waiting their moment
var muted := false
var t := 0.0
var bird_t := 2.0
var cricket_t := 1.0
var note_t := 3.0
var crackle_t := 0.0
var land_t := 6.0
var music := AudioStreamPlayer.new()
var beds := {}             ## wind/water/rain -> {player, bus, fx, g}

func _ready() -> void:
	# the bank: every baked wav by name, and its variants under the name without the _N
	var dir := "res://assets/baked/sound/"
	for f in DirAccess.get_files_at(dir):
		var stem := f.trim_suffix(".import").trim_suffix(".remap")
		if not stem.ends_with(".wav"): continue
		stem = stem.trim_suffix(".wav")
		if bank.has(stem): continue
		var s: AudioStream = load(dir + stem + ".wav")
		if s == null: continue
		bank[stem] = [s]
		var cut := stem.rfind("_")
		if cut > 0 and stem.substr(cut + 1).is_valid_int():
			var base := stem.substr(0, cut)
			if not bank.has(base) or not bank[base].has(s): bank[base] = bank.get(base, []) + [s]
	for i in 32:
		var p := AudioStreamPlayer.new(); add_child(p); pool.append(p)
	music.volume_db = 0.0; add_child(music)
	# the beds: a loop of white noise through a filter bus each
	var noise := _noise(2.0)
	for spec in [["Wind", "band", 420.0, 0.6], ["Water", "low", 650.0, 1.25], ["Rain", "band", 3200.0, 0.4]]: # (cutoff, and the web's Q as the resonance)
		AudioServer.add_bus(); var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, spec[0]); AudioServer.set_bus_send(bi, "Master")
		var fx: AudioEffectFilter = AudioEffectBandPassFilter.new() if spec[1] == "band" else AudioEffectLowPassFilter.new()
		fx.cutoff_hz = spec[2]; fx.resonance = spec[3]
		AudioServer.add_bus_effect(bi, fx)
		var pl := AudioStreamPlayer.new(); pl.stream = noise; pl.bus = spec[0]; pl.volume_db = -80.0; add_child(pl); pl.play(randf() * 1.5)
		beds[String(spec[0]).to_lower()] = {"player": pl, "fx": fx, "g": 0.0}

static func _noise(secs: float) -> AudioStreamWAV:
	var n := int(44100 * secs); var data := PackedByteArray(); data.resize(n * 2)
	for i in n: data.encode_s16(i * 2, int((randf() * 2.0 - 1.0) * 32000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = 44100; w.stereo = false; w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = n
	return w

func toggle_mute() -> bool:
	muted = not muted; AudioServer.set_bus_mute(0, muted); return muted

## Play a baked sound (a random variant if there are several) at vol (linear, as audio.js's vol arguments), after delay s.
func play(name: String, vol := 1.0, delay := 0.0) -> void:
	if not bank.has(name) or vol <= 0.002: return
	if delay > 0.0: queue.append([t + delay, name, vol]); return
	var list: Array = bank[name]; var s: AudioStream = list[randi() % list.size()]
	var p: AudioStreamPlayer = null
	for q in pool: if not q.playing: p = q; break
	if p == null: p = pool[randi() % pool.size()] # (all busy: the oldest-sounding gives way)
	p.stream = s; p.volume_db = linear_to_db(vol); p.pitch_scale = 1.0; p.play()

# ------------------------------------------------------------------ audio.js's game sounds, by name
func chop() -> void: play("chop")
func mine() -> void: play("mine")
func pick() -> void: play("pick")
func tree_fall() -> void: play("treefall")
func step(surface := "grass") -> void: play("step_" + surface)
func jump() -> void: play("jump")
func land() -> void: play("land")
func splash() -> void: play("splash")
func place() -> void: play("place")
func tear() -> void: play("tear")
func knock() -> void: play("knock")
func craft() -> void: play("craft")
func eat() -> void: play("eat")
func denied() -> void: play("denied")
func woof() -> void: play("woof")
func hoot() -> void: play("hoot")
func lullaby() -> void: play("lullaby")
func bite() -> void: play("bite")
func rustle() -> void: play("rustle")
func purr() -> void: play("purr")
func honk() -> void: play("honk")
func plop() -> void: play("plop")
func caw() -> void: play("caw")
func growl() -> void: play("growl")
func click() -> void: play("click")
func horse_call() -> void: play("horsecall")
func bang(big := false) -> void: play("bang_big" if big else "bang")
func stamp(v := 1.0) -> void: play("stamp", v)
func whistle(v := 1.0) -> void: play("whistle", v)
func chuff(v := 1.0) -> void: play("chuff", v)
func quack(v := 1.0) -> void: play("quack", v)
func gobble(v := 1.0) -> void: play("gobble", v)
func horn(v := 1.0) -> void: play("horn", v)
func crow(v := 1.0) -> void: play("crow", v)
func howl(v := 1.0, answer := false) -> void: play("howl_answer" if answer else "howl", v)
func pop(v := 1.0) -> void: play("pop", v)
func thunder(v := 1.0) -> void: play("thunder", v)
func moo(v := 1.0) -> void: play("moo", v)
func croak(v := 1.0) -> void: play("croak", v)
## The barn-dance and dance-hall fiddle: one bowed note (baked per note of the reel).
func fiddle(freq: float, _dur := 0.2, vol := 1.0) -> void: play("fiddle_%d" % roundi(69.0 + 12.0 * log(freq / 440.0) / log(2.0)), vol)
## The meeting's hymn: one pump-organ note of the tune (m, beats, bass), baked per note.
func hymn(m: int, beats: int, bass: int, vol := 1.0) -> void: play("hymn_%d_%d_%d" % [m, beats, bass], vol)
## The saloon's honky-tonk piano: one plucked note (baked at the web's 0.07; the left hand an octave down).
func piano(m: int, vol: float) -> void: play("piano_%d" % m, vol / 0.07)
## The church bell's three strokes' worth of partials (baked at the web's 0.12).
func bell(vol: float) -> void: play("bell", vol / 0.12)

# ------------------------------------------------------------------ ambience & music (audio.js update)
func update(dt: float, night: float, near_fire: float, water: float, rain: float, sheltered: bool, time: float, land_id: String, indoors_wind := 1.0) -> void:
	t += dt
	for q in queue.duplicate(): if q[0] <= t: queue.erase(q); play(q[1], q[2])
	var gust := 0.5 + 0.3 * sin(t * 0.21) + 0.2 * sin(t * 0.57 + 1.3)
	var LW: Array = LAND_WIND.get(land_id, LAND_WIND.home)
	_bed("wind", 0.045 * LW[0] * gust * indoors_wind, 1.5, dt); beds.wind.fx.cutoff_hz = lerpf(beds.wind.fx.cutoff_hz, LW[1] + gust * 260.0, 1.0 - exp(-dt / 1.5))
	_bed("rain", (0.055 if sheltered else 0.08) * rain, 0.6, dt) # (the player found the web's 0.09/0.13 a little much); beds.rain.fx.cutoff_hz = lerpf(beds.rain.fx.cutoff_hz, 900.0 if sheltered else 3200.0, 1.0 - exp(-dt / 0.4))
	_bed("water", 0.22 * water * (0.6 + 0.4 * sin(t * 0.9)), 0.3, dt)
	# the land's own voices, now and then (never a constant bed)
	land_t -= dt
	if land_t <= 0.0:
		land_t = 5.0 + randf() * 9.0
		if land_id != "home" and rain < 0.5: _land_sound(land_id, night)
	bird_t -= dt
	if bird_t <= 0.0:
		bird_t = (2.0 if land_id == "home" or land_id == "hollows" else 7.0) + randf() * 6.0 # (fewer songbirds out in the wilds)
		if night < 0.4 and rain < 0.4: play("bird")
	cricket_t -= dt
	if cricket_t <= 0.0:
		cricket_t = 4.0 + randf() * 7.0 # (now and then, not a constant shrill)
		if night > 0.6 and rain < 0.3: play("cricket")
	if near_fire > 0.0:
		crackle_t -= dt
		if crackle_t <= 0.0: crackle_t = 0.04 + randf() * 0.25; play("crackle", near_fire)
	note_t -= dt
	if note_t <= 0.0: _music_box(time)

func _bed(id: String, target: float, tau: float, dt: float) -> void:
	var b: Dictionary = beds[id]
	b.g += (target * AMB - b.g) * (1.0 - exp(-dt / tau))
	b.player.volume_db = linear_to_db(maxf(b.g, 0.00001))

func _land_sound(id: String, night: float) -> void:
	var day := night < 0.4; var r := randf()
	if id == "fen": play(("frog_bull" if night > 0.5 else "frog") if r < 0.6 else "plink")
	elif id == "breaks": play("hawk" if day and r < 0.45 else "pebbles")
	elif id == "prairie": play(("meadowlark" if r < 0.5 else "grasshopper") if day else "cricket")
	elif id == "pines": play("hoot" if not day and r < 0.5 else ("woodpecker" if r < 0.55 else "raven"))
	elif id == "hollows": play("thrush" if day and r < 0.55 else "twig")

## The banjo: one of the four tunes, picked by the time of day, then a quiet spell before the next.
func _music_box(time: float) -> void:
	var name := "tune_lullaby"
	for tu in TUNES: if time > tu[1] and time < tu[2]: name = tu[0]
	if time <= 0.2 or time >= 0.82: name = "tune_lullaby"
	if time > 0.2 and time < 0.42: name = "tune_sunup"
	if not bank.has(name): note_t = 30.0; return
	music.stream = bank[name][0]; music.play()
	note_t = music.stream.get_length() - 3.0 + 12.0 + randf() * 14.0 # (the tune, then a quiet spell)
