extends Control
## Screen router: main menu, research, settings, field notes, and the battle.
## The battle itself is scripts/battle.gd.

const UIKit = preload("res://scripts/ui_kit.gd")
const Starfield = preload("res://scripts/starfield.gd")
const ShipBadge = preload("res://scripts/ship_badge.gd")
const Glyph = preload("res://scripts/weapon_glyph.gd")
const Battle = preload("res://scripts/battle.gd")
const Dev = preload("res://scripts/dev_console.gd")

var _screen: Control
var _battle
var _dev
var _confirm: Control
var _page := "menu"
var _built_w := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = UIKit.font_body()
	theme.default_font_size = int(round(UIKit.px(18.0)))
	self.theme = theme
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UIKit.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var stars := Starfield.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stars)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	_dev = Dev.new()
	add_child(_dev)
	get_tree().root.size_changed.connect(_on_fit_changed)
	if ScreenFit.has_signal("changed"):
		ScreenFit.changed.connect(_on_fit_changed)
	show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _battle and is_instance_valid(_battle) and _battle.alive:
			_battle.toggle_pause()


func show_menu() -> void:
	_page = "menu"
	_built_w = get_viewport_rect().size.x
	_clear()
	var root := _column(10)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 8)
	var title := UIKit.label("VECTOR HOLD", 36, UIKit.TEXT, false, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var ver := str(ProjectSettings.get_setting("application/config/version", "1.0.1"))
	var ver_label := UIKit.label("v" + ver, 12, UIKit.MUTED, true)
	ver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(ver_label)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.add_child(_home_status())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var dev := _small_button("DEV")
	dev.pressed.connect(_dev.toggle)
	row.add_child(dev)
	var gear := _small_button("SET")
	gear.pressed.connect(show_settings)
	row.add_child(gear)
	root.add_child(row)
	var ship := ShipBadge.new()
	ship.custom_minimum_size = Vector2(UIKit.px(120), UIKit.px(112))
	ship.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(ship)
	var glyphs := HBoxContainer.new()
	glyphs.alignment = BoxContainer.ALIGNMENT_CENTER
	glyphs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyphs.add_theme_constant_override("separation", 4)
	root.add_child(glyphs)
	for kind in ["rail", "missile", "laser", "tesla", "drone", "flame"]:
		var icon := Glyph.new()
		icon.kind = kind
		icon.dim = not Profile.weapon_unlocked(kind)
		glyphs.add_child(icon)
	root.add_child(_lore_block())
	root.add_child(_menu_button("DEPLOY", true, show_battle))
	root.add_child(_menu_button("RESEARCH", false, show_research))
	root.add_child(_menu_button("FIELD NOTES", false, show_notes))
	var extra := UIKit.label(Profile.next_unlock_label(), 13, UIKit.MUTED)
	extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(extra)


func _home_status() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_box())
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	col.add_child(UIKit.label(Profile.act_line(), 13, UIKit.AMBER, true))
	var bar := UIKit.progress_bar(Profile.act_ratio(), UIKit.AMBER)
	bar.custom_minimum_size = Vector2(UIKit.px(168), UIKit.px(8))
	col.add_child(bar)
	col.add_child(UIKit.label("GOLD %d" % int(Profile.gold), 14, UIKit.TEXT, true))
	col.add_child(UIKit.label("BEST ROUND %d" % Profile.best_round, 14, UIKit.TEXT, true))
	return panel


func _menu_button(text: String, primary: bool, action: Callable) -> Button:
	var node := UIKit.button(text, primary)
	node.custom_minimum_size = Vector2(UIKit.px(176), UIKit.px(40))
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.add_theme_font_size_override("font_size", int(round(UIKit.px(15.0))))
	node.pressed.connect(action)
	return node


func _small_button(text: String) -> Button:
	var node := UIKit.button(text, false)
	node.custom_minimum_size = Vector2(UIKit.px(56), UIKit.px(34))
	node.add_theme_font_size_override("font_size", int(round(UIKit.px(13.0))))
	return node


func show_battle() -> void:
	_page = "battle"
	_built_w = get_viewport_rect().size.x
	_clear()
	Sfx.unlock()
	_battle = Battle.new()
	_battle.leave.connect(_on_leave)
	_screen.add_child(_battle)
	_dev.battle_ref = _battle


func show_research() -> void:
	_page = "research"
	_built_w = get_viewport_rect().size.x
	_clear()
	var root := _column()
	_back_row(root, "RESEARCH")
	root.add_child(UIKit.label("Gold %d. Buys persist. Damage research is the long climb. Acts also add hull and defense." % int(Profile.gold), 16, UIKit.MUTED, true))
	var list := _scroll_list(root, 360.0, 8)
	for track in _tracks():
		list.add_child(_research_row(track))


