class_name BossEncounterDirector
extends RefCounted
## 四位失律者的独立遭遇状态机。
##
## 这个对象不持有场景节点，只把 Boss 的「何时可调律」和逐阶段升级规则
## 收束为一个可测试的 API。main.gd 负责移动、碰撞与绘制；命中特定情境后
## 通知本对象，再以 can_tune() / register_tune() 决定调律是否成立。

const PATTERN_ALIASES := {
	"mosquito": "orbital",
	"cricket": "erratic",
	"thrush": "lure",
	"bear": "charge"
}

const INITIAL_STATES := {
	"orbital": "feeding",
	"erratic": "airborne",
	"lure": "singing",
	"charge": "charging"
}

const VULNERABLE_STATES := {
	"orbital": "sated",
	"erratic": "landing_pause",
	"lure": "truth_revealed",
	"charge": "warm_stun"
}

# phase 0 是开场；每次成功调律后 phase +1，并立即换用下一组参数。
# 第三次调律结束战斗，但仍保留 phase 3 的终局参数供演出与遥测读取。
const PHASE_PROFILES := {
	"orbital": [
		{"speed_multiplier": 1.00, "window_seconds": 1.30, "feint_count": 0, "attack_interval": 2.40},
		{"speed_multiplier": 1.12, "window_seconds": 1.10, "feint_count": 1, "attack_interval": 2.10},
		{"speed_multiplier": 1.26, "window_seconds": 0.90, "feint_count": 2, "attack_interval": 1.80},
		{"speed_multiplier": 1.40, "window_seconds": 0.72, "feint_count": 3, "attack_interval": 1.55}
	],
	"erratic": [
		{"speed_multiplier": 1.00, "window_seconds": 1.15, "feint_count": 1, "attack_interval": 2.20},
		{"speed_multiplier": 1.10, "window_seconds": 0.95, "feint_count": 2, "attack_interval": 1.95},
		{"speed_multiplier": 1.22, "window_seconds": 0.78, "feint_count": 3, "attack_interval": 1.70},
		{"speed_multiplier": 1.34, "window_seconds": 0.62, "feint_count": 4, "attack_interval": 1.48}
	],
	"lure": [
		{"speed_multiplier": 1.00, "window_seconds": 1.80, "feint_count": 2, "attack_interval": 3.00},
		{"speed_multiplier": 1.07, "window_seconds": 1.50, "feint_count": 3, "attack_interval": 2.65},
		{"speed_multiplier": 1.15, "window_seconds": 1.22, "feint_count": 4, "attack_interval": 2.30},
		{"speed_multiplier": 1.24, "window_seconds": 0.98, "feint_count": 5, "attack_interval": 2.00}
	],
	"charge": [
		{"speed_multiplier": 1.00, "window_seconds": 1.40, "feint_count": 0, "attack_interval": 3.20},
		{"speed_multiplier": 1.11, "window_seconds": 1.16, "feint_count": 1, "attack_interval": 2.85},
		{"speed_multiplier": 1.24, "window_seconds": 0.94, "feint_count": 2, "attack_interval": 2.50},
		{"speed_multiplier": 1.38, "window_seconds": 0.75, "feint_count": 3, "attack_interval": 2.18}
	]
}

var pattern := ""
var phase := 0
var tunings := 0
var required_tunings := 3
var state := "invalid"
var last_event := ""
var parameters: Dictionary = {}

var _window_remaining := 0.0
var _window_reason := ""
var _completed := false


func reset(pattern_id: String, tuning_target := 3) -> bool:
	var normalized := String(PATTERN_ALIASES.get(pattern_id, pattern_id))
	if not PHASE_PROFILES.has(normalized):
		pattern = ""
		phase = 0
		tunings = 0
		required_tunings = maxi(1, tuning_target)
		state = "invalid"
		last_event = "invalid_pattern"
		parameters = {}
		_window_remaining = 0.0
		_window_reason = ""
		_completed = false
		return false

	pattern = normalized
	phase = 0
	tunings = 0
	required_tunings = maxi(1, tuning_target)
	state = String(INITIAL_STATES[pattern])
	last_event = "reset"
	_window_remaining = 0.0
	_window_reason = ""
	_completed = false
	_apply_phase_parameters()
	return true


