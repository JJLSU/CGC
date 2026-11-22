class_name CraftingPanel
extends RefCounted
## crafting.js's CraftingPanel view: a paper card in the middle of the screen (520 px, scrolls), "Crafting" and a
## close cross, what you have, then each tier (By hand, Workbench, Campfire, Forge, the tinker's wagon, and the
## town's shops, the depot, a trading post, a camp's fire and the fair when they're open), every recipe a row:
## its name (a tick once made), its note, its cost (what you're short of in red, with what you have), and a button
## (Craft / Trade / Buy / Enter, or Made / Owned / Delivered / Entered / Away greyed). Then the build pieces.

var hud: Hud
var crafting: Crafting
var card: PanelContainer
var list: VBoxContainer
var have_label: RichTextLabel
var open := false
var on_close: Callable
# the town's and the rail's tiers, opened by their systems (each a Callable -> bool, or -> {name, land} for a post)
var store_open: Callable; var smithy_open: Callable; var bakery_open: Callable; var bank_open: Callable
var feed_open: Callable; var drygoods_open: Callable; var cooper_open: Callable; var depot_open: Callable
var post_open: Callable; var camp_open: Callable; var fair_today: Callable
var pieces: Array = []

func _init(h: Hud, c: Crafting) -> void:
	hud = h; crafting = c
	pieces = JSON.parse_string(FileAccess.open("res://assets/baked/data/pieces_list.json", FileAccess.READ).get_as_text())
	card = hud.card(-0.5, Vector4(22, 14, 22, 12))
	# (where index.html puts every centre panel, held to its 100vh - 320px: 580 tall at 900, the list scrolling)
	card.anchor_left = 0.5; card.anchor_right = 0.5; card.anchor_top = Hud.CENTRE_Y; card.anchor_bottom = Hud.CENTRE_Y
	card.custom_minimum_size = Vector2(520, 0)
	card.offset_left = -260; card.offset_right = 260; card.offset_top = -290; card.offset_bottom = 290
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_child(hud.label("Crafting", 34))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	var x := Button.new(); x.text = "×"; x.flat = true; x.add_theme_font_size_override("font_size", 28)
	x.add_theme_color_override("font_color", Hud.INK); x.pressed.connect(func() -> void: if on_close.is_valid(): on_close.call())
	head.add_child(x); v.add_child(head)
	have_label = _rich(17, Hud.INK_SOFT); v.add_child(have_label)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 0)
	scroll.add_child(list); v.add_child(scroll)
	var foot := hud.label("C or Esc to close", 14, Hud.INK_SOFT); foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; v.add_child(foot)
	card.add_child(v)
	card.visible = false
	hud.root.add_child(card)

