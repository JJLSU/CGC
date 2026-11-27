class_name Quality
extends RefCounted
## Graphics quality (main.js QUALITY, applyQuality, the O key and the auto step-down) and the depth of field switch
## (P). Levels high / medium / low, or auto: starts high and, after a 6 s warm-up, three seconds in a row under 50
## fps steps it down one level (never up). Kept in user://paperfjord.quality.json as the page keeps it in
## localStorage ('paperfjord.quality': {mode, level}).
##
## What each level sets, the page's level mapped onto Godot's renderer:
##   ratio   the pixel ratio cap (min(devicePixelRatio, ratio)): the 3D render scale against the screen's own scale
##   shadow  the sun's shadow map: the directional shadow atlas (4096 holds the two 2048 splits on high)
##   soft    the shadow penumbra (PCF radius 5/4/3): the sun's shadow blur, and the soft-shadow filter quality
##   post    ao (SSAO), bloom (glow), dof (the lens blur), line (the cut-edge line) as post.js builds them
## The page's shadowEvery (the shadow map redrawn every 2nd/3rd frame while the view is still) has no switch in Godot's
## renderer; left out.
const LEVELS := {
	"high": {"ratio": 2.0, "shadow": 4096, "soft": 5, "filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "ao": true, "bloom": true, "dof": true, "line": true},
	"medium": {"ratio": 1.5, "shadow": 2048, "soft": 4, "filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "ao": true, "bloom": false, "dof": true, "line": true},
	"low": {"ratio": 1.0, "shadow": 2048, "soft": 3, "filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "ao": false, "bloom": false, "dof": false, "line": false},
}
const ORDER := ["auto", "high", "medium", "low"]
const PATH := "user://paperfjord.quality.json"

var main: Node
var mode := "auto"
var level := "high"
var dof_on := true        ## P (the page's dofEnabled uniform: kept across level changes)
var low_seconds := 0
var started_at := 0
var persist := true       ## (tests leave the player's setting alone)
var auto_ok := true       ## (tests: no stepping down on a slow headless run)
var fps_rate := 0         ## frames in the last second (the dev badge shows it, 22d)
var _frames := 0
var _since := 0

func _init(m: Node, keep := true) -> void:
	main = m; persist = keep; auto_ok = keep
	started_at = Time.get_ticks_msec(); _since = started_at
	if persist and FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary and LEVELS.has(d.get("level", "")):
			mode = "manual" if d.get("mode") == "manual" else "auto"; level = d.level

func apply(lv: String) -> void:
	var q: Dictionary = LEVELS[lv]
	level = lv
	var dpr := maxf(1.0, DisplayServer.screen_get_scale())
	main.get_viewport().scaling_3d_scale = minf(dpr, q.ratio) / dpr
	RenderingServer.directional_shadow_atlas_set_size(q.shadow, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(q.filter)
	main.sky.sun.shadow_blur = q.soft / 5.0
	# on high, the sun's shadow in four slices (crisp at your feet, soft and cheap far off) instead of two
	var sun: DirectionalLight3D = main.sky.sun
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if lv == "high" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.08; sun.directional_shadow_split_2 = 0.22; sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = lv == "high"
	var env: Environment = main.env.environment
	env.ssao_enabled = q.ao
	# contact shadow: where a card stands on the ground, a wall meets a porch, a figure a step: a little deeper and a little
	# wider, and a touch of it in the sun too (so things sit on the land, not just in the shade)
	env.ssao_radius = 1.1; env.ssao_intensity = 1.7; env.ssao_power = 1.4; env.ssao_detail = 0.6; env.ssao_light_affect = 0.25
	# screen-space indirect light (the engine's own bounce: sunlit ground and walls tint the shade beside them), on high
	# and medium; on low the post pass's faked bounce does it alone (its share back to whole)
	env.ssil_enabled = q.ao; env.ssil_radius = 6.0; env.ssil_intensity = 1.4; env.ssil_sharpness = 0.98; env.ssil_normal_rejection = 1.0
	main.post.set_shader_parameter("bounce_k", 0.45 if q.ao else 1.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50.0, 300.0) # (half resolution: its bounce is soft anyway)
	env.glow_enabled = q.bloom
	main.post.set_shader_parameter("line_enabled", q.line)
	_set_dof()
	if persist:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify({"mode": mode, "level": level})); f.close()

func _set_dof() -> void:
	main.post.set_shader_parameter("dof_enabled", 1.0 if dof_on and LEVELS[level].dof and not main.rig.first_person else 0.0) # (no tilt-shift through his own eyes)

## O: auto → high → medium → low → auto. Returns the new setting's name for the toast.
func cycle() -> String:
	var cur := "auto" if mode == "auto" else level
	var next: String = ORDER[(ORDER.find(cur) + 1) % ORDER.size()]
	if next == "auto": mode = "auto"; low_seconds = 0; apply("high")
	else: mode = "manual"; apply(next)
	return next

## P: the lens blur on or off.
func toggle_dof() -> bool:
	dof_on = not dof_on; _set_dof()
	return dof_on

## Called every frame: counts frames, and once a second checks the auto step-down. Returns a toast or "".
func tick() -> String:
	_frames += 1
	var now := Time.get_ticks_msec()
	if now - _since < 1000: return ""
	fps_rate = roundi(_frames * 1000.0 / (now - _since)); _frames = 0; _since = now
	if mode == "auto" and auto_ok and now - started_at > 6000 and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
		low_seconds = low_seconds + 1 if fps_rate < 50 else 0
		if low_seconds >= 3 and level != "low":
			apply("medium" if level == "high" else "low"); low_seconds = 0
			return "Graphics lowered to %s for smoother play (O to change)" % level
	return ""
