extends Control
## Match simulation. Numbers come from Balance.getv so the dev console applies live.
## Flow, targeting, and upgrade rules: notes/01 through notes/05.

const Formulas = preload("res://scripts/formulas.gd")
const UIKit = preload("res://scripts/ui_kit.gd")
const FieldView = preload("res://scripts/field_view.gd")
const Glyph = preload("res://scripts/weapon_glyph.gd")
const ShipBadge = preload("res://scripts/ship_badge.gd")
const Shapes = preload("res://scripts/shapes.gd")

signal leave(retry: bool)

var round_num: int = 1
var match_level: int = 1
var xp: float = 0.0
var hull: float = 100.0
var hull_max: float = 100.0
var kills: int = 0
var gold_run: float = 0.0
var overclock: int = 0
var owned: Dictionary = {"rail": true}
var ranks: Dictionary = {}
var alive: bool = true
var menu_hold: bool = false
var dev_hold: bool = false
var pause_open: bool = false
var upgrade_open: bool = false
var pending_upgrades: int = 0
var clock: float = 0.0
var shake: float = 0.0
var banner: String = ""
var banner_life: float = 0.0
var intro_life: float = 0.0
var muzzle_life: float = 0.0
var space_seed: int = 1
var flame_on: bool = false
var laser_on: bool = false
var laser_end: Vector2 = Vector2.ZERO
var laser_extra: Array[Vector2] = []

var enemies: Array[Enemy] = []
var shots: Array[Shot] = []
var drones: Array[DroneUnit] = []
var arcs: Array = []
var shocks: Array = []
var floaters: Array = []

var _spawn_queue: Array = []
var _spawn_cd: float = 0.6
var _pack: bool = false
var _mark_left: int = 0
var _fuses: Array = []
var _between: bool = false
var _between_t: float = 0.0
var _acc: float = 0.0
var _next_id: int = 1
var _rail_cd: float = 0.15
var _missile_cd: float = 0.6
var _tesla_cd: float = 0.3
var _laser_id: int = -1
var _laser_focus: float = 0.0
var _laser_switch: float = 0.0
var _laser_tick: float = 0.0
var _flame_tick: float = 0.0
var _tray_open: bool = true
var _field
var _hud: PanelContainer
var _pause_btn: Button
var _tray: PanelContainer
var _tray_row: HBoxContainer
var _chrome: float = -1.0
var _haste: float = 1.0
var _view_cam: Dictionary = {}
var _view_w: float = 1280.0
var _hit_r: Dictionary = {}
var _player := Vector2.ZERO
var _max_range := 0.0
var _width := 0.0
var _ids: Dictionary = {}
var _upgrade_layer: Control
var _pause_layer: Control
var _over_layer: Control
var _hull_label: Label
var _meta_label: Label
var _act_label: Label
var _hull_fill: ColorRect
var _xp_fill: ColorRect
var _act_fill: ColorRect


class Enemy:
	var id: int
	var kind: String
	var x: float
	var y: float
	var hp: float
	var hp_max: float
	var defense: float
	var attack: float
	var weapon_range: float
	var radius: float
	var gold: float
	var xp: float
	var stun: float
	var shoot_cd: float
	var flash: float
	var shred: float
	var gone: bool
	var lane: float
	var wobble: float
	var sway: float
	var forward: float
	var side: float
	var bulk: float = 1.0
	var marked: bool = false
	var armed: bool = false
	var guard: float = 0.0
	var fuse: float = 0.0


class Shot:
	var kind: String
	var x: float
	var y: float
	var ang: float
	var speed: float
	var traveled: float
	var max_range: float
	var dmg: float
	var pierce: int
	var hits: int
	var hit_ids: Array = []
	var target_id: int = -1
	var can_split: bool
	var split_rank: int
	var life: float
	var aoe: float
	var scale: float = 1.0


class DroneUnit:
	var x: float
	var y: float
	var angle: float
	var hp: float
	var hp_max: float
	var alive: bool = true
	var respawn: float
	var shoot_cd: float
	var missile_cd: float
	var flash: float
	var lane: float


func _ready() -> void:
	_anchor_full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hull_max = hull_max_now()
	hull = hull_max
	if not Profile.intro_seen:
		intro_life = 8.0
		Profile.mark_intro()
	space_seed = randi() | 1
	_build_ui()
	resized.connect(_layout_chrome)
	call_deferred("_layout_chrome")
	call_deferred("_start_round", true)
	Sfx.unlock()


func _anchor_full(node: Control) -> void:
	# Anchors first. Godot keeps the old pixel edges when an anchor changes,
	# so offsets are cleared after or the control stays 0×0 in the corner.
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH


func _process(delta: float) -> void:
	clock += delta
	var speed := maxi(Balance.sim_speed, 1)
	if alive and not menu_hold and not dev_hold:
		_acc += minf(delta, 0.1) * float(speed)
		var guard := 0
		while _acc >= 1.0 / 60.0 and guard < 8:
			_acc -= 1.0 / 60.0
			_simulate(1.0 / 60.0)
			guard += 1
	else:
		_acc = 0.0
		banner_life = maxf(0.0, banner_life - delta)
		intro_life = maxf(0.0, intro_life - delta)
	_refresh_hud()
	if pending_upgrades > 0 and alive and not upgrade_open and not dev_hold and not pause_open:
		_open_upgrade()


func player_pos() -> Vector2:
	return Vector2(float(Balance.getv("player.x")), float(Balance.getv("player.y")))


func hull_max_now() -> float:
	var base := Formulas.linear_level(float(Balance.getv("player.hull")), float(Balance.getv("player.hull_per_level")), match_level)
	return base + float(Balance.getv("player.hull_per_act")) * float(maxi(Profile.act_level - 1, 0))


func defense_now() -> float:
	var base := Formulas.linear_level(float(Balance.getv("player.defense")), float(Balance.getv("player.defense_per_level")), match_level)
	return base + float(Balance.getv("player.defense_per_act")) * float(maxi(Profile.act_level - 1, 0))


func flame_reach() -> float:
	return Formulas.flame_range(
		float(Balance.getv("flame.range")),
		float(Balance.getv("flame.range_per")),
		rank("flame_range"),
		float(Balance.getv("flame.range_cap"))
	)


func flame_half_angle() -> float:
	return float(Balance.getv("flame.half_angle")) * (1.0 + float(Balance.getv("flame.width_per")) * float(rank("flame_width")))


func rank(key: String) -> int:
	return int(ranks.get(key, 0))


func spawn_enemy(kind: String, at: Vector2 = Vector2(-1, -1), power: float = 1.0, from_wave: bool = true) -> void:
	var e := Enemy.new()
	e.id = _next_id
	_next_id += 1
	e.kind = kind
	var stats := "enemy." + kind + "_"
	e.hp_max = Formulas.enemy_hp(float(Balance.getv(stats + "hp")), float(Balance.getv(stats + "hp_per")), round_num)
	var hp_mult := Formulas.boss_hp_mult(round_num, int(Balance.getv("boss.every")), float(Balance.getv("boss.hp_bonus")))
	hp_mult *= Formulas.compound(
		float(Balance.getv("enemy.hp_curve")),
		round_num,
		float(Balance.getv("enemy.hp_grace")),
		float(Balance.getv("enemy.hp_bend"))
	)
	e.hp_max *= hp_mult
	e.hp = e.hp_max
	e.defense = Formulas.enemy_scaled(float(Balance.getv(stats + "def")), float(Balance.getv(stats + "def_pct")), round_num)
	e.defense *= Formulas.compound(
		float(Balance.getv("enemy.def_curve")),
		round_num,
		float(Balance.getv("enemy.def_grace")),
		float(Balance.getv("enemy.def_bend"))
	)
	e.forward = float(Balance.getv(stats + "speed"))
	e.side = float(Balance.getv(stats + "side"))
	e.attack = Formulas.enemy_scaled(float(Balance.getv(stats + "atk")), float(Balance.getv(stats + "atk_pct")), round_num)
	e.attack *= Formulas.compound(float(Balance.getv("enemy.atk_curve")), round_num)
	e.weapon_range = float(Balance.getv(stats + "range"))
	e.radius = float(Balance.getv(stats + "radius"))
	e.gold = float(Balance.getv(stats + "gold")) * power
	e.xp = float(Balance.getv(stats + "xp")) * power
	e.hp_max *= power
	e.hp = e.hp_max
	e.attack *= power
	e.bulk = clampf(power, 0.45, 1.0) if power < 0.99 else 1.0
	e.radius *= e.bulk
	e.shoot_cd = randf_range(0.4, 1.4)
	var width := float(Balance.getv("field.width"))
	var span := _approach_span()
	var margin := 56.0
	e.x = randf_range(margin, width - margin)
	e.lane = clampf(e.x + randf_range(-160.0, 160.0), margin, width - margin)
	e.wobble = randf() * TAU
	e.sway = randf_range(70.0, 180.0)
	e.y = randf_range(span.x, span.y)
	if at.x >= 0.0:
		e.x = clampf(at.x, margin, width - margin)
		e.y = at.y
		e.lane = e.x
	if from_wave and _pack and kind != "hex":
		e.x = clampf(width * 0.5 + randf_range(-90.0, 90.0), margin, width - margin)
		e.lane = e.x
		e.sway = randf_range(16.0, 42.0)
	if kind == "hex":
		e.x = width * 0.5
		e.lane = e.x
		e.sway = 36.0
	if from_wave and _mark_left > 0 and kind != "hex":
		_mark_left -= 1
		e.marked = true
		e.hp_max *= float(Balance.getv("enemy.mark_hp"))
		e.hp = e.hp_max
		e.gold *= float(Balance.getv("enemy.mark_pay"))
		e.xp *= float(Balance.getv("enemy.mark_pay"))
	enemies.append(e)


