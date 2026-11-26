class_name Hud
extends CanvasLayer
## hud.js and index.html's overlay, as Godot Controls: paper cards (cream #f4ecd8, a 1 px edge #d8c9a8, a short warm
## drop shadow, never quite straight) in Patrick Hand (Segoe Print when it isn't installed, as the web's CSS falls
## back). The top bar (Cold Glitter Creek, the clock), the NEXT note, the ledger top right, and along the bottom the loot
## notes, the action hint, health, stamina and fullness bars (they fade out after a few calm seconds) and the tool
## bar (1-8). The pack (I) shows the inventory slots. A red-paper flash when hurt. Icons are the web's own SVGs
## (assets/baked/hud/icons.json, pulled from hud.js) rasterised by Godot.

const PAPER := Color("f4ecd8")
const INK := Color("3a2f25")
const INK_SOFT := Color("6b5b49")
const EDGE := Color("d8c9a8")
const TOOL_NAMES := {"hands": "Hands", "spear": "Ash spear", "rod": "Fishing pole", "bow": "Hunting bow", "revolver": "Six-shooter", "rifle": "Buffalo rifle"}

var font: Font
var icons := {}           ## item -> svg body
var data := {}
var _tex_cache := {}
var root: Control
var clock: Label
var next_card: PanelContainer
var next_label: Label
var ledger: VBoxContainer
var ledger_sig := ""
var ledger_rows := {}
var bottom: VBoxContainer
var toasts: VBoxContainer
var hint: PanelContainer
var hint_label: Label
var health: PanelContainer
var health_fill: ColorRect
var stamina: PanelContainer
var stamina_fill: ColorRect
var fullness: PanelContainer
var fullness_fill: ColorRect
var toolbar: HBoxContainer
var tool_sig := ""
var buildbar: VBoxContainer
var bar_sig := ""
var pack: PanelContainer
var slots: HFlowContainer
var slots_sig := ""
var hurt_rect: ColorRect
var homeward: PanelContainer
var homeward_icon: Control
var homeward_arrow: Control
var homeward_label: Label
var homeward_sig := ""
var fortune: PanelContainer
var fortune_label: Label
var next_urgent := false
var next_t := 0.0
var rumour: PanelContainer
var rumour_arrow: Control
var rumour_text: Label
var rumour_small: Label
var rumour_sig := ""
var map_card: PanelContainer    ## the county map (M or Tab): index.html #map
var county_map: CountyMap
var story: PanelContainer      ## the centre card: a tall tale, a letter, the almanac's day (index.html #story/#letter/#almanac)
var story_box: VBoxContainer
var calendar: PanelContainer   ## the Farmer's Almanac (H): the week at a glance, and what's ready today
var cal_box: VBoxContainer
var sleep_rect: ColorRect
var hurt_t := 0.0
var calm_t := 0.0
var queue: Array = []
var live: Array = []      ## [{card, label, t, text}]
var panels: Array = []    ## the centre panels, one shown at a time (main.js: whichever opened last)
var _panel_order: Array = []

func _ready() -> void:
	layer = 10
	var sf := SystemFont.new(); sf.font_names = PackedStringArray(["Patrick Hand", "Segoe Print", "Comic Sans MS"]); font = sf
	var f := FileAccess.open("res://assets/baked/hud/icons.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text()); icons = data.ICONS
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new(); th.default_font = font; th.default_font_size = 20
	th.set_color("font_color", "Label", INK)
	root.theme = th
	add_child(root)
	_build_hurt()
	sleep_rect = ColorRect.new(); sleep_rect.set_anchors_preset(Control.PRESET_FULL_RECT); sleep_rect.color = Color("2b2a3a"); sleep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zz := label("Zzz… the night passes under the quilt", 26, Color("efe3c4")); zz.set_anchors_preset(Control.PRESET_CENTER); zz.grow_horizontal = Control.GROW_DIRECTION_BOTH; zz.grow_vertical = Control.GROW_DIRECTION_BOTH
	sleep_rect.add_child(zz); sleep_rect.modulate.a = 0.0; sleep_rect.z_index = 5
	root.add_child.call_deferred(sleep_rect)
	_build_top()
	_build_ledger()
	_build_bottom()
	_build_pack()
	_build_cards()
	_build_settlers()
	_build_overlay()
	_build_dev()
	_build_boss()

# ------------------------------------------------------------------ building blocks
func paper_box(pad := Vector4(12, 4, 12, 4), bg := PAPER, left_border := 0, border_col := EDGE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg; sb.border_color = EDGE
	sb.set_border_width_all(1)
	if left_border: sb.border_width_left = left_border; sb.border_color = border_col
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(58 / 255.0, 47 / 255.0, 37 / 255.0, 0.18); sb.shadow_size = 1; sb.shadow_offset = Vector2(2, 3)
	sb.content_margin_left = pad.x; sb.content_margin_top = pad.y; sb.content_margin_right = pad.z; sb.content_margin_bottom = pad.w
	return sb

func card(tilt_deg := 0.0, pad := Vector4(12, 4, 12, 4)) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", paper_box(pad))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.rotation_degrees = tilt_deg
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2.0)
	return c

func label(text := "", size := 20, col := INK) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## An icon from the web's SVG body (viewBox 0 0 32 32), rasterised at px.
func icon(body: String, px := 32) -> TextureRect:
	var key := "%d:%s" % [px, body.hash()]
	if not _tex_cache.has(key):
		var img := Image.new()
		img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">%s</svg>' % body, px / 32.0)
		_tex_cache[key] = ImageTexture.create_from_image(img)
	var tr := TextureRect.new(); tr.texture = _tex_cache[key]
	tr.custom_minimum_size = Vector2(px, px); tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func bar(w: float, h: float, fill_col: Color) -> Array:
	var c := card(0.0, Vector4(2, 2, 2, 2))
	c.custom_minimum_size = Vector2(w, h)
	var holder := Control.new(); holder.custom_minimum_size = Vector2(w - 4, h - 4); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new(); fill.color = fill_col; fill.size = Vector2(w - 4, h - 4); fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill); c.add_child(holder)
	return [c, fill]

# ------------------------------------------------------------------ the layout
func _build_hurt() -> void:
	hurt_rect = ColorRect.new(); hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT); hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new(); var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float k = 0.0;\nvoid fragment(){ vec2 d = UV - 0.5; float r = length(d * vec2(1.0, 1.0)) / 0.7071; COLOR = vec4(170.0/255.0, 40.0/255.0, 30.0/255.0, 0.55 * smoothstep(0.45, 1.0, r) * k); }"
	m.shader = sh; hurt_rect.material = m
	root.add_child(hurt_rect)

