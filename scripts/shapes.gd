extends RefCounted
## Line-art drawing helpers. Call only from a CanvasItem _draw().

const UIKit = preload("res://scripts/ui_kit.gd")

const CYAN := UIKit.CYAN
const AMBER := UIKit.AMBER
const DANGER := UIKit.DANGER
const MUTED := UIKit.MUTED
const CIRCLE := Color("8fd4ff")
const SQUARE := Color("ffb020")
const TRI := Color("ff6b81")
const RECT := Color("c3b4ff")
const HEX := Color("ffe38a")
const DIAMOND := Color("7dffc3")
const CHEVRON := Color("ff7a3c")
const CROSS := Color("d7e6ff")
const MINE := Color("ffe14a")
const _KINDS := ["circle", "square", "triangle", "rect", "hex", "diamond", "chevron", "cross", "mine"]


static func enemy_color(kind: String) -> Color:
	match kind:
		"square":
			return SQUARE
		"triangle":
			return TRI
		"rect":
			return RECT
		"hex":
			return HEX
		"diamond":
			return DIAMOND
		"chevron":
			return CHEVRON
		"cross":
			return CROSS
		"mine":
			return MINE
		_:
			return CIRCLE


static func draw_ship(c: CanvasItem, center: Vector2, radius: float) -> void:
	# Point faces the front (up). The barrel sticks out just past that tip.
	var tip := center + Vector2(0, -radius)
	var left := center + Vector2(-radius * 0.86, radius * 0.78)
	var right := center + Vector2(radius * 0.86, radius * 0.78)
	var w := maxf(1.6, radius * 0.07)
	c.draw_polyline(PackedVector2Array([tip, left, right, tip]), CYAN, w, true)
	var nose := tip.lerp(center, 0.42)
	c.draw_line(left.lerp(right, 0.18), nose, Color(CYAN, 0.85), w * 0.55, true)
	c.draw_line(left.lerp(right, 0.82), nose, Color(CYAN, 0.85), w * 0.55, true)
	c.draw_line(left.lerp(center, 0.55), right.lerp(center, 0.55), Color(CYAN, 0.45), w * 0.4, true)
	c.draw_arc(center + Vector2(0, -radius * 0.08), radius * 0.16, 0, TAU, 12, Color(0.85, 0.95, 1.0), maxf(1.0, w * 0.45), true)
	var base := center + Vector2(0, -radius * 0.08)
	var muzzle := barrel_end(center, radius)
	c.draw_line(base + Vector2(-radius * 0.07, 0), muzzle + Vector2(-radius * 0.025, 0), CYAN, w * 0.7, true)
	c.draw_line(base + Vector2(radius * 0.07, 0), muzzle + Vector2(radius * 0.025, 0), CYAN, w * 0.7, true)
	c.draw_line(muzzle + Vector2(-radius * 0.09, radius * 0.04), muzzle + Vector2(radius * 0.09, radius * 0.04), CYAN, w * 0.45, true)


static func barrel_end(center: Vector2, radius: float) -> Vector2:
	return center + Vector2(0, -radius * 1.52)


static func muzzle_point(center: Vector2, radius: float) -> Vector2:
	# Just before the end of the barrel, where the shot leaves.
	return center + Vector2(0, -radius * 1.46)


static func draw_muzzle(c: CanvasItem, at: Vector2, radius: float, life: float) -> void:
	var alpha := clampf(life / 0.1, 0.0, 1.0)
	var burst := radius * 0.28
	c.draw_circle(at, burst * 0.28, Color(1.0, 0.95, 0.8, alpha))
	c.draw_arc(at, burst, 0, TAU, 14, Color(CYAN, alpha), maxf(1.2, radius * 0.045), true)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var dir := Vector2(cos(ang), sin(ang))
		c.draw_line(at + dir * burst * 0.2, at + dir * burst * 1.35, Color(AMBER, alpha), maxf(1.0, radius * 0.035), true)