func _approach_span() -> Vector2:
	# Spawn at the far end so the full field length is the trip to the hull.
	var length := float(Balance.getv("field.length"))
	var player_y := player_pos().y
	var far := 60.0
	var band := minf(length * 0.07, maxf(player_y - 400.0, far + 80.0))
	return Vector2(far, maxf(band, far + 40.0))


func kill_all() -> void:
	for e in enemies:
		if not e.gone:
			kill_enemy(e, "dev")


func add_levels(count: int) -> void:
	for _i in count:
		if match_level >= int(Balance.getv("player.level_cap")):
			break
		match_level += 1
		if match_level % 2 == 0:
			pending_upgrades += 1
	sync_hull_max()


func set_round(value: int) -> void:
	round_num = maxi(value, 1)
	_spawn_queue.clear()
	_between = false
	_start_round(false)


func heal_full() -> void:
	sync_hull_max()
	hull = hull_max


func _start_round(reset_banner: bool) -> void:
	_build_wave()
	if reset_banner:
		if Formulas.is_boss_round(round_num, int(Balance.getv("boss.every"))):
			banner = "BOSS"
		elif _escort_round(round_num):
			banner = "ESCORT"
		elif _convoy_round(round_num):
			banner = "CONVOY"
		else:
			banner = "ROUND %d" % round_num
		banner_life = 1.6
	Profile.note_round(round_num)


func _build_wave() -> void:
	var list: Array = []
	for kind in ["circle", "triangle", "rect", "square", "diamond", "chevron", "cross", "mine"]:
		if kind == "chevron" and not Profile.weapon_unlocked("tesla"):
			continue
		var count := Formulas.wave_count(
			float(Balance.getv("waves.%s_base" % kind)),
			float(Balance.getv("waves.%s_per" % kind)),
			round_num,
			int(Balance.getv("waves.%s_from" % kind))
		)
		for _n in count:
			list.append(kind)
	if _escort_round(round_num):
		for i in list.size():
			if i % 4 != 0:
				list[i] = "rect"
		list.append("rect")
		list.append("rect")
	list.shuffle()
	if Formulas.is_boss_round(round_num, int(Balance.getv("boss.every"))):
		list.insert(0, "hex")
	_pack = _convoy_round(round_num)
	_mark_left = 1 if round_num >= int(Balance.getv("enemy.mark_from")) and not list.is_empty() else 0
	_spawn_queue = list
	var burst := mini(3, _spawn_queue.size())
	for _i in burst:
		spawn_enemy(str(_spawn_queue.pop_front()))
	_spawn_cd = float(Balance.getv("waves.spawn_interval"))


func _escort_round(round_num: int) -> bool:
	var every := int(Balance.getv("boss.every"))
	return every > 1 and round_num > 0 and (round_num + 1) % every == 0


func _convoy_round(round_num: int) -> bool:
	if round_num < 3 or round_num % 3 != 0:
		return false
	if Formulas.is_boss_round(round_num, int(Balance.getv("boss.every"))):
		return false
	return not _escort_round(round_num)


func _simulate(dt: float) -> void:
	if not alive:
		return
	_player = player_pos()
	_max_range = float(Balance.getv("field.max_range"))
	_width = float(Balance.getv("field.width"))
	_refresh_view()
	banner_life = maxf(0.0, banner_life - dt)
	intro_life = maxf(0.0, intro_life - dt)
	muzzle_life = maxf(0.0, muzzle_life - dt)
	shake = move_toward(shake, 0.0, dt * 36.0)
	if _between:
		_between_t -= dt
		if _between_t <= 0.0:
			_between = false
			round_num += 1
			_start_round(true)
	else:
		_spawn_cd -= dt
		var interval := maxf(float(Balance.getv("waves.spawn_interval_min")), float(Balance.getv("waves.spawn_interval")) - float(Balance.getv("waves.spawn_interval_per")) * float(round_num - 1))
		if _spawn_cd <= 0.0 and not _spawn_queue.is_empty() and _living() < int(Balance.getv("waves.max_alive")):
			spawn_enemy(str(_spawn_queue.pop_front()))
			_spawn_cd = interval
	_index_enemies()
	_haste = 1.0 + float(Balance.getv("utility.overclock_pct")) * float(overclock)
	_weapons(dt)
	_projectiles(dt)
	_drones(dt)
	_enemies(dt)
	_tick_fuses(dt)
	_separate()
	_fx(dt)
	_keep_enemies()
	_keep_shots()
	if alive and not _between and _spawn_queue.is_empty() and _living() == 0:
		_between = true
		_between_t = float(Balance.getv("waves.between"))
		banner = "SECTOR CLEAR"
		banner_life = _between_t


func _living() -> int:
	var n := 0
	for e in enemies:
		if not e.gone:
			n += 1
	return n


func _weapons(dt: float) -> void:
	_rail_cd -= dt
	if _rail_cd <= 0.0 and _try_rail():
		_rail_cd = _shot_interval("rail.rate", "rail.rate_per_level")
	if owned.get("missile", false):
		_missile_cd -= dt
		if _missile_cd <= 0.0 and _try_missile():
			var reload := Formulas.reload_time(float(Balance.getv("missile.reload")), float(Balance.getv("upgrades.missile_reload_sec")), rank("missile_reload"), float(Balance.getv("missile.reload_min")))
			_missile_cd = reload / _haste
	if owned.get("tesla", false):
		_tesla_cd -= dt
		if _tesla_cd <= 0.0 and _try_tesla():
			_tesla_cd = _shot_interval("tesla.rate", "tesla.rate_per_level")
	_laser(dt, _haste)
	_flame(dt, _haste)


func _try_rail() -> bool:
	var reach := _reach("rail.range")
	var target := _threat_target(reach)
	if target == null:
		return false
	var muzzle := _rail_origin()
	var speed := float(Balance.getv("rail.speed"))
	var aim_at := _lead_point(target, muzzle, speed)
	var aim_world := aim_at - muzzle
	if aim_world.length_squared() < 1.0:
		aim_world = Vector2(0, -1)
	var count := Formulas.spread_shots(rank("rail_spread"), int(Balance.getv("upgrades.rail_spread_per")), int(Balance.getv("upgrades.rail_spread_cap")))
	var arc := float(Balance.getv("upgrades.rail_spread_arc"))
	var fired := false
	var tracker := 0
	var tracker_t := 2.0
	for i in count:
		var t := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5)
		if absf(t) < tracker_t:
			tracker_t = absf(t)
			tracker = i
	for i in count:
		var t := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5)
		# Cone is measured on screen around the lead shot, and kept narrow.
		var ang := _screen_cone(aim_world, t * arc)
		if sin(ang) >= -0.05:
			continue
		var shot := Shot.new()
		shot.kind = "rail"
		shot.x = muzzle.x
		shot.y = muzzle.y
		shot.ang = ang
		shot.speed = speed
		shot.max_range = reach
		shot.dmg = _damage("rail", "upgrades.rail_damage_pct")
		shot.pierce = rank("rail_pierce")
		shot.hit_ids = []
		shot.target_id = target.id if i == tracker else -1
		shots.append(shot)
		fired = true
	if fired:
		Sfx.play("rail")
		muzzle_life = 0.1
	return fired


func _rail_origin() -> Vector2:
	var view := Vector2.ZERO
	if _field != null:
		view = _field.size
	var sy := float(_view_cam.get("scale_y", 0.0))
	if view.x < 2.0 or sy < 0.00001:
		return _player
	var ahead := ScreenFit.ship_radius(view) * 1.46
	return _player + Vector2(0.0, -ahead / sy)