func _build_top() -> void:
	var top := HBoxContainer.new(); top.position = Vector2(16, 14); top.add_theme_constant_override("separation", 10); top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := card(-1.2); var ab := HBoxContainer.new(); ab.add_theme_constant_override("separation", 8); ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ab.add_child(label("Cold Glitter Creek")); town_rank = label("", 15, INK_SOFT); town_rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER; ab.add_child(town_rank)
	a.add_child(ab); top.add_child(a)
	var b := card(0.8); clock = label("Day 1"); b.add_child(clock); top.add_child(b)
	# the way home (#homeward): once you're well out, a chip with an arrow that turns with your view (the assay
	# office instead while you carry gold); and the poke (#fortune)
	homeward = card(-0.6, Vector4(12, 4, 12, 4)); homeward.visible = false
	var hr := HBoxContainer.new(); hr.add_theme_constant_override("separation", 6); hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	homeward_icon = Glyph.new(); hr.add_child(homeward_icon)
	homeward_arrow = Glyph.new(); homeward_arrow.kind = "arrow"; hr.add_child(homeward_arrow)
	homeward_label = label("", 16); hr.add_child(homeward_label); homeward.add_child(hr); top.add_child(homeward)
	fortune = card(0.5); fortune_label = label(""); fortune.add_child(fortune_label); fortune.visible = false; top.add_child(fortune)
	root.add_child(top)
	var notes := VBoxContainer.new(); notes.position = Vector2(16, 58); notes.add_theme_constant_override("separation", 8); notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_card = PanelContainer.new(); next_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_card.add_theme_stylebox_override("panel", paper_box(Vector4(12, 5, 12, 5), PAPER, 6, Color("b5473a")))
	next_card.rotation_degrees = -0.5
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label("NEXT", 15, Color("b5473a")))
	next_label = label("", 19); row.add_child(next_label)
	next_card.add_child(row); next_card.visible = false
	notes.add_child(next_card)
	# the rumour note (#rumour): a small torn note under NEXT, an inked arrow turning to point the way
	rumour = card(0.9, Vector4(10, 4, 10, 6)); rumour.custom_minimum_size = Vector2(230, 0); rumour.visible = false
	var rr := HBoxContainer.new(); rr.add_theme_constant_override("separation", 8); rr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rumour_arrow = RumourArrow.new(); rr.add_child(rumour_arrow)
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 0); rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rumour_text = label("", 15); rumour_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rumour_text.custom_minimum_size = Vector2(180, 0); rv.add_child(rumour_text)
	rumour_small = label("", 13, INK_SOFT); rv.add_child(rumour_small); rr.add_child(rv)
	rumour.add_child(rr)
	notes.add_child(rumour)
	root.add_child(notes)

func _build_ledger() -> void:
	var c := card(0.8, Vector4(8, 6, 10, 6))
	c.anchor_left = 1.0; c.anchor_right = 1.0; c.offset_top = 92; c.grow_horizontal = Control.GROW_DIRECTION_BEGIN; c.offset_right = -16
	ledger = VBoxContainer.new(); ledger.add_theme_constant_override("separation", 2); ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ledger)
	root.add_child(c)

func _build_bottom() -> void:
	bottom = VBoxContainer.new(); bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.anchor_left = 0.0; bottom.anchor_right = 1.0; bottom.anchor_top = 1.0; bottom.anchor_bottom = 1.0
	bottom.offset_left = 16; bottom.offset_right = -16; bottom.offset_bottom = -18; bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	toasts = VBoxContainer.new(); toasts.add_theme_constant_override("separation", 6); toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(toasts)
	hint = card(-1.0, Vector4(12, 3, 12, 3)); hint_label = label("", 19); hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_child(hint_label); hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; hint.visible = false
	bottom.add_child(hint)
	buildbar = VBoxContainer.new(); buildbar.mouse_filter = Control.MOUSE_FILTER_IGNORE; buildbar.visible = false
	buildbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; buildbar.add_theme_constant_override("separation", 4)
	bottom.add_child(buildbar)
	for spec in [["health", 240.0, 12.0, Color("c4463a")], ["stamina", 220.0, 12.0, Color("e2b33c")], ["fullness", 180.0, 8.0, Color("b8904a")]]:
		var pair := bar(spec[1], spec[2], spec[3])
		pair[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bottom.add_child(pair[0])
		set(spec[0], pair[0]); set(spec[0] + "_fill", pair[1])
	toolbar = HBoxContainer.new(); toolbar.add_theme_constant_override("separation", 8); toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(toolbar)
	root.add_child(bottom)

func _build_pack() -> void:
	pack = card(-0.5, Vector4(14, 8, 14, 12))
	pack.anchor_left = 0.5; pack.anchor_right = 0.5; pack.anchor_top = CENTRE_Y; pack.anchor_bottom = CENTRE_Y
	pack.grow_horizontal = Control.GROW_DIRECTION_BOTH; pack.grow_vertical = Control.GROW_DIRECTION_BOTH; pack.z_index = 4
	panels.append(pack)
	var v := VBoxContainer.new(); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new(); h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label("Your pack", 18)); h.add_child(label("(I to close)", 13, INK_SOFT)); v.add_child(h)
	slots = HFlowContainer.new(); slots.add_theme_constant_override("h_separation", 10); slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(slots); pack.add_child(v)
	pack.visible = false
	root.add_child(pack)

# ------------------------------------------------------------------ hud.js's API
func set_clock(text: String) -> void: if clock.text != text: clock.text = text
func set_next(text: String, urgent := false) -> void:
	next_label.text = text; next_card.visible = text != ""
	if urgent != next_urgent:
		next_urgent = urgent
		next_card.add_theme_stylebox_override("panel", paper_box(Vector4(12, 5, 12, 5), Color("fbe6d6") if urgent else PAPER, 6, Color("c4302c") if urgent else Color("b5473a")))
		if not urgent: next_card.position.x = 0.0

## The homeward chip: show, the icon ("home" or "gold"), the arrow's angle (degrees clockwise from up) and its text.
func set_homeward(show: bool, icon := "home", deg := 0.0, text := "") -> void:
	homeward.visible = show
	if not show: return
	if homeward_icon.kind != icon: homeward_icon.kind = icon; homeward_icon.queue_redraw()
	homeward_arrow.rotation = lerp_angle(homeward_arrow.rotation, deg_to_rad(deg), 0.25)
	if text != homeward_sig: homeward_sig = text; homeward_label.text = text

func set_fortune(text: String) -> void:
	if fortune_label.text != text: fortune_label.text = text; fortune.visible = text != ""

## The homeward chip's little SVG glyphs (main.js HOME_ICON, GOLD_ICON and the arrow), drawn in a 24 px box.
class Glyph extends Control:
	var kind := "home"
	func _init() -> void:
		custom_minimum_size = Vector2(22, 22); pivot_offset = Vector2(11, 11); mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _poly(pts: Array, fill: Color, edge: Color, w: float) -> void:
		var k := 22.0 / 24.0; var o := PackedVector2Array()
		for q in pts: o.append(q * k)
		draw_colored_polygon(o, fill); var c := o.duplicate(); c.append(o[0]); draw_polyline(c, edge, w, true)
	func _draw() -> void:
		if kind == "home": _poly([Vector2(3, 12), Vector2(12, 4), Vector2(21, 12), Vector2(18, 12), Vector2(18, 20), Vector2(6, 20), Vector2(6, 12)], Color("a8352a"), Color("4a3426"), 1.6)
		elif kind == "gold":
			var pts := [Vector2(3, 18)]
			for i in 13: var t := i / 12.0; pts.append(Vector2(3, 18).bezier_interpolate(Vector2(5, 11), Vector2(9, 8), Vector2(12, 8), t) if t <= 1.0 else Vector2.ZERO)
			for i in 13: var t := i / 12.0; pts.append(Vector2(12, 8).bezier_interpolate(Vector2(15, 8), Vector2(19, 11), Vector2(21, 18), t))
			_poly(pts, Color("d8a830"), Color("7a5a14"), 1.5)
			draw_circle(Vector2(9, 14) * 22.0 / 24.0, 1.4, Color("ffe08a")); draw_circle(Vector2(14, 12) * 22.0 / 24.0, 1.2, Color("ffe08a"))
		else: # the arrow, centred (viewBox -12 -12 24 24)
			var pts := []
			for q in [Vector2(0, -10), Vector2(7, 3), Vector2(2, 1.5), Vector2(2, 10), Vector2(-2, 10), Vector2(-2, 1.5), Vector2(-7, 3)]: pts.append(q + Vector2(12, 12))
			_poly(pts, Color("b5523b"), Color("4a3426"), 1.4)
