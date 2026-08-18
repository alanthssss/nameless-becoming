class_name HuddleMechanic
extends RefCounted
## 冬至 · 抱团：共御严寒。
## 储备是选项空间，不是生死线——储备足则归巢抱团回暖快（从容），
## 储备不足则回暖慢、更依赖冒险（风险留给老兵）。
## 侦察解锁：储备达标后寻迹冷却缩短，蜂巢以摇摆舞标出花源方向。

var mechanic_id := "huddle"
var main
var warmth_drain := 0.5
var warmth_rest := 45.0
var warmth_weak_rest := 25.0
var reserve_per_rest := 1
var scout_reserve_threshold := 5
var sense_cooldown_scout := 4.0
var cold_warmth_threshold := 15.0
var cold_recovery_factor := 0.5
var scouting_unlocked := false
var _low_warned := false


func start(game, data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("huddle", {})
	warmth_drain = float(params.get("warmth_drain", 0.5))
	warmth_rest = float(params.get("warmth_rest", 45.0))
	warmth_weak_rest = float(params.get("warmth_weak_rest", 25.0))
	reserve_per_rest = int(params.get("reserve_per_rest", 1))
	scout_reserve_threshold = int(params.get("scout_reserve_threshold", 5))
	sense_cooldown_scout = float(params.get("sense_cooldown_scout", 4.0))
	cold_warmth_threshold = float(params.get("cold_warmth_threshold", 15.0))
	cold_recovery_factor = float(params.get("cold_recovery_factor", 0.5))
	main.cold_warmth_threshold = cold_warmth_threshold
	# 整季越冬期间体温延续：仅入冬第一个节令（index % 6 == 0）重置
	if not main.preserve_warmth:
		main.warmth = 100.0
	_low_warned = false
	scouting_unlocked = main.hive_reserve >= scout_reserve_threshold
	# 幼虫加成：来年劳动力 → 更耐寒的体格（出巢能量上限）
	var reserve_params: Dictionary = mechanics.get("reserve", {})
	var larvae_per_boost := int(reserve_params.get("larvae_per_boost", 10))
	var boost_per_round := int(reserve_params.get("boost_energy_cap", 5))
	var bonus := int(main.larval_boost / maxi(larvae_per_boost, 1)) * boost_per_round
	main.energy_cap_override = 100.0 + float(bonus)
	if bonus > 0:
		main.bee.energy = main.energy_cap_override
		main.message = "幼虫已长成来年劳动力：出巢能量上限 +%d。" % bonus
	elif not scouting_unlocked:
		main.message = "储备不足，侦察队尚未出发。储备达到 %d 滴后，花源信息会随摇摆舞传来。" % scout_reserve_threshold


func process(delta: float) -> void:
	if main.bee.position.x >= main.HIVE_SAFE_X:
		main.warmth = maxf(0.0, main.warmth - warmth_drain * delta)
		if main.warmth <= cold_warmth_threshold and not _low_warned:
			_low_warned = true
			main.message = "严寒让蜂翼发沉。储备见底时，连蜂巢的温暖也所剩无几。"
	elif _low_warned:
		_low_warned = false


func on_home(amount: int, delta: float) -> void:
	if amount > 0:
		# 抱团回暖：消耗一份储备燃料
		if main.hive_reserve >= reserve_per_rest:
			main.hive_reserve -= reserve_per_rest
			main.warmth = minf(100.0, main.warmth + warmth_rest)
		else:
			main.warmth = minf(100.0, main.warmth + warmth_weak_rest)
			main.message = "储备见底，抱团也只能半暖半冷。"
	else:
		# 空手回巢也能短暂挤进蜂团
		main.warmth = minf(100.0, main.warmth + 12.0)


func is_scouting_ready() -> bool:
	return scouting_unlocked


func scout_cooldown_value() -> float:
	return sense_cooldown_scout


func draw() -> void:
	# 抱团光晕（蜂巢）
	var hive_position := Vector2(86, 410)
	var glow := 26.0 + sin(main.elapsed * 3.0) * 3.0
	main.draw_arc(hive_position, glow, 0, TAU, 28, Color("f4d893", 0.45), 3)
	# 温暖条（蜂巢上方）
	var ratio := clampf(main.warmth / 100.0, 0.0, 1.0)
	var bar_position := Vector2(52, 138)
	main.draw_rect(Rect2(bar_position, Vector2(72, 6)), Color("33494b", 0.8))
	main.draw_rect(Rect2(bar_position, Vector2(72 * ratio, 6)), Color("f4d893") if ratio > 0.3 else Color("b84a3f"))
	main.draw_string(main.zh_font, bar_position + Vector2(0, -12), "温暖 %d%%" % roundi(main.warmth), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f4d893"))
	# 摇摆舞（侦察解锁且正在寻迹）
	if scouting_unlocked and main.bee.sense_time > 0.0:
		var origin := Vector2(86, 470)
		for i in 15:
			var t := float(i) / 14.0
			var x := origin.x + sin(t * TAU) * 30.0
			var y := origin.y + sin(t * TAU * 2.0) * 10.0
			main.draw_circle(Vector2(x, y), 2.5, Color("f1d46d", 0.9))
		main.draw_string(main.zh_font, origin + Vector2(-45, 24), "摇摆舞：花源在此方向", HORIZONTAL_ALIGNMENT_CENTER, 90, 11, Color("f1d46d"))