func _screen_cone(aim_world: Vector2, offset: float) -> float:
	var sx := float(_view_cam.get("scale_x", 1.0))
	var sy := float(_view_cam.get("scale_y", 1.0))
	if sx < 0.0001 or sy < 0.0001 or absf(offset) < 0.00001:
		return aim_world.angle()
	var screen := Vector2(aim_world.x * sx, aim_world.y * sy)
	if screen.length_squared() < 0.0001:
		screen = Vector2(0, -1)
	var turned := screen.rotated(offset)
	return Vector2(turned.x / sx, turned.y / sy).angle()


func _try_missile() -> bool:
	var reach := _reach("missile.range")
	var target := _strongest(reach)
	if target == null:
		return false
	var origin := _player
	var shot := Shot.new()
	shot.kind = "missile"
	shot.x = origin.x
	shot.y = origin.y - 18.0
	shot.ang = (Vector2(target.x, target.y) - origin).angle()
	shot.speed = float(Balance.getv("missile.speed"))
	shot.max_range = reach
	shot.dmg = _damage("missile")
	shot.target_id = target.id
	shot.can_split = rank("missile_split") > 0
	shot.split_rank = rank("missile_split")
	shot.aoe = float(Balance.getv("missile.aoe")) * pow(1.0 + float(Balance.getv("upgrades.missile_aoe_pct")), float(rank("missile_aoe")))
	shots.append(shot)
	Sfx.play("missile")
	muzzle_life = 0.1
	return true


func _try_tesla() -> bool:
	var reach := _reach("tesla.range")
	var first := _threat_target(reach)
	if first == null:
		return false
	var limit := Formulas.count_with_rank(int(Balance.getv("tesla.bounces")), int(Balance.getv("upgrades.tesla_targets_per")), rank("tesla_targets"))
	var chain: Array = [first]
	while chain.size() < limit:
		var last: Enemy = chain[chain.size() - 1]
		var nxt: Enemy = null
		var best := float(Balance.getv("tesla.bounce_link"))
		for e in enemies:
			if e.gone or chain.has(e) or not _in_front(e.y):
				continue
			if _player.distance_to(Vector2(e.x, e.y)) > reach:
				continue
			var dist := Vector2(last.x, last.y).distance_to(Vector2(e.x, e.y))
			if dist < best:
				best = dist
				nxt = e
		if nxt == null:
			break
		chain.append(nxt)
	var dmg := _damage("tesla", "upgrades.tesla_damage_pct")
	var pts: Array = [_player]
	for i in chain.size():
		var e: Enemy = chain[i]
		e.stun = maxf(e.stun, Formulas.stun_duration(float(Balance.getv("tesla.stun")), float(Balance.getv("tesla.stun_falloff")), i, float(Balance.getv("tesla.stun_min"))))
		deal(e, dmg, 0.0, "tesla")
		pts.append(Vector2(e.x, e.y))
	arcs.append({"pts": pts, "life": 0.14, "kind": "tesla"})
	Sfx.play("tesla")
	muzzle_life = 0.1
	return true


func _laser(dt: float, haste: float) -> void:
	laser_on = false
	laser_extra = []
	if not owned.get("laser", false):
		return
	var reach := _reach("laser.range")
	var current := _by_id(_laser_id)
	if current == null or current.gone or not _in_front(current.y) or _player.distance_to(Vector2(current.x, current.y)) > reach:
		_laser_switch -= dt
		if _laser_switch <= 0.0:
			var nxt := _threat_target(reach)
			_laser_id = nxt.id if nxt else -1
			_laser_focus = 0.0
			_laser_switch = float(Balance.getv("laser.retarget"))
		current = _by_id(_laser_id)
	if current == null or current.gone:
		return
	laser_on = true
	laser_end = Vector2(current.x, current.y)
	_laser_focus += dt
	var cap := float(Balance.getv("laser.shred_cap"))
	current.shred = maxf(current.shred, minf(cap, _laser_focus / maxf(float(Balance.getv("laser.shred_time")), 0.05) * cap))
	_laser_tick += dt
	var interval := float(Balance.getv("laser.tick")) * pow(float(Balance.getv("upgrades.laser_rate_factor")), float(rank("laser_rate"))) / haste
	if _laser_tick < interval:
		return
	_laser_tick = 0.0
	var dmg := _damage("laser")
	deal(current, dmg, 0.0, "laser")
	Sfx.play("laser")
	muzzle_life = 0.08
	var extras := rank("laser_reflect")
	if extras <= 0:
		return
	for other in _nearest_list(Vector2(current.x, current.y), extras, reach, current.id):
		laser_extra.append(Vector2(other.x, other.y))
		deal(other, dmg * 0.5, 0.0, "laser")


func _flame(dt: float, haste: float) -> void:
	flame_on = owned.get("flame", false)
	if not flame_on:
		return
	_flame_tick += dt
	var interval := float(Balance.getv("flame.tick")) / haste
	if _flame_tick < interval:
		return
	_flame_tick = 0.0
	var reach := flame_reach()
	var half := flame_half_angle()
	var forward := -PI * 0.5
	var origin := _player
	var dmg := _damage("flame", "upgrades.flame_damage_pct")
	var burned := false
	for e in enemies:
		if e.gone or not _in_front(e.y):
			continue
		var rel := Vector2(e.x, e.y) - origin
		var dist := rel.length()
		if dist > reach or dist < 1.0:
			continue
		if absf(angle_difference(forward, rel.angle())) <= half:
			deal(e, dmg, 0.0, "flame")
			burned = true
	if burned:
		Sfx.play("flame")
		muzzle_life = 0.08


func _projectiles(dt: float) -> void:
	var snapshot: Array = shots.duplicate()
	for shot in snapshot:
		if shot.life < 0.0:
			continue
		if shot.kind == "rail":
			_step_rail(shot, dt)
		else:
			_step_missile(shot, dt)


func _step_rail(shot: Shot, dt: float) -> void:
	if shot.target_id >= 0:
		var target := _by_id(shot.target_id)
		if target != null and not target.gone:
			var aim := _lead_point(target, Vector2(shot.x, shot.y), shot.speed) - Vector2(shot.x, shot.y)
			if aim.length_squared() > 4.0:
				shot.ang = rotate_toward(shot.ang, aim.angle(), 2.6 * dt)
	var prev := _advance(shot, dt)
	var expired := shot.traveled > shot.max_range or not _in_front(shot.y)
	var a := _project(prev)
	var b := _project(Vector2(shot.x, shot.y))
	for e in enemies:
		if e.gone or shot.hit_ids.has(e.id):
			continue
		if not _hits_segment(e, a, b):
			continue
		var mul := 1.0 if shot.hits == 0 else float(Balance.getv("upgrades.rail_pierce_mul"))
		shot.hits += 1
		shot.hit_ids.append(e.id)
		var hit := shot.dmg * mul
		deal(e, hit, Profile.rail_pen(), "rail")
		_static_jump(e, hit, shot.hit_ids)
		if shot.hits > shot.pierce:
			shot.life = -1.0
			return
	if expired:
		shot.life = -1.0


func _static_jump(from: Enemy, raw: float, already: Array) -> void:
	var jumps := rank("rail_static")
	if jumps <= 0 or raw <= 0.0:
		return
	var reach := float(Balance.getv("upgrades.rail_static_range"))
	var frac := float(Balance.getv("upgrades.rail_static_frac"))
	var origin := Vector2(from.x, from.y)
	var pool: Array = []
	for e in enemies:
		if e.gone or e == from or already.has(e.id):
			continue
		var dist := origin.distance_to(Vector2(e.x, e.y))
		if dist <= reach:
			pool.append(e)
	pool.sort_custom(func(a, b): return origin.distance_to(Vector2(a.x, a.y)) < origin.distance_to(Vector2(b.x, b.y)))
	if pool.size() > jumps:
		pool.resize(jumps)
	if pool.is_empty():
		return
	for e in pool:
		var ship: Enemy = e
		arcs.append({"pts": [origin, Vector2(ship.x, ship.y)], "life": 0.14, "kind": "static"})
		deal(ship, raw * frac, Profile.rail_pen(), "rail")
	Sfx.play("tesla")


func _enemy_vel(e: Enemy) -> Vector2:
	var margin := 56.0
	var desired := clampf(e.lane + sin(e.wobble) * e.sway, margin, _width - margin)
	var delta := desired - e.x
	var vx := cos(e.wobble) * e.sway * 0.7
	if absf(delta) > 1.0:
		vx = signf(delta) * e.side
	var vy := e.forward
	if e.weapon_range > 1.0 and (_player.y - e.y) <= e.weapon_range:
		vy = 0.0
		vx *= 0.35
	return Vector2(vx, vy)


