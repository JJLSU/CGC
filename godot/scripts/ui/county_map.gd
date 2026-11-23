class_name CountyMap
extends Control
## map.js: the county map (M or Tab). A hand-inked map on a sheet of handmade paper, washed in watercolour where
## you've been and left blank parchment where you haven't. It marks the wild lands you've seen (lettered big),
## Cold Glitter Creek's streets, the tinker, old orchards, your own camps and yard, the fair, a fallen star, the guarded
## sites, landmarks and the camps' lands, you (an arrow), an inset of the home place, a compass and scale, and
## margin arrows home, to the nearest iron and to their land. Exploration is remembered in 16 m cells.

const CELL := 16.0
const SEE := 3
const SPAN := 320.0
const W := 560.0
const N := 96 ## wash samples a side (blurred soft after; 140 cost ~150 ms each time the map opened)
const WASH := {"water": "8fb3ad", "forest": "93a35c", "meadow": "d6c47a", "field": "e2b65a", "highland": "b8a68a", "peak": "d9d2c4"}
const INK := Color("3a2a1c")
const MARKS := {"campfire": "e07a2e", "bed": "b5473a", "dock": "c99a5e", "skep": "d9a948", "woodpile": "7a5636", "feeder": "4f6f96", "press": "c4362f", "patch": "de7a32", "homeapple": "7d9a4e", "forge": "8a8580"}
const KIND_NAMES := {"sang": "Sang", "silver": "Silver", "pearl": "Pearls", "geode": "Thunder eggs", "amber": "Amber"}

var explored := {}
var cell := ""
var ctx := {}
var wash: ImageTexture
var named := {}
var specks := PackedVector3Array()
var serif: SystemFont
var serif_i: SystemFont
var serif_bi: SystemFont
var serif_b: SystemFont
var inset := Control.new()
## Panning and zooming (the player's ask): the sheet looks at the farmer + view, SPAN wide by default; the wash is
## painted for one view (wash_c, wash_span) and slid and scaled to follow until it's painted afresh.
var view := Vector2.ZERO
var span := SPAN
var wash_c := Vector2.ZERO
var wash_span := SPAN
const SPAN_MIN := 120.0
const SPAN_MAX := 1400.0
var paper := ColorRect.new()
var wash_rect := TextureRect.new()
var wash_sharp := TextureRect.new()
const BLUR := """shader_type canvas_item;
uniform float px = 0.0054; // (3 px of the 560 px sheet)
void fragment() {
	vec4 c = vec4(0.0); float w = 0.0;
	for (int i = -3; i <= 3; i++) for (int j = -3; j <= 3; j++) {
		float k = exp(-float(i * i + j * j) / 4.5);
		c += texture(TEXTURE, UV + vec2(float(i), float(j)) * px * 0.5) * k; w += k;
	}
	COLOR = c / w;
}"""

func _init() -> void:
	custom_minimum_size = Vector2(W, W); size = Vector2(W, W); mouse_filter = Control.MOUSE_FILTER_IGNORE; texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	serif = _font(false, false); serif_i = _font(true, false); serif_b = _font(false, true); serif_bi = _font(true, true)
	# the parchment and the wash sit behind the ink: the wash blurred soft, then a fainter sharp pass for the pooled edge
	for r in [paper, wash_rect, wash_sharp]:
		r.show_behind_parent = true; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; r.size = Vector2(W, W); add_child(r)
	paper.color = Color("efe3c4")
	wash_rect.stretch_mode = TextureRect.STRETCH_SCALE; wash_sharp.stretch_mode = TextureRect.STRETCH_SCALE
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = BLUR; sm.shader = sh; wash_rect.material = sm
	wash_sharp.modulate.a = 0.35
	inset.clip_contents = true; inset.mouse_filter = Control.MOUSE_FILTER_IGNORE; inset.draw.connect(_draw_inset); add_child(inset)

static func _font(italic: bool, bold: bool) -> SystemFont:
	var f := SystemFont.new(); f.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"]); f.font_italic = italic; f.font_weight = 700 if bold else 400
	return f

func load_state(list) -> void:
	for k in (list if list != null else []): explored[k] = true
func save() -> Array: return explored.keys()