func _rich(size: int, col: Color) -> RichTextLabel:
	var l := RichTextLabel.new(); l.bbcode_enabled = true; l.fit_content = true; l.scroll_active = false
	l.add_theme_font_size_override("normal_font_size", size); l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_font_size_override("italics_font_size", size)
	l.add_theme_color_override("default_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## costHTML: what you're short of in red, with what you have in brackets.
func _cost_bb(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in cost:
		var have: int = crafting.inventory.get(k, 0)
		parts.append("%d %s" % [cost[k], k] if have >= cost[k] else "[color=#b5302a][b]%d %s[/b] (%d)[/color]" % [cost[k], k, have])
	return ", ".join(parts)

static func _html_to_bb(s: String) -> String:
	return s.replace("<i>", "[i]").replace("</i>", "[/i]").replace("<b>", "[b]").replace("</b>", "[/b]")

func set_open(v: bool) -> void:
	open = v; card.visible = v
	if v: render()

func _tier(title: String, station) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6)
	h.add_child(hud.label(title, 21))
	if station != null:
		var near: bool = crafting.station_near.is_valid() and crafting.station_near.call(station)
		h.add_child(hud.label("· nearby" if near else "· needs " + String(crafting.station_name.get(station, station)), 15, Color("4f7d43") if near else Hud.INK_SOFT))
	var box := VBoxContainer.new(); box.add_child(h)
	var line := ColorRect.new(); line.color = Hud.EDGE; line.custom_minimum_size = Vector2(0, 1); box.add_child(line)
	box.add_theme_constant_override("separation", 2)
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", 12); m.add_child(box)
	list.add_child(m)
	for r in crafting.recipes:
		if r.get("station") != station: continue
		var why := crafting.blocked(r)
		var owned := why == "Made" or why == "Done" or why == "Owned"
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
		var left := _rich(15, Hud.INK_SOFT)
		left.text = "[font_size=19][color=#3a2f25]%s%s[/color][/font_size]\n%s" % [r.name, " [color=#4f7d43]✓[/color]" if owned else "", _html_to_bb(String(r.get("desc", "")))]
		row.add_child(left)
		var cost := _rich(15, Hud.INK)
		cost.size_flags_horizontal = Control.SIZE_SHRINK_END; cost.autowrap_mode = TextServer.AUTOWRAP_OFF
		cost.text = _cost_bb(r.cost) + ((" → " + Crafting.cost_text(r.gives)) if r.has("gives") else "")
		row.add_child(cost)
		var b := Button.new()
		var label: String
		if why == "Done": label = "Entered" if r.get("fair", false) else "Delivered"
		elif why == "Owned": label = "Owned"
		elif owned: label = "Made"
		elif why != "" and why != "Need more": label = "Away"
		elif r.get("fair", false): label = "Enter"
		elif r.has("gives"): label = "Trade"
		elif r.has("tool"): label = "Buy"
		else: label = "Craft"
		b.text = label; b.disabled = why != ""; b.tooltip_text = why
		b.add_theme_font_size_override("font_size", 17)
		var sb := hud.paper_box(Vector4(12, 2, 12, 2), Color("e9c98a")); sb.border_color = Color("b89a5a")
		var sbd := hud.paper_box(Vector4(12, 2, 12, 2), Color("e8e0cc")); sbd.shadow_size = 0
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sb); b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("disabled", sbd)
		b.add_theme_color_override("font_color", Hud.INK); b.add_theme_color_override("font_disabled_color", Color("9a8c78"))
		var id: String = r.id
		b.pressed.connect(func() -> void:
			if crafting.craft(id): render())
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		var rowbox := VBoxContainer.new(); rowbox.add_child(row)
		var dots := ColorRect.new(); dots.color = Color(Hud.EDGE, 0.7); dots.custom_minimum_size = Vector2(0, 1); rowbox.add_child(dots)
		var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_top", 6); pad.add_theme_constant_override("margin_bottom", 0); pad.add_child(rowbox)
		list.add_child(pad)

func render() -> void:
	for c in list.get_children(): list.remove_child(c); c.queue_free() # (not free(): a Craft press re-renders from inside its own button's signal, and freeing that button mid-signal crashed the game)
	var have := PackedStringArray()
	for k in crafting.inventory:
		if crafting.inventory[k] > 0: have.append("%d %s" % [crafting.inventory[k], k])
	have_label.text = "You have " + (" · ".join(have) if have.size() else "nothing yet")
	_tier("By hand", null); _tier("Workbench", "workbench"); _tier("Campfire", "campfire"); _tier("Forge", "forge"); _tier("Tinker's wagon", "tinker")
	for t in [[store_open, "General store · Cold Glitter Creek", "store"], [smithy_open, "Blacksmith's · Cold Glitter Creek", "smithy"], [bakery_open, "Bakery · Second Street", "bakery"],
			[bank_open, "Miners' bank · Second Street", "bank"], [feed_open, "Feed & grain · Second Street", "feed"], [drygoods_open, "Dry goods · Third Street", "drygoods"],
			[cooper_open, "Cooperage · Third Street", "cooper"], [depot_open, "Freight office · Overland & Western", "depot"]]:
		if (t[0] as Callable).is_valid() and t[0].call(): _tier(t[1], t[2])
	if post_open.is_valid():
		var p = post_open.call()
		if p: _tier("Trading post · %s" % p.name, "post-" + p.land)
	if camp_open.is_valid() and camp_open.call(): _tier("Trading at the camp fire", "camp")
	if fair_today.is_valid() and fair_today.call(): _tier("County Fair · judging today", "fair")
	# the build pieces
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", 12)
	var hb := HBoxContainer.new(); hb.add_child(hud.label("Build pieces", 21)); hb.add_child(hud.label("— craft a hammer, then press B", 15, Hud.INK_SOFT))
	m.add_child(hb); list.add_child(m)
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 18)
	for p in pieces:
		var l := _rich(15, Hud.INK)
		l.text = "• %s [color=#6b5b49]%s%s[/color]" % [p.name, _cost_bb(_ints(p.cost)), "" if p.free else " · near a workbench"]
		grid.add_child(l)
	list.add_child(grid)

static func _ints(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d: o[k] = int(d[k])
	return o