func _lead_point(e: Enemy, from: Vector2, speed: float) -> Vector2:
	var pos := Vector2(e.x, e.y)
	var vel := _enemy_vel(e)
	var t := from.distance_to(pos) / maxf(speed, 1.0)
	for _i in 2:
		t = from.distance_to(pos + vel * t) / maxf(speed, 1.0)
	t = clampf(t, 0.0, 1.6)
	return pos + vel * t


func _step_missile(shot: Shot, dt: float) -> void:
	var target := _by_id(shot.target_id)
	if target and not target.gone:
		var desired := (Vector2(target.x, target.y) - Vector2(shot.x, shot.y)).angle()
		shot.ang = rotate_toward(shot.ang, desired, float(Balance.getv("missile.turn")) * dt)
	var prev := _advance(shot, dt)
	var pos := Vector2(shot.x, shot.y)
	var a := _project(prev)
	var b := _project(pos)
	for e in enemies:
		if e.gone:
			continue
		if _hits_segment(e, a, b):
			_detonate(shot, e)
			return
	if shot.traveled > shot.max_range or pos.y > _player.y + 20.0:
		_detonate(shot, null)


func _detonate(shot: Shot, direct: Enemy) -> void:
	if shot.life < 0.0:
		return
	shot.life = -1.0
	if shot.kind == "drone_missile":
		if direct:
			deal(direct, shot.dmg, 0.0, "drone")
		shocks.append({"x": shot.x, "y": shot.y, "r": 36.0, "life": 0.16, "max": 0.16})
		return
	var radius := shot.aoe if shot.aoe > 1.0 else float(Balance.getv("missile.aoe"))
	var edge := Profile.missile_edge()
	for e in enemies:
		if e.gone or not _in_front(e.y):
			continue
		var dist := Vector2(shot.x, shot.y).distance_to(Vector2(e.x, e.y))
		if dist > radius:
			continue
		var mul := lerpf(1.0, edge, dist / maxf(radius, 1.0))
		deal(e, shot.dmg * mul, 0.0, "missile")
	shocks.append({"x": shot.x, "y": shot.y, "r": radius, "life": 0.28, "max": 0.28})
	if shot.can_split and shot.split_rank > 0:
		var extra := int(Balance.getv("upgrades.missile_split_per")) * shot.split_rank
		var reach := _reach("missile.range")
		var origin := Vector2(shot.x, shot.y)
		var avoid := direct.id if direct != null else -1
		var pool: Array = _nearest_list(origin, extra, reach, avoid)
		if pool.is_empty():
			var fallback := _nearest(origin, reach)
			if fallback != null:
				pool.append(fallback)
		for i in extra:
			var child := Shot.new()
			child.kind = "missile"
			child.x = origin.x
			child.y = origin.y
			var tgt: Enemy = pool[i % pool.size()] if not pool.is_empty() else null
			if tgt != null:
				child.target_id = tgt.id
				child.ang = (Vector2(tgt.x, tgt.y) - origin).angle() + randf_range(-0.2, 0.2)
			else:
				child.ang = -PI * 0.5 + randf_range(-0.35, 0.35)
			if sin(child.ang) >= -0.05:
				child.ang = -PI * 0.5 + randf_range(-0.4, 0.4)
			child.speed = float(Balance.getv("missile.split_speed"))
			child.max_range = reach
			child.dmg = shot.dmg * float(Balance.getv("upgrades.missile_split_mul"))
			child.can_split = false
			child.scale = 0.72
			child.aoe = radius * 0.75
			shots.append(child)


func _drones(dt: float) -> void:
	if not owned.get("drone", false):
		drones.clear()
		return
	var want := Formulas.count_with_rank(int(Balance.getv("drone.count")), int(Balance.getv("upgrades.drone_count_per")), rank("drone_count"))
	while drones.size() < want:
		var unit := DroneUnit.new()
		unit.angle = TAU * float(drones.size()) / float(maxi(want, 1))
		unit.hp_max = float(Balance.getv("drone.hp"))
		unit.hp = unit.hp_max
		unit.shoot_cd = 0.15 * float(drones.size())
		unit.missile_cd = 0.8
		unit.lane = _drone_lane(drones.size(), maxi(want, 1))
		unit.x = _player.x
		unit.y = _player.y - 80.0
		drones.append(unit)
	var index := 0
	var shoot_every := _shot_interval("drone.rate", "drone.rate_per_level")
	var detect := _reach("drone.detect")
	var attack := minf(float(Balance.getv("drone.range")), detect)
	var fly := float(Balance.getv("drone.speed"))
	var orbit := float(Balance.getv("drone.orbit"))
	var defense := float(Balance.getv("drone.defense"))
	for unit in drones:
		if index >= want:
			break
		index += 1
		if not unit.alive:
			unit.respawn -= dt
			if unit.respawn <= 0.0:
				unit.alive = true
				unit.hp_max = float(Balance.getv("drone.hp"))
				unit.hp = unit.hp_max
				unit.x = _player.x
				unit.y = _player.y - 80.0
			else:
				continue
		unit.flash = maxf(0.0, unit.flash - dt)
		unit.lane = _drone_lane(index - 1, want)
		unit.angle += dt * orbit
		var pos := Vector2(unit.x, unit.y)
		var prey := _drone_target(pos, unit.lane, detect)
		if prey != null:
			var enemy_at := Vector2(prey.x, prey.y)
			var gap := pos.distance_to(enemy_at)
			if gap > attack:
				pos += (enemy_at - pos).limit_length(fly * dt)
			else:
				var hold := enemy_at + (pos - enemy_at).limit_length(attack * 0.85)
				pos += (hold - pos).limit_length(fly * 0.55 * dt)
		else:
			var dest := Vector2(_player.x + cos(unit.angle) * 160.0, _player.y - 300.0 + sin(unit.angle * 1.7) * 90.0)
			pos += (dest - pos).limit_length(fly * dt)
		pos.x = clampf(pos.x, 36.0, _width - 36.0)
		pos.y = clampf(pos.y, 48.0, _player.y - 36.0)
		unit.x = pos.x
		unit.y = pos.y
		var drone_at := _project(pos)
		for e in enemies:
			if e.gone:
				continue
			if _hits_point(e, drone_at):
				unit.hp -= Formulas.mitigate(e.attack, defense, 0.0) * dt
				unit.flash = 0.08
		if unit.hp <= 0.0:
			unit.alive = false
			unit.respawn = float(Balance.getv("drone.respawn"))
			continue
		unit.shoot_cd -= dt
		if unit.shoot_cd <= 0.0:
			var tgt := _drone_shot(pos, attack, detect)
			if tgt:
				unit.shoot_cd = shoot_every
				deal(tgt, _damage("drone", "upgrades.drone_damage_pct"), 0.0, "drone")
				arcs.append({"pts": [pos, Vector2(tgt.x, tgt.y)], "life": 0.07, "kind": "drone"})
				Sfx.play("drone")
		var miss_rank := rank("drone_missiles")
		if miss_rank <= 0:
			continue
		unit.missile_cd -= dt
		if unit.missile_cd > 0.0:
			continue
		var tgt2 := _drone_shot(pos, attack, detect)
		if tgt2 == null:
			continue
		unit.missile_cd = float(Balance.getv("drone.missile_reload"))
		var burst := miss_rank * int(Balance.getv("upgrades.drone_missiles_per"))
		var missile_dmg := _damage("drone", "upgrades.drone_damage_pct") * float(Balance.getv("drone.missile_frac"))
		for _n in burst:
			var shot := Shot.new()
			shot.kind = "drone_missile"
			shot.x = unit.x
			shot.y = unit.y
			shot.ang = (Vector2(tgt2.x, tgt2.y) - pos).angle() + randf_range(-0.25, 0.25)
			shot.speed = float(Balance.getv("missile.speed")) * 0.75
			shot.max_range = attack
			shot.dmg = missile_dmg
			shot.target_id = tgt2.id
			shots.append(shot)


func _drone_lane(index: int, count: int) -> float:
	var margin := 80.0
	if count <= 1:
		return _width * 0.5
	return lerpf(margin, _width - margin, float(index) / float(count - 1))


func _drone_target(origin: Vector2, lane: float, detect: float) -> Enemy:
	var best: Enemy = null
	var best_score := 0.0
	var found := false
	for e in enemies:
		if not _drone_sees(e, origin, detect):
			continue
		var score := origin.distance_to(Vector2(e.x, e.y)) + absf(e.x - lane) * 0.15
		if not found or score < best_score:
			found = true
			best_score = score
			best = e
	return best