func set_hint(text: String) -> void:
	if hint_label.text != text: hint_label.text = text
	hint.visible = text != ""

func set_inventory(inv: Dictionary) -> void:
	_set_ledger(inv)
	if not pack.visible: return
	var shown := []
	for k in data.ORDER:
		if not (k in data.DISHES) and ((k in data.ALWAYS) or inv.get(k, 0) > 0): shown.append(k)
	var pantry := 0; var best := ""
	for k in data.DISHES:
		pantry += inv.get(k, 0)
		if best == "" and inv.get(k, 0) > 0: best = k
	if pantry > 0: shown.append("pantry")
	var sig := ",".join(shown) + "|" + best
	if sig != slots_sig:
		slots_sig = sig
		for c in slots.get_children(): c.queue_free()
		# (#slots: 76x64 slots 10 px apart, or 60x54 and 6 px once there are more than nine; the card, placed at left 50%,
		# can only be as wide as the half screen it starts in, so the row wraps at ~800 px)
		var many := shown.size() > 9
		var sw := 60.0 if many else 76.0; var sh := 54.0 if many else 64.0; var gap := 6.0 if many else 10.0
		slots.add_theme_constant_override("h_separation", int(gap)); slots.add_theme_constant_override("v_separation", int(gap))
		var per_row := maxi(1, floori((800.0 - 28.0 + gap) / (sw + gap)))
		slots.custom_minimum_size.x = mini(shown.size(), per_row) * (sw + gap) - gap
		var i := 0
		for k in shown:
			var s := card(-1.5 if i % 2 == 0 else 1.2, Vector4(2, 2, 2, 2)); s.custom_minimum_size = Vector2(sw, sh)
			var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_theme_constant_override("separation", 0)
			var top := Control.new(); top.custom_minimum_size.y = 9.0 if many else 10.0; top.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(top) # (room for the name)
			var body: String = data.BASKET + '<g transform="translate(8 1) scale(.5)">' + icons.get(best, "") + "</g>" if k == "pantry" else icons.get(k, "")
			var ic := icon(body, 25 if many else 30); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_child(ic)
			var n := label("0", 17 if many else 20); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; n.name = "n"; v.add_child(n)
			s.add_child(v); s.set_meta("k", k)
			# the item's name, small, in the slot's top-left corner (.slot .k), over the card, not in its layout
			var key := label(k, 11, INK_SOFT); key.position = Vector2(5, 1); key.z_index = 1
			var keyhold := Control.new(); keyhold.mouse_filter = Control.MOUSE_FILTER_IGNORE; keyhold.add_child(key); s.add_child(keyhold)
			if k == "pantry": (s.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("f3e2c0")
			slots.add_child(s)
			i += 1
	for s in slots.get_children():
		var k: String = s.get_meta("k")
		var v := pantry if k == "pantry" else int(inv.get(k, 0))
		(s.find_child("n", true, false) as Label).text = str(v)

func _set_ledger(inv: Dictionary) -> void:
	var shown := []
	for k in data.LEDGER:
		if (k in data.LEDGER_ALWAYS) or inv.get(k, 0) > 0: shown.append(k)
	var sig := ",".join(shown)
	if sig != ledger_sig:
		ledger_sig = sig; ledger_rows.clear()
		for c in ledger.get_children(): c.queue_free()
		for k in shown:
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); row.custom_minimum_size = Vector2(64, 0); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon(icons.get(k, ""), 22))
			var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(sp)
			var n := label("0", 18); row.add_child(n)
			ledger.add_child(row); ledger_rows[k] = [row, n]
	for k in shown:
		var v := int(inv.get(k, 0))
		ledger_rows[k][1].text = str(v)
		ledger_rows[k][0].modulate.a = 0.45 if v == 0 else 1.0

## The tool bar: tools (Set-like dict) owned, held id, owns(id) -> bool, wear {id: 0..100}.
func set_tools(tools: Dictionary, held: String, owns: Callable, wear := {}) -> void:
	var sig := held
	for k in wear: sig += "|%s%d" % [k, ceili(wear[k] / 5.0)]
	for t in data.TOOLBAR: sig += _tool_name(t.id, tools) if owns.call(t.id) else "-"
	if sig == tool_sig: return
	tool_sig = sig
	for c in toolbar.get_children(): c.queue_free()
	var i := 0
	for t in data.TOOLBAR:
		var have: bool = owns.call(t.id)
		var on: bool = t.id == held
		var s := card((-1.0 if on else (-1.5 if i % 2 == 0 else 1.2)), Vector4(4, 4, 4, 4)); s.custom_minimum_size = Vector2(74, 66)
		if on:
			(s.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("e9c98a")
			s.position.y -= 6
		var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 0); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := icon(t.svg, 32); v.add_child(ic)
		var w = wear.get(t.id)
		var nm := (_tool_name(t.id, tools) + (" · dull" if w != null and w <= 0 else "")) if have else "?"
		var l := label(nm, 13); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l)
		s.add_child(v)
		var key := label(str(i + 1), 13, INK_SOFT); key.position = Vector2(6, 2); s.add_child(key)
		if not have: s.modulate.a = 0.45; ic.modulate = Color(0.6, 0.6, 0.6)
		toolbar.add_child(s)
		i += 1

func _tool_name(id: String, t: Dictionary) -> String:
	match id:
		"axe": return "Steel axe" if t.has("steelaxe") else ("Iron axe" if t.has("ironaxe") else ("Stone axe" if t.has("stoneaxe") else "Old hatchet"))
		"pick": return "Steel pickaxe" if t.has("steelpick") else ("Iron pickaxe" if t.has("ironpick") else "Pickaxe")
	return TOOL_NAMES.get(id, id)

## main.js renderBuildBar: the shelves named across the top (the current one underlined), then that shelf's pieces,
## the selected one raised and gold, the ones you can't afford faded, each with its cost (shortfalls in red).
## built: type -> how many stand. On the Works shelf (one of each is all a settler needs) a work already standing is
## marked "✓ built" and set back (the player's ask: it says you don't need another).
const ONE_EACH := "Works"
func set_buildbar(on: bool, selected: int, order: Array, groups: Array, pieces: Dictionary, inv: Dictionary, built := {}) -> void:
	buildbar.visible = on
	if not on: return
	var cur: String = order[selected]
	var sig := "%d|%s|%s" % [selected, str(inv), str(built)]
	if sig == bar_sig: return
	bar_sig = sig
	for c in buildbar.get_children(): buildbar.remove_child(c); c.queue_free()
	var gi := 0
	for i in groups.size(): if cur in groups[i][1]: gi = i
	var shelves := HBoxContainer.new(); shelves.alignment = BoxContainer.ALIGNMENT_CENTER; shelves.add_theme_constant_override("separation", 10)
	for i in groups.size():
		var l := label("%d %s" % [i + 1, groups[i][0]], 14, INK if i == gi else INK_SOFT)
		if i == gi: l.add_theme_color_override("font_outline_color", Color("b5473a"))
		shelves.add_child(l)
	buildbar.add_child(shelves)
	var row := HFlowContainer.new(); row.alignment = FlowContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("h_separation", 6)
	row.custom_minimum_size.x = 1100
	for t in groups[gi][1]:
		var p: Dictionary = pieces[t]
		var poor := false
		for k in p.cost: poor = poor or inv.get(k, 0) < p.cost[k]
		var c := card(-1.5 if t == cur else 0.0, Vector4(9, 3, 9, 2))
		if t == cur: (c.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("e9c98a"); c.position.y -= 5
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := label(p.name, 15); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(n)
		var parts := PackedStringArray()
		for k in p.cost: parts.append(("[color=#b5302a][b]%d %s[/b][/color]" if inv.get(k, 0) < p.cost[k] else "%d %s") % [int(p.cost[k]), k])
		var cl := RichTextLabel.new(); cl.bbcode_enabled = true; cl.fit_content = true; cl.autowrap_mode = TextServer.AUTOWRAP_OFF; cl.scroll_active = false
		cl.add_theme_font_size_override("normal_font_size", 12); cl.add_theme_font_size_override("bold_font_size", 12); cl.add_theme_color_override("default_color", INK_SOFT)
		cl.text = "[center]%s[/center]" % ", ".join(parts); cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cl)
		var have: bool = groups[gi][0] == ONE_EACH and built.get(t, 0) > 0
		if have:
			var bl := label("✓ built", 13, Color("3f7a3a")); bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(bl)
		c.add_child(v)
		if have: c.modulate.a = 0.6
		elif poor: c.modulate.a = 0.55
		row.add_child(c)
	buildbar.add_child(row)

