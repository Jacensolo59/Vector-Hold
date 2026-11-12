extends Node
## Live balance. Defaults live in balance_data.gd. Overrides save to user://balance.json.
## The dev console writes through setv(). Combat reads getv() at the moment of use.

const Data = preload("res://scripts/balance_data.gd")

var defaults: Dictionary = {}
var overrides: Dictionary = {}
var _flat: Dictionary = {}
var show_ranges: bool = false
var show_hitboxes: bool = false
var god_mode: bool = false
var sim_speed: int = 1


func _ready() -> void:
	defaults = Data.defaults()
	_load()


func getv(path: String):
	if _flat.has(path):
		return _flat[path]
	push_error("Missing balance path: " + path)
	return 0.0


func setv(path: String, value: float) -> void:
	overrides[path] = value
	_flat[path] = value
	_save()


func clear_overrides() -> void:
	overrides = {}
	_save()
	_reindex()


func override_json() -> String:
	return JSON.stringify(overrides, "\t")


func _save() -> void:
	var file := FileAccess.open("user://balance.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(overrides))


func _load() -> void:
	if FileAccess.file_exists("user://balance.json"):
		var file := FileAccess.open("user://balance.json", FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				overrides = parsed
				_migrate_enemy_percents()
	_reindex()


func _reindex() -> void:
	_flat.clear()
	_walk(defaults, "")
	for path in overrides:
		_flat[path] = overrides[path]


func _walk(node: Dictionary, prefix: String) -> void:
	for key in node:
		var path := str(key) if prefix.is_empty() else prefix + "." + str(key)
		var value = node[key]
		if typeof(value) == TYPE_DICTIONARY:
			_walk(value, path)
		else:
			_flat[path] = value


func _migrate_enemy_percents() -> void:
	# Older builds stored 1% as 0.01. The console now uses 1 for 1%.
	var changed := false
	for key in overrides.keys():
		var path := str(key)
		if not path.begins_with("enemy."):
			continue
		if not path.ends_with("_def_pct") and not path.ends_with("_atk_pct"):
			continue
		var value := float(overrides[key])
		if value > 0.0 and value < 1.0:
			overrides[key] = value * 100.0
			changed = true
	if changed:
		_save()