## Mark the cells around (x, z) as explored (only when it moves into a new cell).
func update_at(x: float, z: float) -> void:
	var ci := floori(x / CELL); var cj := floori(z / CELL); var key := "%d,%d" % [ci, cj]
	if key == cell: return
	cell = key
	for dj in range(-SEE, SEE + 1):
		for di in range(-SEE, SEE + 1):
			if di * di + dj * dj <= SEE * SEE + 1: explored["%d,%d" % [ci + di, cj + dj]] = true
## Ink a ring of country round (x, z) onto the map (a tip, a view, a sketch on a handbill).
func reveal(x: float, z: float, r: float, step_a := 0.8, step_r := 14.0) -> void:
	var a := 0.0
	while a < TAU:
		var rr := 0.0
		while rr <= r:
			cell = ""; update_at(x + cos(a) * rr, z + sin(a) * rr); rr += step_r
		a += step_a
	cell = ""

func seen(x: float, z: float) -> bool: return explored.has("%d,%d" % [floori(x / CELL), floori(z / CELL)])

static func _hash(a: int, b: int) -> float:
	var h := sin(a * 127.1 + b * 311.7) * 43758.5453; return h - floorf(h)

func center() -> Vector2: return Vector2(ctx.player.x + view.x, ctx.player.z + view.y) if not ctx.is_empty() else view

func _px(x: float, z: float) -> Vector2:
	var c := center()
	return Vector2(((x - c.x) / span + 0.5) * W, ((z - c.y) / span + 0.5) * W)

## Drag the sheet by (dx, dy) screen pixels (it follows the mouse); zoom by steps of the wheel (in: smaller span).
func pan(d: Vector2) -> void:
	if d == Vector2.ZERO or ctx.is_empty(): return
	view -= d * span / W
	view = view.limit_length(1600.0)
	_place_wash(); repaint()
func zoom(steps: float) -> void:
	if steps == 0.0 or ctx.is_empty(): return
	span = clampf(span * pow(1.18, steps), SPAN_MIN, SPAN_MAX)
	_place_wash(); repaint()
func recenter() -> void:
	view = Vector2.ZERO; span = SPAN
	_place_wash(); repaint()
func moved() -> bool: return center().distance_to(wash_c) > 1.0 or absf(span - wash_span) > 1.0

func _place_wash() -> void:
	var c := center()
	var tl := ((wash_c - Vector2(wash_span, wash_span) / 2.0) - (c - Vector2(span, span) / 2.0)) / span * W
	for r in [wash_rect, wash_sharp]: r.position = tl; r.size = Vector2.ONE * wash_span / span * W
	if not ctx.is_empty(): var hp := _px(ctx.home.x, ctx.home.z); inset.visible = _on(hp) and span <= SPAN * 1.4

func _on(p: Vector2) -> bool: return p.x >= 0 and p.y >= 0 and p.x <= W and p.y <= W

## ctx: player (pos), fwd, home, sites, tinker (pos or null), orchards, pieces, fair, star, town {at, along, toward, offs, mended}.
## rewash false: only the ink is redrawn (new marks as far country is laid out), the wash and specks kept.
func paint(c: Dictionary, rewash := true) -> void:
	ctx = c
	if not rewash: repaint(); return
	var vc := center(); var cx: float = vc.x; var cz: float = vc.y
	wash_c = vc; wash_span = span
	# 1. the watercolour wash of the land, sampled coarse and scaled up soft; unexplored left as parchment
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	named = {}
	for j in N:
		for i in N:
			var x := cx + (float(i) / N - 0.5) * span; var z := cz + (float(j) / N - 0.5) * span
			var jx := (_hash(i >> 1, j >> 1) - 0.5) * 14.0; var jz := (_hash(j >> 1, i >> 1) - 0.5) * 14.0
			if not seen(x + jx, z + jz): img.set_pixel(i, j, Color(0, 0, 0, 0)); continue
			var col := Color(WASH.get(Terrain.region_at(x, z), WASH.meadow))
			var t := Terrain.land_tint(x, z) # (the wild lands wash in their own colours; also sets L_id/L_wild)
			if Terrain.L_wild > 0.7:
				var n: Array = named.get(Terrain.L_id, [0.0, 0.0, 0]); n[0] += x; n[1] += z; n[2] += 1; named[Terrain.L_id] = n # (in the world: they move with the sheet)
			img.set_pixel(i, j, Color(minf(1.0, col.r * t.x), minf(1.0, col.g * t.y), minf(1.0, col.b * t.z), 215.0 / 255.0))
	wash = ImageTexture.create_from_image(img)
	wash_rect.texture = wash; wash_sharp.texture = wash
	# 2. paper fibre specks
	specks = PackedVector3Array()
	for k in 700: specks.append(Vector3(randf() * W, randf() * W, randf() * 0.08))
	_place_wash()
	inset.position = Vector2(14, W - 150 - 62); inset.size = Vector2(150, 150); inset.rotation = -0.02; inset.pivot_offset = Vector2(75, 75)
	repaint()