func _drone_shot(origin: Vector2, attack: float, detect: float) -> Enemy:
	var best: Enemy = null
	var best_d := attack
	for e in enemies:
		if not _drone_sees(e, origin, detect):
			continue
		var dist := origin.distance_to(Vector2(e.x, e.y))
		if dist <= best_d:
			best_d = dist
			best = e
	return best


func _enemies(dt: float) -> void:
	var line_y := _player.y
	var margin := 40.0
	var line_screen := _project(Vector2(0.0, line_y)).y
	for e in enemies:
		if e.gone:
			continue
		e.flash = maxf(0.0, e.flash - dt)
		if e.id != _laser_id:
			e.shred = maxf(0.0, e.shred - dt * 0.4)
		var stunned: bool = e.stun > 0.0
		e.guard = maxf(0.0, e.guard - dt)
		if stunned:
			e.stun -= dt
			continue
		if e.kind == "mine":
			_step_mine(e, dt, line_y, margin)
			continue
		if e.kind == "cross":
			_step_cross(e, dt, line_y)
			continue
		var gap: float = line_y - float(e.y)
		if e.weapon_range > 1.0 and gap <= e.weapon_range and gap > -e.radius:
			e.shoot_cd -= dt
			if e.shoot_cd <= 0.0 and _in_front(e.y):
				e.shoot_cd = float(Balance.getv("enemy.fire_interval"))
				hurt(e.attack)
				arcs.append({"pts": [Vector2(e.x, e.y), Vector2(e.x, line_y)], "life": 0.1, "kind": "enemy"})
			_weave(e, dt, _width, margin, 0.35)
			continue
		_weave(e, dt, _width, margin, 1.0)
		e.y += e.forward * dt
		# The hull is the full width of the bottom edge. A ram lands when the
		# drawn shape, not the old world circle, touches that line.
		if e.weapon_range <= 1.0:
			var reach := _body_r(e)
			if _project(Vector2(e.x, e.y)).y + Shapes.shape_bottom(e.kind, reach) >= line_screen:
				hurt(e.attack)
				kill_enemy(e, "ram")


func _step_mine(e: Enemy, dt: float, line_y: float, margin: float) -> void:
	_weave(e, dt, _width, margin, 0.6)
	if not e.armed:
		e.y += e.forward * dt
		if e.y >= line_y * float(Balance.getv("enemy.mine_arm")):
			e.armed = true
			e.fuse = float(Balance.getv("enemy.mine_fuse"))
		return
	e.y += e.forward * 0.35 * dt
	e.fuse -= dt
	if e.fuse <= 0.0:
		var at := Vector2(e.x, e.y)
		var atk := e.attack
		e.armed = false
		e.gone = true
		_mine_blast(atk, at)


func _step_cross(e: Enemy, dt: float, line_y: float) -> void:
	var host := _heal_host(e.id)
	if host == null:
		e.y += e.forward * 0.25 * dt
	else:
		e.x = move_toward(e.x, host.x, e.side * dt)
		e.y = move_toward(e.y, host.y - 28.0, e.forward * dt)
		host.hp = minf(host.hp_max, host.hp + host.hp_max * float(Balance.getv("enemy.cross_heal")) * dt)
	if e.y >= line_y:
		kill_enemy(e, "slip")


func _heal_host(self_id: int) -> Enemy:
	var best: Enemy = null
	var best_hp := -1.0
	for e in enemies:
		if e.gone or e.id == self_id or e.kind == "cross" or e.kind == "mine":
			continue
		if e.hp > best_hp:
			best_hp = e.hp
			best = e
	return best


func _mine_blast(amount: float, at: Vector2) -> void:
	hurt(amount)
	arcs.append({"pts": [at, _player], "life": 0.22, "kind": "enemy"})
	shocks.append({"x": at.x, "y": at.y, "r": 90.0, "life": 0.28, "max": 0.28})


func _tick_fuses(dt: float) -> void:
	var write := 0
	for fuse in _fuses:
		fuse["t"] = float(fuse["t"]) - dt
		if float(fuse["t"]) <= 0.0:
			_mine_blast(float(fuse["atk"]), Vector2(float(fuse["x"]), float(fuse["y"])))
		else:
			_fuses[write] = fuse
			write += 1
	_fuses.resize(write)


func _split_diamond(e: Enemy) -> void:
	var scale := float(Balance.getv("enemy.diamond_split"))
	spawn_enemy("circle", Vector2(e.x - 46.0, e.y), scale, false)
	spawn_enemy("circle", Vector2(e.x + 46.0, e.y), scale, false)


func _refresh_view() -> void:
	var view := Vector2(1280, 720)
	if _field != null and _field.size.x > 4.0 and _field.size.y > 4.0:
		view = _field.size
	_view_w = view.x
	var world := Vector2(_width, float(Balance.getv("field.length")))
	_view_cam = ScreenFit.fit_camera(view, world)
	_hit_r.clear()


func _project(world: Vector2) -> Vector2:
	return ScreenFit.project(_view_cam, world)


func _reach(path: String) -> float:
	return minf(float(Balance.getv(path)), _max_range)


func _shot_interval(base_path: String, per_path: String) -> float:
	var rate := Formulas.rate_with_level(float(Balance.getv(base_path)), float(Balance.getv(per_path)), match_level) * _haste
	return 1.0 / maxf(rate, 0.05)


func _advance(shot: Shot, dt: float) -> Vector2:
	var prev := Vector2(shot.x, shot.y)
	var step := shot.speed * dt
	var dir := Vector2(cos(shot.ang), sin(shot.ang))
	shot.x += dir.x * step
	shot.y += dir.y * step
	shot.traveled += step
	return prev


func _hits_segment(e: Enemy, a: Vector2, b: Vector2) -> bool:
	return Shapes.segment_hits(e.kind, _project(Vector2(e.x, e.y)), _body_r(e), a, b)


func _hits_point(e: Enemy, at: Vector2) -> bool:
	return Shapes.point_hits(e.kind, _project(Vector2(e.x, e.y)), _body_r(e), at)


func _index_enemies() -> void:
	_ids.clear()
	for e in enemies:
		_ids[e.id] = e


func _drone_sees(e: Enemy, origin: Vector2, detect: float) -> bool:
	if e.gone or not _in_front(e.y) or e.y > origin.y + 40.0:
		return false
	return _player.distance_to(Vector2(e.x, e.y)) <= detect


func _body_r(e: Enemy) -> float:
	return _icon_r(e.kind) * e.bulk


func _icon_r(kind: String) -> float:
	if not _hit_r.has(kind):
		_hit_r[kind] = Shapes.icon_radius(kind, _view_w)
	return float(_hit_r[kind])


func _weave(e: Enemy, dt: float, width: float, margin: float, rate: float) -> void:
	e.wobble += dt * 0.7 * rate
	var desired := clampf(e.lane + sin(e.wobble) * e.sway, margin, width - margin)
	var delta := desired - e.x
	# Follow the lane, but never step past it. The old ±1 clamp times side
	# speed jumped over the target and flipped direction every tick.
	var step := e.side * dt
	if absf(delta) <= step:
		e.x = desired
	else:
		e.x += signf(delta) * step
	e.x = clampf(e.x, margin, width - margin)


func _separate() -> void:
	for i in enemies.size():
		var a: Enemy = enemies[i]
		if a.gone:
			continue
		for j in range(i + 1, enemies.size()):
			var b: Enemy = enemies[j]
			if b.gone:
				continue
			if a.kind == "cross" or b.kind == "cross":
				continue
			var delta := Vector2(b.x - a.x, b.y - a.y)
			var min_d := (a.radius + b.radius) * 0.85
			if absf(delta.x) >= min_d or absf(delta.y) >= min_d:
				continue
			var dist := delta.length()
			if dist > 0.01 and dist < min_d:
				var overlap := min_d - dist
				# A hard shove every tick rattled ships that were only grazing.
				var push := delta / dist * minf(overlap * 0.22, 1.6)
				a.x -= push.x
				a.y -= push.y
				b.x += push.x
				b.y += push.y


func _fx(dt: float) -> void:
	for floater in floaters:
		floater["y"] = float(floater["y"]) - 42.0 * dt
		floater["life"] = float(floater["life"]) - dt
	_keep_life(floaters)
	for shock in shocks:
		shock["life"] = float(shock["life"]) - dt
	_keep_life(shocks)
	for arc in arcs:
		arc["life"] = float(arc["life"]) - dt
	_keep_life(arcs)


func _keep_enemies() -> void:
	var write := 0
	for e in enemies:
		if not e.gone:
			enemies[write] = e
			write += 1
	enemies.resize(write)


