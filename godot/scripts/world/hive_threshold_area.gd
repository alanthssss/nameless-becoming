class_name HiveThresholdArea
extends Node2D

signal sortie_requested
signal presentation_finished

const COLONY_BEE_PATH := "res://assets/art/commercial/worker_bee_topdown_v1.png"
const MENTOR_BEE_PATH := "res://assets/art/commercial/mentor_bee_topdown_v1.png"
const HIVE_INTERIOR_PATH := "res://assets/art/commercial/hive_threshold_interior_v1.png"
const RECEIVING_DURATION := 2.35

var returning := false
var return_kind := ""
var deposit_amount := 0
var pollinations := 0
var reserve := 0
var first_return_complete := false
var title_reveal := false
var chapter_complete := false
var journey_complete := false
var next_segment := ""
var world_results: Dictionary = {}
var signs_resolved := 0
var honey_lost := 0
var presentation_time := 0.0
var ready_for_sortie := true
var departure_input_enabled := true
var colony_bee_texture: Texture2D
var mentor_bee_texture: Texture2D
var hive_interior_texture: Texture2D


func configure(context: Dictionary) -> Error:
	returning = bool(context.get("returning", false))
	return_kind = String(context.get("return_kind", ""))
	deposit_amount = maxi(0, int(context.get("deposit_amount", 0)))
	pollinations = maxi(0, int(context.get("pollinations", 0)))
	reserve = maxi(0, int(context.get("reserve", 0)))
	first_return_complete = bool(context.get("first_return_complete", false))
	title_reveal = bool(context.get("title_reveal", false))
	chapter_complete = bool(context.get("chapter_complete", false))
	journey_complete = bool(context.get("journey_complete", false))
	next_segment = String(context.get("next_segment", ""))
	world_results = Dictionary(context.get("world_results", {})).duplicate(true)
	signs_resolved = maxi(0, int(context.get("signs_resolved", 0)))
	honey_lost = maxi(0, int(context.get("honey_lost", 0)))
	presentation_time = RECEIVING_DURATION if returning else 0.0
	ready_for_sortie = not returning and not journey_complete
	return OK