static func weapon_icon(c: CanvasItem, center: Vector2, radius: float, kind: String, active: bool) -> void:
	var col := CYAN if active else Color(MUTED, 0.45)
	var w := maxf(1.0, radius * 0.09)
	c.draw_arc(center, radius, 0, TAU, 24, col, w, true)
	match kind:
		"rail":
			c.draw_line(center + Vector2(0, radius * 0.55), center + Vector2(0, -radius * 0.7), col, w, true)
			c.draw_line(center + Vector2(-radius * 0.16, radius * 0.2), center + Vector2(radius * 0.16, radius * 0.2), col, w * 0.6, true)
			c.draw_circle(center + Vector2(0, -radius * 0.7), radius * 0.08, col)
		"missile":
			var body := AMBER if active else col
			c.draw_polyline(PackedVector2Array([
				center + Vector2(0, -radius * 0.62),
				center + Vector2(radius * 0.16, -radius * 0.2),
				center + Vector2(radius * 0.16, radius * 0.28),
				center + Vector2(-radius * 0.16, radius * 0.28),
				center + Vector2(-radius * 0.16, -radius * 0.2),
				center + Vector2(0, -radius * 0.62),
			]), body, w, true)
			c.draw_line(center + Vector2(-radius * 0.16, radius * 0.05), center + Vector2(-radius * 0.38, radius * 0.32), body, w * 0.7, true)
			c.draw_line(center + Vector2(radius * 0.16, radius * 0.05), center + Vector2(radius * 0.38, radius * 0.32), body, w * 0.7, true)
		"laser":
			var beam := DANGER if active else col
			c.draw_line(center + Vector2(0, radius * 0.45), center + Vector2(0, -radius * 0.15), col, w, true)
			c.draw_line(center + Vector2(0, -radius * 0.15), center + Vector2(0, -radius * 0.7), beam, w * 0.7, true)
			c.draw_circle(center + Vector2(0, -radius * 0.15), radius * 0.1, beam)
		"tesla":
			var arc := AMBER if active else col
			c.draw_polyline(PackedVector2Array([
				center + Vector2(0, radius * 0.5),
				center + Vector2(-radius * 0.22, radius * 0.12),
				center + Vector2(radius * 0.18, -radius * 0.08),
				center + Vector2(-radius * 0.08, -radius * 0.28),
				center + Vector2(radius * 0.16, -radius * 0.58),
			]), arc, w, true)
			c.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.42), radius * 0.06, arc)
		"drone":
			c.draw_polyline(PackedVector2Array([
				center + Vector2(0, -radius * 0.2),
				center + Vector2(-radius * 0.16, radius * 0.18),
				center + Vector2(radius * 0.16, radius * 0.18),
				center + Vector2(0, -radius * 0.2),
			]), col, w * 0.8, true)
			c.draw_arc(center + Vector2(-radius * 0.34, radius * 0.02), radius * 0.16, 0, TAU, 10, col, w * 0.7, true)
			c.draw_arc(center + Vector2(radius * 0.34, radius * 0.02), radius * 0.16, 0, TAU, 10, col, w * 0.7, true)
		"flame":
			var fire := DANGER if active else col
			c.draw_polyline(PackedVector2Array([
				center + Vector2(0, radius * 0.5),
				center + Vector2(-radius * 0.12, radius * 0.05),
				center + Vector2(0, -radius * 0.15),
				center + Vector2(radius * 0.12, radius * 0.05),
				center + Vector2(0, radius * 0.5),
			]), col, w, true)
			c.draw_arc(center + Vector2(0, -radius * 0.05), radius * 0.42, PI * 1.2, PI * 1.8, 8, fire, w, true)
			c.draw_line(center + Vector2(0, -radius * 0.15), center + Vector2(0, -radius * 0.55), fire, w * 0.6, true)


static func icon_radius(kind: String, view_w: float) -> float:
	var key := kind if kind in _KINDS else "circle"
	var design := float(Balance.getv("hitbox." + key))
	return maxf(4.0, design * float(Balance.getv("hitbox.scale")) * ScreenFit.px(view_w, 1.0))