func _label(text: String, p: Vector2, size := 17, font: Font = null, col := INK) -> void:
	var f := font if font else serif_i
	draw_string(f, Vector2(p.x - 150, p.y), text, HORIZONTAL_ALIGNMENT_CENTER, 300, size, col)

func _poly(pts: PackedVector2Array, fill: Color, line := 0.0, line_col := INK) -> void:
	draw_colored_polygon(pts, fill)
	if line > 0.0: var q := pts.duplicate(); q.append(pts[0]); draw_polyline(q, line_col, line, true)

func _circle(p: Vector2, r: float, fill: Color, line := 0.0) -> void:
	draw_circle(p, r, fill)
	if line > 0.0: draw_arc(p, r, 0, TAU, 24, INK, line, true)

func _arrow(at: Vector2, ang: float, col: Color, s := 1.0) -> void:
	var pts := PackedVector2Array([Vector2(20, 0), Vector2(2, -11), Vector2(6, -4), Vector2(-14, -4), Vector2(-14, 4), Vector2(6, 4), Vector2(2, 11)])
	var out := PackedVector2Array()
	for q in pts: out.append(at + (q * s).rotated(ang))
	_poly(out, col, 2.0)

func _draw() -> void:
	if ctx.is_empty(): return
	var cx: float = ctx.player.x; var cz: float = ctx.player.z
	for s in specks: draw_rect(Rect2(s.x, s.y, 1.5, 1.5), Color(90 / 255.0, 60 / 255.0, 30 / 255.0, s.z))
	# the wild lands you've seen, lettered big across their country
	var put_names := [_px(ctx.home.x, ctx.home.z), _px(ctx.town.at.x, ctx.town.at.z) - Vector2(0, 30)] # (never over home or the town's chit)
	var by_size := named.keys(); by_size.sort_custom(func(a, b): return named[a][2] > named[b][2]) # (the biggest stretch named first)
	for id in by_size:
		var n: Array = named[id]
		if n[2] < 40: continue
		var p := _px(n[0] / n[2], n[1] / n[2])
		if put_names.any(func(q): return absf(q.x - p.x) < 150.0 and absf(q.y - p.y) < 34.0): continue # (zoomed out they gather: one per spot)
		put_names.append(p)
		var nm: String = String(Terrain.LANDS[id].name).trim_prefix("the ").to_upper()
		_label(nm, p, 22, serif_i, Color(58 / 255.0, 42 / 255.0, 28 / 255.0, 0.75))
	# Cold Glitter Creek: each street an ochre band with a row of false fronts down either side, its name on a chit
	var town: Dictionary = ctx.town
	if seen(town.at.x, town.at.z):
		for off in town.offs:
			var a: Vector3 = town.at + town.toward * off
			var p0 := _px((a - town.along * 24.0).x, (a - town.along * 24.0).z); var p1 := _px((a + town.along * 24.0).x, (a + town.along * 24.0).z)
			draw_line(p0, p1, Color("c9a46a"), 7.0, true); draw_line(p0, p1, INK, 1.0, true)
			for s in range(-20, 21, 8):
				for side in [-1, 1]:
					var q: Vector3 = a + town.along * s + town.toward * (side * 9.5); var qp := _px(q.x, q.z)
					draw_rect(Rect2(qp - Vector2(3, 3), Vector2(6, 6)), Color("b8875a") if side > 0 else Color("a87a52")); draw_rect(Rect2(qp - Vector2(3, 3), Vector2(6, 6)), INK, false, 1.0)
		var tp := _px(town.at.x, town.at.z)
		var pop: String = ("pop. %d" % (11 + town.mended * 4)) if town.mended else "pop. 11 (and falling)"
		var cy := tp.y - 34; var cw := maxf(serif_bi.get_string_size("Cold Glitter Creek", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, 90) + 16
		draw_rect(Rect2(tp.x - cw / 2 + 2, cy - 15, cw, 34), Color(0, 0, 0, 0.18))
		var chit := PackedVector2Array()
		for i in 9: chit.append(Vector2(tp.x - cw / 2 + cw * i / 8.0, cy - 17 + (1.5 if i % 2 else -1.0)))
		for i in range(8, -1, -1): chit.append(Vector2(tp.x - cw / 2 + cw * i / 8.0, cy + 15 + (1.0 if i % 2 else -1.5)))
		_poly(chit, Color("f3ead6"), 1.0)
		_label("Cold Glitter Creek", Vector2(tp.x, cy), 17, serif_bi); _label(pop, Vector2(tp.x, cy + 12), 12, serif_i)
		draw_line(Vector2(tp.x, cy + 16), Vector2(tp.x, tp.y - 6), INK, 1.0)
	if ctx.tinker != null and seen(ctx.tinker.x, ctx.tinker.z):
		var p := _px(ctx.tinker.x, ctx.tinker.z); _circle(p, 6, Color("d9a441"), 2.0); _label("Tinker", p + Vector2(30, 5))
	for o in ctx.orchards:
		if not seen(o.x, o.z): continue
		var p := _px(o.x, o.z)
		if not _on(p): continue
		_circle(p + Vector2(0, -4), 8, Color("7d9a4e"), 1.5); draw_rect(Rect2(p.x - 1.5, p.y + 3, 3, 6), Color("6b4a30"))
		for d in [Vector2(-3, -6), Vector2(3, -3), Vector2(0, -1)]: draw_circle(p + Vector2(0, -4) + d + Vector2(0, 2), 1.8, Color("c4362f"))
		_label("Apples", p + Vector2(0, 22))
	# your own camps and yard
	for pc in ctx.pieces:
		if not MARKS.has(pc.type): continue
		var p := _px(pc.x, pc.z)
		if not _on(p): continue
		_glyph(self, pc.type, p, 1.0)
	if ctx.fair != null and seen(ctx.fair.x, ctx.fair.z):
		var p := _px(ctx.fair.x, ctx.fair.z); var ros := PackedVector2Array()
		for k in 16: var a := k / 16.0 * TAU; ros.append(p + Vector2(cos(a), sin(a)) * (6.0 if k % 2 else 9.0))
		_poly(ros, Color("4a7ab8"), 1.5); draw_circle(p, 3.5, Color("d9a441")); _label("Fair", p + Vector2(-26, 8))
	if ctx.star != null:
		var p := _px(ctx.star.x, ctx.star.z)
		if p.x > 0 and p.y > 0 and p.x < W and p.y < W:
			var st := PackedVector2Array()
			for k in 10: var a := -PI / 2 + k * PI / 5; st.append(p + Vector2(cos(a), sin(a)) * (4.0 if k % 2 else 9.0))
			_poly(st, Color("e8c870"), 1.5); _label("Star", p + Vector2(24, 4))
	var iron_on := false
	for site in ctx.sites:
		var known := seen(site.x, site.z)
		if not known and not site.get("rumour", false): continue
		var p := _px(site.x, site.z)
		if not _on(p): continue
		if site.kind == "camp": # their land: a ring of red dashes where the poles stand, and a little lodge
			var rr := absf(_px(site.x + site.r, site.z).x - p.x)
			var segs := int(TAU * rr / 10.0)
			for k in segs: var a0 := k * TAU / segs; draw_arc(p, rr, a0, a0 + TAU / segs * 0.5, 3, Color("a8352a"), 2.0, true)
			_poly(PackedVector2Array([p + Vector2(-8, 7), p + Vector2(0, -9), p + Vector2(8, 7)]), Color("e6d3ae"), 1.5)
			draw_polyline(PackedVector2Array([p + Vector2(-2, -13), p + Vector2(0, -9), p + Vector2(2, -13)]), INK, 1.5)
			_label(("Friends: welcome %d day%s" % [site.peace, "s" if site.peace > 1 else ""]) if site.peace > 0 else "Natives", p + Vector2(0, rr + 16))
			continue
		if site.kind == "jumpers": # a claim jumpers' camp: a dark tent and a crossed pick and pistol, in red
			var col := Color("8a2a20") if not site.cleared else Color(INK, 0.45)
			_poly(PackedVector2Array([p + Vector2(-9, 7), p + Vector2(0, -8), p + Vector2(9, 7)]), Color("6b5a48") if not site.cleared else Color("b8a890"), 1.5)
			draw_arc(p, 15.0, 0, TAU, 20, col, 2.0, true)
			_label("Claim Jumpers" + (" (cleared)" if site.cleared else ""), p + Vector2(0, 31), 15, serif_b, col)
			continue
		if site.kind == "vein": # crossed picks; inked faint from the assayer's say-so till you've seen it
			iron_on = true; var c := Color(INK, 1.0 if known else 0.55)
			draw_line(p + Vector2(-8, -8), p + Vector2(8, 8), c, 2.5, true); draw_line(p + Vector2(8, -8), p + Vector2(-8, 8), c, 2.5, true)
			_label("Iron" if known else "Iron?", p + Vector2(0, 24), 17, null, c)
		elif site.kind == "thicket":
			for d in [Vector2(-5, 2), Vector2(5, 2), Vector2(0, -5)]: _circle(p + d, 4.5, Color("c4363a"), 2.5)
			_label("Berries", p + Vector2(0, 24))
		elif site.kind == "landmark": # an inked compass star, named once you've been there
			var st := PackedVector2Array()
			for k in 8: var a := -PI / 2 + k * PI / 4; st.append(p + Vector2(cos(a), sin(a)) * (4.0 if k % 2 else 11.0))
			_poly(st, Color("d9a441"), 2.5); _label(site.get("foundName", "?") if site.get("foundName") != null else "?", p + Vector2(0, 26))
		elif site.has("land") and site.land != null: # a wild land's treasure: a question mark till you know what keeps it
			_circle(p, 9, Color("efe3c4"), 2.5); _label("?", p + Vector2(0, 5), 14, serif_b)
			_label(KIND_NAMES.get(site.kind, "?"), p + Vector2(0, 26))
		else: # a skep hive
			var hv := PackedVector2Array()
			for k in 9: var a := PI + k * PI / 8; hv.append(p + Vector2(cos(a) * 8, sin(a) * 9))
			hv.append(p + Vector2(8, 5)); hv.append(p + Vector2(-8, 5))
			_poly(hv, Color("d9a948"), 2.5); _label("Honey", p + Vector2(0, 24))
	# the farmer: an inked arrow pointing the way he faces
	var me := _px(cx, cz); var f: Vector3 = ctx.fwd; var ang := atan2(f.x, -f.z)
	var tri := PackedVector2Array()
	for q in [Vector2(0, -13), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)]: tri.append(me + q.rotated(ang))
	_poly(tri, Color("b5523b"), 2.0)
	# compass rose (north = -z) and a scale bar
	var rose := Vector2(W - 50, 54)
	draw_arc(rose, 22, 0, TAU, 32, INK, 1.5, true)
	draw_colored_polygon(PackedVector2Array([rose + Vector2(0, -30), rose + Vector2(6, 0), rose + Vector2(0, 30), rose + Vector2(-6, 0)]), INK)
	_label("N", rose + Vector2(0, -34), 16, serif_b)
	var yards := 50.0
	for yd in [25.0, 50.0, 100.0, 200.0, 400.0]: if yd / span * W >= 40.0: yards = yd; break
	var px50 := yards / span * W
	for seg in [[Vector2(24, W - 28), Vector2(24 + px50, W - 28)], [Vector2(24, W - 33), Vector2(24, W - 23)], [Vector2(24 + px50, W - 33), Vector2(24 + px50, W - 23)]]: draw_line(seg[0], seg[1], INK, 2.0)
	draw_string(serif_i, Vector2(24, W - 38), "%d yards, more or less" % yards, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	if view.length() > 2.0 or absf(span - SPAN) > 1.0: draw_string(serif_i, Vector2(W - 210, W - 14), "right-click or R: back to you", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(INK, 0.7))
	var to_margin := func(q: Vector2, m: float) -> Array:
		var d := q - Vector2(W / 2, W / 2); var k := (W / 2 - m) / maxf(absf(d.x), absf(d.y))
		return [Vector2(W / 2, W / 2) + d * k, atan2(d.y, d.x)]
	# no iron on the sheet: a grey arrow on the margin toward the nearest vein the assayer knows of
	if not iron_on:
		var vein = null; var vd := INF
		for s in ctx.sites: if s.kind == "vein" and Vector2(s.x - cx, s.z - cz).length() < vd: vd = Vector2(s.x - cx, s.z - cz).length(); vein = s
		if vein != null:
			var m: Array = to_margin.call(_px(vein.x, vein.z), 44.0); _arrow(m[0], m[1], Color("7a7470"))
			_label("Iron, %d paces" % (roundi(vd * 1.3 / 10.0) * 10), Vector2(clampf(m[0].x - cos(m[1]) * 50, 70, W - 70), clampf(m[0].y - sin(m[1]) * 32, 24, W - 16)))
	# their land off the sheet: a red arrow toward the nearest camp
	var camps: Array = ctx.sites.filter(func(q): return q.kind == "camp")
	if camps.size() and not camps.any(func(q): return _on(_px(q.x, q.z))):
		camps.sort_custom(func(a, b): return Vector2(a.x - cx, a.z - cz).length() < Vector2(b.x - cx, b.z - cz).length())
		var cs: Dictionary = camps[0]; var m: Array = to_margin.call(_px(cs.x, cs.z), 44.0); _arrow(m[0], m[1], Color("a8352a"))
		_label("%s, %d paces" % ["Friends" if cs.peace > 0 else "Natives", roundi(Vector2(cs.x - cx, cs.z - cz).length() * 1.3 / 10.0) * 10], Vector2(clampf(m[0].x - cos(m[1]) * 60, 90, W - 90), clampf(m[0].y - sin(m[1]) * 32, 24, W - 16)))
	# home: an arrow on the margin when it's off the sheet, else a big red house on a cream badge
	var home: Vector3 = ctx.home; var hp := _px(home.x, home.z); var hd := Vector2(home.x - cx, home.z - cz).length()
	if not _on(hp):
		var m: Array = to_margin.call(hp, 38.0); _arrow(m[0], m[1], Color("a8352a"), 1.1)
		_label("Home, %d paces" % maxi(10, roundi(hd * 1.3 / 10.0) * 10), Vector2(clampf(m[0].x - cos(m[1]) * 46, 70, W - 70), clampf(m[0].y - sin(m[1]) * 30, 24, W - 16)))

func _glyph(c: CanvasItem, type: String, p: Vector2, s: float) -> void:
	var col := Color(MARKS[type])
	match_glyph(c, type, p, s, col)

func match_glyph(c: CanvasItem, type: String, p: Vector2, s: float, col: Color) -> void:
	if type == "campfire":
		var fl := PackedVector2Array()
		for k in 9: var t := k / 8.0; fl.append(p + Vector2(sin(t * PI) * 5.0 * s, lerpf(-7.0, 4.0, t) * s))
		for k in range(7, 0, -1): var t := k / 8.0; fl.append(p + Vector2(-sin(t * PI) * 5.0 * s, lerpf(-7.0, 4.0, t) * s))
		c.draw_colored_polygon(fl, col); var q := fl.duplicate(); q.append(fl[0]); c.draw_polyline(q, INK, 1.0, true)
	elif type == "woodpile":
		for o in [Vector2(-3, 2), Vector2(3, 2), Vector2(0, -3)]: c.draw_circle(p + o * s, 3.0 * s, col); c.draw_arc(p + o * s, 3.0 * s, 0, TAU, 12, INK, 1.0, true)
	elif type == "patch" or type == "homeapple":
		c.draw_circle(p, 5.0 * s, col); c.draw_arc(p, 5.0 * s, 0, TAU, 16, INK, 1.0, true)
	elif type == "feeder":
		var t := PackedVector2Array([p + Vector2(-6, 0) * s, p + Vector2(0, -6) * s, p + Vector2(6, 0) * s])
		c.draw_colored_polygon(t, col); c.draw_polyline(PackedVector2Array([t[0], t[1], t[2], t[0]]), INK, 1.0, true); c.draw_rect(Rect2(p.x - 1, p.y, 2, 6 * s), col)
	else:
		c.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), col); c.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), INK, false, 1.0)

