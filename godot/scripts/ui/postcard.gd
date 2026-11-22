class_name Postcard
extends RefCounted
## K: a postcard (main.js makePostcard). The view as it is, without the HUD, printed onto a cream card with a deckled
## edge and a scatter of fibres, pasted on with a thin warm shadow and framed in a fine ink line, captioned
## "Greetings from Cold Glitter Creek" in an italic postcard hand with the day and hour, and a little red 2¢ stamp in the
## corner; saved as cold-glitter-creek-day<N>.png in the Downloads folder (where the page's download lands).

## Grab the frame (the HUD hidden for it), lay out the card in an offscreen viewport, and save it. Returns the path
## written ("" on failure). `dir`: where to save (tests); the Downloads folder by default.
static func snap(main: Node, dir := "") -> String:
	var tree := main.get_tree()
	var hud: CanvasLayer = main.hud
	var was := hud.visible
	hud.visible = false
	await RenderingServer.frame_post_draw
	var shot := main.get_viewport().get_texture().get_image()
	hud.visible = was
	var card := await compose(main, shot, main.sky.clock_text().replace(" · ", ", "))
	if dir == "": dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dir == "": dir = OS.get_user_data_dir()
	var path := dir.path_join("cold-glitter-creek-day%d.png" % main.sky.day)
	return path if card.save_png(path) == OK else ""

## The card itself, the same sizes as the page: pad 6 % of the short side, a foot of 2.2 pads for the caption.
static func compose(main: Node, shot: Image, when: String) -> Image:
	var w := shot.get_width(); var h := shot.get_height()
	var pad := roundi(mini(w, h) * 0.06); var foot := roundi(pad * 2.2)
	var W := w + pad * 2; var H := h + pad + foot
	var vp := SubViewport.new(); vp.size = Vector2i(W, H); vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	main.add_child(vp)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var c := Control.new(); c.size = Vector2(W, H); vp.add_child(c)
	var tex := ImageTexture.create_from_image(shot)
	var serif := SystemFont.new(); serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	var italic := SystemFont.new(); italic.font_names = serif.font_names; italic.font_italic = true
	var bold := SystemFont.new(); bold.font_names = serif.font_names; bold.font_weight = 700
	# the deckled outline and the fibres, fixed now so the one draw is the card
	var j := func() -> float: return rng.randf() * 5.0
	# (as strips of small quads between the torn line and an inner rectangle 5 px in: one big jagged polygon is more
	# than the canvas triangulator will take)
	var edge := []
	var side := func(pts: Array, inner: Callable) -> void:
		for i in pts.size() - 1: edge.append(PackedVector2Array([pts[i], pts[i + 1], inner.call(pts[i + 1]), inner.call(pts[i])]))
	var top := []; var right := []; var bottom := []; var left := []
	for x in range(0, W + 1, 14): top.append(Vector2(x, j.call()))
	for y in range(0, H + 1, 14): right.append(Vector2(W - j.call(), y))
	for x in range(W, -1, -14): bottom.append(Vector2(x, H - j.call()))
	for y in range(H, -1, -14): left.append(Vector2(j.call(), y))
	side.call(top, func(q: Vector2) -> Vector2: return Vector2(clampf(q.x, 5, W - 5), 5))
	side.call(right, func(q: Vector2) -> Vector2: return Vector2(W - 5, clampf(q.y, 5, H - 5)))
	side.call(bottom, func(q: Vector2) -> Vector2: return Vector2(clampf(q.x, 5, W - 5), H - 5))
	side.call(left, func(q: Vector2) -> Vector2: return Vector2(5, clampf(q.y, 5, H - 5)))
	var fibres := []
	for i in int(W * H / 900.0): fibres.append([Rect2(rng.randf() * W, rng.randf() * H, 1.0 + rng.randf() * 3.0, 1.0), rng.randf() * 0.12])
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(5, 5, W - 10, H - 10), Color("efe3c4"))
		for q in edge: c.draw_colored_polygon(q, Color("efe3c4"))
		for f in fibres: c.draw_rect(f[0], Color(110 / 255.0, 80 / 255.0, 50 / 255.0, f[1]))
		# the picture, pasted on with a thin warm shadow (blur 8, offset 3,4)
		var sh := StyleBoxFlat.new(); sh.bg_color = Color(0, 0, 0, 0)
		sh.shadow_color = Color(74 / 255.0, 38 / 255.0, 14 / 255.0, 0.35); sh.shadow_size = 8; sh.shadow_offset = Vector2(3, 4)
		c.draw_style_box(sh, Rect2(pad, pad, w, h))
		c.draw_texture(tex, Vector2(pad, pad))
		c.draw_rect(Rect2(pad, pad, w, h), Color(58 / 255.0, 42 / 255.0, 28 / 255.0, 0.6), false, 2.0)
		# the caption, in a postcard hand (textBaseline middle: the line's middle on the mark)
		var s1 := roundi(foot * 0.36); var s2 := roundi(foot * 0.22)
		c.draw_string(italic, Vector2(pad, h + pad + foot * 0.45 + _mid(italic, s1)), "Greetings from Cold Glitter Creek", HORIZONTAL_ALIGNMENT_LEFT, -1, s1, Color("3a2a1c"))
		c.draw_string(serif, Vector2(pad, h + pad + foot * 0.78 + _mid(serif, s2)), when, HORIZONTAL_ALIGNMENT_LEFT, -1, s2, Color("6b5440"))
		# a little red stamp in the corner, a dashed cream frame inside it
		var sx := W - pad - foot * 0.7; var sy := h + pad + foot * 0.12; var sw := foot * 0.62; var sht := foot * 0.72
		c.draw_rect(Rect2(sx, sy, sw, sht), Color("b5473a"))
		var r := Rect2(sx + 4, sy + 4, sw - 8, sht - 8)
		for e in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
			c.draw_dashed_line(e[0], e[1], Color("efe3c4"), 2.0, 3.0, false)
		var s3 := roundi(sht * 0.35)
		c.draw_string(bold, Vector2(sx, sy + sht / 2.0 + _mid(bold, s3)), "2¢", HORIZONTAL_ALIGNMENT_CENTER, sw, s3, Color("efe3c4")))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

## The baseline offset that puts a line's middle on y (canvas textBaseline 'middle').
static func _mid(f: Font, size: int) -> float:
	return (f.get_ascent(size) - f.get_descent(size)) / 2.0
