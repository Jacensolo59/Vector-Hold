extends Control

const UIKit = preload("res://scripts/ui_kit.gd")

var _stars: Array[Vector2] = []
var _layers: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)
	call_deferred("_rebuild")


func _rebuild() -> void:
	_fill()
	queue_redraw()


func _fill() -> void:
	_stars.clear()
	_layers.clear()
	if size.x < 2 or size.y < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701
	var count := int(clampf(size.x * size.y / 9000.0, 40, 160))
	for _i in count:
		_stars.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
		_layers.append(rng.randf_range(0.25, 1.0))


func _draw() -> void:
	if _stars.is_empty():
		_fill()
	if _stars.is_empty():
		return
	draw_circle(Vector2(size.x * 0.16, size.y * 0.22), size.x * 0.2, Color(0.14, 0.06, 0.24, 0.16))
	draw_circle(Vector2(size.x * 0.78, size.y * 0.7), size.x * 0.16, Color(0.04, 0.1, 0.22, 0.14))
	for i in _stars.size():
		var s: float = _layers[i]
		var dot := ScreenFit.px(size.x, 0.8 if s < 0.75 else 1.7)
		var col := Color(0.82, 0.91, 0.96, 0.18 + s * 0.5)
		if s > 0.92:
			col = Color(1.0, 0.86, 0.68, 0.7)
		draw_circle(_stars[i], dot, col)
	var planet := Vector2(size.x * 0.86, size.y * 0.18)
	var pr := ScreenFit.px(size.x, 34.0)
	draw_circle(planet, pr, Color(0.12, 0.14, 0.22, 0.9))
	draw_arc(planet, pr, 0, TAU, 32, Color(UIKit.CYAN, 0.35), 1.0, true)