## The inset of the home place, drawn bigger in the lower-left corner (56 m across), only while home is on the
## sheet; the home badge is drawn over everything last.
func _draw_inset() -> void:
	if ctx.is_empty(): return
	var IW := 150.0; var S := IW / 56.0; var home: Vector3 = ctx.home
	var ip := func(x: float, z: float) -> Vector2: return Vector2(IW / 2 + (x - home.x) * S, IW / 2 + (z - home.z) * S)
	inset.draw_rect(Rect2(0, 0, IW, IW), Color("efe3c4")); inset.draw_rect(Rect2(0, 0, IW, IW), INK, false, 1.5)
	inset.draw_string(serif_i, Vector2(6, 15), "The home place", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	var h: Vector2 = ip.call(home.x, home.z)
	var hs := PackedVector2Array([h + Vector2(-9, 6), h + Vector2(-9, -2), h + Vector2(0, -10), h + Vector2(9, -2), h + Vector2(9, 6)])
	inset.draw_colored_polygon(hs, Color("b5473a")); var q := hs.duplicate(); q.append(hs[0]); inset.draw_polyline(q, INK, 1.5, true)
	for pc in ctx.pieces:
		if not MARKS.has(pc.type): continue
		var p: Vector2 = ip.call(pc.x, pc.z)
		if p.x > 0 and p.y > 0 and p.x < IW and p.y < IW: match_glyph(inset, pc.type, p, 0.87, Color(MARKS[pc.type]))
	if ctx.fair != null: var p: Vector2 = ip.call(ctx.fair.x, ctx.fair.z); inset.draw_circle(p, 5, Color("4a7ab8")); inset.draw_arc(p, 5, 0, TAU, 16, INK, 1.0, true)
	if ctx.tinker != null: var p: Vector2 = ip.call(ctx.tinker.x, ctx.tinker.z); inset.draw_circle(p, 4.5, Color("d9a441")); inset.draw_arc(p, 4.5, 0, TAU, 16, INK, 1.0, true)
	var me: Vector2 = ip.call(ctx.player.x, ctx.player.z); inset.draw_circle(me, 3.5, Color("b5523b")); inset.draw_arc(me, 3.5, 0, TAU, 12, INK, 1.0, true)

## The home badge, drawn over everything else (a child drawn after the inset).
class Badge extends Control:
	var m: CountyMap
	func _draw() -> void:
		if m.ctx.is_empty(): return
		var home: Vector3 = m.ctx.home; var p := m._px(home.x, home.z)
		if not m._on(p): return
		draw_circle(p + Vector2(0, -2), 19, Color("f6efe0")); draw_arc(p + Vector2(0, -2), 19, 0, TAU, 32, CountyMap.INK, 2.0, true)
		var hs := PackedVector2Array([p + Vector2(-12, 9), p + Vector2(-12, -3), p + Vector2(0, -15), p + Vector2(12, -3), p + Vector2(12, 9)])
		draw_colored_polygon(hs, Color("a8352a")); var q := hs.duplicate(); q.append(hs[0]); draw_polyline(q, CountyMap.INK, 2.0, true)
		draw_rect(Rect2(p.x - 3, p.y + 1, 6, 8), Color("f6efe0"))
		var c: Vector3 = m.ctx.player; var d := Vector2(home.x - c.x, home.z - c.z).length()
		var ly := p.y - 28 if p.y + 36 > CountyMap.W - 8 else p.y + 36
		var text := ("Home, %d paces" % (roundi(d * 1.3 / 10.0) * 10)) if d > 25 else "Home"
		draw_string_outline(m.serif_bi, Vector2(p.x - 150, ly), text, HORIZONTAL_ALIGNMENT_CENTER, 300, 17, 4, Color(246 / 255.0, 239 / 255.0, 224 / 255.0, 0.9))
		draw_string(m.serif_bi, Vector2(p.x - 150, ly), text, HORIZONTAL_ALIGNMENT_CENTER, 300, 17, CountyMap.INK)

var badge := Badge.new()
func _ready() -> void:
	badge.m = self; badge.size = Vector2(W, W); badge.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(badge)

func repaint() -> void: queue_redraw(); inset.queue_redraw(); badge.queue_redraw()
