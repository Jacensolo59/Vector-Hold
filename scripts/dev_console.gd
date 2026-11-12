extends Control
## Balance console for the first version. Backtick or F1, or the DEV button.
## Edits call Balance.setv and are saved on this device. See notes/06-dev-console-and-balance.txt.

const UIKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/balance_data.gd")

var battle_ref = null
var _list: VBoxContainer
var _dump: TextEdit
var _scroll: ScrollContainer
var _menu := "field"
var _section := ""
var _tab_buttons := {}


func _ready() -> void:
	name = "DevConsole"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func toggle() -> void:
	visible = not visible
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	if visible:
		var parent := get_parent()
		if parent:
			parent.move_child(self, parent.get_child_count() - 1)
		_rebuild()
	_sync_hold()
	Sfx.unlock()
	Sfx.play("ui")


func _sync_hold() -> void:
	if battle_ref and is_instance_valid(battle_ref):
		battle_ref.dev_hold = visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F1:
			toggle()
			get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.035, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)
	var title := UIKit.label("BALANCE", 26, UIKit.AMBER, false, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UIKit.button("CLOSE", true)
	close.custom_minimum_size = Vector2(96, 44)
	close.pressed.connect(toggle)
	header.add_child(close)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	col.add_child(tools)
	_tool(tools, "RESET", _reset)
	_tool(tools, "GOD", _god)
	_tool(tools, "RANGES", _ranges)
	_tool(tools, "HITS", _hits)
	_tool(tools, "1x", func() -> void: _speed(1))
	_tool(tools, "2x", func() -> void: _speed(2))
	_tool(tools, "4x", func() -> void: _speed(4))
	var fight := HBoxContainer.new()
	fight.add_theme_constant_override("separation", 6)
	col.add_child(fight)
	_tool(fight, "+LVL", func() -> void: _call_battle("add_levels", 1))
	_tool(fight, "HEAL", func() -> void: _call_battle("heal_full"))
	_tool(fight, "KILL", func() -> void: _call_battle("kill_all"))
	_tool(fight, "+GOLD", func() -> void: Profile.add_gold(50))
	_tool(fight, "ROUND+", func() -> void: _bump_round(1))
	var spawns := HBoxContainer.new()
	spawns.add_theme_constant_override("separation", 6)
	col.add_child(spawns)
	for kind in ["circle", "triangle", "rect", "square", "hex"]:
		_tool(spawns, kind.to_upper(), _spawn.bind(kind))
	var spawns2 := HBoxContainer.new()
	spawns2.add_theme_constant_override("separation", 6)
	col.add_child(spawns2)
	for kind in ["diamond", "chevron", "cross", "mine"]:
		_tool(spawns2, kind.to_upper(), _spawn.bind(kind))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	_tab(tabs, "field", "FIELD")
	_tab(tabs, "research", "RESEARCH")
	var tabs2 := HBoxContainer.new()
	tabs2.add_theme_constant_override("separation", 6)
	col.add_child(tabs2)
	_tab(tabs2, "weapons", "WEAPONS")
	_tab(tabs2, "enemies", "ENEMIES")
	_paint_tabs()
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_scroll = scroll
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_dump = TextEdit.new()
	_dump.custom_minimum_size = Vector2(0, 52)
	_dump.size_flags_vertical = Control.SIZE_SHRINK_END
	_dump.editable = false
	_dump.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_dump.scroll_fit_content_height = false
	_dump.add_theme_font_override("font", UIKit.font_mono())
	_dump.add_theme_font_size_override("font_size", 14)
	_dump.add_theme_color_override("font_color", UIKit.MUTED)
	var dump_box := StyleBoxFlat.new()
	dump_box.bg_color = Color("070b14")
	dump_box.set_content_margin_all(6)
	_dump.add_theme_stylebox_override("normal", dump_box)
	_dump.add_theme_stylebox_override("read_only", dump_box)
	col.add_child(_dump)


func _tool(parent: Node, text: String, callback: Callable) -> void:
	var button := UIKit.button(text, false)
	button.custom_minimum_size = Vector2(0, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	parent.add_child(button)


func _tab(parent: Node, id: String, text: String) -> void:
	var button := UIKit.button(text, false)
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_set_menu.bind(id))
	parent.add_child(button)
	_tab_buttons[id] = button


func _set_menu(id: String) -> void:
	_menu = id
	_section = ""
	_paint_tabs()
	_rebuild()
	if _scroll:
		_scroll.scroll_vertical = 0


func _paint_tabs() -> void:
	for id in _tab_buttons:
		var button: Button = _tab_buttons[id]
		var on: bool = str(id) == _menu
		UIKit._paint(button, UIKit.AMBER if on else UIKit.TEXT)


func _menu_of(section: String) -> String:
	if section == "Field" or section == "Player" or section == "Progress" or section == "Unlocks":
		return "field"
	if section == "Research" or section == "Upgrades":
		return "research"
	if section == "Railgun" or section == "Missiles" or section == "Laser" or section == "Tesla" or section == "Drones" or section == "Flame":
		return "weapons"
	return "enemies"


func _open_section(section: String) -> void:
	if _section == section:
		_section = ""
	else:
		_section = section
	_rebuild()


func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var groups: Dictionary = {}
	var order: Array = []
	for spec in Data.fields():
		var section_name := str(spec[0])
		if _menu_of(section_name) != _menu:
			continue
		if not groups.has(section_name):
			groups[section_name] = []
			order.append(section_name)
		var bucket: Array = groups[section_name]
		bucket.append(spec)
	if _section == "" and not order.is_empty():
		_section = str(order[0])
	for section_name in order:
		var title := str(section_name)
		var open: bool = title == _section
		var header := UIKit.button(title.to_upper(), open)
		header.custom_minimum_size = Vector2(0, 40)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.pressed.connect(_open_section.bind(title))
		_list.add_child(header)
		if not open:
			continue
		var specs: Array = groups[title]
		for spec in specs:
			_row(spec)
	if _dump:
		_dump.text = Balance.override_json() if not Balance.overrides.is_empty() else "No overrides. Document defaults are live."


func _row(spec: Array) -> void:
	var path := str(spec[1])
	var step := float(spec[3])
	var lo := float(spec[4])
	var hi := float(spec[5])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name := UIKit.label(str(spec[2]), 16, UIKit.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var minus := UIKit.button("-", false)
	minus.custom_minimum_size = Vector2(40, 36)
	var edit := UIKit.line_edit()
	edit.custom_minimum_size = Vector2(120, 36)
	edit.text = _fmt(Balance.getv(path))
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.editable = true
	var plus := UIKit.button("+", false)
	plus.custom_minimum_size = Vector2(40, 36)
	minus.pressed.connect(_step.bind(path, edit, -step, lo, hi))
	plus.pressed.connect(_step.bind(path, edit, step, lo, hi))
	edit.text_submitted.connect(func(text: String) -> void: _apply_text(path, edit, lo, hi, text))
	edit.focus_exited.connect(func() -> void: _apply_text(path, edit, lo, hi, edit.text))
	row.add_child(minus)
	row.add_child(edit)
	row.add_child(plus)
	_list.add_child(row)


func _step(path: String, edit: LineEdit, delta: float, lo: float, hi: float) -> void:
	_commit(path, edit, clampf(float(Balance.getv(path)) + delta, lo, hi))


func _apply_text(path: String, edit: LineEdit, lo: float, hi: float, text: String) -> void:
	if not is_instance_valid(edit):
		return
	var cleaned := text.strip_edges()
	if cleaned.is_empty() or not cleaned.is_valid_float():
		edit.text = _fmt(Balance.getv(path))
		return
	_commit(path, edit, clampf(float(cleaned), lo, hi))


func _commit(path: String, edit: LineEdit, value: float) -> void:
	Balance.setv(path, value)
	edit.text = _fmt(value)
	_dump.text = Balance.override_json()


func _fmt(value) -> String:
	var number := float(value)
	if absf(number - round(number)) < 0.0001:
		return str(int(round(number)))
	return "%.4f" % number


func _reset() -> void:
	Balance.clear_overrides()
	Balance.god_mode = false
	Balance.sim_speed = 1
	Balance.show_ranges = false
	Balance.show_hitboxes = false
	_rebuild()


func _god() -> void:
	Balance.god_mode = not Balance.god_mode


func _ranges() -> void:
	Balance.show_ranges = not Balance.show_ranges


func _hits() -> void:
	Balance.show_hitboxes = not Balance.show_hitboxes


func _speed(value: int) -> void:
	Balance.sim_speed = value


func _spawn(kind: String) -> void:
	_call_battle("spawn_enemy", kind)


func _bump_round(delta: int) -> void:
	if battle_ref and is_instance_valid(battle_ref):
		battle_ref.set_round(int(battle_ref.round_num) + delta)


func _call_battle(method: String, arg = null) -> void:
	if battle_ref == null or not is_instance_valid(battle_ref):
		return
	if arg == null:
		battle_ref.call(method)
	else:
		battle_ref.call(method, arg)
