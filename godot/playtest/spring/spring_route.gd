extends "res://playtest/rain_route/rain_route.gd"

const SpringModel := preload("res://playtest/spring/spring_model.gd")
const TERM_NAMES := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨"]
const SAVE := "user://spring_route_v1.json"
var term_index := 0
var prior_terms: Array = []
var world: Dictionary = {}
var spring_save_enabled := true
var spring_save_path := SAVE
var seed_world: Dictionary = {}

func landscape_script() -> Script:
	return preload("res://playtest/spring/spring_landscape.gd")

func make_model(index: int):
	if index == 1:
		return Model.new()
	var next = SpringModel.new()
	next.configure(index, world)
	return next

func _ready() -> void:
	save_enabled = false
	model = make_model(term_index)
	if spring_save_enabled and FileAccess.file_exists(spring_save_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(spring_save_path))
		if not parsed is Dictionary or not restore_spring(parsed):
			spring_save_enabled = false
			push_warning("春季存档未能载入，旧文件保留，本次不覆盖。")
	super._ready()
	DisplayServer.window_set_title("一会儿巢里见 · 春天 · " + TERM_NAMES[term_index])

func restore_spring(data: Dictionary) -> bool:
	if data.get("schema") != 1 or not model._whole(data.get("term"), 0, 5) or not data.get("prior_terms") is Array or not SpringModel.valid_world(data.get("world")) or not data.get("chapter") is Dictionary or not SpringModel.valid_world(data.get("seed_world", data.get("world"))):
		return false
	var index := int(data.term)
	if data.prior_terms.size() != index:
		return false
	for i in range(index):
		if data.prior_terms[i] != i:
			return false
	if index != 1 and data.chapter.get("term") != index:
		return false
	var candidate = make_model(index)
	if not candidate.restore(data.chapter):
		return false
	term_index = index
	prior_terms = data.prior_terms.duplicate()
	world = data.world.duplicate(true)
	seed_world = data.get("seed_world", world).duplicate(true) if data.get("seed_world", world) is Dictionary else world.duplicate(true)
	model = candidate
	return true

func spring_snapshot() -> Dictionary:
	var checkpoint: Dictionary = model.snapshot() if model.day_finished else model.dawn_state
	if model.day_finished and not model.complete:
		checkpoint = checkpoint.duplicate(true)
		checkpoint.day = model.day + 1
	return {"schema": 1, "term": term_index, "prior_terms": prior_terms.duplicate(), "world": world.duplicate(true), "seed_world": seed_world.duplicate(true), "chapter": checkpoint}

func _save_dawn() -> void:
	if not spring_save_enabled:
		return
	var temporary := spring_save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("春季进度未能保存，旧文件保留。")
		return
	file.store_string(JSON.stringify(spring_snapshot()))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if ok:
		if DirAccess.rename_absolute(temporary, spring_save_path) != OK:
			push_warning("春季进度未能替换，旧文件保留。")

func _next_term() -> void:
	if paused or not model.complete or term_index >= 5:
		return
	if term_index == 1:
		world["built_site"] = model.built_site
		world["beetle_home"] = model.beetle_home
		world["cleared_gutter"] = model.cleared.size() == 3
		for id in model.pollinated:
			var p: Vector2 = Model.Calendar.DAYS[3].points[int(id)]
			world["pollinate:%d:%d" % [p.x, p.y]] = {"kind": "pollinate", "x": p.x, "y": p.y, "shape": 0, "born_day": 19}
	else:
		world = model.world.duplicate(true)
	prior_terms.append(term_index)
	term_index += 1
	seed_world = world.duplicate(true)
	model = make_model(term_index)
	_save_dawn()
	_reset_feedback()
	# The immutable ground cache belongs to the current chapter's palette.
	landscape.route = null
	landscape.queue_free()
	landscape = Node2D.new()
	landscape.set_script(landscape_script())
	landscape.route = self
	landscape.show_behind_parent = true
	add_child(landscape)
	_update_camera(1)
	DisplayServer.window_set_title("一会儿巢里见 · 春天 · " + TERM_NAMES[term_index])

func _restart() -> void:
	if paused:
		return
	if model.complete:
		_next_term()
		return
	var replacement = make_model(term_index)
	if replacement.restore(model.dawn_state.duplicate(true)):
		model = replacement
	_save_dawn()
	_reset_feedback()

