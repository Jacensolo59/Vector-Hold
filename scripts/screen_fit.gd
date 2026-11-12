extends Node
## Picks a logical resolution from the live window so the UI scales with the
## device and the battlefield keeps its aspect. Desktop builds open maximized.

signal changed

var window_size := Vector2i(720, 1280)
var aspect := 720.0 / 1280.0
var landscape := false

var _last_logical := Vector2i.ZERO


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_tree().root.size_changed.connect(_on_size_changed)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		var saved := "auto"
		var profile := get_node_or_null("/root/Profile")
		if profile != null:
			saved = str(profile.resolution)
		apply_resolution(saved, false)
	call_deferred("_on_size_changed")


func _on_size_changed() -> void:
	var win := DisplayServer.window_get_size()
	if win.x < 2 or win.y < 2:
		return
	window_size = win
	aspect = float(win.x) / float(win.y)
	landscape = win.x >= win.y
	var logical := content_base(win)
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	root.content_scale_factor = 1.0
	# Width drives the scale. 1280 wide is 1x, 1920 is 1.5x, 3840 is 3x.
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = logical
	_last_logical = logical
	changed.emit()


func describe() -> String:
	var shape := "square" if absf(aspect - 1.0) < 0.08 else ("landscape" if landscape else "portrait")
	return "Display %d×%d · %s · %s" % [window_size.x, window_size.y, aspect_label(window_size.x, window_size.y), shape]


func column_width(view_w: float) -> float:
	return maxf(view_w - 36.0, 260.0)


static func monitor_presets() -> Array:
	return [
		Vector2i(1024, 768),
		Vector2i(1280, 720),
		Vector2i(1280, 800),
		Vector2i(1280, 1024),
		Vector2i(1366, 768),
		Vector2i(1440, 900),
		Vector2i(1600, 900),
		Vector2i(1680, 1050),
		Vector2i(1920, 1080),
		Vector2i(1920, 1200),
		Vector2i(2048, 1152),
		Vector2i(2560, 1080),
		Vector2i(2560, 1440),
		Vector2i(2560, 1600),
		Vector2i(3440, 1440),
		Vector2i(3840, 2160),
	]


static func preset_key(size: Vector2i) -> String:
	return "%d x %d" % [size.x, size.y]


func apply_resolution(key: String, persist: bool) -> void:
	var choice := key if _known(key) else "auto"
	var profile := get_node_or_null("/root/Profile")
	if profile != null:
		profile.resolution = choice
		if persist:
			profile.save()
	if OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	if choice == "auto":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return
	var parts := choice.split("x", false)
	if parts.size() != 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return
	var want := Vector2i(int(str(parts[0]).strip_edges()), int(str(parts[1]).strip_edges()))
	var screen := DisplayServer.screen_get_size()
	if want.x >= screen.x and want.y >= screen.y:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var fitted := Vector2i(mini(want.x, screen.x), mini(want.y, screen.y))
	DisplayServer.window_set_size(fitted)
	var origin := DisplayServer.screen_get_position()
	DisplayServer.window_set_position(origin + (screen - fitted) / 2)


func _known(key: String) -> bool:
	if key == "auto":
		return true
	for size in monitor_presets():
		if preset_key(size) == key:
			return true
	return false


static func ui_scale(window: Vector2i) -> float:
	# 1 at 1280 wide. Phones stay 1:1 so text does not collapse.
	if window.x < 960:
		return 1.0
	return maxf(float(window.x) / 1280.0, 0.05)


static func content_base(window: Vector2i) -> Vector2i:
	var scale := ui_scale(window)
	if window.x < 960:
		return window
	var logical_h := maxi(int(round(float(window.y) / scale)), 1)
	return Vector2i(1280, logical_h)


static func px(view_w: float, design_px: float) -> float:
	# Design pixels at a 1280-wide canvas. If the live view is the raw
	# window instead, this grows the art with that resolution.
	return design_px * maxf(view_w, 1.0) / 1280.0


static func ship_radius(view: Vector2) -> float:
	var s := px(view.x, 1.0)
	var by_frac := minf(view.x, view.y) * 0.038
	return clampf(by_frac, 16.0 * s, 30.0 * s)


static func fit_camera(view: Vector2, world: Vector2) -> Dictionary:
	# Map the whole field onto the battle view, but keep a strip under the
	# player so the ship base is not clipped by the field edge.
	var inset := 14.0
	var foot := clampf(view.y * 0.08, 36.0, 64.0)
	var avail_w := maxf(view.x - inset * 2.0, 4.0)
	var avail_h := maxf(view.y - inset - foot, 4.0)
	var scale_x := avail_w / maxf(world.x, 1.0)
	var scale_y := avail_h / maxf(world.y, 1.0)
	return {
		"scale": maxf(scale_x, scale_y),
		"scale_x": scale_x,
		"scale_y": scale_y,
		"origin": Vector2(inset, inset),
	}


static func project(cam: Dictionary, world: Vector2) -> Vector2:
	var origin: Vector2 = cam["origin"]
	return origin + Vector2(world.x * float(cam["scale_x"]), world.y * float(cam["scale_y"]))


static func aspect_label(width: int, height: int) -> String:
	if width < 1 or height < 1:
		return "0:0"
	var ratio := float(width) / float(height)
	var known: Array = [
		[16.0 / 9.0, "16:9"],
		[9.0 / 16.0, "9:16"],
		[19.5 / 9.0, "19.5:9"],
		[9.0 / 19.5, "9:19.5"],
		[20.0 / 9.0, "20:9"],
		[9.0 / 20.0, "9:20"],
		[21.0 / 9.0, "21:9"],
		[9.0 / 21.0, "9:21"],
		[16.0 / 10.0, "16:10"],
		[10.0 / 16.0, "10:16"],
		[4.0 / 3.0, "4:3"],
		[3.0 / 4.0, "3:4"],
		[32.0 / 9.0, "32:9"],
		[1.0, "1:1"],
	]
	for item in known:
		if absf(ratio - float(item[0])) < 0.02:
			return str(item[1])
	if ratio >= 1.0:
		return "%.2f:1" % ratio
	return "1:%.2f" % (1.0 / ratio)
