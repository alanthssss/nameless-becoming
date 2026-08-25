extends SceneTree

const Rules := preload("res://scripts/mechanics/evade_rules.gd")
const InputController := preload("res://scripts/player/evade_input_controller.gd")
const BeeScript := preload("res://scripts/player/bee_player.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func fresh_bee(at := Vector2(600, 410)) -> BeePlayer:
	var bee: BeePlayer = BeeScript.new()
	root.add_child(bee)
	bee.reset_for_expedition(at)
	return bee

func run_test() -> void:
	expect(is_equal_approx(Rules.DOUBLE_TAP_WINDOW, 0.34), "共享急转登记窗不再是 0.34 秒")
	expect(is_equal_approx(Rules.PATH_CLEARANCE, 36.0), "共享危险通道不再是 36px")
	expect(is_equal_approx(Rules.LOCK_ORIGIN_TOLERANCE, 52.0), "共享锁点起手容差不再是 52px")
	expect(is_equal_approx(Rules.WORLD_TAP_REPEAT_RADIUS, 56.0), "共享指针重复半径不再是 56px")
	expect(BeeScript.WORLD_BOUNDS == Rect2(34, 146, 970, 538), "Main 的 BeePlayer 默认边界被 B01 扩宽污染")
	var bounds_bee: BeePlayer = fresh_bee(Vector2(600.0, 410.0))
	expect(bounds_bee.get_movement_bounds() == BeeScript.WORLD_BOUNDS, "BeePlayer 新实例未默认使用 Main WORLD_BOUNDS")
	var wider_bounds := Rect2(34.0, 146.0, 1178.0, 538.0)
	expect(bounds_bee.set_movement_bounds(wider_bounds) == OK, "BeePlayer 拒绝合法实例 movement bounds")
	bounds_bee.position = Vector2(1300.0, 410.0)
	bounds_bee._physics_process(0.001)
	expect(is_equal_approx(bounds_bee.position.x, wider_bounds.end.x - 18.0), "BeePlayer 实例边界没有允许 B01 到达右侧")
	expect(bounds_bee.set_movement_bounds(Rect2(0.0, 0.0, 12.0, 12.0)) == ERR_INVALID_PARAMETER, "BeePlayer 接受了小于角色直径的不安全边界")
	expect(bounds_bee.get_movement_bounds() == wider_bounds, "非法 setter 调用改写了已验证 movement bounds")
	bounds_bee.free()
	var untouched_bee: BeePlayer = fresh_bee(Vector2(1300.0, 410.0))
	untouched_bee._physics_process(0.001)
	expect(is_equal_approx(untouched_bee.position.x, BeeScript.WORLD_BOUNDS.end.x - 18.0), "自定义 B01 边界泄漏到后续 Main 默认实例")
	untouched_bee.free()

	var bee: BeePlayer = fresh_bee()
	var input = InputController.new()
	var sequence_before: int = bee.evade_sequence
	var first: Dictionary = input.register_direction_tap("up", Vector2.UP, 10.0, bee)
	expect(not bool(first.evade_attempted) and not bool(first.evade_started), "方向首击错误发动急转")
	expect(bee.evade_tap_time > 0.0 and is_equal_approx(float(input.direction_tap_times.up), 10.0), "方向首击没有共享缓存或身体反馈")
	var second: Dictionary = input.register_direction_tap("up", Vector2.UP, 10.34, bee)
	expect(bool(second.evade_attempted) and bool(second.evade_started), "0.34 秒边界的同向第二击没有发动急转")
	expect(bee.evade_sequence == sequence_before + 1 and bee.last_evade_direction.dot(Vector2.UP) > 0.99, "共享控制器没有沿登记方向发动一次急转")

	bee.evade_cooldown = 0.0
	bee.evade_time = 0.0
	bee.energy = 100.0
	input.clear(bee)
	sequence_before = bee.evade_sequence
	input.register_direction_tap("left", Vector2.LEFT, 20.0, bee)
	var late: Dictionary = input.register_direction_tap("left", Vector2.LEFT, 20.341, bee)
	expect(not bool(late.evade_attempted) and bee.evade_sequence == sequence_before, "超出 0.34 秒的第二击仍发动急转")
	expect(is_equal_approx(float(input.direction_tap_times.left), 20.341), "超窗方向输入没有成为新的首击")

	bee.evade_cooldown = 1.0
	bee.energy = 100.0
	input.clear(bee)
	input.register_direction_tap("right", Vector2.RIGHT, 30.0, bee)
	var cooldown_attempt: Dictionary = input.register_direction_tap("right", Vector2.RIGHT, 30.2, bee)
	expect(bool(cooldown_attempt.evade_attempted) and not bool(cooldown_attempt.evade_started), "冷却中的完整尝试没有作为失败尝试返回")
	expect(float(input.direction_tap_times.right) == 0.0 and bee.evade_tap_time == 0.0, "冷却失败留下了隐藏第三击捷径")
	var post_failure: Dictionary = input.register_direction_tap("right", Vector2.RIGHT, 30.25, bee)
	expect(not bool(post_failure.evade_attempted) and is_equal_approx(float(input.direction_tap_times.right), 30.25), "失败后的下一击没有重新从首击开始")

	bee.evade_cooldown = 0.0
	bee.evade_time = 0.0
	bee.energy = 100.0
	input.clear(bee)
	input.direction_tap_times.right = 40.0
	input.direction_tap_times.up = 40.0
	input.direction_tap_origins.right = bee.position
	input.direction_tap_origins.up = bee.position
	var chord: Dictionary = input.process_pressed_directions(["right", "up"], 40.2, bee, Vector2.RIGHT)
	expect(bool(chord.evade_started) and bee.last_evade_direction.dot(Vector2.UP) > 0.99, "斜向同帧输入没有选择远离攻击线的轴")
	expect(input.direction_tap_times.values().all(func(value): return float(value) == 0.0), "斜向急转后仍遗留另一个方向缓存")

	bee.free()
	bee = fresh_bee()
	input = InputController.new()
	var pointer_origin: Vector2 = bee.position
	var repeated_point: Vector2 = bee.position + Vector2.UP * 42.0
	var pointer_first: Dictionary = input.handle_world_tap(repeated_point, 50.0, bee, BeeScript.WORLD_BOUNDS)
	expect(bool(pointer_first.consumed) and not bool(pointer_first.evade_attempted) and bee.has_target, "指针首击没有登记普通移动")
	bee._physics_process(0.2)
	var pointer_second: Dictionary = input.handle_world_tap(repeated_point, 50.2, bee, BeeScript.WORLD_BOUNDS)
	expect(bool(pointer_second.evade_started) and bee.last_evade_direction.dot(Vector2.UP) > 0.99, "移动后的同点第二击没有沿第一击方向急转")
	expect(bee.last_evade_origin.distance_to(pointer_origin) < 0.01, "指针急转没有保留第一击因果起点")
	expect(input.world_tap_time == 0.0, "完整指针急转后仍残留首击缓存")

	input.clear(bee)
	bee.has_target = false
	var outside: Dictionary = input.handle_world_tap(Vector2(5, 5), 60.0, bee, BeeScript.WORLD_BOUNDS)
	expect(not bool(outside.consumed) and not bee.has_target, "世界外指针输入被共享控制器消费")
	var move_only: Dictionary = input.handle_world_tap(Vector2(500, 410), 60.1, bee, BeeScript.WORLD_BOUNDS, false)
	expect(bool(move_only.consumed) and bee.has_target and input.world_tap_time == 0.0, "禁用急转时没有保留普通移动，或错误缓存急转首击")

	bee.free()
	bee = fresh_bee()
	var locked_target: Vector2 = bee.position
	var sequence_at_lock: int = bee.evade_sequence
	expect(not Rules.cleared_locked_path(bee, Vector2.RIGHT, locked_target, sequence_at_lock), "锁定后没有新急转也被算作离线")
	expect(bee.try_evade(Vector2.RIGHT, locked_target), "因果对照无法发动沿线急转")
	bee.position = locked_target + Vector2.RIGHT * 60.0
	expect(not Rules.cleared_locked_path(bee, Vector2.RIGHT, locked_target, sequence_at_lock), "沿攻击路线的急转被算作侧向离线")

	bee.evade_cooldown = 0.0
	bee.evade_time = 0.0
	bee.energy = 100.0
	bee.position = locked_target + Vector2.RIGHT * 80.0
	expect(bee.try_evade(Vector2.UP, bee.position), "远处因果对照无法发动急转")
	bee.position += Vector2.UP * 60.0
	expect(not Rules.cleared_locked_path(bee, Vector2.RIGHT, locked_target, sequence_at_lock), "远离锁点后的无关急转被算作成功")

	bee.evade_cooldown = 0.0
	bee.evade_time = 0.0
	bee.energy = 100.0
	bee.position = locked_target
	sequence_at_lock = bee.evade_sequence
	expect(bee.try_evade(Vector2.UP, locked_target), "合法侧向因果对照无法发动急转")
	bee.position = locked_target + Vector2.UP * 35.0
	expect(not Rules.cleared_locked_path(bee, Vector2.RIGHT, locked_target, sequence_at_lock), "35px 仍在危险通道内却被算作成功")
	bee.position = locked_target + Vector2.UP * 36.0
	expect(Rules.cleared_locked_path(bee, Vector2.RIGHT, locked_target, sequence_at_lock), "36px 可见边界没有被算作离线")

	expect(Rules.attack_crossed_locked_target(Vector2(500, 410), Vector2(700, 410), locked_target, 29.0), "攻击线段穿过锁点却未被确认")
	expect(not Rules.attack_crossed_locked_target(Vector2(500, 350), Vector2(700, 350), locked_target, 29.0), "远离锁点的攻击线段被误判为穿过")

	var center_bounds := BeeScript.WORLD_BOUNDS.grow(-18.0)
	var escapes: Array[Vector2] = Rules.cardinal_escape_directions(locked_target, Vector2.RIGHT, center_bounds)
	expect(escapes.size() == 2 and escapes.has(Vector2.UP) and escapes.has(Vector2.DOWN), "水平攻击没有给出两个可达的垂直侧标")
	for escape in escapes:
		expect(absf(escape.dot(Vector2.RIGHT)) <= Rules.SIDE_ALIGNMENT_LIMIT, "共享侧标邀请了因果规则会拒绝的方向")
	var geometry: Dictionary = Rules.committed_corridor_geometry(Vector2(400, 410), Vector2.RIGHT, BeeScript.WORLD_BOUNDS, Rules.PATH_CLEARANCE)
	expect(bool(geometry.valid), "合法攻击没有生成共享通道几何")
	expect(Vector2(geometry.start).distance_to(Vector2(376, 410)) < 0.01, "共享通道起点不再包含 24px 后沿")
	expect(is_equal_approx(float(Vector2(geometry.finish).x), BeeScript.WORLD_BOUNDS.end.x), "共享通道没有延伸到世界边界")
	expect(PackedVector2Array(geometry.polygon).size() == 4, "共享通道没有生成四点多边形")

	bee.free()
	if failures.is_empty():
		print("EVADE RUNTIME TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