func set_stamina(v: float, mx: float, boosted: bool) -> void:
	var w := minf(360.0, mx * 1.2)
	stamina.custom_minimum_size.x = w
	stamina_fill.size.x = (w - 4) * clampf(v / mx, 0.0, 1.0)
	stamina_fill.color = Color("e07a3c") if boosted else Color("e2b33c")
	stamina_fill.modulate.a = (0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 160.0))) if v < 15.0 else 1.0
func set_fullness(v: float) -> void:
	fullness_fill.size.x = 176.0 * clampf(v / 100.0, 0.0, 1.0)
	fullness_fill.color = Color("b5473a") if v < 10 else (Color("9a4a2a") if v < 30 else Color("b8904a"))
	fullness_fill.modulate.a = (0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 190.0))) if v < 10 else 1.0
func set_health(v: float, mx: float) -> void:
	health_fill.size.x = 236.0 * clampf(v / mx, 0.0, 1.0)
	health_fill.modulate.a = (0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 160.0))) if v < mx * 0.3 else 1.0
func hurt() -> void: hurt_t = 0.7

## A quiet HUD: the bars fade out after a few seconds of all being well, and are back at once when they matter.
func set_calm(all_well: bool, dt: float) -> void:
	calm_t = calm_t + dt if all_well else 0.0
	var target := 0.0 if calm_t > 3.0 else 1.0
	for b in [health, stamina, fullness]:
		b.modulate.a = move_toward(b.modulate.a, target, dt / 0.8)

# ------------------------------------------------------------------ the loot notes
## A paper note, one short line (the player's ask: fewer of them, simpler, each on one line): brief() keeps the gist,
## one shows at a time and at most three wait (the oldest let go), the same note twice just stays longer, a short
## "+2 wood" replaces the last short one instead of queueing.
const NOTE_MAX := 58
const NOTES_UP := 1
const NOTES_WAITING := 3
var heard: Array = []  ## the last notes in full, before brief() cut them (newest last; tests read these)
func toast(text: String) -> void:
	heard.append(text)
	if heard.size() > 40: heard.remove_at(0)
	text = brief(text)
	if text == "": return
	for n in live:
		if n.text == text and not n.out: n.t = note_s(text); return
	if text in queue: return
	var short := text.length() < 30
	if short:
		for n in live:
			if not n.out and n.text.length() < 30:
				n.text = text; n.label.text = text; n.t = note_s(text); return
	var pinned := 0
	for n in live: if not n.out: pinned += 1
	if pinned >= NOTES_UP:
		queue.push_back(text)
		while queue.size() > NOTES_WAITING: queue.remove_at(0)
		return
	_pin(text)

## A long note cut to its gist: asides in brackets and quote marks dropped, the first sentence (or, if that has no
## number in it, the first that does: the paces, the dollars, the count), at most NOTE_MAX characters.
static func brief(text: String) -> String:
	var t := RegEx.create_from_string("\\s*\\([^)]*\\)").sub(text, "", true)
	t = t.replace("\"", "").replace("“", "").replace("”", "").strip_edges()
	var parts := RegEx.create_from_string("(?<=[.!?])\\s+").sub(t, "\n", true).split("\n", false)
	if parts.is_empty(): return ""
	var pick: String = parts[0]
	if pick.length() < 18 and parts.size() > 1: pick = pick + " " + parts[1] # ("Snap!" alone says nothing)
	var digit := RegEx.create_from_string("[0-9]")
	if digit.search(pick) == null:
		for q in parts: if digit.search(q) != null: pick = q; break
	var colon := pick.rfind(": ")
	if colon > 0 and digit.search(pick.substr(colon)) != null and pick.length() > NOTE_MAX: pick = pick.substr(colon + 2) # (the tip, not who told it)
	pick = pick.strip_edges()
	if pick.length() > 0: pick = pick.left(1).to_upper() + pick.substr(1)
	if pick.length() > NOTE_MAX:
		var cut := pick.left(NOTE_MAX - 1); var sp := cut.rfind(" ")
		pick = (cut.left(sp) if sp > 30 else cut).rstrip(",;: ") + "…"
	return pick

func note_s(text: String) -> float: return minf(6.0, 2.2 + text.length() * 0.05)

func _pin(text: String) -> void:
	var c := card((randf() - 0.5) * 1.2, Vector4(10, 2, 10, 3))
	var l := label(text, 15); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l); c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toasts.add_child(c)
	live.append({"card": c, "label": l, "text": text, "t": note_s(text), "out": false, "fade": 0.0})

var sleep_show := false
func _process(dt: float) -> void:
	_overlay_tick(dt)
	_panels_tick()
	if next_urgent: next_t += dt; next_card.position.x = 3.0 * (0.5 - 0.5 * cos(next_t * TAU / 1.6)) # (the nudge)
	sleep_rect.modulate.a = move_toward(sleep_rect.modulate.a, 1.0 if sleep_show else 0.0, dt / 0.6)
	if hurt_t > 0.0:
		hurt_t = maxf(0.0, hurt_t - dt)
		(hurt_rect.material as ShaderMaterial).set_shader_parameter("k", sin(hurt_t / 0.7 * PI))
	for n in live.duplicate():
		if not n.out:
			n.t -= dt
			if n.t <= 0.0: n.out = true
		else:
			n.fade += dt / 0.5
			n.card.modulate.a = 1.0 - n.fade
			n.card.position.y -= dt * 28.0
			if n.fade >= 1.0:
				n.card.queue_free(); live.erase(n)
				if queue.size(): _pin(queue.pop_front())

# ------------------------------------------------------------------ the centre cards (index.html #story, #calendar)
## index.html puts every centre panel (#craft, #map, #story, #almanac, #letter, #calendar, #settlers, #pack) in one
## place: centred a little above the middle (top: 50vh - 84px, translate -50%), tilted -0.5 deg.
const CENTRE_Y := 0.5 - 84.0 / 900.0
const MAP_PX := 500.0
var _bold_font: FontVariation
func _bold() -> FontVariation:
	if _bold_font == null: _bold_font = FontVariation.new(); _bold_font.base_font = font; _bold_font.variation_embolden = 0.7
	return _bold_font
