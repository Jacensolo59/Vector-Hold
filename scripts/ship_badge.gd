extends Control

const Shapes = preload("res://scripts/shapes.gd")
const UIKit = preload("res://scripts/ui_kit.gd")

var spinning: float = 0.0


func _process(delta: float) -> void:
	spinning += delta
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.42
	Shapes.draw_ship(self, size * 0.5, radius)
	draw_arc(size * 0.5, radius * 1.25, spinning, spinning + 1.1, 12, Color(UIKit.CYAN, 0.45), 1.0, true)
