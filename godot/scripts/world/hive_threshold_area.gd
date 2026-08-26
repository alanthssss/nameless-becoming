class_name HiveThresholdArea
extends Node2D

signal sortie_requested
signal presentation_finished

const COLONY_BEE_PATH := "res://assets/art/launch/player_bee_v1.png"
const RECEIVING_DURATION := 2.35

var returning := false
var deposit_amount := 0
var pollinations := 0
var reserve := 0
var first_return_complete := false
var presentation_time := 0.0
var ready_for_sortie := true
var colony_bee_texture: Texture2D


func configure(context: Dictionary) -> Error:
	returning = bool(context.get("returning", false))
	deposit_amount = maxi(0, int(context.get("deposit_amount", 0)))
	pollinations = maxi(0, int(context.get("pollinations", 0)))
	reserve = maxi(0, int(context.get("reserve", 0)))
	first_return_complete = bool(context.get("first_return_complete", false))
	presentation_time = RECEIVING_DURATION if returning else 0.0
	ready_for_sortie = not returning
	return OK


func _ready() -> void:
	if ResourceLoader.exists(COLONY_BEE_PATH):
		colony_bee_texture = ResourceLoader.load(COLONY_BEE_PATH, "Texture2D") as Texture2D
	queue_redraw()


func _process(delta: float) -> void:
	if presentation_time > 0.0:
		presentation_time = maxf(0.0, presentation_time - delta)
		if presentation_time <= 0.0:
			ready_for_sortie = true
			presentation_finished.emit()
	queue_redraw()


func request_sortie() -> bool:
	if not ready_for_sortie:
		return false
	ready_for_sortie = false
	sortie_requested.emit()
	return true


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("action") and request_sortie() and viewport != null:
		viewport.set_input_as_handled()


func heading() -> String:
	if returning and presentation_time > 0.0:
		return "接住了，往里递"
	if returning:
		return "回来啦"
	return "花田有事，搭把翅膀"


func body_text() -> String:
	if returning and presentation_time > 0.0:
		return "%d 滴花蜜正沿着接货队往里传；你送到的散粉也让 %d 朵花开始结籽。" % [deposit_amount, pollinations]
	if returning:
		return "这一趟做完了。歇一小会儿，想再飞时就从亮着的巢门出去。"
	return "老师傅：先去给两朵花送对散粉，再从远花坡带 6 滴蜜回来。路上那间小蜂房只能歇脚，货要带回这里。"


func action_text() -> String:
	if not ready_for_sortie:
		return "接货中…"
	return "再飞一趟" if first_return_complete else "出巢"


func _draw() -> void:
	# A shallow threshold, not an explorable hive interior. The open right-hand
	# doorway and receiving line make returning home a social hand-off rather than
	# a result screen.
	draw_rect(Rect2(0, 0, 1280, 720), Color("5c5037"))
	for band in 12:
		var ratio := float(band) / 11.0
		draw_rect(
			Rect2(0, float(band) * 60.0, 1280, 61),
			Color("526044").lerp(Color("917142"), ratio * 0.52)
		)
	# Low roof and floor keep the doorway readable without pretending this is a
	# complete room map.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1180, 150), Vector2(90, 150)
	]), Color("43513b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 610), Vector2(1280, 570), Vector2(1280, 720), Vector2(0, 720)
	]), Color("725535"))
	# Storage frames: amber only appears inside a few cells, never as a dripping
	# building shell.
	for rack in 3:
		var rack_origin := Vector2(110.0 + float(rack) * 255.0, 230.0)
		draw_rect(Rect2(rack_origin, Vector2(190, 270)), Color("b8965e", 0.28), true)
		draw_rect(Rect2(rack_origin, Vector2(190, 270)), Color("d9bd83", 0.62), false, 5.0)
		for cell in 8:
			var cell_pos := rack_origin + Vector2(36.0 + float(cell % 2) * 82.0, 42.0 + float(cell / 2) * 58.0)
			var lit := cell + rack * 8 < mini(24, reserve)
			draw_circle(cell_pos, 17.0, Color("382f27", 0.72))
			draw_circle(cell_pos, 11.0, Color("f0c85f", 0.88) if lit else Color("826f4e", 0.42))
	# Doorway to the field. Its warm frame is the landmark; there is no magic ring.
	draw_colored_polygon(PackedVector2Array([
		Vector2(982, 142), Vector2(1278, 86), Vector2(1278, 626), Vector2(982, 560)
	]), Color("d6b36d"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(1020, 176), Vector2(1280, 130), Vector2(1280, 582), Vector2(1020, 528)
	]), Color("a8cf9a"))
	for ray in 7:
		var ray_y := 205.0 + float(ray) * 48.0
		draw_line(Vector2(1028, ray_y), Vector2(1240, ray_y - 30.0), Color("f9e69b", 0.12), 16.0)
	_draw_workers()


func _draw_workers() -> void:
	var progress := 1.0 - clampf(presentation_time / RECEIVING_DURATION, 0.0, 1.0)
	var worker_count := 5
	var worker_positions: Array[Vector2] = []
	for worker_index in worker_count:
		var resting_pos := Vector2(205.0 + float(worker_index) * 150.0, 552.0 - float(worker_index % 2) * 34.0)
		var worker_pos := resting_pos
		if returning and presentation_time > 0.0:
			worker_pos = Vector2(930.0 - float(worker_index) * 155.0, 452.0)
			worker_pos.y += sin(progress * PI * 4.0 + float(worker_index) * 0.9) * 12.0
		worker_positions.append(worker_pos)
		_draw_worker_bee(worker_pos, PI if returning else sin(float(worker_index)) * 0.15, worker_index == 0)
	if returning and presentation_time > 0.0:
		# Honey travels in small wax cups between neighboring receivers. It is never
		# drawn as a droplet attached to a bee's abdomen.
		for cup_index in mini(deposit_amount, worker_count - 1):
			var cup_pos := worker_positions[cup_index].lerp(worker_positions[cup_index + 1], 0.5)
			draw_rect(Rect2(cup_pos + Vector2(-8, -2), Vector2(16, 8)), Color("c49b5b"))
			draw_circle(cup_pos + Vector2(0, -3), 4.0, Color("f4d36f"))


func _draw_worker_bee(position: Vector2, angle: float, mentor: bool) -> void:
	if colony_bee_texture == null:
		draw_circle(position, 10.0, Color("e4bd48"))
		draw_line(position + Vector2(-8, 0), position + Vector2(8, 0), Color("3b3328"), 4.0)
		return
	draw_set_transform(position, angle, Vector2(0.62, 0.62))
	draw_texture_rect(
		colony_bee_texture,
		Rect2(-41, -30, 82, 60),
		false,
		Color("c7d8e8") if mentor else Color.WHITE
	)
	draw_set_transform(Vector2.ZERO)