func _centre_card(width: float, fy: float, tilt: float) -> PanelContainer:
	var c := card(tilt, Vector4(24, 16, 24, 12))
	panels.append(c)
	c.anchor_left = 0.5; c.anchor_right = 0.5; c.anchor_top = fy; c.anchor_bottom = fy
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH; c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.custom_minimum_size = Vector2(width, 0); c.visible = false; c.z_index = 4
	root.add_child(c)
	return c

func _build_cards() -> void:
	story = _centre_card(470, CENTRE_Y, -0.5); story_box = VBoxContainer.new(); story_box.add_theme_constant_override("separation", 6); story.add_child(story_box)
	map_card = _centre_card(560, CENTRE_Y, -0.5); var mv := VBoxContainer.new(); mv.add_theme_constant_override("separation", 4); map_card.add_child(mv)
	var mt := label("The County, as you know it", 26); mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mv.add_child(mt)
	var frame := PanelContainer.new(); var fb := StyleBoxFlat.new(); fb.bg_color = Color(0, 0, 0, 0); fb.border_color = Color(60 / 255.0, 40 / 255.0, 25 / 255.0, 0.35); fb.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", fb); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; county_map = CountyMap.new()
	# (the page draws the sheet min(540, 100vw - 60, 100vh - 400) px across: 500 at 900 tall; the 560 sheet scaled to it)
	var mhold := Control.new(); mhold.custom_minimum_size = Vector2(MAP_PX, MAP_PX); mhold.mouse_filter = Control.MOUSE_FILTER_IGNORE; mhold.clip_contents = true # (names run off the sheet at its edge, as the page's canvas cuts them)
	county_map.scale = Vector2.ONE * (MAP_PX / CountyMap.W); mhold.add_child(county_map); frame.add_child(mhold); mv.add_child(frame)
	var mf := label("M to fold it away", 15, INK_SOFT); mf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mv.add_child(mf)
	calendar = _centre_card(560, CENTRE_Y, -0.5); cal_box = VBoxContainer.new(); cal_box.add_theme_constant_override("separation", 6); calendar.add_child(cal_box)

func _clear(box: Container) -> void:
	for c in box.get_children(): box.remove_child(c); c.queue_free()

func _heading(box: Container, text: String) -> void:
	var h := label(text, 27); h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; h.add_theme_font_override("font", _bold()); box.add_child(h) # (wraps and is bold, as the page's h2, so a long title can't widen the card)
	var rule := Control.new(); rule.custom_minimum_size = Vector2(0, 3); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE # (border-bottom: 1px dashed)
	rule.draw.connect(func() -> void: rule.draw_dashed_line(Vector2(0, 1), Vector2(rule.size.x, 1), EDGE.darkened(0.15), 1.0, 5.0)); box.add_child(rule)

func _para(box: Container, text: String, size := 19, col := INK) -> Label:
	var l := label(text, size, col); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(l); return l

## The story card: a title, paragraphs, an optional list, and a small footnote.
func story_show(title: String, paras: Array, items := [], foot := "") -> void:
	_clear(story_box); _heading(story_box, title)
	for t in paras: _para(story_box, t)
	for t in items: _para(story_box, "•  " + t, 18)
	if foot != "": _para(story_box, foot, 14, INK_SOFT)
	story.visible = true
func story_hide() -> void: story.visible = false

## The almanac (H): week = [{"label", "today", "bits": [[text, colour hex or "", bold]]}], notes = lines.
func calendar_show(title: String, week: Array, notes: Array, foot: String) -> void:
	_clear(cal_box); _heading(cal_box, title)
	var grid := GridContainer.new(); grid.columns = 7; grid.add_theme_constant_override("h_separation", 5); grid.add_theme_constant_override("v_separation", 5)
	for d in week:
		var cell := PanelContainer.new(); cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(217 / 255.0, 164 / 255.0, 65 / 255.0, 0.28) if d.today else Color(1, 250 / 255.0, 236 / 255.0, 0.4)
		sb.border_color = Color(120 / 255.0, 80 / 255.0, 30 / 255.0, 0.6) if d.today else Color(60 / 255.0, 40 / 255.0, 25 / 255.0, 0.3); sb.set_border_width_all(1)
		sb.content_margin_left = 3; sb.content_margin_right = 3; sb.content_margin_top = 4; sb.content_margin_bottom = 5
		cell.add_theme_stylebox_override("panel", sb); cell.custom_minimum_size = Vector2(68, 64); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if d.today: cell.rotation_degrees = -1.5; cell.resized.connect(func() -> void: cell.pivot_offset = cell.size / 2.0)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); cell.add_child(v)
		var h := label(d.label, 16); h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(h)
		for b in d.bits:
			var l := label(b[0], 14, Color(b[1]) if b[1] != "" else INK); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if b[2]: l.add_theme_constant_override("outline_size", 1); l.add_theme_color_override("font_outline_color", Color(b[1]))
			v.add_child(l)
		grid.add_child(cell)
	cal_box.add_child(grid)
	for t in notes: _para(cal_box, "•  " + t, 17)
	_para(cal_box, foot, 14, INK_SOFT)
	calendar.visible = true
func calendar_hide() -> void: calendar.visible = false

## The rumour note: what folks tell, how far, and the arrow's on-screen angle (degrees, clockwise from up).
func set_rumour(r, deg: float) -> void:
	if r == null:
		if rumour_sig != "": rumour_sig = ""; rumour.visible = false
		return
	var sig := "%s|%d" % [r.key, r.paces]
	if sig != rumour_sig:
		rumour_sig = sig; rumour.visible = true; rumour_text.text = r.text; rumour_small.text = "about %d paces that way" % r.paces
	rumour_arrow.rotation = lerp_angle(rumour_arrow.rotation, deg_to_rad(deg), 0.25)

class RumourArrow extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(28, 28); pivot_offset = Vector2(14, 14); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var pts := PackedVector2Array()
		for q in [Vector2(0, -11), Vector2(8, 3), Vector2(2.5, 1.5), Vector2(2, 11), Vector2(-2, 11), Vector2(-2.5, 1.5), Vector2(-8, 3)]: pts.append(q * 28.0 / 28.0 + Vector2(14, 14))
		draw_colored_polygon(pts, Color("b5523b")); var q := pts.duplicate(); q.append(pts[0]); draw_polyline(q, Color("4a3426"), 1.6, true)

# ------------------------------------------------------------------ the title card, the pause note, the crosshair
## index.html #overlay: the torn-paper vignette (baked from the page's own SVG and its torn filter), the name, the
## line, the controls in two columns, "Click to begin" (pulsing in a dashed frame) and the New game button; shown at
## the start and whenever the mouse is let go. #peek: the small pause note Escape folds the card into. #crosshair:
## the dot at the centre while building.
const CONTROLS := [["WASD", "walk"], ["Shift", "sprint"], ["Space", "jump"], ["Mouse", "look · wheel to zoom"],
	["Left click", "chop, mine, pick, break builds (hold to repeat)"],
	["E", "sleep · rock on the porch · tall tales at a campfire · gather eggs · milk & shear · read the mail · pat Old Blue & Marmalade · catch lightning bugs · trade with the tinker · enter the County Fair"],
	["M / Tab", "the county map"], ["G", "fly your paper kite (once you've made one)"],
	["H", "the almanac: this week's calendar and today's chores"], ["K", "snap a postcard (saved as a picture)"],
	["F", "eat (best food first: honey cake, pie, apple crisp, flapjacks, stew, bread, cornbread, berries)"],
	["C", "crafting"], ["B", "build mode · 1–4 shelf · Q/E piece · R rotate · LMB place · RMB remove"],
	["1 – 5", "tool in hand: hands · axe · pickaxe · spear · fishing pole (in build mode: a shelf)"],
	["I", "open your pack (wood, stone, food…)"], ["J", "settlers & works: who's working where, what's in the storehouse"],
	["P", "depth of field on/off"], ["N", "sound on/off"], ["F3", "show the frame rate and time-of-day buttons"],
	["O", "graphics: auto · high · medium · low"], ["Esc", "pause"]]
