extends RefCounted
## Pure numbers for Vector Hold. See notes/03-weapons.txt and notes/06-dev-console-and-balance.txt.
## Round 1 uses the written base. Later rounds add the "per round" term (round - 1) times.


static func round_delta(round_num: int) -> float:
	return float(maxi(round_num, 1) - 1)


static func enemy_hp(base: float, per_round: float, round_num: int) -> float:
	return base + per_round * round_delta(round_num)


static func enemy_scaled(base: float, pct_per_round: float, round_num: int) -> float:
	# pct_per_round is a percent: 1 means +1% of the base each round after the first.
	return base * (1.0 + (pct_per_round / 100.0) * round_delta(round_num))


static func mitigate(raw: float, defense: float, pen: float) -> float:
	var kept := maxf(0.0, defense) * (1.0 - clampf(pen, 0.0, 0.95))
	return raw * (100.0 / (100.0 + kept))


static func research_cost(start: float, base_inc: float, band_inc: float, band: int, owned_rank: int) -> int:
	var cost := start
	var step := maxi(band, 1)
	for r in owned_rank:
		var inc := base_inc + band_inc * float(int(r / step))
		cost *= 1.0 + inc
	return int(ceili(cost - 0.0000001))


static func edge_multiplier(edge_base: float, per_rank: float, rank: int) -> float:
	return edge_base + per_rank * float(maxi(rank, 0))


static func linear_level(base: float, per_level: float, level: int) -> float:
	return base + per_level * float(maxi(level, 1) - 1)


static func rate_with_level(base: float, pct_per_level: float, level: int) -> float:
	return base * (1.0 + pct_per_level * float(maxi(level, 1) - 1))


static func spread_shots(rank: int, shots_per_rank: int, cap_shots: int) -> int:
	if rank <= 0:
		return 1
	return mini(cap_shots, shots_per_rank * rank)


static func flame_range(base: float, per_rank: float, rank: int, cap_range: float) -> float:
	return minf(cap_range, base + per_rank * float(maxi(rank, 0)))


static func count_with_rank(base: int, per_rank: int, rank: int) -> int:
	return base + per_rank * maxi(rank, 0)


static func stun_duration(base: float, falloff: float, index: int, minimum: float) -> float:
	return maxf(minimum, base - falloff * float(maxi(index, 0)))


static func xp_needed(base: float, per_level: float, level: int) -> float:
	return base + per_level * float(maxi(level, 1))


static func reload_time(base: float, seconds_per_rank: float, rank: int, minimum: float) -> float:
	return maxf(minimum, base - seconds_per_rank * float(maxi(rank, 0)))


static func wave_count(base: float, per: float, round_num: int, from_round: int) -> int:
	if round_num < from_round:
		return 0
	var n := base + per * float(round_num - from_round)
	return maxi(int(floor(n + 0.0001)), 0)


static func compound(pct_per_round: float, round_num: int, grace: float = 0.0, bend: float = 0.0) -> float:
	# pct_per_round is a percent. Round 1 is 1. Later rounds compound.
	# grace and bend leave the first rounds close to the written stats, then
	# bend the exponent so a fully researched ship still meets a wall.
	var steps := round_delta(round_num)
	if steps <= 0.0 or pct_per_round <= 0.0:
		return 1.0
	var extra := maxf(0.0, steps - grace) * maxf(bend, 0.0)
	var exponent := steps * (1.0 + extra)
	return pow(1.0 + pct_per_round / 100.0, exponent)


static func is_boss_round(round_num: int, every: int) -> bool:
	return every > 0 and round_num > 0 and round_num % every == 0


static func boss_hp_mult(round_num: int, every: int, pct: float) -> float:
	if every <= 0:
		return 1.0
	var stacks := int(maxi(round_num, 0)) / every
	return 1.0 + (pct / 100.0) * float(stacks)


static func act_progress(total_xp: float, base: float, per_level: float) -> Dictionary:
	var level := 1
	var remain := maxf(0.0, total_xp)
	while level < 240:
		var need := xp_needed(base, per_level, level)
		if remain < need:
			return {"level": level, "into": remain, "need": need}
		remain -= need
		level += 1
	return {"level": level, "into": remain, "need": xp_needed(base, per_level, level)}
