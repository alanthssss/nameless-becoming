extends SceneTree

const DirectorScript := preload("res://scripts/boss_encounter_director.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func expect_phase_upgrade(director, previous: Dictionary, label: String) -> void:
	var current: Dictionary = director.draw_state()
	expect(int(current.phase) == int(previous.phase) + 1, "%s：调律后 phase 未递增" % label)
	expect(float(current.parameters.speed_multiplier) > float(previous.parameters.speed_multiplier), "%s：调律后速度未升级" % label)
	expect(float(current.parameters.window_seconds) < float(previous.parameters.window_seconds), "%s：调律后暴露窗口未收紧" % label)
	expect(int(current.parameters.feint_count) > int(previous.parameters.feint_count), "%s：调律后假动作数量未升级" % label)
	expect(float(current.parameters.attack_interval) < float(previous.parameters.attack_interval), "%s：调律后攻击间隔未收紧" % label)


func test_mosquito() -> void:
	var director = DirectorScript.new()
	expect(director.reset("mosquito"), "蚊：别名无法重置为 orbital")
	expect(director.pattern == "orbital" and not director.can_tune(), "蚊：开场不应直接可调律")
	expect(not director.notify_landed() and not director.notify_sense(), "蚊：其他 Boss 事件不应打开窗口")
	expect(director.notify_feed_completed() and director.can_tune(), "蚊：完成吸食后未打开短窗口")
	var first_window := float(director.draw_state().window_remaining)
	director.update(first_window + 0.01)
	expect(not director.can_tune() and not director.register_tune(), "蚊：吸食窗口结束后仍能调律")

	expect(director.notify_feed_completed(), "蚊：第二次吸食未重新打开窗口")
	var before: Dictionary = director.draw_state()
	expect(director.register_tune(), "蚊：吸食窗口内调律失败")
	expect_phase_upgrade(director, before, "蚊")


func test_cricket() -> void:
	var director = DirectorScript.new()
	expect(director.reset("erratic"), "油葫芦：无法重置")
	expect(not director.notify_feed_completed() and not director.notify_sense(), "油葫芦：错误事件不应打开窗口")
	expect(not director.can_tune(), "油葫芦：空中不应可调律")
	var state: Dictionary = director.update(0.0, {"landed": true})
	expect(bool(state.can_tune) and state.state == "landing_pause", "油葫芦：真实落地后没有停顿窗口")
	var before: Dictionary = director.draw_state()
	expect(director.register_tune(), "油葫芦：落地停顿内调律失败")
	expect_phase_upgrade(director, before, "油葫芦")


func test_thrush() -> void:
	var director = DirectorScript.new()
	expect(director.reset("thrush"), "画眉：别名无法重置为 lure")
	expect(not director.notify_feed_completed() and not director.notify_landed(), "画眉：错误事件不应揭出真声")
	expect(not director.can_tune(), "画眉：未寻迹时不应可调律")
	expect(director.notify_sense() and director.can_tune(), "画眉：寻迹未揭出真实回声")
	var before: Dictionary = director.draw_state()
	expect(director.register_tune(), "画眉：真声窗口内调律失败")
	expect_phase_upgrade(director, before, "画眉")


func test_bear() -> void:
	var director = DirectorScript.new()
	expect(director.reset("charge"), "熊：无法重置")
	expect(not director.notify_evade_collision(false), "熊：撞到非暖花不应打开眩晕窗口")
	expect(not director.can_tune() and not director.register_tune(), "熊：普通冲锋恢复期不应可调律")
	var state: Dictionary = director.update(0.0, {"evade_collision": true, "warm_bloom": true})
	expect(bool(state.can_tune) and state.state == "warm_stun", "熊：撞入暖花后没有进入眩晕窗口")
	var before: Dictionary = director.draw_state()
	expect(director.register_tune(), "熊：暖花眩晕窗口内调律失败")
	expect_phase_upgrade(director, before, "熊")


func test_three_phase_completion() -> void:
	var event_by_pattern := {
		"orbital": func(director): return director.notify_feed_completed(),
		"erratic": func(director): return director.notify_landed(),
		"lure": func(director): return director.notify_sense(),
		"charge": func(director): return director.notify_evade_collision(true)
	}
	for pattern in event_by_pattern:
		var director = DirectorScript.new()
		director.reset(pattern)
		for expected_phase in range(1, 4):
			var before: Dictionary = director.draw_state()
			expect(bool(event_by_pattern[pattern].call(director)), "%s：phase %d 未打开专属窗口" % [pattern, expected_phase])
			expect(director.register_tune(), "%s：phase %d 调律失败" % [pattern, expected_phase])
			expect_phase_upgrade(director, before, "%s phase %d" % [pattern, expected_phase])
		expect(director.is_complete(), "%s：三次调律后未完成" % pattern)
		expect(not director.can_tune() and not director.register_tune(), "%s：完成后仍接受额外调律" % pattern)


func run_test() -> void:
	test_mosquito()
	test_cricket()
	test_thrush()
	test_bear()
	test_three_phase_completion()

	if failures.is_empty():
		print("BOSS ENCOUNTER DIRECTOR TEST PASSED: 四类暴露条件与逐次 phase 升级有效")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		print("BOSS ENCOUNTER DIRECTOR TEST FAILED: %d 项未通过" % failures.size())
	quit(1 if not failures.is_empty() else 0)