const TITLE_SCALE := 0.82 ## the title card drawn smaller than its page layout, as the rest of the interface
const CONTROLS_SPLIT := 10 ## (the first column: WASD to K, as the page's two CSS columns break)
var overlay: ColorRect
var overlay_on := true
var cta: Label
var cta_box: PanelContainer
var newgame_btn: Button
var save_btn: Button
var quit_btn: Button
var options_card: PanelContainer
var option_buttons := {}       ## id -> Button showing the setting's value
var on_save: Callable          ## Save game
var on_quit: Callable          ## Quit (main saves first)
var on_option: Callable        ## (id) -> the new value's text, after cycling it
var option_value: Callable     ## (id) -> the value's text now
var confirm_card: PanelContainer
var peek: PanelContainer
var crosshair: Control
var on_overlay_click: Callable  ## a click on the card (main: take the mouse)
var on_newgame: Callable        ## the new game, confirmed
var _pulse_t := 0.0
var _title_card: Control

func _build_overlay() -> void:
	overlay = ColorRect.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(40 / 255.0, 52 / 255.0, 60 / 255.0, 0.28)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP; overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	overlay.z_index = 6
	overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and overlay_on and not confirm_card.visible and not options_card.visible and on_overlay_click.is_valid(): on_overlay_click.call())
	root.add_child(overlay)
	# the card, with the page's faint paper halo round it (box-shadow 0 0 0 4px)
	var halo := PanelContainer.new(); halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := StyleBoxFlat.new(); hb.bg_color = Color(PAPER, 0.35); hb.set_corner_radius_all(6); hb.set_content_margin_all(4)
	halo.add_theme_stylebox_override("panel", hb); halo.rotation_degrees = -1.0
	overlay.add_child(halo); _title_card = halo # (placed by hand in _overlay_tick: a container would undo its tilt)
	var c := card(0.0, Vector4(30, 18, 30, 18)); halo.add_child(c)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); v.custom_minimum_size.x = 620; v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var vig := TextureRect.new(); vig.texture = load("res://assets/baked/hud/vignette.png")
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; vig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vig.custom_minimum_size = Vector2(620, 134); vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(vig); v.add_child(_gap(10))
	var h1 := label("Cold Glitter Creek", 52); h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(h1)
	var sub := label("a hard-scrabble gold-rush tale, cut from paper and stood up on its hinges", 17, INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub); v.add_child(_gap(10))
	var bold := FontVariation.new(); bold.base_font = font; bold.variation_embolden = 0.7
	var cols := HBoxContainer.new(); cols.add_theme_constant_override("separation", 26); cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cols)
	for half in 2:
		var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 2); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE; cols.add_child(col)
		for k in range(0 if half == 0 else CONTROLS_SPLIT, CONTROLS_SPLIT if half == 0 else CONTROLS.size()):
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var dt := label(CONTROLS[k][0], 14); dt.custom_minimum_size.x = 74; dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			dt.add_theme_font_override("font", bold); dt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var dd := label(CONTROLS[k][1], 14, INK_SOFT); dd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dd.custom_minimum_size.x = 180
			dd.add_theme_constant_override("line_spacing", -6)
			row.add_child(dt); row.add_child(dd); col.add_child(row)
	v.add_child(_gap(14))
	# "Click to begin" in its dashed frame, breathing
	cta_box = PanelContainer.new(); cta_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cb := StyleBoxEmpty.new(); cb.content_margin_left = 18; cb.content_margin_right = 18; cb.content_margin_top = 4; cb.content_margin_bottom = 6
	cta_box.add_theme_stylebox_override("panel", cb); cta_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cta_box.draw.connect(func() -> void:
		var r := Rect2(Vector2(1, 1), cta_box.size - Vector2(2, 2))
		for e in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
			cta_box.draw_dashed_line(e[0], e[1], INK_SOFT, 2.0, 6.0, true, true))
	cta_box.resized.connect(func() -> void: cta_box.pivot_offset = cta_box.size / 2.0)
	cta = label("Click to begin", 24); cta_box.add_child(cta)
	v.add_child(cta_box); v.add_child(_gap(14))
	# the menu row (the port's own: the page has only New game; the browser does the rest): save, options, a new
	# game, and quit to the desktop (saving first)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_btn = paper_button("Save game", 17, false)
	save_btn.pressed.connect(func() -> void: if on_save.is_valid(): on_save.call())
	var opt_btn := paper_button("Options", 17, false)
	opt_btn.pressed.connect(func() -> void: _refresh_options(); options_card.visible = true)
	newgame_btn = paper_button("New game", 17, false)
	newgame_btn.pressed.connect(func() -> void: confirm_card.visible = true)
	quit_btn = paper_button("Quit", 17, false)
	quit_btn.pressed.connect(func() -> void: if on_quit.is_valid(): on_quit.call())
	for bt in [save_btn, opt_btn, newgame_btn, quit_btn]: row.add_child(bt)
	v.add_child(row)
	# (the page asks with the browser's own confirm(); here a paper card asks the same)
	confirm_card = card(0.6, Vector4(22, 14, 22, 14)); confirm_card.visible = false; confirm_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 10); confirm_card.add_child(cv)
	cv.add_child(label("Start a new game? Your builds, items and tools will be lost.", 20))
	var bh := HBoxContainer.new(); bh.alignment = BoxContainer.ALIGNMENT_CENTER; bh.add_theme_constant_override("separation", 14); cv.add_child(bh)
	var yes := paper_button("Start over", 17, true); var no := paper_button("Keep my farm", 17, false)
	yes.pressed.connect(func() -> void: if on_newgame.is_valid(): on_newgame.call())
	no.pressed.connect(func() -> void: confirm_card.visible = false)
	bh.add_child(yes); bh.add_child(no)
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(confirm_card); overlay.add_child(cc)
	_build_options()
	# the pause note
	peek = card(-1.0, Vector4(14, 3, 14, 3)); peek.add_child(label("Paused · click to carry on · Esc for the controls", 17))
	peek.visible = false; peek.z_index = 3
	peek.set_anchors_preset(Control.PRESET_CENTER_TOP); peek.grow_horizontal = Control.GROW_DIRECTION_BOTH; peek.offset_top = 16
	root.add_child(peek)
	# the crosshair: an 8 px paper dot ringed in ink
	crosshair = Control.new(); crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -6; crosshair.offset_top = -6; crosshair.offset_right = 6; crosshair.offset_bottom = 6
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE; crosshair.visible = false
	crosshair.draw.connect(func() -> void:
		crosshair.draw_circle(Vector2(6, 6), 5.0, Color(244 / 255.0, 236 / 255.0, 216 / 255.0, 0.8))
		crosshair.draw_arc(Vector2(6, 6), 5.0, 0, TAU, 24, Color(58 / 255.0, 47 / 255.0, 37 / 255.0, 0.8), 2.0, true))
	root.add_child(crosshair)

