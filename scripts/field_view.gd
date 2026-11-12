extends Control
## Screen-space line art for the battle. Simulation lives in battle.gd.

const UIKit = preload("res://scripts/ui_kit.gd")
const Shapes = preload("res://scripts/shapes.gd")

var battle
var _frame: Dictionary = {}
var _px := 1.0
var _radii: Dictionary = {}
var _stars := PackedVector2Array()
var _star_z := PackedFloat32Array()
var _star_hue := PackedFloat32Array()
var _dust := PackedVector2Array()
var _nebulae: Array = []
var _planets: Array = []
var _void := Color(0.008, 0.012, 0.028)
var _built := Vector2.ZERO
var _space_seed := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _to(world: Vector2) -> Vector2:
	return ScreenFit.project(_frame, world)


func _draw() -> void:
	if battle == null:
		return
	var world_w := float(Balance.getv("field.width"))
	var world_h := float(Balance.getv("field.length"))
	if size.x < 4 or size.y < 4:
		return
	var player: Vector2 = battle.player_pos()
	var frame := ScreenFit.fit_camera(size, Vector2(world_w, world_h))
	if Profile.shake:
		var mag: float = battle.shake
		var origin: Vector2 = frame["origin"]
		frame["origin"] = origin + Vector2(sin(battle.clock * 53.0), cos(battle.clock * 47.0)) * mag
	_frame = frame
	_px = ScreenFit.px(size.x, 1.0)
	_radii.clear()
	var s := _px
	_draw_space(s)
	var left := _to(Vector2(0, 0))
	var right := _to(Vector2(world_w, world_h))
	var hull_y := _to(player).y
	draw_line(Vector2(left.x, hull_y), Vector2(right.x, hull_y), Color(UIKit.AMBER, 0.16), maxf(3.0, 5.0 * s), true)
	draw_line(Vector2(left.x, hull_y), Vector2(right.x, hull_y), Color(UIKit.AMBER, 0.72), maxf(1.0, 1.15 * s), true)
	if Balance.show_ranges:
		var cap := float(Balance.getv("field.max_range"))
		for spec in [
			["", "rail.range", UIKit.CYAN, 0.25],
			["missile", "missile.range", UIKit.AMBER, 0.25],
			["laser", "laser.range", UIKit.DANGER, 0.25],
		]:
			var owned := str(spec[0])
			if owned != "" and not battle.owned.get(owned, false):
				continue
			var tint: Color = spec[2]
			_ring(player, minf(float(Balance.getv(str(spec[1]))), cap), Color(tint, float(spec[3])))
		if battle.owned.get("flame", false):
			_ring(player, battle.flame_reach(), Color(UIKit.DANGER, 0.35))
		if battle.owned.get("drone", false):
			_ring(player, minf(float(Balance.getv("drone.detect")), cap), Color(UIKit.CYAN, 0.18))
	if battle.flame_on:
		_draw_flame(player)
	if battle.laser_on:
		var muzzle := Shapes.muzzle_point(_to(player), ScreenFit.ship_radius(size))
		var tip := _to(battle.laser_end)
		draw_line(muzzle, tip, Color(1.0, 0.35, 0.5, 0.22), maxf(4.0, 7.0 * s), true)
		draw_line(muzzle, tip, Color("ff8aa0"), maxf(1.2, 2.0 * s), true)
		draw_line(muzzle, tip, Color(1.0, 0.94, 0.96, 0.85), maxf(0.6, 0.7 * s), true)
		for extra in battle.laser_extra:
			var fork := _to(extra)
			draw_line(tip, fork, Color(1.0, 0.45, 0.6, 0.2), maxf(2.5, 4.0 * s), true)
			var beam := Color("ff8aa0")
			beam.a = 0.75
			draw_line(tip, fork, beam, maxf(1.0, 1.3 * s), true)
	for arc in battle.arcs:
		var pts: Array = arc["pts"]
		if pts.size() < 2:
			continue
		var col := UIKit.AMBER
		if arc.get("kind", "") == "enemy":
			col = UIKit.DANGER
		elif arc.get("kind", "") == "static":
			col = Color(0.78, 0.95, 1.0)
		elif arc.get("kind", "") == "drone":
			col = UIKit.CYAN
		var alpha := clampf(float(arc["life"]) / 0.12, 0.0, 1.0)
		var kind := str(arc.get("kind", ""))
		for i in range(pts.size() - 1):
			var a := _to(pts[i])
			var b := _to(pts[i + 1])
			if kind == "tesla" or kind == "static" or kind == "":
				var jagged := _jagged(a, b, 5.0 * s, float(i) + float(battle.clock))
				draw_polyline(jagged, Color(col, alpha * 0.35), maxf(2.4, 3.4 * s), true)
				draw_polyline(jagged, Color(col, alpha), maxf(1.0, 1.3 * s), true)
			else:
				draw_line(a, b, Color(col, alpha * 0.35), maxf(2.2, 3.0 * s), true)
				draw_line(a, b, Color(col, alpha), maxf(1.0, 1.4 * s), true)
	for shock in battle.shocks:
		var t := 1.0 - float(shock["life"]) / maxf(float(shock["max"]), 0.01)
		var radius: float = float(shock["r"]) * (0.4 + t) * float(_frame["scale"])
		draw_arc(_to(Vector2(shock["x"], shock["y"])), radius, 0, TAU, 28, Color(UIKit.AMBER, 1.0 - t), maxf(1.0, 1.5 * s), true)
		draw_arc(_to(Vector2(shock["x"], shock["y"])), radius * 0.62, 0, TAU, 20, Color(1.0, 0.9, 0.6, 0.65 * (1.0 - t)), maxf(1.0, 1.1 * s), true)
	for shot in battle.shots:
		if shot.life < 0:
			continue
		var p := _to(Vector2(shot.x, shot.y))
		var dir := Vector2(cos(shot.ang), sin(shot.ang))
		var ahead := _to(Vector2(shot.x, shot.y) + dir)
		var sdir := ahead - p
		if sdir.length_squared() > 0.0001:
			sdir = sdir.normalized()
		else:
			sdir = Vector2(0, -1)
		var body: float = float(shot.scale)
		if body < 0.05:
			body = 1.0
		var tail_design: float = 14.0
		if str(shot.kind) == "rail":
			tail_design = 12.0
		var tail: float = tail_design * s * body
		if str(shot.kind) == "rail":
			var charged: bool = int(battle.rank("rail_static")) > 0
			if charged:
				draw_line(p - sdir * tail, p, Color(0.72, 0.94, 1.0, 0.4), maxf(3.2, 8.0 * s * body), true)
			draw_line(p - sdir * tail, p, Color(UIKit.CYAN, 0.28), maxf(2.4, 6.0 * s * body), true)
			draw_line(p - sdir * tail * 0.85, p, UIKit.CYAN, maxf(1.1, 2.2 * s * body), true)
			draw_line(p - sdir * tail * 0.4, p, Color(0.9, 0.97, 1.0), maxf(0.6, 0.8 * s * body), true)
			draw_circle(p, maxf(1.2, 2.1 * s * body), Color(0.9, 0.97, 1.0, 0.9))
		else:
			var nose := p + sdir * (7.0 * s * body)
			var tailp := p - sdir * (5.0 * s * body)
			var side := Vector2(-sdir.y, sdir.x)
			draw_line(tailp - sdir * (12.0 * s * body), tailp, Color(1.0, 0.42, 0.12, 0.75), maxf(1.2, 2.4 * s * body), true)
			draw_line(tailp, nose, UIKit.AMBER, maxf(1.2, 2.0 * s * body), true)
			draw_line(tailp, tailp + side * (4.5 * s * body) + sdir * (2.0 * s * body), UIKit.AMBER, maxf(1.0, 1.3 * s), true)
			draw_line(tailp, tailp - side * (4.5 * s * body) + sdir * (2.0 * s * body), UIKit.AMBER, maxf(1.0, 1.3 * s), true)
			draw_circle(nose, maxf(1.0, 1.6 * s * body), Color(1.0, 0.92, 0.7, 0.9))
	for e in battle.enemies:
		if e.gone:
			continue
		var center := _to(Vector2(e.x, e.y))
		var kind := str(e.kind)
		var radius: float = _icon_r(kind) * float(e.bulk)
		var col: Color = Shapes.enemy_color(e.kind)
		if e.flash > 0.0:
			col = col.lerp(Color.WHITE, 0.7)
		if e.stun > 0.0:
			col = col.lerp(UIKit.AMBER, 0.35)
		if e.marked:
			draw_arc(center, radius * 1.45, 0, TAU, 22, Color(UIKit.AMBER, 0.9), maxf(1.3, 1.8 * s), true)
		if e.armed:
			var pulse: float = 0.75 + 0.25 * absf(sin(float(battle.clock) * 10.0))
			draw_arc(center, radius * (1.3 + pulse * 0.35), 0, TAU, 18, Color(1.0, 0.45, 0.2, pulse), maxf(1.2, 1.6 * s), true)
		Shapes.draw_enemy(self, e.kind, center, radius, col)
		if Balance.show_hitboxes:
			Shapes.draw_hitbox(self, kind, center, radius)
		if e.hp < e.hp_max:
			var w := radius * 2.2
			var ratio := clampf(e.hp / e.hp_max, 0.0, 1.0)
			var bar := center + Vector2(-w * 0.5, -radius - 7.0 * s)
			draw_line(bar, bar + Vector2(w, 0), Color(1, 1, 1, 0.15), maxf(1.0, 2.0 * s), true)
			draw_line(bar, bar + Vector2(w * ratio, 0), col, maxf(1.0, 2.0 * s), true)
		var def_text := _def_text(e.defense)
		var def_size := int(round(11.0 * s))
		var def_font := UIKit.font_mono()
		var def_w := def_font.get_string_size(def_text, HORIZONTAL_ALIGNMENT_LEFT, -1, def_size).x
		draw_string(def_font, center + Vector2(-def_w * 0.5, radius + 14.0 * s), def_text, HORIZONTAL_ALIGNMENT_LEFT, -1, def_size, UIKit.MUTED)
	for d in battle.drones:
		if not d.alive:
			continue
		var center := _to(Vector2(d.x, d.y))
		if Balance.show_ranges and d.alive:
			_ring(Vector2(d.x, d.y), float(Balance.getv("drone.range")), Color(UIKit.CYAN, 0.45))
		var col := UIKit.CYAN if d.flash <= 0.0 else Color.WHITE
		var nose := center + Vector2(0, -8.0) * s
		var wing_l := center + Vector2(-7.0, 4.0) * s
		var wing_r := center + Vector2(7.0, 4.0) * s
		draw_polyline(PackedVector2Array([nose, wing_l, wing_r, nose]), col, maxf(1.0, 1.2 * s), true)
		draw_line(center + Vector2(0, 2.0) * s, center + Vector2(0, 7.0) * s, Color(1.0, 0.55, 0.2, 0.8), maxf(1.0, 1.3 * s), true)
		draw_circle(center + Vector2(0, -1.5) * s, 1.6 * s, col)
		if d.hp < d.hp_max:
			var ratio := clampf(d.hp / d.hp_max, 0.0, 1.0)
			draw_line(center + Vector2(-8, -10) * s, center + Vector2(-8 + 16.0 * ratio, -10) * s, UIKit.CYAN, maxf(1.0, 1.5 * s), true)
	var radius := ScreenFit.ship_radius(size)
	var ship_at := _to(player)
	Shapes.draw_ship(self, ship_at, radius)
	var flicker: float = 0.45 + 0.55 * absf(sin(float(battle.clock) * 18.0))
	draw_circle(ship_at + Vector2(-radius * 0.34, radius * 0.7), radius * 0.09, Color(1.0, 0.5, 0.18, flicker))
	draw_circle(ship_at + Vector2(radius * 0.34, radius * 0.7), radius * 0.09, Color(1.0, 0.5, 0.18, flicker * 0.85))
	if battle.muzzle_life > 0.0:
		Shapes.draw_muzzle(self, Shapes.muzzle_point(ship_at, radius), radius, battle.muzzle_life)
	var font := UIKit.font_mono()
	for floater in battle.floaters:
		var alpha := clampf(float(floater["life"]) / 0.7, 0.0, 1.0)
		var pos := _to(Vector2(floater["x"], floater["y"]))
		draw_string(font, pos, str(floater["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(14.0 * s)), Color(floater["color"], alpha))
	if battle.banner_life > 0.0:
		var title := UIKit.font_bold()
		var text: String = battle.banner
		var banner_size := int(round(28.0 * s))
		var width := title.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, banner_size).x
		draw_string(title, Vector2((size.x - width) * 0.5, 42.0 * s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, banner_size, UIKit.AMBER)
	if battle.intro_life > 0.0:
		var hint := "Enemies come from the top. Weapons fire on their own."
		var hint_font := UIKit.font_body()
		var hint_w := minf(size.x - 24.0 * s, 460.0 * s)
		draw_string(hint_font, Vector2((size.x - hint_w) * 0.5, 78.0 * s), hint, HORIZONTAL_ALIGNMENT_CENTER, hint_w, int(round(16.0 * s)), UIKit.TEXT)


func _icon_r(kind: String) -> float:
	if not _radii.has(kind):
		_radii[kind] = Shapes.icon_radius(kind, size.x)
	return float(_radii[kind])


func _def_text(value: float) -> String:
	if absf(value - round(value)) < 0.05:
		return str(int(round(value)))
	return "%.1f" % value


func _ring(origin: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var ang := TAU * float(i) / 48.0
		pts.append(_to(origin + Vector2(cos(ang), sin(ang)) * radius))
	draw_polyline(pts, color, maxf(1.0, _px), true)


func _draw_flame(player: Vector2) -> void:
	var reach: float = battle.flame_reach()
	var half: float = battle.flame_half_angle()
	var forward := -PI * 0.5
	var origin := Shapes.muzzle_point(_to(player), ScreenFit.ship_radius(size))
	for i in 11:
		var t := float(i) / 10.0
		var ang := forward + lerpf(-half, half, t)
		var wobble := sin(float(battle.clock) * 16.0 + float(i) * 1.3) * 0.05
		var tip := _to(player + Vector2(cos(ang + wobble), sin(ang + wobble)) * reach)
		var hot := 1.0 - absf(t - 0.5) * 1.4
		draw_line(origin, tip, Color(1.0, 0.28 + hot * 0.25, 0.08, 0.22 + hot * 0.18), maxf(1.4, 2.4 * _px), true)
	for i in 5:
		var t := float(i) / 4.0
		var ang := forward + lerpf(-half * 0.42, half * 0.42, t)
		var wobble := sin(float(battle.clock) * 22.0 + float(i)) * 0.04
		var tip := _to(player + Vector2(cos(ang + wobble), sin(ang + wobble)) * reach * 0.58)
		draw_line(origin, tip, Color(1.0, 0.82, 0.4, 0.55), maxf(1.0, 1.4 * _px), true)


func _draw_space(s: float) -> void:
	var seed := int(battle.space_seed)
	if _built != size or _space_seed != seed:
		_build_space(seed)
	var drift: float = float(battle.clock)
	draw_rect(Rect2(Vector2.ZERO, size), _void, true)
	for cloud in _nebulae:
		var nx: float = float(cloud["x"]) * size.x
		var ny: float = fposmod(float(cloud["y"]) * size.y - drift * float(cloud["v"]) * 4.0, size.y + 120.0) - 60.0
		var nr: float = float(cloud["r"]) * maxf(size.x, size.y)
		var ncol: Color = cloud["c"]
		ncol.a = float(cloud["a"])
		draw_circle(Vector2(nx, ny), nr, ncol)
		ncol.a *= 0.55
		draw_circle(Vector2(nx + nr * 0.18, ny - nr * 0.08), nr * 0.62, ncol)
	for i in _dust.size():
		var p: Vector2 = _dust[i]
		var y := fposmod(p.y + drift * 5.0, size.y)
		draw_circle(Vector2(p.x, y), maxf(0.4, s * 0.35), Color(0.75, 0.82, 0.95, 0.14))
	for i in _stars.size():
		var z: float = _star_z[i]
		var p: Vector2 = _stars[i]
		var y := fposmod(p.y + drift * (4.0 + z * 34.0), size.y)
		var tw: float = 0.55 + 0.45 * sin(drift * (0.7 + z * 1.4) + p.x * 0.015)
		var col := Color(0.78, 0.86, 0.98)
		var hue: float = _star_hue[i]
		if hue > 0.9:
			col = Color(1.0, 0.78, 0.55)
		elif hue > 0.78:
			col = Color(1.0, 0.92, 0.78)
		elif hue < 0.06:
			col = Color(0.55, 0.72, 1.0)
		col.a = (0.18 + z * 0.78) * tw
		var rad: float = maxf(0.45, s * (0.35 + z * 1.35))
		draw_circle(Vector2(p.x, y), rad, col)
		if z > 0.92:
			draw_line(Vector2(p.x - rad * 2.2, y), Vector2(p.x + rad * 2.2, y), Color(col.r, col.g, col.b, col.a * 0.45), maxf(0.6, s * 0.4), true)
	for body in _planets:
		var px: float = float(body["x"]) * size.x
		var py: float = fposmod(float(body["y"]) * size.y - drift * float(body["v"]) * 6.0, size.y + 100.0) - 50.0
		var pr: float = float(body["r"]) * s
		var pcol: Color = body["c"]
		var at := Vector2(px, py)
		draw_circle(at, pr * 1.15, Color(pcol.r, pcol.g, pcol.b, 0.08))
		draw_circle(at, pr, pcol)
		draw_arc(at, pr, 0.0, TAU, 40, Color(1, 1, 1, 0.22), maxf(1.0, s * 0.7), true)
		draw_arc(at + Vector2(pr * 0.12, -pr * 0.16), pr * 0.62, PI * 1.1, PI * 1.85, 14, Color(1, 1, 1, 0.16), maxf(1.0, s * 0.55), true)
		if bool(body["ring"]):
			draw_arc(at, pr * 1.55, -0.7, PI + 0.5, 28, Color(0.82, 0.86, 0.95, 0.35), maxf(1.0, s * 0.8), true)


func _build_space(seed: int) -> void:
	_space_seed = seed
	_built = size
	_stars = PackedVector2Array()
	_star_z = PackedFloat32Array()
	_star_hue = PackedFloat32Array()
	_dust = PackedVector2Array()
	_nebulae = []
	_planets = []
	if size.x < 2.0 or size.y < 2.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else 1
	_void = Color(rng.randf_range(0.004, 0.012), rng.randf_range(0.006, 0.016), rng.randf_range(0.02, 0.04))
	var count := int(clampf(size.x * size.y / 3800.0, 160, 360))
	for _i in count:
		_stars.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
		var roll := rng.randf()
		var z := rng.randf() * 0.45
		if roll > 0.82:
			z = rng.randf_range(0.55, 1.0)
		_star_z.append(z)
		_star_hue.append(rng.randf())
	var cluster := Vector2(rng.randf_range(0.12, 0.88) * size.x, rng.randf_range(0.06, 0.62) * size.y)
	for _i in rng.randi_range(24, 48):
		_stars.append(cluster + Vector2(rng.randfn() * size.x * 0.045, rng.randfn() * size.y * 0.035))
		_star_z.append(rng.randf_range(0.62, 1.0))
		_star_hue.append(rng.randf())
	var palette: Array[Color] = [
		Color(0.24, 0.08, 0.38),
		Color(0.05, 0.14, 0.34),
		Color(0.32, 0.08, 0.14),
		Color(0.05, 0.22, 0.24),
		Color(0.16, 0.08, 0.28),
	]
	for i in rng.randi_range(3, 5):
		_nebulae.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"r": rng.randf_range(0.18, 0.42),
			"c": palette[i % palette.size()],
			"a": rng.randf_range(0.07, 0.15),
			"v": rng.randf_range(0.35, 1.5),
		})
	var band := rng.randf_range(0.22, 0.72)
	var tilt := rng.randf_range(-0.08, 0.08)
	for i in 90:
		var t := float(i) / 89.0
		var x := t * size.x
		var y := (band + sin(t * TAU * 2.0 + float(seed % 7)) * 0.035 + tilt * (t - 0.5)) * size.y
		y += rng.randf_range(-22.0, 22.0)
		_dust.append(Vector2(x, y))
	for _i in rng.randi_range(1, 2):
		_planets.append({
			"x": rng.randf_range(0.08, 0.92),
			"y": rng.randf_range(0.06, 0.78),
			"r": rng.randf_range(16.0, 42.0),
			"c": Color(rng.randf_range(0.12, 0.38), rng.randf_range(0.14, 0.42), rng.randf_range(0.2, 0.55)),
			"ring": rng.randf() > 0.5,
			"v": rng.randf_range(0.12, 0.5),
		})


func _jagged(a: Vector2, b: Vector2, amount: float, seed: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(a)
	var dir := b - a
	var side := Vector2(-dir.y, dir.x)
	if side.length_squared() > 0.001:
		side = side.normalized()
	else:
		side = Vector2.RIGHT
	for i in range(1, 5):
		var t := float(i) / 5.0
		var kick := sin(seed * 9.0 + float(i) * 2.1) * amount
		pts.append(a.lerp(b, t) + side * kick)
	pts.append(b)
	return pts