func show_settings() -> void:
	_page = "settings"
	_built_w = get_viewport_rect().size.x
	_clear()
	var root := _column()
	_back_row(root, "SETTINGS")
	var display := UIKit.label(ScreenFit.describe(), 16, UIKit.TEXT, true)
	display.name = "DisplayReadout"
	root.add_child(display)
	root.add_child(UIKit.label("Resolution", 16, UIKit.MUTED))
	root.add_child(_resolution_menu())
	root.add_child(UIKit.label("Auto matches the monitor. A listed size resizes the desktop window. The browser preview stays with the page.", 16, UIKit.MUTED))
	root.add_child(UIKit.label("Sound", 16, UIKit.MUTED))
	root.add_child(UIKit.volume_row())
	var shake := CheckButton.new()
	shake.text = "Screen shake"
	shake.button_pressed = Profile.shake
	shake.add_theme_font_override("font", UIKit.font_body())
	shake.add_theme_font_size_override("font_size", int(round(UIKit.px(18.0))))
	UIKit._paint(shake, UIKit.TEXT)
	shake.toggled.connect(func(on: bool) -> void:
		Profile.shake = on
		Profile.save()
	)
	root.add_child(shake)
	root.add_child(UIKit.label("PC: F1 or ` opens the balance console. Esc pauses a run.", 16, UIKit.MUTED))
	var reset := UIKit.button("RESET PROGRESS", false)
	reset.pressed.connect(_ask_reset)
	root.add_child(reset)


func _resolution_menu() -> OptionButton:
	var menu := OptionButton.new()
	menu.custom_minimum_size = Vector2(0, UIKit.px(52))
	menu.focus_mode = Control.FOCUS_ALL
	menu.add_theme_font_override("font", UIKit.font_mono())
	menu.add_theme_font_size_override("font_size", int(round(UIKit.px(18.0))))
	menu.add_theme_color_override("font_color", UIKit.TEXT)
	menu.add_theme_color_override("font_hover_color", UIKit.AMBER)
	menu.add_theme_color_override("font_pressed_color", UIKit.AMBER)
	menu.add_theme_color_override("font_focus_color", UIKit.TEXT)
	var box := StyleBoxFlat.new()
	box.bg_color = UIKit.PANEL
	box.border_color = UIKit.LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = UIKit.px(14)
	box.content_margin_right = UIKit.px(14)
	box.content_margin_top = UIKit.px(8)
	box.content_margin_bottom = UIKit.px(8)
	menu.add_theme_stylebox_override("normal", box)
	menu.add_theme_stylebox_override("hover", box)
	menu.add_theme_stylebox_override("pressed", box)
	menu.add_theme_stylebox_override("focus", box)
	menu.add_item("Auto (this display)")
	menu.set_item_metadata(0, "auto")
	var selected := 0
	var index := 1
	for size in ScreenFit.monitor_presets():
		var key := ScreenFit.preset_key(size)
		menu.add_item(key.replace("x", "×"))
		menu.set_item_metadata(index, key)
		if key == Profile.resolution:
			selected = index
		index += 1
	var popup := menu.get_popup()
	popup.add_theme_font_override("font", UIKit.font_mono())
	popup.add_theme_font_size_override("font_size", int(round(UIKit.px(16.0))))
	popup.add_theme_color_override("font_color", UIKit.TEXT)
	popup.add_theme_color_override("font_hover_color", UIKit.AMBER)
	menu.select(selected)
	menu.item_selected.connect(func(which: int) -> void:
		ScreenFit.apply_resolution(str(menu.get_item_metadata(which)), true)
		Sfx.unlock()
		Sfx.play("ui")
	)
	return menu


func show_notes() -> void:
	_page = "notes"
	_built_w = get_viewport_rect().size.x
	_clear()
	var root := _column()
	_back_row(root, "FIELD NOTES")
	var list := _scroll_list(root, 420.0, 14)
	var dir := DirAccess.open("res://notes")
	if dir == null:
		list.add_child(UIKit.label("Notes folder missing from the export.", 16, UIKit.DANGER))
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not str(file_name).ends_with(".txt"):
			continue
		var text := FileAccess.get_file_as_string("res://notes/" + str(file_name))
		list.add_child(UIKit.label(str(file_name), 14, UIKit.AMBER, true))
		list.add_child(UIKit.label(text.strip_edges(), 16, UIKit.TEXT))


func _on_leave(retry: bool) -> void:
	if retry:
		show_battle()
	else:
		show_menu()


func _on_fit_changed() -> void:
	_fit_columns()
	if _screen == null:
		return
	var w := get_viewport_rect().size.x
	if _page != "battle" and absf(w - _built_w) > 24.0:
		match _page:
			"research":
				show_research()
			"settings":
				show_settings()
			"notes":
				show_notes()
			_:
				show_menu()
		return
	var readout := _screen.find_child("DisplayReadout", true, false)
	if readout is Label:
		readout.text = ScreenFit.describe()


func _clear() -> void:
	_dev.battle_ref = null
	_battle = null
	for child in _screen.get_children():
		child.queue_free()