# observations 是可选的一帧事件包，便于 main.gd 在一次调用中完成集成：
# feed_completed / landed / sense / evade_collision / warm_bloom。
func update(delta: float, observations: Dictionary = {}) -> Dictionary:
	if not _completed and _window_remaining > 0.0:
		_window_remaining = maxf(0.0, _window_remaining - maxf(delta, 0.0))
		if _window_remaining <= 0.0:
			_close_window("window_expired")

	if bool(observations.get("feed_completed", false)):
		notify_feed_completed()
	if bool(observations.get("landed", false)):
		notify_landed()
	if bool(observations.get("sense", false)):
		notify_sense()
	if bool(observations.get("evade_collision", false)):
		notify_evade_collision(bool(observations.get("warm_bloom", false)))

	return draw_state()


# 蚊：完成一次吸食后腹部膨胀，短暂失去节律。
func notify_feed_completed() -> bool:
	if pattern != "orbital":
		return false
	return _open_window("sated", "feed_completed")


# 油葫芦：只有真实落地后的停顿可调律，残影或仍在空中均无效。
func notify_landed() -> bool:
	if pattern != "erratic":
		return false
	return _open_window("landing_pause", "landed")


# 画眉：寻迹揭出真实回声，真声存在期间才可调律。
func notify_sense() -> bool:
	if pattern != "lure":
		return false
	return _open_window("truth_revealed", "sense_revealed_truth")


# 熊：玩家避开冲锋并不等于暴露；熊还必须撞入暖息花。
func notify_evade_collision(collided_with_warm_bloom := false) -> bool:
	if pattern != "charge" or _completed:
		return false
	if not collided_with_warm_bloom:
		state = "charge_recovery"
		last_event = "cold_collision"
		return false
	return _open_window("warm_stun", "warm_bloom_collision")


func can_tune() -> bool:
	if _completed or pattern == "" or _window_remaining <= 0.0:
		return false
	return state == String(VULNERABLE_STATES[pattern]) and _window_reason != ""


func register_tune() -> bool:
	if not can_tune():
		return false

	tunings += 1
	phase += 1
	_apply_phase_parameters()
	_window_remaining = 0.0
	_window_reason = ""
	last_event = "tune_registered"

	if tunings >= required_tunings:
		_completed = true
		state = "complete"
	else:
		state = String(INITIAL_STATES[pattern])
	return true


func is_complete() -> bool:
	return _completed


# 绘制层只读取快照，不需要知道状态机内部字段。
func draw_state() -> Dictionary:
	return {
		"pattern": pattern,
		"phase": phase,
		"tunings": tunings,
		"required_tunings": required_tunings,
		"state": state,
		"last_event": last_event,
		"window_reason": _window_reason,
		"window_remaining": _window_remaining,
		"can_tune": can_tune(),
		"complete": _completed,
		"parameters": parameters.duplicate(true)
	}


func _open_window(next_state: String, reason: String) -> bool:
	if _completed or pattern == "" or _window_remaining > 0.0:
		return false
	state = next_state
	_window_reason = reason
	_window_remaining = float(parameters.get("window_seconds", 0.0))
	last_event = reason
	return _window_remaining > 0.0


func _close_window(reason: String) -> void:
	_window_remaining = 0.0
	_window_reason = ""
	last_event = reason
	if pattern != "" and not _completed:
		state = String(INITIAL_STATES[pattern])


func _apply_phase_parameters() -> void:
	if pattern == "" or not PHASE_PROFILES.has(pattern):
		parameters = {}
		return
	var profiles: Array = PHASE_PROFILES[pattern]
	var profile_index := mini(phase, profiles.size() - 1)
	parameters = Dictionary(profiles[profile_index]).duplicate(true)
