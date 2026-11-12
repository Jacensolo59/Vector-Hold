extends Node
## Meta progress between matches: gold, act level, research. Saved at user://profile.json.

const Formulas = preload("res://scripts/formulas.gd")

var gold: float = 0.0
var act_xp_total: float = 0.0
var research: Dictionary = {}
var sfx_volume: float = 0.7
var shake: bool = true
var resolution: String = "auto"
var best_round: int = 0
var intro_seen: bool = false
var balance_epoch: int = 2

var act_level: int = 1
var act_into: float = 0.0
var act_need: float = 1.0


func _ready() -> void:
	_load()
	_recompute_act()


func weapon_unlocked(id: String) -> bool:
	if id == "rail":
		return true
	return act_level >= int(Balance.getv("unlock." + id))


func research_rank(track: String) -> int:
	return int(research.get(track, 0))


func research_cap(track: String) -> int:
	if track == "rail_pen":
		return int(Balance.getv("research.pen_cap"))
	if track == "missile_edge":
		return int(Balance.getv("research.edge_cap"))
	return int(Balance.getv("research.damage_cap"))


func research_cost(track: String) -> int:
	var rank := research_rank(track)
	var start := "research.damage_start"
	var inc := "research.damage_inc"
	var band_inc := "research.damage_band_inc"
	var band := "research.damage_band"
	if track == "rail_pen":
		start = "research.pen_start"
		inc = "research.pen_inc"
		band_inc = "research.pen_band_inc"
		band = "research.pen_band"
	elif track == "missile_edge":
		start = "research.edge_start"
	return Formulas.research_cost(
		float(Balance.getv(start)),
		float(Balance.getv(inc)),
		float(Balance.getv(band_inc)),
		int(Balance.getv(band)),
		rank
	)


func track_unlocked(track: String) -> bool:
	match track:
		"rail", "rail_pen":
			return true
		"missile", "missile_edge":
			return weapon_unlocked("missile")
		"laser":
			return weapon_unlocked("laser")
		"tesla":
			return weapon_unlocked("tesla")
		"drone":
			return weapon_unlocked("drone")
		"flame":
			return weapon_unlocked("flame")
	return false


func can_buy(track: String) -> bool:
	if not track_unlocked(track):
		return false
	if research_rank(track) >= research_cap(track):
		return false
	return gold >= float(research_cost(track))


func buy(track: String) -> bool:
	if not can_buy(track):
		return false
	gold -= float(research_cost(track))
	research[track] = research_rank(track) + 1
	save()
	return true


func add_gold(amount: float) -> void:
	gold = maxf(0.0, gold + amount)
	save()


func add_act_xp(amount: float) -> void:
	act_xp_total += maxf(0.0, amount)
	_recompute_act()
	save()


func note_round(round_num: int) -> void:
	if round_num > best_round:
		best_round = round_num
		save()


func mark_intro() -> void:
	intro_seen = true
	save()


func damage_multiplier(weapon_id: String) -> float:
	return 1.0 + float(Balance.getv("research.damage_per")) * float(research_rank(weapon_id))


func rail_pen() -> float:
	return float(Balance.getv("research.pen_per")) * float(research_rank("rail_pen"))


func missile_edge() -> float:
	return Formulas.edge_multiplier(
		float(Balance.getv("research.edge_base")),
		float(Balance.getv("research.edge_per")),
		research_rank("missile_edge")
	)


func act_ratio() -> float:
	return clampf(act_into / maxf(act_need, 1.0), 0.0, 1.0)


func act_line() -> String:
	return "ACT %02d   %s / %s XP" % [act_level, _grouped(int(floor(act_into))), _grouped(int(ceil(act_need)))]


func act_title() -> String:
	match _lore_index():
		1: return "OUTER DARK"
		2: return "THE PICKET"
		3: return "THE BELT"
		4: return "CHARGED SPACE"
		5: return "THE WING"
		6: return "INNER BURN"
		7: return "THE APPROACHES"
		8: return "HARBOR LIGHT"
		9: return "THE DOOR"
		10: return "THE SIGNAL"
		_: return "LAST LANE"