func _ready() -> void:
	if ResourceLoader.exists(COLONY_BEE_PATH):
		colony_bee_texture = ResourceLoader.load(COLONY_BEE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(MENTOR_BEE_PATH):
		mentor_bee_texture = ResourceLoader.load(MENTOR_BEE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(HIVE_INTERIOR_PATH):
		hive_interior_texture = ResourceLoader.load(HIVE_INTERIOR_PATH, "Texture2D") as Texture2D
	queue_redraw()


func _process(delta: float) -> void:
	if presentation_time > 0.0:
		presentation_time = maxf(0.0, presentation_time - delta)
		if presentation_time <= 0.0:
			ready_for_sortie = not journey_complete
			presentation_finished.emit()
	queue_redraw()


func request_sortie() -> bool:
	if not departure_input_enabled or not ready_for_sortie or journey_complete:
		return false
	ready_for_sortie = false
	sortie_requested.emit()
	return true


func set_departure_input_enabled(enabled: bool) -> void:
	departure_input_enabled = enabled


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("action") and request_sortie() and viewport != null:
		viewport.set_input_as_handled()


func heading() -> String:
	if returning and presentation_time > 0.0:
		match return_kind:
			JourneyState.SIGN_INCIDENT:
				return "一起回来啦"
			JourneyState.SUMMER_RECOVERY:
				return "远路上的货，接住啦"
			JourneyState.AUTUMN_HARVEST:
				return "秋花怎么收，都记下啦"
			JourneyState.WINTER_WARMTH:
				return "挡风墙立住啦"
			JourneyState.FINALE_HANDOFF:
				return "这回，是你带它回来"
			_:
				return "接住了，往里递"
	if returning:
		match return_kind:
			JourneyState.SIGN_INCIDENT:
				return "春天这件事，收好啦"
			JourneyState.SUMMER_RECOVERY:
				return "夏天这件事，接回来啦"
			JourneyState.AUTUMN_HARVEST:
				return "秋天这件事，收好啦"
			JourneyState.WINTER_WARMTH:
				return "冬天这件事，挡稳啦"
			JourneyState.FINALE_HANDOFF:
				return "一会儿巢里见"
			_:
				return "第一次，稳稳回来啦"
	if journey_complete:
		return "一会儿巢里见"
	if next_segment == JourneyState.SUMMER_RECOVERY:
		return "夏日远路，有东西被吹散了"
	if next_segment == JourneyState.AUTUMN_HARVEST:
		return "秋花等着逐朵收尾"
	if next_segment == JourneyState.WINTER_WARMTH:
		return "暖路要一段段接起来"
	if next_segment == JourneyState.FINALE_HANDOFF:
		return "巢门口来了一只新蜂"
	return "花田有事，搭把翅膀"


func body_text() -> String:
	if returning and presentation_time > 0.0:
		match return_kind:
			JourneyState.SIGN_INCIDENT:
				return (
					"三处花标都回到原处，最后一块还搭了蚊庄主一程。你带回 %d 滴，路上实实在在掉了 %d 滴；接货蜂照单全收。"
					% [deposit_amount, honey_lost]
				)
			JourneyState.SUMMER_RECOVERY:
				return "%d 份真花蜜沿接货队往里传；油葫芦把三件家当重新卷好，小蜂房也能歇脚了。" % deposit_amount
			JourneyState.AUTUMN_HARVEST:
				return "%d 份秋蜜入库，%d 朵种头留在花田。画眉在门外抖抖尾羽，又听了一遍。" % [
					int(world_results.get("autumn_harvested", 0)),
					int(world_results.get("autumn_seeded", 0)),
				]
			JourneyState.WINTER_WARMTH:
				return "四段暖路都接上了。大熊和修补蜂搬成的三段挡风墙，正在替晚班蜂挡风。"
			JourneyState.FINALE_HANDOFF:
				return "新蜂照着你的动作飞了一遍。老师傅留在旁边，和大家一起看它找到巢门。"
			_:
				return "%d 滴花蜜正沿着接货队往里传；你送到的散粉也让 %d 朵花开始结籽。" % [deposit_amount, pollinations]
	if returning:
		match return_kind:
			JourneyState.SIGN_INCIDENT:
				return "老师傅把落脚板往你这边推了推。蚊庄主在门外把背上的花标放正，大家各忙各的。"
			JourneyState.SUMMER_RECOVERY:
				return "接货队把带回的蜜往储蜜架传。远坡的小蜂房还留着修好的横梁。"
			JourneyState.AUTUMN_HARVEST:
				return "花田保留了你逐朵做出的组合：有短花梗，也有来年的种头。"
			JourneyState.WINTER_WARMTH:
				return "挡风墙、暖路和大熊推木留下的印子都还在，雪边也认得出前几季的活。"
			JourneyState.FINALE_HANDOFF:
				return "你说完“一会儿巢里见”，新蜂就朝着刚才认准的花路飞去。"
			_:
				return "这一趟做完了。歇一小会儿，想再飞时就从亮着的巢门出去。"
	if journey_complete:
		return "四季留下的花标、小蜂房、种头和挡风墙都还在。巢里照常接货、换班、修补，也照常等下一只新蜂回来。"
	if next_segment == JourneyState.SUMMER_RECOVERY:
		return "春天的三块花标仍在原处。油葫芦说远花路散了 8 份真花蜜和三件家当，回防长路也需要重新走一遍。"
	if next_segment == JourneyState.AUTUMN_HARVEST:
		return "修好的小蜂房还在远坡。秋花逐朵可收蜜或留种，三只听声种壳也等着为画眉转正。"
	if next_segment == JourneyState.WINTER_WARMTH:
		return "秋花的短梗和种头都留在原位。四处续暖点、三段挡风木和一只犯困的大熊在冬路上等着。"
	if next_segment == JourneyState.FINALE_HANDOFF:
		return "老师傅看了看门口那只头顶花片的新蜂，又把落脚板往你这边让了一点。"
	if first_return_complete:
		return "蚊庄主的三处花标被风带进花路了。接货蜂从刚入库的蜜里拨出 6 滴周转蜜；就算一路颠空，三块花标也还等着你和老师傅。"
	return "老师傅：先看一次，再给两朵花送对散粉，从远花坡带 6 滴蜜回来。小蜂房只能歇脚，货要带回这里。"


func action_text() -> String:
	if journey_complete:
		return "四季旅程完成"
	if not ready_for_sortie:
		return "接货中…"
	match next_segment:
		JourneyState.SIGN_INCIDENT:
			return "去理花标"
		JourneyState.SUMMER_RECOVERY:
			return "去夏日远花路"
		JourneyState.AUTUMN_HARVEST:
			return "去收秋花"
		JourneyState.WINTER_WARMTH:
			return "去续暖路"
		JourneyState.FINALE_HANDOFF:
			return "把方法交下去"
		_:
			return "第一次出巢"


func _draw() -> void:
	if hive_interior_texture != null:
		draw_texture_rect(hive_interior_texture, Rect2(0, 0, 1280, 720), false)
		_draw_workers()
		return
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
	var texture := mentor_bee_texture if mentor else colony_bee_texture
	if texture == null:
		draw_circle(position, 10.0, Color("e4bd48"))
		draw_line(position + Vector2(-8, 0), position + Vector2(8, 0), Color("3b3328"), 4.0)
		return
	draw_set_transform(position, angle, Vector2(0.62, 0.62))
	draw_texture_rect(
		texture,
		Rect2(-50, -42, 100, 84),
		false
	)
	draw_set_transform(Vector2.ZERO)
