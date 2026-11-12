extends SceneTree
## Headless check of the document formulas. Run with:
## godot --headless --path . --script res://scripts/self_test.gd

const Formulas = preload("res://scripts/formulas.gd")
const ScreenFitScript = preload("res://scripts/screen_fit.gd")

var _failed := false


func _init() -> void:
	_eq(Formulas.enemy_hp(10, 5, 1), 10, "circle r1 hp")
	_eq(Formulas.enemy_hp(10, 5, 2), 15, "circle r2 hp")
	_eq(Formulas.enemy_hp(50, 15, 1), 50, "square r1 hp")
	_eq(Formulas.enemy_hp(15, 2.5, 3), 20, "triangle r3 hp")
	_eq(Formulas.enemy_hp(30, 7.5, 2), 37.5, "rect r2 hp")
	_eq(Formulas.enemy_scaled(10, 1.0, 1), 10, "circle r1 def")
	_eq(Formulas.enemy_scaled(10, 1.0, 2), 10.1, "circle r2 def")
	_eq(Formulas.enemy_scaled(75, 10.0, 2), 82.5, "rect r2 atk")
	_eq(Formulas.enemy_scaled(15, 5.0, 1), 15, "square r1 atk")
	_eq(Formulas.mitigate(100, 0, 0), 100, "no defense")
	_eq(Formulas.mitigate(100, 100, 0), 50, "100 defense halves")
	_eq(Formulas.linear_level(25, 10, 1), 25, "rail lv1")
	_eq(Formulas.linear_level(25, 10, 2), 35, "rail lv2")
	_eq(Formulas.rate_with_level(1.25, 0.10, 1), 1.25, "rail rate lv1")
	_eq(Formulas.rate_with_level(1.25, 0.10, 2), 1.375, "rail rate lv2")
	_eq(Formulas.research_cost(5, 0.10, 0.05, 10, 0), 5, "research rank 0")
	_eq(Formulas.research_cost(5, 0.10, 0.05, 10, 1), 6, "research rank 1")
	_eq(Formulas.research_cost(10, 0.15, 0.10, 10, 0), 10, "pen rank 0")
	_eq(Formulas.research_cost(10, 0.15, 0.10, 10, 1), 12, "pen rank 1")
	_eq(Formulas.edge_multiplier(0.25, 0.003, 0), 0.25, "edge 0")
	_eq(Formulas.edge_multiplier(0.25, 0.003, 100), 0.55, "edge 100")
	_eq(0.005 * 40.0, 0.2, "pen cap fraction")
	_eq(Formulas.compound(10.0, 1), 1.0, "curve r1")
	_eq(Formulas.compound(10.0, 2), 1.1, "curve r2")
	_eq(Formulas.compound(0.0, 8), 1.0, "curve off")
	_eq(Formulas.compound(10.0, 3, 10.0, 0.2), 1.21, "curve ignores bend inside grace")
	_eq(Formulas.spread_shots(0, 3, 9), 1, "spread 0")
	_eq(Formulas.spread_shots(1, 3, 9), 3, "spread 1")
	_eq(Formulas.spread_shots(3, 3, 9), 9, "spread 3")
	_eq(Formulas.flame_range(250, 250, 0, 1000), 250, "flame 0")
	_eq(Formulas.flame_range(250, 250, 3, 1000), 1000, "flame 3")
	_eq(Formulas.count_with_rank(2, 2, 0), 2, "drones base")
	_eq(Formulas.count_with_rank(3, 2, 1), 5, "tesla +1")
	_eq(Formulas.stun_duration(1.6, 0.2, 0, 0.15), 1.6, "stun 0")
	_eq(Formulas.stun_duration(1.6, 0.2, 1, 0.15), 1.4, "stun 1")
	_eq(Formulas.stun_duration(1.6, 0.2, 2, 0.15), 1.2, "stun 2")
	_eq(Formulas.reload_time(4, 1, 1, 0.45), 3, "reload rank 1")
	_eq(Formulas.wave_count(5, 2, 1, 1), 5, "wave circles r1")
	_eq(Formulas.wave_count(2, 1, 1, 2), 0, "no triangles r1")
	_eq(Formulas.wave_count(2, 1, 2, 2), 2, "triangles r2")
	var desk := ScreenFitScript.content_base(Vector2i(1920, 1080))
	_eq(desk.x, 1280, "1080p logical width")
	_eq(desk.y, 720, "1080p logical height")
	var phone := ScreenFitScript.content_base(Vector2i(390, 844))
	_eq(phone.x, 390, "phone logical width")
	_eq(phone.y, 844, "phone logical height")
	var small := ScreenFitScript.content_base(Vector2i(1024, 768))
	_eq(small.x, 1280, "1024 logical width")
	_eq(small.y, 960, "1024 logical height")
	var ship_a := ScreenFitScript.ship_radius(Vector2(1280, 720))
	var ship_b := ScreenFitScript.ship_radius(Vector2(2560, 1440))
	if ship_b < ship_a * 1.9 or ship_b > ship_a * 2.1:
		_failed = true
		push_error("ship does not scale with resolution %s vs %s" % [ship_a, ship_b])
	if absf(ScreenFitScript.ui_scale(Vector2i(1920, 1080)) - 1.5) > 0.01:
		_failed = true
		push_error("1080p scale")
	if absf(ScreenFitScript.ui_scale(Vector2i(3840, 2160)) - 3.0) > 0.01:
		_failed = true
		push_error("4k scale")
	var wide := ScreenFitScript.content_base(Vector2i(2560, 1080))
	_eq(wide.x, 1280, "ultrawide logical width")
	_eq(wide.y, 540, "ultrawide logical height")
	if ScreenFitScript.aspect_label(1920, 1080) != "16:9":
		_failed = true
		push_error("aspect 16:9")
	if ScreenFitScript.aspect_label(1080, 1920) != "9:16":
		_failed = true
		push_error("aspect 9:16")
	if ScreenFitScript.aspect_label(1080, 2340) != "9:19.5":
		_failed = true
		push_error("aspect 9:19.5 got %s" % ScreenFitScript.aspect_label(1080, 2340))
	var view := Vector2(390, 640)
	var cam: Dictionary = ScreenFitScript.fit_camera(view, Vector2(1000, 3000))
	var cam_origin: Vector2 = cam["origin"]
	var sx := float(cam["scale_x"])
	var sy := float(cam["scale_y"])
	var ship_x := cam_origin.x + 500.0 * sx
	if absf(ship_x - 195.0) > 3.0:
		_failed = true
		push_error("player not centered x=%s" % ship_x)
	var ship_y := cam_origin.y + 2920.0 * sy
	if ship_y < 560.0 or ship_y > 630.0:
		_failed = true
		push_error("player not at bottom y=%s" % ship_y)
	var top_y := cam_origin.y
	if top_y >= ship_y:
		_failed = true
		push_error("front is not above the ship")
	var field_bottom := cam_origin.y + 3000.0 * sy
	if field_bottom > view.y + 1.0:
		_failed = true
		push_error("field longer than the view %s" % field_bottom)
	var saw_1080 := false
	for size in ScreenFitScript.monitor_presets():
		if ScreenFitScript.preset_key(size) == "1920 x 1080":
			saw_1080 = true
	if not saw_1080 or ScreenFitScript.monitor_presets().size() < 16:
		_failed = true
		push_error("resolution list missing 1080p")
	var act: Dictionary = Formulas.act_progress(0, 50, 30)
	_eq(act["level"], 1, "act starts at 1")
	var notes := FileAccess.open("res://notes/00-overview.txt", FileAccess.READ)
	if notes == null:
		_failed = true
		push_error("missing overview note")
	else:
		notes.close()
	if _failed:
		push_error("SELF TEST FAILED")
		quit(1)
	else:
		print("SELF TEST OK")
		quit(0)


func _eq(got, expect, label: String) -> void:
	if absf(float(got) - float(expect)) > 0.001:
		_failed = true
		push_error("%s got %s expected %s" % [label, str(got), str(expect)])