func act_lore() -> String:
	match _lore_index():
		1:
			return "You are pointed at home and still in their sky. The railgun is all that came through with you."
		2:
			return "The first patrol line breaks. You pull a missile rack off the wreckage. Home is a bearing, not a light."
		3:
			return "The lane crowds. A cutting beam comes off a dead hull, and you keep the same heading."
		4:
			return "The storms here carry a current. You rig it into the tesla. Their guards start answering in kind."
		5:
			return "Two drones fall back into your formation. For the first time the lane is not only you."
		6:
			return "Close enough that the hull runs hot. The flame is for ships that get inside the guns."
		7:
			return "Every weapon is online. Their beacons are in your charts now, and they are still firing."
		8:
			return "Home is on the scope. The last stretch of their territory does not open on its own."
		9:
			return "You can see the harbor. Every ship you stop is one that does not stand between you and it."
		10:
			return "Home answers. The space in front of the reply is still theirs."
		_:
			return "The light is steady. You hold until the lane in front of it is empty."


func _lore_index() -> int:
	if act_level <= 8:
		return maxi(act_level, 1)
	return 9 + (act_level - 9) % 3


func _grouped(n: int) -> String:
	var text := str(maxi(n, 0))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count == 3:
			out = "," + out
			count = 0
		out = text[i] + out
		count += 1
	return out


func next_unlock_label() -> String:
	var order: Array = [
		["missile", "Missiles"],
		["laser", "Laser"],
		["tesla", "Tesla"],
		["drone", "Drones"],
		["flame", "Flamethrower"],
	]
	for entry in order:
		if not weapon_unlocked(entry[0]):
			return "Next unlock: %s (act %d)" % [entry[1], int(Balance.getv("unlock." + entry[0]))]
	return "All weapons online"


func mastery_label() -> String:
	var steps := maxi(act_level - 1, 0)
	var hull := int(round(float(Balance.getv("player.hull_per_act")) * float(steps)))
	var defense := int(round(float(Balance.getv("player.defense_per_act")) * float(steps)))
	if steps <= 0:
		return "Each act adds hull and defense to every future run."
	return "Act mastery +%d hull, +%d defense." % [hull, defense]


func reset_progress() -> void:
	gold = 0.0
	act_xp_total = 0.0
	research = {}
	best_round = 0
	intro_seen = false
	_recompute_act()
	save()


func save() -> void:
	var payload := {
		"gold": gold,
		"act_xp_total": act_xp_total,
		"research": research,
		"sfx_volume": sfx_volume,
		"shake": shake,
		"resolution": resolution,
		"best_round": best_round,
		"intro_seen": intro_seen,
		"balance_epoch": balance_epoch,
	}
	var file := FileAccess.open("user://profile.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))


func _load() -> void:
	if not FileAccess.file_exists("user://profile.json"):
		return
	var file := FileAccess.open("user://profile.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	gold = float(parsed.get("gold", 0))
	act_xp_total = float(parsed.get("act_xp_total", 0))
	sfx_volume = clampf(float(parsed.get("sfx_volume", 0.7)), 0.0, 1.0)
	shake = bool(parsed.get("shake", true))
	resolution = str(parsed.get("resolution", "auto"))
	best_round = int(parsed.get("best_round", 0))
	intro_seen = bool(parsed.get("intro_seen", false))
	var epoch := int(parsed.get("balance_epoch", 0))
	if epoch < 2 and act_xp_total > 0.0:
		# 1.0.29 stretched the act curve. Scale stored XP once so an old act
		# level does not collapse back to act 1.
		act_xp_total *= 900.0
	balance_epoch = 2
	var stored = parsed.get("research", {})
	if typeof(stored) == TYPE_DICTIONARY:
		research = stored


func _recompute_act() -> void:
	var progress: Dictionary = Formulas.act_progress(
		act_xp_total,
		float(Balance.getv("xp.act_base")),
		float(Balance.getv("xp.act_per_level"))
	)
	act_level = int(progress.level)
	act_into = float(progress.into)
	act_need = float(progress.need)