func _gap(h: float) -> Control:
	var g := Control.new(); g.custom_minimum_size.y = h; g.mouse_filter = Control.MOUSE_FILTER_IGNORE; return g

## A paper button (#newgame: no fill, soft ink, an edge line, warm on hover; `warm`: the recipe buttons' tan).
func paper_button(text: String, size := 17, warm := false) -> Button:
	var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = border; sb.set_border_width_all(1); sb.set_corner_radius_all(3)
		sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 3; sb.content_margin_bottom = 3
		return sb
	var base: Color = Color("e9c98a") if warm else Color(0, 0, 0, 0)
	var edge: Color = Color("b89a5a") if warm else EDGE
	b.add_theme_stylebox_override("normal", mk.call(base, edge))
	b.add_theme_stylebox_override("hover", mk.call(Color("f0d49a") if warm else Color("efe3c4"), edge))
	b.add_theme_stylebox_override("pressed", mk.call(Color("e6d8b6"), edge))
	b.add_theme_color_override("font_color", INK if warm else INK_SOFT)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	return b

## Show or fold away the title card (it fades .3 s as on the page; `now`: at once).
func show_overlay(on: bool, now := false) -> void:
	overlay_on = on
	if not on: confirm_card.visible = false; options_card.visible = false
	if now: overlay.modulate.a = 1.0 if on else 0.0; overlay.visible = on
func show_peek(on: bool) -> void: peek.visible = on
func set_crosshair(on: bool) -> void: if crosshair.visible != on: crosshair.visible = on

func _overlay_tick(dt: float) -> void:
	if overlay == null: return
	overlay.modulate.a = move_toward(overlay.modulate.a, 1.0 if overlay_on else 0.0, dt / 0.3)
	overlay.visible = overlay.modulate.a > 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP if overlay_on else Control.MOUSE_FILTER_IGNORE
	if overlay.visible:
		# (the page scrolls a card taller than the window; here it is scaled to fit, 12 px clear top and bottom)
		var cs := _title_card.get_combined_minimum_size()
		if _title_card.size != cs: _title_card.size = cs
		var fit := minf(TITLE_SCALE, (root.size.y - 24.0) / maxf(1.0, cs.y)) # (a size down from the rest: the player's ask)
		_title_card.pivot_offset = cs / 2.0; _title_card.scale = Vector2(fit, fit)
		_title_card.position = ((root.size - cs) / 2.0).round()
		_pulse_t += dt
		var k := 1.0 + 0.05 * (0.5 - 0.5 * cos(_pulse_t * TAU / 1.6))
		cta_box.scale = Vector2(k, k)

# ------------------------------------------------------------------ developer bits (F3), the +$500 button, #error
## #backend: the renderer, the frame rate and the graphics setting, top right; #times: the four time-of-day chips
## under it (Afternoon, Golden, Blue hour, Night; the one picked warm). Both out of sight unless F3 is pressed.
## #devcash: the +$500 button bottom right (on the page it shows always). #error: the red card along the bottom that
## says the game could not start.
const TIME_PRESETS := [["Afternoon", 0.58], ["Golden", 0.715], ["Blue hour", 0.775], ["Night", 0.9]]
var dev := false
var backend: PanelContainer
var backend_label: Label
var times: HBoxContainer
var time_chips: Array = []
var devcash: Button
var error_card: PanelContainer
var error_label: Label
var on_time_preset: Callable  ## (i) a chip clicked
var on_devcash: Callable

func _build_dev() -> void:
	backend = card(0.0, Vector4(10, 2, 10, 2)); backend_label = label("…", 15, INK_SOFT); backend.add_child(backend_label)
	backend.set_anchors_preset(Control.PRESET_TOP_RIGHT); backend.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	backend.offset_right = -16; backend.offset_top = 16
	root.add_child(backend)
	times = HBoxContainer.new(); times.add_theme_constant_override("separation", 6)
	times.set_anchors_preset(Control.PRESET_TOP_RIGHT); times.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	times.offset_right = -16; times.offset_top = 52; times.z_index = 2
	for i in TIME_PRESETS.size():
		var b := Button.new(); b.text = TIME_PRESETS[i][0]; b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15); b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, paper_box(Vector4(9, 2, 9, 2)))
		for st in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(st, INK)
		b.rotation_degrees = -1.0 if i % 2 == 0 else 1.0 # (odd chips tilt one way, even the other)
		b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
		b.pressed.connect(func() -> void: if on_time_preset.is_valid(): on_time_preset.call(i))
		times.add_child(b); time_chips.append(b)
	root.add_child(times)
	devcash = Button.new(); devcash.text = "+$500"; devcash.tooltip_text = "Dev: add $500 (F4)"; devcash.focus_mode = Control.FOCUS_NONE
	var serif := SystemFont.new(); serif.font_names = PackedStringArray(["Georgia", "serif"]); serif.font_weight = 600
	devcash.add_theme_font_override("font", serif); devcash.add_theme_font_size_override("font_size", 14)
	var mk := func(bg: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = Color("6a4a30"); sb.set_border_width_all(2); sb.set_corner_radius_all(6)
		sb.shadow_color = Color(90 / 255.0, 60 / 255.0, 30 / 255.0, 0.35); sb.shadow_size = 1; sb.shadow_offset = Vector2(2, 3)
		sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 6; sb.content_margin_bottom = 6
		return sb
	devcash.add_theme_stylebox_override("normal", mk.call(Color("f2e8d0"))); devcash.add_theme_stylebox_override("hover", mk.call(Color("f2e8d0")))
	devcash.add_theme_stylebox_override("pressed", mk.call(Color("e6d8b6")))
	for st in ["font_color", "font_hover_color", "font_pressed_color"]: devcash.add_theme_color_override(st, Color("3a2a1c"))
	devcash.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	devcash.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); devcash.grow_horizontal = Control.GROW_DIRECTION_BEGIN; devcash.grow_vertical = Control.GROW_DIRECTION_BEGIN
	devcash.offset_right = -12; devcash.offset_bottom = -84; devcash.z_index = 7
	devcash.pressed.connect(func() -> void: if on_devcash.is_valid(): on_devcash.call())
	root.add_child(devcash)
	error_card = PanelContainer.new(); error_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eb := StyleBoxFlat.new(); eb.bg_color = Color("fde2df"); eb.border_color = Color("c8323c"); eb.set_border_width_all(1)
	eb.content_margin_left = 14; eb.content_margin_right = 14; eb.content_margin_top = 10; eb.content_margin_bottom = 10
	error_card.add_theme_stylebox_override("panel", eb)
	error_label = Label.new(); error_label.add_theme_font_override("font", SystemFont.new()) # (system-ui)
	error_label.add_theme_font_size_override("font_size", 16); error_label.add_theme_color_override("font_color", Color.BLACK)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_card.add_child(error_label)
	error_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); error_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	error_card.offset_left = 16; error_card.offset_right = -16; error_card.offset_bottom = -16; error_card.z_index = 9
	error_card.visible = false
	root.add_child(error_card)
	set_dev(false)

func set_dev(on: bool) -> void:
	dev = on; backend.visible = on; times.visible = on
func set_backend(text: String) -> void: if backend_label.text != text: backend_label.text = text
func set_time_chip(i: int) -> void:
	for k in time_chips.size():
		var sb := paper_box(Vector4(9, 2, 9, 2), Color("e9c98a") if k == i else PAPER)
		for st in ["normal", "hover", "pressed"]: time_chips[k].add_theme_stylebox_override(st, sb)