func _keep_shots() -> void:
	var write := 0
	for shot in shots:
		if shot.life >= 0.0:
			shots[write] = shot
			write += 1
	shots.resize(write)


func _keep_life(list: Array) -> void:
	var write := 0
	for item in list:
		if float(item["life"]) > 0.0:
			list[write] = item
			write += 1
	list.resize(write)


func deal(e: Enemy, raw: float, pen: float, cause: String) -> void:
	if e.gone or raw <= 0.0:
		return
	if e.kind == "chevron" and e.stun <= 0.0 and e.guard <= 0.0:
		e.guard = float(Balance.getv("enemy.chevron_block"))
		e.flash = 0.1
		_floater(e.x, e.y - e.radius, "BLOCK", UIKit.MUTED)
		return
	var defense := e.defense * (1.0 - clampf(e.shred, 0.0, 0.95))
	if e.stun > 0.0:
		var cond := rank("tesla_conductive")
		if cond > 0:
			raw *= 1.0 + float(Balance.getv("upgrades.tesla_conductive_pct")) * float(cond)
	var dealt := Formulas.mitigate(raw, defense, pen)
	e.hp -= dealt
	e.flash = 0.1
	_floater(e.x, e.y - e.radius, str(int(round(dealt))), UIKit.TEXT)
	if e.hp <= 0.0:
		kill_enemy(e, cause)


func kill_enemy(e: Enemy, cause: String) -> void:
	if e.gone:
		return
	e.gone = true
	e.hp = 0.0
	kills += 1
	gold_run += e.gold
	Profile.add_gold(e.gold)
	Profile.add_act_xp(e.xp)
	_gain_xp(e.xp)
	Sfx.play("hit")
	shocks.append({"x": e.x, "y": e.y, "r": e.radius * 2.2, "life": 0.2, "max": 0.2})
	if e.kind == "mine" and e.armed and e.fuse > 0.0:
		_fuses.append({"t": e.fuse, "atk": e.attack, "x": e.x, "y": e.y})
		e.armed = false
	if e.kind == "diamond" and cause != "dev":
		_split_diamond(e)
	if cause == "laser" and rank("laser_explode") > 0:
		var radius := float(Balance.getv("laser.explode_radius"))
		var raw := e.hp_max * float(Balance.getv("laser.explode_hp_frac"))
		for other in enemies:
			if other == e or other.gone:
				continue
			if Vector2(other.x, other.y).distance_to(Vector2(e.x, e.y)) <= radius:
				deal(other, raw, 0.0, "explode")
		shocks.append({"x": e.x, "y": e.y, "r": radius, "life": 0.25, "max": 0.25})


func hurt(amount: float) -> void:
	if not alive or Balance.god_mode:
		return
	var dealt := Formulas.mitigate(amount, defense_now(), 0.0)
	hull -= dealt
	if Profile.shake:
		shake = maxf(shake, 7.0)
	_floater(_player.x, _player.y - 36.0, "-%d" % int(round(dealt)), UIKit.DANGER)
	Sfx.play("hull")
	if hull <= 0.0:
		hull = 0.0
		_die()


func sync_hull_max() -> void:
	var max_h := hull_max_now()
	if max_h > hull_max:
		hull += max_h - hull_max
	hull_max = max_h
	hull = clampf(hull, 0.0, maxf(hull_max, 1.0))


func _gain_xp(amount: float) -> void:
	var cap := int(Balance.getv("player.level_cap"))
	if match_level >= cap:
		return
	xp += amount
	while match_level < cap:
		var need := Formulas.xp_needed(float(Balance.getv("xp.match_base")), float(Balance.getv("xp.match_per_level")), match_level)
		if xp < need:
			break
		xp -= need
		match_level += 1
		sync_hull_max()
		if match_level % 2 == 0:
			pending_upgrades += 1
			Sfx.play("level")
	if match_level >= cap:
		xp = 0.0


func _die() -> void:
	if not alive:
		return
	alive = false
	menu_hold = true
	banner = "HULL LOST"
	banner_life = 4.0
	Sfx.play("dead")
	Profile.note_round(round_num)
	_show_gameover()


func _floater(x: float, y: float, text: String, color: Color) -> void:
	floaters.append({"x": x, "y": y, "text": text, "life": 0.7, "color": color})
	if floaters.size() > 40:
		floaters.pop_front()


func _in_front(y: float) -> bool:
	return y < _player.y - 8.0


func _by_id(id: int) -> Enemy:
	if id < 0 or not _ids.has(id):
		return null
	return _ids[id]


func _threat_target(reach: float) -> Enemy:
	var best: Enemy = null
	var best_score := -1.0
	for e in enemies:
		if e.gone or not _in_front(e.y):
			continue
		if _player.distance_to(Vector2(e.x, e.y)) > reach:
			continue
		var score := _threat(e)
		if score > best_score:
			best_score = score
			best = e
	return best


func _threat(e: Enemy) -> float:
	var gap := _player.y - e.y
	var lead := 0.35
	var score := 0.0
	if e.kind == "cross":
		# It does not shoot. Leaving it up is what keeps the tank alive.
		score = 28.0 / lead
	elif e.kind == "mine":
		if e.armed:
			score = 0.0
		else:
			var arm_gap := maxf(0.0, _player.y * float(Balance.getv("enemy.mine_arm")) - e.y)
			score = e.attack / maxf(lead, arm_gap / maxf(e.forward, 1.0))
	elif e.weapon_range > 1.0 and gap <= e.weapon_range:
		score = e.attack / lead
	else:
		var dist := maxf(0.0, gap - maxf(e.weapon_range, 0.0))
		score = e.attack / maxf(lead, dist / maxf(e.forward, 1.0))
	if e.marked and score > 0.0:
		score *= float(Balance.getv("enemy.mark_hp"))
	return score


func _nearest(origin: Vector2, reach: float) -> Enemy:
	var best: Enemy = null
	var best_d := reach
	for e in enemies:
		if e.gone or not _in_front(e.y):
			continue
		var dist := origin.distance_to(Vector2(e.x, e.y))
		if dist <= best_d:
			best_d = dist
			best = e
	return best


func _strongest(reach: float) -> Enemy:
	var best: Enemy = null
	var best_hp := -1.0
	for e in enemies:
		if e.gone or not _in_front(e.y):
			continue
		if _player.distance_to(Vector2(e.x, e.y)) > reach:
			continue
		if e.hp > best_hp:
			best_hp = e.hp
			best = e
	return best


func _nearest_list(origin: Vector2, count: int, reach: float, ignore_id: int) -> Array:
	var pool: Array = []
	for e in enemies:
		if e.gone or e.id == ignore_id or not _in_front(e.y):
			continue
		if _player.distance_to(Vector2(e.x, e.y)) > reach:
			continue
		pool.append(e)
	pool.sort_custom(func(a, b): return origin.distance_to(Vector2(a.x, a.y)) < origin.distance_to(Vector2(b.x, b.y)))
	if pool.size() > count:
		pool.resize(count)
	return pool


func _damage(weapon: String, bonus_path: String = "") -> float:
	var dmg := Formulas.linear_level(float(Balance.getv(weapon + ".damage")), float(Balance.getv(weapon + ".damage_per_level")), match_level)
	dmg *= Profile.damage_multiplier(weapon)
	if not bonus_path.is_empty():
		dmg *= 1.0 + float(Balance.getv(bonus_path)) * float(rank(weapon + "_damage"))
	return dmg


func _build_ui() -> void:
	_field = FieldView.new()
	_field.battle = self
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	_hud = PanelContainer.new()
	_hud.add_theme_stylebox_override("panel", UIKit.glass_box())
	add_child(_hud)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_hud.add_child(col)
	_hull_label = UIKit.label("HULL", 16, UIKit.TEXT, true)
	col.add_child(_hull_label)
	_hull_fill = _bar(col, UIKit.DANGER)
	_meta_label = UIKit.label("", 14, UIKit.MUTED, true)
	col.add_child(_meta_label)
	_xp_fill = _bar(col, UIKit.CYAN)
	_act_label = UIKit.label("", 13, UIKit.AMBER, true)
	col.add_child(_act_label)
	_act_fill = _bar(col, UIKit.AMBER)
	_pass_through(_hud)
	_pause_btn = UIKit.button("SET", false)
	_pause_btn.custom_minimum_size = Vector2(64, 44)
	_pause_btn.pressed.connect(toggle_pause)
	add_child(_pause_btn)
	_build_tray()
	_layout_chrome()
	_pause_layer = _overlay()
	_upgrade_layer = _overlay()
	_over_layer = _overlay()
	_build_pause()