static func point_hits(kind: String, center: Vector2, radius: float, point: Vector2) -> bool:
	var d := point - center
	match kind:
		"square", "rect":
			var half := _box_half(kind, radius)
			return absf(d.x) <= half.x and absf(d.y) <= half.y
		"triangle":
			return _in_triangle(point, center, radius)
		"hex":
			return _in_hex(point, center, radius)
		"diamond":
			return _in_diamond(point, center, radius)
		"chevron":
			return _in_triangle_pts(point, _chev_points(center, radius))
		"cross":
			return _in_cross(point, center, radius)
		"mine":
			return d.length() <= radius * 0.85
		_:
			return d.length() <= radius


static func segment_hits(kind: String, center: Vector2, radius: float, a: Vector2, b: Vector2) -> bool:
	var reach := _box_half(kind, radius).y
	var steps := int(ceil(a.distance_to(b) / maxf(reach * 0.45, 1.0)))
	steps = clampi(steps, 1, 40)
	for i in steps + 1:
		if point_hits(kind, center, radius, a.lerp(b, float(i) / float(steps))):
			return true
	return false


static func shape_bottom(kind: String, radius: float) -> float:
	return _box_half(kind, radius).y


static func draw_hitbox(c: CanvasItem, kind: String, center: Vector2, radius: float) -> void:
	var col := Color(1, 1, 1, 0.92)
	var w := maxf(1.25, radius * 0.08)
	match kind:
		"square", "rect":
			var half := _box_half(kind, radius)
			c.draw_rect(Rect2(center - half, half * 2.0), col, false, w)
		"triangle":
			c.draw_polyline(_tri_points(center, radius), col, w, true)
		"hex":
			c.draw_polyline(_hex_points(center, radius), col, w, true)
		"diamond":
			c.draw_polyline(_diamond_points(center, radius), col, w, true)
		"chevron":
			c.draw_polyline(_chev_points(center, radius), col, w, true)
		"cross":
			_draw_cross_box(c, center, radius, col, w)
		"mine":
			c.draw_arc(center, radius * 0.85, 0, TAU, 20, col, w, true)
		_:
			c.draw_arc(center, radius, 0, TAU, 24, col, w, true)


static func _box_half(kind: String, radius: float) -> Vector2:
	if kind == "rect":
		return Vector2(radius * 1.45, radius * 0.62)
	return Vector2(radius, radius)


static func _tri_points(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, radius),
		center + Vector2(-radius, -radius * 0.75),
		center + Vector2(radius, -radius * 0.75),
		center + Vector2(0, radius),
	])


static func _box_points(center: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
		center + Vector2(-half.x, -half.y),
	])


static func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var ang := -PI * 0.5 + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	return pts


static func _diamond_points(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
		center + Vector2(0, -radius),
	])


static func _in_diamond(point: Vector2, center: Vector2, radius: float) -> bool:
	var d := point - center
	return absf(d.x) / maxf(radius, 0.001) + absf(d.y) / maxf(radius, 0.001) <= 1.0


static func _chev_points(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, radius * 0.95),
		center + Vector2(-radius * 1.15, -radius * 0.45),
		center + Vector2(radius * 1.15, -radius * 0.45),
		center + Vector2(0, radius * 0.95),
	])


static func _in_triangle_pts(point: Vector2, pts: PackedVector2Array) -> bool:
	return _tri_side(point, pts[0], pts[1], pts[2]) and _tri_side(point, pts[1], pts[2], pts[0]) and _tri_side(point, pts[2], pts[0], pts[1])


static func _in_cross(point: Vector2, center: Vector2, radius: float) -> bool:
	var d := point - center
	var thick := radius * 0.34
	return (absf(d.x) <= thick and absf(d.y) <= radius) or (absf(d.y) <= thick and absf(d.x) <= radius)


static func _draw_cross_box(c: CanvasItem, center: Vector2, radius: float, col: Color, w: float) -> void:
	var thick := radius * 0.34
	c.draw_rect(Rect2(center + Vector2(-thick, -radius), Vector2(thick * 2.0, radius * 2.0)), col, false, w)
	c.draw_rect(Rect2(center + Vector2(-radius, -thick), Vector2(radius * 2.0, thick * 2.0)), col, false, w)


static func _in_hex(point: Vector2, center: Vector2, radius: float) -> bool:
	var d := point - center
	var ax := absf(d.x)
	var ay := absf(d.y)
	if ax > radius * 0.86602540378:
		return false
	return ay + ax / 1.73205080757 <= radius