func show_error(text: String) -> void:
	error_label.text = text; error_card.visible = true

## The options card (the port's own; the page leaves display matters to the browser): each row a setting and a button
## showing its value that cycles it. Shown over the title card; Done folds it away.
const OPTIONS := [["window", "Display"], ["vsync", "Vertical sync"], ["ui", "Interface size"], ["quality", "Graphics"], ["dof", "Depth of field"], ["sound", "Sound"]]
func _build_options() -> void:
	options_card = card(-0.6, Vector4(26, 16, 26, 16)); options_card.visible = false; options_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); options_card.add_child(v)
	var h := label("Options", 30); h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(h)
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 18); grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for o in OPTIONS:
		var l := label(o[1], 19, INK_SOFT); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b := paper_button("…", 18, true); b.custom_minimum_size.x = 190
		var id: String = o[0]
		b.pressed.connect(func() -> void: if on_option.is_valid(): b.text = on_option.call(id))
		grid.add_child(l); grid.add_child(b); option_buttons[id] = b
	var done := paper_button("Done", 18, false); done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func() -> void: options_card.visible = false)
	v.add_child(_gap(4)); v.add_child(done)
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(options_card); overlay.add_child(cc)

func _refresh_options() -> void:
	if option_value.is_valid():
		for id in option_buttons: option_buttons[id].text = option_value.call(id)

## The Save game button's answer, for a moment.
func flash_saved(text: String) -> void:
	save_btn.text = text
	get_tree().create_timer(1.6).timeout.connect(func() -> void: save_btn.text = "Save game")

## One centre panel at a time (main.js's PANELS observer): whichever opened last is shown, any others wait, hidden,
## till it's put away; while one is up the ledger steps aside and only the newest note shows.
func register_panel(c: Control) -> void: if not panels.has(c): panels.append(c)
func _panels_tick() -> void:
	var open := panels.filter(func(c): return is_instance_valid(c) and c.visible)
	_panel_order = _panel_order.filter(func(c): return open.has(c))
	for c in open: if not _panel_order.has(c): _panel_order.append(c)
	for i in _panel_order.size():
		var a := 1.0 if i == _panel_order.size() - 1 else 0.0
		if _panel_order[i].modulate.a != a: _panel_order[i].modulate.a = a
	var any := not _panel_order.is_empty()
	var lc := ledger.get_parent() as Control
	if lc.visible == any: lc.visible = not any
	for i in live.size(): live[i].card.visible = not any or i == live.size() - 1

# ------------------------------------------------------------------ settlers & works (J), index.html #settlers
var settlers_card: PanelContainer
var _settlers_box: VBoxContainer
var _settlers_scroll: ScrollContainer
func _build_settlers() -> void:
	settlers_card = _centre_card(520, CENTRE_Y, -0.5)
	var sb := settlers_card.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 10; sb.content_margin_bottom = 12
	_settlers_scroll = ScrollContainer.new(); _settlers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settlers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; _settlers_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settlers_box = VBoxContainer.new(); _settlers_box.add_theme_constant_override("separation", 4); _settlers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settlers_scroll.add_child(_settlers_box); settlers_card.add_child(_settlers_scroll)

## The card's text: the storehouse and larder in a tinted box, a line for each settler (the name bold, the trade in
## italics, the status under it), and the footnote. (Its height is held to the page's 100vh - 320px.)
func set_settlers(store_line: String, larder: String, rows: Array) -> void:
	_clear(_settlers_box)
	_settlers_box.add_child(label("Settlers & works", 24))
	var rule := Control.new(); rule.custom_minimum_size.y = 4
	rule.draw.connect(func() -> void: rule.draw_dashed_line(Vector2(0, 1), Vector2(rule.size.x, 1), EDGE, 1.0, 5.0)); _settlers_box.add_child(rule)
	var sum := PanelContainer.new(); var sbx := paper_box(Vector4(8, 4, 8, 4), PAPER.lerp(Color(185 / 255.0, 150 / 255.0, 90 / 255.0), 0.12), 0)
	sbx.set_border_width_all(0); sbx.border_width_left = 3; sbx.border_color = Color("b8904a"); sbx.shadow_size = 0; sbx.set_corner_radius_all(0)
	sum.add_theme_stylebox_override("panel", sbx)
	var sl := label(store_line + "\n" + larder + ". Each settler eats a ration every morning (R at the storehouse to stock it); without one they work at half pace.", 16)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; sum.add_child(sl); _settlers_box.add_child(sum)
	var bold := FontVariation.new(); bold.base_font = font; bold.variation_embolden = 0.7
	var ital := FontVariation.new(); ital.base_font = font; ital.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	for r in rows:
		var t := RichTextLabel.new(); t.bbcode_enabled = true; t.fit_content = true; t.scroll_active = false; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_theme_font_override("normal_font", font); t.add_theme_font_override("bold_font", bold); t.add_theme_font_override("italics_font", ital)
		for k in ["normal_font_size", "bold_font_size", "italics_font_size"]: t.add_theme_font_size_override(k, 15)
		t.add_theme_color_override("default_color", INK)
		t.text = "  \u2022  [b]%s[/b] [i][color=#6b5b49](%s)[/color][/i]" % [r.name, r.trade]
		_settlers_box.add_child(t)
		var m := MarginContainer.new(); m.add_theme_constant_override("margin_left", 26); m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := label(r.status, 15); st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; m.add_child(st); _settlers_box.add_child(m)
	_settlers_box.add_child(label("J to fold it away", 13, INK_SOFT))
	_settlers_scroll.custom_minimum_size = Vector2(484, minf(_settlers_box.get_combined_minimum_size().y, 900.0 - 320.0 - 22.0))

# ------------------------------------------------------------------ a boss's health (the player's boss battles)
var boss_card: PanelContainer
var _boss_name: Label
var _boss_fill: ColorRect
const BOSS_W := 420.0
## A torn-paper strip at the top centre while a boss is fighting you: his name over a red bar.
func _build_boss() -> void:
	boss_card = card(-0.4, Vector4(14, 4, 14, 8)); boss_card.visible = false
	boss_card.anchor_left = 0.5; boss_card.anchor_right = 0.5; boss_card.offset_top = 14.0
	boss_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name = label("", 20); _boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_boss_name)
	var pair := bar(BOSS_W, 14.0, Color("a8352a")); _boss_fill = pair[1]; v.add_child(pair[0])
	boss_card.add_child(v); root.add_child(boss_card)
## who: "" hides it.
func set_boss(who: String, frac: float) -> void:
	boss_card.visible = who != ""
	if who == "": return
	var riled := frac < 0.5 # (below half he starts his tricks: say so)
	var nm := (who + "  —  riled!") if riled else who
	if _boss_name.text != nm: _boss_name.text = nm; _boss_name.add_theme_color_override("font_color", Color("8a2a20") if riled else INK)
	_boss_fill.size.x = (BOSS_W - 4.0) * clampf(frac, 0.0, 1.0)
	_boss_fill.color = Color("7a1f18") if riled else Color("a8352a")

## The town's standing beside its name (the player's boss battles: each boss beaten raises it): a mining camp, a
## boom town once Second Street's up, the county seat with Third, a free town once Crane's mortgage is burnt.
var town_rank: Label
func set_town_rank(rank: String) -> void:
	if town_rank and town_rank.text != rank: town_rank.text = rank