func _act() -> void:
	if term_index == 1:
		super._act()
		return
	if paused or model.day_finished:
		return
	var response: String = model.act()
	if model.social.dance_age >= 0:
		pointer_active = false
	if response != "":
		sound.volume_db = -12
		sound.stream = DELIVER_SOUND if response in ["help", "deliver", "day_end"] else LOAD_SOUND
		sound.play()
		if response == "day_end":
			world = model.world.duplicate(true)
			_save_dawn()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	for control in result_controls.get_children():
		if control is Button:
			control.text = "下一节气 · " + TERM_NAMES[mini(5, term_index + 1)] if term_index < 5 else "春天的路走完了"
			control.disabled = term_index == 5

func _context_message() -> String:
	return super._context_message() if term_index == 1 else model.hint()

func title_today() -> String:
	if term_index == 1:
		return str({8: "带粉途中歇歇脚", 13: "带大家采粉回家", 14: "到叶台接伙伴", 15: "一起带粉回家"}.get(model.day, model.event_today().title))
	return str(model.today().title)

func _draw_hud() -> void:
	_panel(Rect2(28, 24, 374, 115), Color("f7efd7", 0.97), 20, Color("fff6dd", 0.65))
	_text(Vector2(50, 59), TERM_NAMES[term_index], 27, INK)
	_text(Vector2(119, 57), "第 %d 天 · %s" % [model.day, ["一候", "二候", "三候"][model.stage]], 19, Color("566a48"))
	_text(Vector2(50, 91), title_today(), 17, INK)
	for i in range(15):
		var p := Vector2(54 + i * 22, 116)
		draw_circle(p, 4, Color("729052") if i < model.completed_days.size() else Color("d8d8b9"))
		if i == model.day - 1:
			draw_arc(p, 7, 0, TAU, 18, INK, 1.4, true)
	_panel(Rect2(687, 25, 351, 76), Color("264b39", 0.96), 18, Color("a4b889", 0.5))
	_text(Vector2(709, 53), "春天", 14, Color("c0d0ab"))
	_text(Vector2(709, 81), "%d / 90 天" % (term_index * 15 + model.completed_days.size()), 21)
	var name := "花粉" if term_index == 1 or model.food_kind != "nectar" else "花蜜"
	_text(Vector2(837, 53), "身上" + name, 14, Color("c0d0ab"))
	_text(Vector2(851, 81), "%d / 3" % model.cargo, 21)
	if not model.companions.is_empty():
		_text(Vector2(950, 53), "伙伴", 14, Color("c0d0ab"))
		_text(Vector2(954, 81), "%d / 5" % (5 - model.waiting_companion_points().size()), 21)
	if not model.day_finished:
		_panel(Rect2(28, 624, 777, 62), Color("f7efd7", 0.97), 16, Color("fff6dd", 0.6))

func _draw() -> void:
	_draw_hud()
	_panel(Rect2(29, 490, 212, 112), CREAM, 13, INK)
	_text(Vector2(44, 513), TERM_NAMES[term_index] + " · 花路", 15, INK)
	var origin := Vector2(40, 514)
	for i in range(Model.SAFE_ROUTE.size() - 1):
		draw_line(origin + Model.SAFE_ROUTE[i] * 0.053, origin + Model.SAFE_ROUTE[i + 1] * 0.053, Color("9ba885"), 2)
	for p: Vector2 in [Model.HIVE, Model.BUILD_SITE, Model.FLOWERS]:
		draw_circle(origin + p * 0.053, 3, INK)
	for p: Vector2 in model.objective_points():
		draw_circle(origin + p * 0.053, 4, GOLD)
	draw_circle(origin + model.position * 0.053, 4, INK)
	draw_rect(Rect2(origin + camera_origin * 0.053, Vector2(1280, 720) * 0.053), Color("637960", 0.4), false)
	for i in range(6):
		_text(Vector2(274 + i * 78, 589), TERM_NAMES[i], 16, INK if i <= term_index else Color("a7af98"))
		if i == term_index:
			draw_line(Vector2(274 + i * 78, 596), Vector2(307 + i * 78, 596), GOLD, 2)
	if model.day_finished and not paused:
		_panel(Rect2(348, 204, 584, 290), CREAM, 24, INK)
		_text(Vector2(402, 263), TERM_NAMES[term_index] + (" · 十五天走完了" if model.complete else " · 今天收工"), 25, INK)
		_text(Vector2(402, 318), title_today(), 21, INK)
		_text(Vector2(402, 367), "路和邻居都还在，下一次回来会认得。" if term_index < 5 else "春天的路接好了，大家都能从这里走过。", 19, INK)
	if paused:
		draw_rect(Rect2(0, 145, 1280, 470), Color("142f24", 0.75))
