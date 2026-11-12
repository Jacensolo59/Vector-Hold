extends RefCounted

const BG := Color("070b14")
const PANEL := Color("101826")
const CYAN := Color("7ee0ff")
const AMBER := Color("ffb020")
const DANGER := Color("ff5d73")
const TEXT := Color("e7f2f8")
const MUTED := Color("8ea0b5")
const LINE := Color(0.494, 0.878, 1.0, 0.35)

static var _body: Font
static var _bold: Font
static var _mono: Font


static func font_body() -> Font:
	if _body == null:
		_body = load("res://fonts/Rajdhani-SemiBold.ttf")
	if _body == null:
		_body = ThemeDB.fallback_font
	return _body


static func font_bold() -> Font:
	if _bold == null:
		_bold = load("res://fonts/Rajdhani-Bold.ttf")
	if _bold == null:
		_bold = font_body()
	return _bold


static func font_mono() -> Font:
	if _mono == null:
		_mono = load("res://fonts/ShareTechMono-Regular.ttf")
	if _mono == null:
		_mono = font_body()
	return _mono


static func px(design: float) -> float:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var w := (loop as SceneTree).root.get_visible_rect().size.x
		if w > 2.0:
			return design * w / 1280.0 * 0.66
	return design


static func label(text: String, size: int, color: Color, mono: bool = false, bold: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font_mono() if mono else (font_bold() if bold else font_body()))
	node.add_theme_font_size_override("font_size", int(round(px(float(size)))))
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func progress_bar(ratio: float, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(0, px(8.0))
	bg.color = Color(1, 1, 1, 0.08)
	bg.add_child(_bar_fill(ratio, color))
	return bg


static func _bar_fill(ratio: float, color: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	return fill


static func volume_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(px(8.0)))
	var down := button("-", false)
	down.custom_minimum_size = Vector2(px(56.0), px(52.0))
	var up := button("+", false)
	up.custom_minimum_size = Vector2(px(56.0), px(52.0))
	var readout := label("70%", 18, TEXT, true)
	readout.custom_minimum_size = Vector2(px(78.0), 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(px(120.0), px(44.0))
	slider.focus_mode = Control.FOCUS_ALL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.08)
	track.set_corner_radius_all(2)
	track.content_margin_top = px(16.0)
	track.content_margin_bottom = px(16.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.set_corner_radius_all(2)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var apply := func(v: float) -> void:
		Profile.sfx_volume = clampf(v, 0.0, 1.0)
		Profile.save()
		Sfx.apply_volume()
		Sfx.unlock()
		readout.text = "%d%%" % int(round(Profile.sfx_volume * 100.0))
		slider.set_value_no_signal(Profile.sfx_volume)
		if Profile.sfx_volume > 0.01:
			Sfx.play("ui")
	down.pressed.connect(func() -> void: apply.call(Profile.sfx_volume - 0.05))
	up.pressed.connect(func() -> void: apply.call(Profile.sfx_volume + 0.05))
	slider.value_changed.connect(func(v: float) -> void: apply.call(v))
	readout.text = "%d%%" % int(round(Profile.sfx_volume * 100.0))
	slider.set_value_no_signal(Profile.sfx_volume)
	row.add_child(down)
	row.add_child(slider)
	row.add_child(readout)
	row.add_child(up)
	return row


static func button(text: String, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, px(52.0))
	node.focus_mode = Control.FOCUS_ALL
	node.add_theme_font_override("font", font_bold() if primary else font_body())
	node.add_theme_font_size_override("font_size", int(round(px(20.0))))
	var normal := _box(primary, false)
	var hover := _box(primary, true)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_stylebox_override("focus", normal)
	node.add_theme_stylebox_override("disabled", normal)
	_paint(node, AMBER if primary else TEXT)
	return node


static func _paint(node: Control, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, color)


static func _box(primary: bool, hot: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("172433") if hot else PANEL
	box.border_color = AMBER if primary else LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	_pad(box, 14.0, 8.0)
	return box


static func glass_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PANEL, 0.32)
	box.border_color = Color(LINE.r, LINE.g, LINE.b, 0.28)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	_pad(box, 10.0, 8.0)
	return box


static func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PANEL, 0.94)
	box.border_color = LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	_pad(box, 14.0, 12.0)
	return box


static func _pad(box: StyleBoxFlat, x: float, y: float) -> void:
	box.content_margin_left = px(x)
	box.content_margin_right = px(x)
	box.content_margin_top = px(y)
	box.content_margin_bottom = px(y)


static func line_edit() -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(px(108.0), px(44.0))
	edit.add_theme_font_override("font", font_mono())
	edit.add_theme_font_size_override("font_size", int(round(px(16.0))))
	edit.add_theme_color_override("font_color", TEXT)
	edit.add_theme_color_override("caret_color", AMBER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("070b14")
	box.border_color = LINE
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	edit.add_theme_stylebox_override("normal", box)
	return edit
