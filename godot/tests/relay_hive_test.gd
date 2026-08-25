extends SceneTree

const RelayHiveMechanicScript := preload("res://scripts/mechanics/relay_hive_mechanic.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run_test() -> void:
	var relay = RelayHiveMechanicScript.new()
	relay.configure({
		"position": [640, 548],
		"activation_cost": 1,
		"energy_restore_per_second": 12,
		"energy_cap_ratio": 0.65,
		"warmth_restore_per_second": 8,
		"warmth_cap": 70
	})
	expect(relay.enabled and relay.status_id() == "dormant", "蜂驿没有以未点亮状态进入关卡")
	expect(relay.is_inside(Vector2(640, 548)), "蜂驿可见中心不在真实停靠区内")
	expect(not relay.is_inside(Vector2(510, 548)), "蜂驿停靠区扩成了隐藏空气墙")
	expect(relay.context_action_id(Vector2(640, 548), 0) == "relay_hive_needs_honey", "空蜜囊靠近蜂驿时没有解释燃料需求")
	var insufficient := relay.try_activate(Vector2(640, 548), 0)
	expect(String(insufficient.event) == "needs_honey" and int(insufficient.consumed) == 0, "空蜜囊错误点亮蜂驿")
	var activated := relay.try_activate(Vector2(640, 548), 1)
	expect(String(activated.event) == "activated" and int(activated.consumed) == 1, "显式动作没有用一滴蜜点亮蜂驿")
	expect(relay.active and relay.context_action_id(Vector2(640, 548), 3).is_empty(), "已点亮蜂驿仍重复索取激活蜜")
	var moving := relay.process(1.0, Vector2(640, 548), false, 20.0, 100.0)
	expect(not bool(moving.resting) and float(moving.energy) == 20.0, "经过蜂驿但未停稳仍自动恢复")
	var resting := relay.process(1.0, Vector2(640, 548), true, 20.0, 100.0)
	expect(bool(resting.resting) and float(resting.energy) == 32.0, "蜂驿没有按每秒 12 点恢复体力")
	var capped := relay.process(10.0, Vector2(640, 548), true, 32.0, 100.0)
	expect(float(capped.energy) == 65.0, "蜂驿恢复越过 65% 上限，开始取代主巢")
	var healthy := relay.process(1.0, Vector2(640, 548), true, 88.0, 100.0)
	expect(float(healthy.energy) == 88.0, "高于蜂驿恢复上限的体力反而被停靠区扣低")
	var winter := relay.process(1.0, Vector2(640, 548), true, 65.0, 100.0, 50.0, true)
	expect(float(winter.warmth) == 58.0, "冬季蜂驿没有按每秒 8 点恢复体温")
	var winter_capped := relay.process(10.0, Vector2(640, 548), true, 65.0, 100.0, 58.0, true)
	expect(float(winter_capped.warmth) == 70.0, "蜂驿体温恢复越过 70，上限开始替代主巢")
	var winter_warm := relay.process(1.0, Vector2(640, 548), true, 65.0, 100.0, 84.0, true)
	expect(float(winter_warm.warmth) == 84.0, "高于蜂驿保温上限的体温反而被停靠区扣低")
	expect(relay.try_activate(Vector2(400, 400), 5).event == "", "远离蜂驿仍可隔空激活")

	if failures.is_empty():
		print("RELAY HIVE TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