func _pass_through(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_pass_through(child)


func _bar(parent: Node, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(0, 6)
	bg.color = Color(1, 1, 1, 0.08)
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 0.0
	bg.add_child(fill)
	return fill


func _build_tray() -> void:
	var tray := PanelContainer.new()
	tray.name = "Tray"
	tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tray.offset_top = -168
	tray.add_theme_stylebox_override("panel", UIKit.panel_box())
	add_child(tray)
	_tray = tray
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tray.add_child(box)
	var toggle := UIKit.button("HIDE WEAPONS", false)
	toggle.custom_minimum_size = Vector2(0, 40)
	toggle.pressed.connect(func() -> void:
		_tray_open = not _tray_open
		_tray_row.visible = _tray_open
		toggle.text = "HIDE WEAPONS" if _tray_open else "SHOW WEAPONS"
		_layout_chrome()
	)
	box.add_child(toggle)
	_tray_row = HBoxContainer.new()
	_tray_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray_row.add_theme_constant_override("separation", 8)
	box.add_child(_tray_row)
	_refresh_tray()


func _refresh_tray() -> void:
	if _tray_row == null:
		return
	for child in _tray_row.get_children():
		child.queue_free()
	var left := HBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_END
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	var order_left: Array[String] = ["rail", "missile", "laser"]
	var order_right: Array[String] = ["tesla", "drone", "flame"]
	for kind in order_left:
		left.add_child(_glyph(kind))
	var ship := ShipBadge.new()
	var side := _chrome_size()
	ship.custom_minimum_size = Vector2(side + 18.0, side)
	for kind in order_right:
		right.add_child(_glyph(kind))
	_tray_row.add_child(left)
	_tray_row.add_child(ship)
	_tray_row.add_child(right)


func _glyph(kind: String) -> Control:
	var glyph := Glyph.new()
	var side := _chrome_size()
	glyph.custom_minimum_size = Vector2(side, side)
	glyph.kind = kind
	glyph.dim = kind != "rail" and not owned.get(kind, false)
	return glyph


func _chrome_size() -> float:
	var w := size.x if size.x > 2.0 else get_viewport_rect().size.x
	var s := ScreenFit.px(w, 1.0)
	return clampf(w / 32.0, 18.0 * s, 28.0 * s)


func _layout_chrome() -> void:
	if _field == null or _tray == null or _hud == null:
		return
	_anchor_full(self)
	var h := size.y if size.y > 2.0 else get_viewport_rect().size.y
	var w := size.x if size.x > 2.0 else get_viewport_rect().size.x
	var s := ScreenFit.px(w, 1.0)
	var compact := h / s < 700.0
	var tray_floor := ((108.0 if compact else 120.0) if _tray_open else 44.0) * s
	var tray_h := maxf(_tray.get_combined_minimum_size().y + 6.0, tray_floor)
	_span(_field, 0.0, 1.0, 0.0, -tray_h)
	_span(_tray, 1.0, 1.0, -tray_h, 0.0)
	var pad := 10.0 * s
	var box_w := clampf(w * 0.42, 220.0 * s, 340.0 * s)
	_hud.anchor_left = 0.0
	_hud.anchor_right = 0.0
	_hud.anchor_top = 0.0
	_hud.anchor_bottom = 0.0
	_hud.offset_left = pad
	_hud.offset_top = pad
	_hud.offset_right = pad + box_w
	_hud.offset_bottom = pad + _hud.get_combined_minimum_size().y
	if _pause_btn != null:
		var bw := maxf(64.0 * s, _pause_btn.custom_minimum_size.x)
		var bh := maxf(44.0 * s, _pause_btn.custom_minimum_size.y)
		_pause_btn.anchor_left = 1.0
		_pause_btn.anchor_right = 1.0
		_pause_btn.anchor_top = 0.0
		_pause_btn.anchor_bottom = 0.0
		_pause_btn.offset_right = -pad
		_pause_btn.offset_left = -pad - bw
		_pause_btn.offset_top = pad
		_pause_btn.offset_bottom = pad + bh
	# Field fills to the top. The readout sits over it and does not take a row.
	move_child(_field, 0)
	for node in [_hud, _pause_btn, _tray, _pause_layer, _upgrade_layer, _over_layer]:
		if node != null and node.get_parent() == self:
			move_child(node, get_child_count() - 1)
	var side := _chrome_size()
	if absf(side - _chrome) > 0.5:
		_chrome = side
		_refresh_tray()


func _span(node: Control, top_anchor: float, bottom_anchor: float, top_off: float, bottom_off: float) -> void:
	node.anchor_left = 0.0
	node.anchor_right = 1.0
	node.anchor_top = top_anchor
	node.anchor_bottom = bottom_anchor
	node.offset_left = 0.0
	node.offset_right = 0.0
	node.offset_top = top_off
	node.offset_bottom = bottom_off


func _overlay() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.04, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	return layer


func toggle_pause() -> void:
	if not alive or upgrade_open:
		return
	pause_open = not pause_open
	menu_hold = pause_open
	_pause_layer.visible = pause_open
	if pause_open:
		var act := _pause_layer.find_child("ActReadout", true, false)
		if act is Label:
			act.text = Profile.act_line()
		var fill := _pause_layer.find_child("ActFill", true, false)
		if fill is ColorRect:
			fill.anchor_right = Profile.act_ratio()


func _build_pause() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var box := VBoxContainer.new()
	var w := get_viewport_rect().size.x
	box.custom_minimum_size = Vector2(clampf(w - 48.0, 260.0, 440.0), 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	box.add_child(UIKit.label("HOLDING", 28, UIKit.AMBER, false, true))
	box.add_child(UIKit.label("The field is paused. Gold already earned stays with you.", 16, UIKit.MUTED))
	var act := UIKit.label(Profile.act_line(), 16, UIKit.AMBER, true)
	act.name = "ActReadout"
	box.add_child(act)
	var act_bar := UIKit.progress_bar(Profile.act_ratio(), UIKit.AMBER)
	var act_fill := act_bar.get_node("Fill")
	act_fill.name = "ActFill"
	box.add_child(act_bar)
	box.add_child(UIKit.label(Profile.act_title(), 16, UIKit.AMBER, false, true))
	box.add_child(UIKit.label(Profile.act_lore(), 15, UIKit.MUTED))
	box.add_child(UIKit.label("Sound", 16, UIKit.MUTED))
	box.add_child(UIKit.volume_row())
	var resume := UIKit.button("RESUME", true)
	resume.pressed.connect(toggle_pause)
	box.add_child(resume)
	var notes := UIKit.button("FIELD NOTES", false)
	notes.pressed.connect(func() -> void:
		var root := get_tree().current_scene
		if root and root.has_method("show_notes"):
			root.show_notes()
	)
	box.add_child(notes)
	var abandon := UIKit.button("ABANDON RUN", false)
	abandon.pressed.connect(func() -> void:
		Profile.note_round(round_num)
		leave.emit(false)
	)
	box.add_child(abandon)


func _open_upgrade() -> void:
	if upgrade_open or pending_upgrades <= 0:
		return
	upgrade_open = true
	menu_hold = true
	pause_open = false
	_pause_layer.visible = false
	for child in _upgrade_layer.get_children():
		if not (child is ColorRect):
			child.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_upgrade_layer.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(clampf(get_viewport_rect().size.x - 48.0, 260.0, 520.0), 0)
	center.add_child(col)
	col.add_child(UIKit.label("CHOOSE AN UPGRADE", 26, UIKit.AMBER, false, true))
	col.add_child(UIKit.label("Level %d. Three offers, one pick." % match_level, 16, UIKit.MUTED))
	for card in _roll_cards():
		var button := UIKit.button(card["title"] + "\n" + card["body"], false)
		button.custom_minimum_size = Vector2(0, ScreenFit.px(get_viewport_rect().size.x, 56.0))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_pick.bind(card["id"]))
		col.add_child(button)
	_upgrade_layer.visible = true


func _pick(card_id: String) -> void:
	_apply_card(card_id)
	pending_upgrades = maxi(pending_upgrades - 1, 0)
	upgrade_open = false
	_upgrade_layer.visible = false
	menu_hold = false
	Sfx.play("ui")
	_refresh_tray()


func _roll_cards() -> Array:
	var pool: Array = []
	for weapon in ["missile", "laser", "tesla", "drone", "flame"]:
		if Profile.weapon_unlocked(weapon) and not owned.get(weapon, false):
			pool.append({"id": "acq_" + weapon, "title": "ARM " + _weapon_name(weapon).to_upper(), "body": _acquire_body(weapon), "weight": 5})
	_add_upgrade(pool, "rail_damage", "rail", "RAIL DAMAGE", "Damage +25% for the railgun.", int(Balance.getv("upgrades.rail_damage_max")))
	_add_upgrade(pool, "rail_pierce", "rail", "PIERCE", "Bolts continue into another ship at half damage.", int(Balance.getv("upgrades.rail_pierce_max")))
	_add_upgrade(pool, "rail_static", "rail", "STATIC", "The round is charged. On a hit it jumps to one nearby ship for 25% damage.", int(Balance.getv("upgrades.rail_static_max")))
	_add_upgrade(pool, "missile_aoe", "missile", "WIDER BLAST", "Explosion radius +15%.", int(Balance.getv("upgrades.missile_aoe_max")))
	_add_upgrade(pool, "missile_reload", "missile", "FASTER RELOAD", "Missiles reload 1 second faster.", int(Balance.getv("upgrades.missile_reload_max")))
	_add_upgrade(pool, "missile_split", "missile", "SPLIT", "On impact, extra missiles break away. They home like a normal missile, a little smaller, at half damage.", int(Balance.getv("upgrades.missile_split_max")))
	_add_upgrade(pool, "laser_rate", "laser", "FASTER BEAM", "The laser ticks damage more often.", int(Balance.getv("upgrades.laser_rate_max")))
	_add_upgrade(pool, "laser_reflect", "laser", "REFLECT", "The beam jumps to another ship at half damage.", int(Balance.getv("upgrades.laser_reflect_max")))
	_add_upgrade(pool, "laser_explode", "laser", "DETONATE", "Ships destroyed by the laser burst for half their hull.", int(Balance.getv("upgrades.laser_explode_max")))
	_add_upgrade(pool, "tesla_damage", "tesla", "TESLA DAMAGE", "Zap damage +25%.", int(Balance.getv("upgrades.tesla_damage_max")))
	_add_upgrade(pool, "tesla_targets", "tesla", "MORE ARCS", "The chain hits 2 more ships.", int(Balance.getv("upgrades.tesla_targets_max")))
	_add_upgrade(pool, "tesla_conductive", "tesla", "CONDUCTIVE", "While a ship is stunned, every weapon hits it 15% harder.", int(Balance.getv("upgrades.tesla_conductive_max")))
	_add_upgrade(pool, "drone_damage", "drone", "DRONE DAMAGE", "Each drone hits 20% harder.", int(Balance.getv("upgrades.drone_damage_max")))
	_add_upgrade(pool, "drone_count", "drone", "MORE DRONES", "Launch 2 more drones.", int(Balance.getv("upgrades.drone_count_max")))
	_add_upgrade(pool, "drone_missiles", "drone", "DRONE MISSILES", "Each drone gains a missile every 2 seconds.", int(Balance.getv("upgrades.drone_missiles_max")))
	_add_upgrade(pool, "flame_range", "flame", "LONGER FLAME", "Flame reach +250, up to 1000.", int(Balance.getv("upgrades.flame_range_max")))
	_add_upgrade(pool, "flame_damage", "flame", "HOTTER FLAME", "Flame ticks +25% damage.", int(Balance.getv("upgrades.flame_damage_max")))
	_add_upgrade(pool, "flame_width", "flame", "WIDER FLAME", "The cone opens 10% wider.", int(Balance.getv("upgrades.flame_width_max")))
	if pool.size() < 3:
		pool.append({"id": "util_heal", "title": "PATCH THE HULL", "body": "Restore %d%% of max hull." % int(float(Balance.getv("utility.heal_frac")) * 100.0), "weight": 2})
		pool.append({"id": "util_gold", "title": "SCAVENGE", "body": "Bank bonus gold for research.", "weight": 2})
		if overclock < int(Balance.getv("utility.overclock_max")):
			pool.append({"id": "util_overclock", "title": "OVERCLOCK", "body": "All weapons fire 8% faster for the rest of the run.", "weight": 2})
	var chosen: Array = []
	var working := pool.duplicate()
	while chosen.size() < 3 and not working.is_empty():
		var total := 0
		for card in working:
			total += int(card["weight"])
		var roll := randi() % maxi(total, 1)
		var acc := 0
		var index := 0
		for i in working.size():
			acc += int(working[i]["weight"])
			if roll < acc:
				index = i
				break
		chosen.append(working[index])
		working.remove_at(index)
	return chosen


func _add_upgrade(pool: Array, key: String, weapon: String, title: String, body: String, max_rank: int) -> void:
	if weapon != "rail" and not owned.get(weapon, false):
		return
	if rank(key) >= max_rank:
		return
	pool.append({
		"id": "up_" + key,
		"title": "%s  %d/%d" % [title, rank(key) + 1, max_rank],
		"body": body,
		"weight": 2,
	})


func _apply_card(card_id: String) -> void:
	if card_id.begins_with("acq_"):
		var weapon := card_id.trim_prefix("acq_")
		owned[weapon] = true
		banner = _weapon_name(weapon).to_upper() + " ONLINE"
		banner_life = 1.6
		return
	if card_id.begins_with("up_"):
		var key := card_id.trim_prefix("up_")
		ranks[key] = rank(key) + 1
		banner = key.replace("_", " ").to_upper()
		banner_life = 1.1
		return
	match card_id:
		"util_heal":
			sync_hull_max()
			hull = minf(hull_max, hull + hull_max * float(Balance.getv("utility.heal_frac")))
		"util_gold":
			var bonus := float(Balance.getv("utility.gold")) + float(round_num)
			gold_run += bonus
			Profile.add_gold(bonus)
		"util_overclock":
			overclock = mini(overclock + 1, int(Balance.getv("utility.overclock_max")))


func _show_gameover() -> void:
	for child in _over_layer.get_children():
		if not (child is ColorRect):
			child.queue_free()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -190
	box.offset_right = 190
	box.offset_top = -250
	box.offset_bottom = 300
	box.add_theme_constant_override("separation", 8)
	_over_layer.add_child(box)
	box.add_child(UIKit.label("LINE BROKEN", 30, UIKit.DANGER, false, true))
	box.add_child(UIKit.label("Round %d    Level %d" % [round_num, match_level], 18, UIKit.TEXT, true))
	box.add_child(UIKit.label("%d kills    %d gold banked" % [kills, int(gold_run)], 16, UIKit.MUTED, true))
	box.add_child(UIKit.label(Profile.act_line(), 16, UIKit.AMBER, true))
	box.add_child(UIKit.progress_bar(Profile.act_ratio(), UIKit.AMBER))
	box.add_child(UIKit.label(Profile.act_title(), 16, UIKit.AMBER, false, true))
	box.add_child(UIKit.label(Profile.act_lore(), 15, UIKit.MUTED))
	box.add_child(UIKit.label(Profile.next_unlock_label(), 16, UIKit.MUTED))
	box.add_child(UIKit.label(Profile.mastery_label(), 16, UIKit.MUTED))
	var again := UIKit.button("DEPLOY AGAIN", true)
	again.pressed.connect(func() -> void: leave.emit(true))
	box.add_child(again)
	var menu := UIKit.button("MAIN SCREEN", false)
	menu.pressed.connect(func() -> void: leave.emit(false))
	box.add_child(menu)
	_over_layer.visible = true


func _refresh_hud() -> void:
	if _hull_label == null:
		return
	sync_hull_max()
	_hull_label.text = "HULL %d/%d" % [int(ceil(hull)), int(ceil(hull_max))]
	var need := Formulas.xp_needed(float(Balance.getv("xp.match_base")), float(Balance.getv("xp.match_per_level")), match_level)
	_meta_label.text = "LV %d   ROUND %d   GOLD %d" % [match_level, round_num, int(gold_run)]
	_act_label.text = Profile.act_line()
	_hull_fill.anchor_right = clampf(hull / maxf(hull_max, 1.0), 0.0, 1.0)
	_xp_fill.anchor_right = 1.0 if match_level >= int(Balance.getv("player.level_cap")) else clampf(xp / maxf(need, 1.0), 0.0, 1.0)
	_act_fill.anchor_right = Profile.act_ratio()


func _weapon_name(id: String) -> String:
	match id:
		"rail":
			return "Railgun"
		"missile":
			return "Missiles"
		"laser":
			return "Laser"
		"tesla":
			return "Tesla"
		"drone":
			return "Drones"
		"flame":
			return "Flamethrower"
	return id


func _acquire_body(id: String) -> String:
	match id:
		"missile":
			return "Slow heavy blasts. Weak early, brutal once they level."
		"laser":
			return "Holds a beam, shreds defense, ticks every quarter second."
		"tesla":
			return "Chains between ships and stuns the first hardest."
		"drone":
			return "Two escorts to start. Fast, light, and upgradable."
		"flame":
			return "A short cone. Cooks clustered light ships."
	return ""