func _lore_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := UIKit.label(Profile.act_title(), 18, UIKit.AMBER, false, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var lore := UIKit.label(Profile.act_lore(), 16, UIKit.MUTED)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var width := get_viewport_rect().size.x
	lore.custom_minimum_size = Vector2(clampf(width - 64.0, 240.0, 560.0), 0)
	box.add_child(lore)
	return box


func _column(top_gap: float = 0.0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = top_gap
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_screen.add_child(scroll)
	var margin := MarginContainer.new()
	var width := get_viewport_rect().size.x
	margin.custom_minimum_size = Vector2(width, 0)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	_fit_columns()
	return col


func _fit_columns() -> void:
	if _screen == null:
		return
	var width := get_viewport_rect().size.x
	var col_w := ScreenFit.column_width(width)
	for scroll in _screen.get_children():
		if not (scroll is ScrollContainer):
			continue
		for margin in scroll.get_children():
			if not (margin is MarginContainer):
				continue
			margin.custom_minimum_size = Vector2(width, 0)
			for col in margin.get_children():
				if col is VBoxContainer:
					col.custom_minimum_size = Vector2(col_w, 0)


func _scroll_list(parent: Node, min_h: float, gap: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, UIKit.px(min_h))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", gap)
	scroll.add_child(list)
	return list


func _back_row(parent: VBoxContainer, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var back := UIKit.button("BACK", false)
	back.custom_minimum_size = Vector2(UIKit.px(88), UIKit.px(44))
	back.pressed.connect(show_menu)
	row.add_child(back)
	var label := UIKit.label(title, 24, UIKit.TEXT, false, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)


func _tracks() -> Array:
	var dmg: float = snappedf(float(Balance.getv("research.damage_per")) * 100.0, 0.01)
	var cap := int(Balance.getv("research.damage_cap"))
	var pen: float = snappedf(float(Balance.getv("research.pen_per")) * 100.0, 0.01)
	var pen_cap := int(Balance.getv("research.pen_cap"))
	var edge_cap := int(Balance.getv("research.edge_cap"))
	var edge0 := int(round(float(Balance.getv("research.edge_base")) * 100.0))
	var edge_end := int(round((float(Balance.getv("research.edge_base")) + float(Balance.getv("research.edge_per")) * float(edge_cap)) * 100.0))
	var line := "%s%% more damage per rank. Cap %d. The price climbs, so spread purchases or sink one weapon." % [dmg, cap]
	return [
		["rail", "Railgun damage", line],
		["rail_pen", "Railgun penetration", "%s%% defense ignored per rank. Cap %d. This is how the railgun keeps up with tanks." % [pen, pen_cap]],
		["missile", "Missile damage", line],
		["missile_edge", "Missile edge", "Blasts keep more of their damage at the rim. %d%% climbs to %d%%." % [edge0, edge_end]],
		["laser", "Laser damage", line],
		["tesla", "Tesla damage", line],
		["drone", "Drone damage", line],
		["flame", "Flamethrower damage", line],
	]


func _research_row(track: Array) -> PanelContainer:
	var id := str(track[0])
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var unlocked := Profile.track_unlocked(id)
	var rank := Profile.research_rank(id)
	var cap := Profile.research_cap(id)
	col.add_child(UIKit.label(str(track[1]), 18, UIKit.TEXT if unlocked else UIKit.MUTED, false, true))
	col.add_child(UIKit.label(str(track[2]), 15, UIKit.MUTED))
	var cost := Profile.research_cost(id)
	var status := "Locked until the act unlocks this weapon."
	if unlocked:
		status = "Rank %d / %d" % [rank, cap]
		if rank < cap:
			status += "    Next %d gold" % cost
		else:
			status += "    Maxed"
	col.add_child(UIKit.label(status, 15, UIKit.AMBER if unlocked else UIKit.MUTED, true))
	if unlocked and rank < cap:
		var buy := UIKit.button("BUY", Profile.can_buy(id))
		buy.disabled = not Profile.can_buy(id)
		buy.pressed.connect(func() -> void:
			if Profile.buy(id):
				Sfx.unlock()
				Sfx.play("ui")
				show_research()
		)
		col.add_child(buy)
	return panel


func _ask_reset() -> void:
	if _confirm and is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	_confirm.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -170
	box.offset_right = 170
	box.offset_top = -90
	box.offset_bottom = 90
	box.add_theme_constant_override("separation", 8)
	_confirm.add_child(box)
	box.add_child(UIKit.label("Erase gold, act level, and research on this device?", 16, UIKit.TEXT))
	var yes := UIKit.button("ERASE", true)
	yes.pressed.connect(func() -> void:
		Profile.reset_progress()
		_confirm.queue_free()
		show_settings()
	)
	box.add_child(yes)
	var no := UIKit.button("CANCEL", false)
	no.pressed.connect(func() -> void: _confirm.queue_free())
	box.add_child(no)