static func _in_triangle(point: Vector2, center: Vector2, radius: float) -> bool:
	var pts := _tri_points(center, radius)
	return _tri_side(point, pts[0], pts[1], pts[2]) and _tri_side(point, pts[1], pts[2], pts[0]) and _tri_side(point, pts[2], pts[0], pts[1])


static func _tri_side(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var ab := b - a
	var cross_p := ab.x * (point.y - a.y) - ab.y * (point.x - a.x)
	var cross_c := ab.x * (c.y - a.y) - ab.y * (c.x - a.x)
	return cross_p * cross_c >= 0.0


static func draw_enemy(c: CanvasItem, kind: String, center: Vector2, radius: float, color: Color) -> void:
	var w := maxf(1.25, radius * 0.09)
	var dim := Color(color, 0.55)
	match kind:
		"square":
			var half := _box_half(kind, radius)
			c.draw_polyline(_box_points(center, half), color, w, true)
			c.draw_polyline(_box_points(center, half * 0.58), dim, w * 0.65, true)
			c.draw_line(center + Vector2(-half.x * 0.58, 0), center + Vector2(half.x * 0.58, 0), dim, w * 0.45, true)
		"rect":
			var half := _box_half(kind, radius)
			c.draw_polyline(_box_points(center, half), color, w, true)
			c.draw_line(center + Vector2(-half.x, -half.y * 0.35), center + Vector2(half.x, -half.y * 0.35), dim, w * 0.5, true)
			c.draw_line(center + Vector2(-half.x * 0.35, half.y), center + Vector2(-half.x * 0.35, half.y + radius * 0.35), color, w * 0.6, true)
			c.draw_line(center + Vector2(half.x * 0.35, half.y), center + Vector2(half.x * 0.35, half.y + radius * 0.35), color, w * 0.6, true)
		"triangle":
			c.draw_polyline(_tri_points(center, radius), color, w, true)
			c.draw_polyline(_tri_points(center + Vector2(0, radius * 0.08), radius * 0.48), dim, w * 0.6, true)
		"hex":
			c.draw_polyline(_hex_points(center, radius), color, w, true)
			c.draw_polyline(_hex_points(center, radius * 0.62), color, w * 0.7, true)
			c.draw_polyline(_hex_points(center, radius * 0.28), dim, w * 0.55, true)
			for i in 3:
				var ang := -PI * 0.5 + TAU * float(i) / 3.0
				c.draw_line(center, center + Vector2(cos(ang), sin(ang)) * radius * 0.62, dim, w * 0.4, true)
		"diamond":
			c.draw_polyline(_diamond_points(center, radius), color, w, true)
			c.draw_polyline(_diamond_points(center, radius * 0.5), dim, w * 0.6, true)
		"chevron":
			c.draw_polyline(_chev_points(center, radius), color, w, true)
			c.draw_polyline(_chev_points(center + Vector2(0, -radius * 0.18), radius * 0.55), dim, w * 0.6, true)
		"cross":
			c.draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, w, true)
			c.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, w, true)
			c.draw_line(center + Vector2(0, -radius * 0.45), center + Vector2(0, radius * 0.45), dim, w * 0.45, true)
		"mine":
			c.draw_arc(center, radius * 0.72, 0, TAU, 18, color, w, true)
			c.draw_line(center + Vector2(-radius * 0.38, -radius * 0.38), center + Vector2(radius * 0.38, radius * 0.38), color, w * 0.7, true)
			c.draw_line(center + Vector2(radius * 0.38, -radius * 0.38), center + Vector2(-radius * 0.38, radius * 0.38), color, w * 0.7, true)
		_:
			c.draw_arc(center, radius, 0, TAU, 24, color, w, true)
			c.draw_arc(center, radius * 0.58, 0, TAU, 16, dim, w * 0.6, true)
			c.draw_line(center + Vector2(0, radius * 0.15), center + Vector2(0, radius * 0.95), color, w * 0.55, true)
			c.draw_line(center + Vector2(-radius * 0.35, radius * 0.2), center + Vector2(radius * 0.35, radius * 0.2), dim, w * 0.4, true)
