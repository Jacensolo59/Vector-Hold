extends Control

const Shapes = preload("res://scripts/shapes.gd")

var kind: String = "rail":
	set(value):
		kind = value
		queue_redraw()
var dim: bool = false:
	set(value):
		dim = value
		queue_redraw()


func _ready() -> void:
	if custom_minimum_size.x < 8.0:
		custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.38
	Shapes.weapon_icon(self, size * 0.5, radius, kind, not dim)
