class_name JourneyGame
extends Node

const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const JourneyAreaRouterScript := preload("res://scripts/world/journey_area_router.gd")
const PersistenceScript := preload("res://scripts/system/commercial_persistence.gd")
const CommercialMenuScript := preload("res://scripts/ui/commercial_system_menu.gd")
const SolarTermBoardScript := preload("res://scripts/world/journey_solar_term_board.gd")
const COMMERCIAL_TITLE_PATH := "res://commercial_title.tscn"
const SEGMENT_AREAS := {
	JourneyState.SPRING_ROUTE: "spring_field",
	JourneyState.SIGN_INCIDENT: "spring_sign_incident",
	JourneyState.SUMMER_RECOVERY: "summer_field",
	JourneyState.AUTUMN_HARVEST: "autumn_field",
	JourneyState.WINTER_WARMTH: "winter_field",
	JourneyState.FINALE_HANDOFF: "finale_handoff",
}
const SEGMENT_CAPTIONS := {
	JourneyState.SPRING_ROUTE: "出巢 · 春野",
	JourneyState.SIGN_INCIDENT: "花标路 · 搭把翅膀",
	JourneyState.SUMMER_RECOVERY: "夏 · 远花路",
	JourneyState.AUTUMN_HARVEST: "秋 · 把花田收好",
	JourneyState.WINTER_WARMTH: "冬 · 一段段续暖",
	JourneyState.FINALE_HANDOFF: "巢前 · 这回你来",
}
const PLAYABLE_AREA_IDS := [
	"spring_field",
	"spring_sign_incident",
	"summer_field",
	"autumn_field",
	"winter_field",
	"finale_handoff",
]

var state = JourneyStateScript.new()
var router: JourneyAreaRouter
var area_host: Node2D
var transitioning := false
var transition_duration := 0.28
var full_motion_transition_duration := 0.28
var current_status: Dictionary = {}
var paused_for_focus := false
var story_card_time := 0.0
var persistence: CommercialPersistenceService
var system_menu: CommercialSystemMenu
var sound: SoundFeedback
var session_persistence_active := false
var paused_by_menu := false
var checkpoint_notice := ""
var solar_term_board: JourneySolarTermBoard

var ui_layer: CanvasLayer
var title_label: Label
var area_label: Label
var carried_label: Label
var energy_label: Label
var reserve_label: Label
var objective_label: Label
var message_label: Label
var side_panel: ColorRect
var primary_button: Button
var action_button: Button
var return_button: Button
var title_button: Button
var save_status_label: Label
var controls_label: Label
var fade: ColorRect
var transition_label: Label
var story_card: ColorRect
var story_card_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	full_motion_transition_duration = transition_duration
	sound = get_node_or_null("SoundFeedback") as SoundFeedback
	if sound == null:
		push_error("Journey 缺少共享动作音效节点")
		return
	persistence = get_node_or_null("/root/CommercialPersistence") as CommercialPersistenceService
	if persistence == null:
		persistence = PersistenceScript.new()
		persistence.name = "LocalCommercialPersistence"
		add_child(persistence)
	var launch_requested := persistence.has_pending_launch_request()
	var running_as_product_scene := get_tree().current_scene == self
	session_persistence_active = launch_requested or running_as_product_scene
	var launch_mode := persistence.consume_journey_launch(
		"continue" if session_persistence_active and persistence.has_progress() else "new"
	)
	var restore_error := OK
	if session_persistence_active:
		if launch_mode == "continue":
			restore_error = persistence.restore_journey_state(state)
		else:
			restore_error = persistence.delete_progress()
	area_host = Node2D.new()
	area_host.name = "AreaHost"
	area_host.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(area_host)
	router = JourneyAreaRouterScript.new()
	router.name = "AreaRouter"
	add_child(router)
	var router_error := router.configure(area_host)
	if router_error != OK:
		push_error("无法建立旅程场景入口：%d" % router_error)
		return
	_build_interface()
	system_menu = CommercialMenuScript.new()
	system_menu.name = "CommercialSystemMenu"
	system_menu.configure(persistence)
	add_child(system_menu)
	system_menu.resume_requested.connect(_resume_from_menu)
	system_menu.return_to_title_requested.connect(_return_to_title)
	system_menu.new_journey_requested.connect(_restart_new_journey)
	system_menu.quit_requested.connect(_quit_game)
	persistence.settings_changed.connect(_apply_commercial_settings)
	_apply_commercial_settings(persistence.settings_snapshot())
	_show_hive(false, true)
	if session_persistence_active and launch_mode == "new" and restore_error == OK:
		_save_checkpoint()
	elif restore_error != OK:
		checkpoint_notice = "存档没有安全载入，已从新旅程开始（错误 %d）" % restore_error
		save_status_label.text = "未载入存档"
		_show_story_card(checkpoint_notice, 5.5)
	elif persistence.recovered_progress_from_backup:
		checkpoint_notice = "主存档损坏，已从上一份安全备份恢复"
		save_status_label.text = "已恢复备份"
		_show_story_card(checkpoint_notice, 5.5)


func _build_interface() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "JourneyInterface"
	add_child(ui_layer)

	var top := ColorRect.new()
	top.position = Vector2(20, 16)
	top.size = Vector2(1230, 74)
	top.color = Color("f3e5bd", 0.94)
	ui_layer.add_child(top)
	title_label = _label(top, "新蜂 · 第一趟", Vector2(20, 5), Vector2(270, 40), 25, Color("26342b"))
	area_label = _label(top, "主蜂巢", Vector2(22, 47), Vector2(300, 22), 12, Color("66705d"))
	carried_label = _label(top, "随身蜜 0 / 8", Vector2(345, 18), Vector2(190, 34), 17, Color("4b3e2a"))
	energy_label = _label(top, "体力 120", Vector2(560, 18), Vector2(150, 34), 17, Color("4b3e2a"))
	reserve_label = _label(top, "巢中蜜 0", Vector2(735, 18), Vector2(150, 34), 17, Color("4b3e2a"))
	title_button = Button.new()
	title_button.text = "暂停 / 菜单"
	title_button.position = Vector2(1080, 13)
	title_button.size = Vector2(130, 48)
	title_button.focus_mode = Control.FOCUS_ALL
	title_button.pressed.connect(_open_pause_menu)
	top.add_child(title_button)
	save_status_label = _label(top, "主蜂巢检查点", Vector2(885, 19), Vector2(176, 34), 12, Color("66705d"))
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	side_panel = ColorRect.new()
	side_panel.position = Vector2(1018, 108)
	side_panel.size = Vector2(232, 574)
	side_panel.color = Color("f4edda", 0.93)
	side_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(side_panel)
	_label(side_panel, "这一趟", Vector2(18, 16), Vector2(190, 25), 12, Color("6b715e"))
	objective_label = _label(side_panel, "", Vector2(18, 48), Vector2(196, 176), 16, Color("28352d"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	message_label = _label(side_panel, "", Vector2(18, 244), Vector2(196, 122), 13, Color("4d574b"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	action_button = Button.new()
	action_button.text = "情境动作"
	action_button.position = Vector2(16, 410)
	action_button.size = Vector2(126, 56)
	action_button.button_down.connect(_press_action)
	action_button.button_up.connect(_release_action)
	side_panel.add_child(action_button)
	return_button = Button.new()
	return_button.text = "归巢"
	return_button.position = Vector2(148, 410)
	return_button.size = Vector2(68, 56)
	return_button.pressed.connect(_pulse_return)
	side_panel.add_child(return_button)
	controls_label = _label(side_panel, "WASD / 左摇杆移动\n空格 / A 互动 · Q / Y 归巢", Vector2(18, 492), Vector2(196, 58), 11, Color("737866"))
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	primary_button = Button.new()
	primary_button.position = Vector2(410, 590)
	primary_button.size = Vector2(310, 62)
	primary_button.add_theme_font_size_override("font_size", 20)
	primary_button.set_meta("commercial_base_font_size", 20)
	primary_button.pressed.connect(_on_primary_button)
	ui_layer.add_child(primary_button)

	story_card = ColorRect.new()
	story_card.position = Vector2(235, 202)
	story_card.size = Vector2(720, 210)
	story_card.color = Color("f6edcf", 0.97)
	story_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_card.visible = false
	ui_layer.add_child(story_card)
	story_card_label = _label(story_card, "", Vector2(38, 28), Vector2(644, 154), 23, Color("314037"))
	story_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	solar_term_board = SolarTermBoardScript.new()
	solar_term_board.name = "SolarTermBoard"
	ui_layer.add_child(solar_term_board)
	solar_term_board.configure(state.solar_terms)
	solar_term_board.open_changed.connect(_on_solar_term_board_open_changed)
	solar_term_board.set_hive_available(false)

	fade = ColorRect.new()
	fade.position = Vector2.ZERO
	fade.size = Vector2(1280, 720)
	fade.color = Color("25372d", 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(fade)
	transition_label = _label(fade, "", Vector2(300, 300), Vector2(680, 90), 30, Color("fff1bd"))
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	if paused_by_menu or get_tree().paused:
		return
	if story_card_time <= 0.0:
		return
	story_card_time = maxf(0.0, story_card_time - delta)
	if story_card_time <= 0.0 and story_card != null:
		story_card.visible = false


func _show_story_card(text: String, duration := 4.2) -> void:
	story_card_label.text = text
	story_card.visible = true
	story_card_time = maxf(0.1, duration)


func _label(parent: Node, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("commercial_base_font_size", font_size)
	parent.add_child(label)
	return label


func _show_hive(returning: bool, immediate := false) -> void:
	if transitioning and not immediate:
		return
	transitioning = true
	_release_action()
	_show_fade("巢里见" if returning else "主蜂巢", immediate)
	var error := router.change_area("hive_threshold", state.hive_context(returning))
	if error != OK:
		push_error("蜂巢场景切换失败：%d" % error)
		_finish_transition()
		return
	var hive := router.current_area as HiveThresholdArea
	hive.sortie_requested.connect(_begin_sortie)
	hive.presentation_finished.connect(_refresh_hive_interface)
	_refresh_hive_interface()
	_finish_fade(immediate)


func _begin_sortie() -> void:
	if transitioning:
		return
	if solar_term_board != null and solar_term_board.is_open():
		return
	var segment_id: String = state.next_segment_id()
	if segment_id.is_empty():
		_refresh_hive_interface()
		return
	var area_id := String(SEGMENT_AREAS.get(segment_id, ""))
	if area_id.is_empty():
		push_error("旅程段落没有对应场景：%s" % segment_id)
		_refresh_hive_interface()
		return
	if not state.can_begin_sortie(segment_id):
		push_error("当前蜂巢资源或进度无法安全开始旅程段落：%s" % segment_id)
		_refresh_hive_interface()
		return
	if solar_term_board != null:
		solar_term_board.set_hive_available(false)
	var field_context: Dictionary
	if segment_id == JourneyState.SPRING_ROUTE:
		field_context = state.next_field_context()
	elif segment_id == JourneyState.SIGN_INCIDENT:
		field_context = state.next_incident_context()
	else:
		field_context = state.next_seasonal_context(segment_id)
	field_context["sound_feedback"] = sound
	transitioning = true
	_release_action()
	_show_fade(String(SEGMENT_CAPTIONS.get(segment_id, "出巢")), false)
	var error := router.change_area(area_id, field_context)
	if error != OK:
		push_error("春野旅程场景切换失败：%d" % error)
		var hive := router.current_area as HiveThresholdArea
		if hive != null:
			hive.ready_for_sortie = true
			_refresh_hive_interface()
		_finish_transition()
		return
	var committed_token: int = state.begin_sortie(segment_id)
	assert(committed_token == int(field_context.journey_token))
	if area_id == "spring_field":
		var field := router.current_area as SpringJourneyField
		field.set_input_enabled(false)
		field.status_changed.connect(_on_field_status)
		field.journey_completed.connect(_on_journey_completed)
		_on_field_status(field.status_snapshot())
	elif area_id == "spring_sign_incident":
		var incident := router.current_area as SpringSignIncident
		incident.set_input_enabled(false)
		incident.status_changed.connect(_on_incident_status)
		incident.journey_completed.connect(_on_journey_completed)
		_on_incident_status(incident.status_snapshot())
	else:
		var seasonal := router.current_area as JourneySeasonalFieldBase
		if seasonal == null:
			push_error("季节场景没有使用统一旅程场地基础：%s" % area_id)
			_finish_transition()
			return
		seasonal.set_input_enabled(false)
		seasonal.status_changed.connect(_on_seasonal_status)
		seasonal.journey_completed.connect(_on_journey_completed)
		_on_seasonal_status(seasonal.status_snapshot())
	_finish_fade(false)


func _on_journey_completed(payload: Dictionary) -> void:
	call_deferred("_settle_and_show_hive", payload.duplicate(true))


func _settle_and_show_hive(payload: Dictionary) -> void:
	var journey_kind := String(payload.get("journey_kind", JourneyState.SPRING_ROUTE))
	if not _can_settle_payload(payload):
		push_warning("返巢交接数据不完整，已让当前场景恢复操作：%s" % journey_kind)
		var current_area := router.current_area
		if current_area != null and current_area.has_method("resume_after_failed_transition"):
			current_area.resume_after_failed_transition()
		return
	transitioning = true
	_release_action()
	_show_fade("巢里见", false)
	var hive_context := _preview_return_context(payload)
	var error := router.change_area("hive_threshold", hive_context)
	if error != OK:
		push_error("蜂巢场景切换失败：%d" % error)
		var failed_area := router.current_area
		if failed_area != null and failed_area.has_method("resume_after_failed_transition"):
			failed_area.resume_after_failed_transition()
		_finish_transition()
		return
	var reveal_title: bool = journey_kind == JourneyState.SPRING_ROUTE and not bool(state.title_revealed)
	var accepted := _settle_payload(payload)
	assert(accepted)
	sound.play_cue("complete")
	if reveal_title:
		state.mark_title_revealed()
		title_label.text = "一会儿巢里见"
		_show_story_card(
			"一会儿巢里见\n花田有事，搭把翅膀。飞一圈，巢里见。\n%s" % _latest_solar_term_line(JourneyState.SPRING_ROUTE),
			5.4
		)
	else:
		_show_result_story_card(payload)
	_save_checkpoint()
	var hive := router.current_area as HiveThresholdArea
	hive.sortie_requested.connect(_begin_sortie)
	hive.presentation_finished.connect(_refresh_hive_interface)
	_refresh_hive_interface()
	_finish_fade(false)


func _can_settle_payload(payload: Dictionary) -> bool:
	var journey_kind := String(payload.get("journey_kind", ""))
	var token := int(payload.get("journey_token", -1))
	var deposit := int(payload.get("deposit", -1))
	match journey_kind:
		JourneyState.SPRING_ROUTE:
			return state.can_settle_return(token, deposit, int(payload.get("pollinations", -1)))
		JourneyState.SIGN_INCIDENT:
			return state.can_settle_sign_incident(
				token,
				deposit,
				int(payload.get("signs_resolved", -1)),
				int(payload.get("honey_lost", -1))
			)
		JourneyState.SUMMER_RECOVERY:
			return state.can_settle_summer(
				token,
				deposit,
				int(payload.get("recovered_honey", -1)),
				int(payload.get("honey_lost", -1)),
				int(payload.get("belongings_recovered", -1)),
				bool(payload.get("rest_hive_repaired", false))
			)
		JourneyState.AUTUMN_HARVEST:
			return state.can_settle_autumn(
				token,
				deposit,
				int(payload.get("harvested", -1)),
				int(payload.get("seeded", -1)),
				int(payload.get("echo_points", -1))
			)
		JourneyState.WINTER_WARMTH:
			return deposit == 0 and state.can_settle_winter(
				token,
				int(payload.get("warmth_links", -1)),
				int(payload.get("windbreak_segments", -1)),
				bool(payload.get("bear_helped", false))
			)
		JourneyState.FINALE_HANDOFF:
			return deposit == 0 and state.can_settle_finale(
				token,
				int(payload.get("demonstration_steps", -1)),
				bool(payload.get("phrase_spoken", false))
			)
		_:
			return false


func _settle_payload(payload: Dictionary) -> bool:
	var journey_kind := String(payload.get("journey_kind", ""))
	var token := int(payload.get("journey_token", -1))
	var deposit := int(payload.get("deposit", -1))
	match journey_kind:
		JourneyState.SPRING_ROUTE:
			return state.settle_return(token, deposit, int(payload.get("pollinations", -1)))
		JourneyState.SIGN_INCIDENT:
			return state.settle_sign_incident(
				token,
				deposit,
				int(payload.get("signs_resolved", -1)),
				int(payload.get("honey_lost", -1))
			)
		JourneyState.SUMMER_RECOVERY:
			return state.settle_summer(
				token,
				deposit,
				int(payload.get("recovered_honey", -1)),
				int(payload.get("honey_lost", -1)),
				int(payload.get("belongings_recovered", -1)),
				bool(payload.get("rest_hive_repaired", false))
			)
		JourneyState.AUTUMN_HARVEST:
			return state.settle_autumn(
				token,
				deposit,
				int(payload.get("harvested", -1)),
				int(payload.get("seeded", -1)),
				int(payload.get("echo_points", -1))
			)
		JourneyState.WINTER_WARMTH:
			return state.settle_winter(
				token,
				int(payload.get("warmth_links", -1)),
				int(payload.get("windbreak_segments", -1)),
				bool(payload.get("bear_helped", false))
			)
		JourneyState.FINALE_HANDOFF:
			return state.settle_finale(
				token,
				int(payload.get("demonstration_steps", -1)),
				bool(payload.get("phrase_spoken", false))
			)
		_:
			return false


func _preview_return_context(payload: Dictionary) -> Dictionary:
	var journey_kind := String(payload.get("journey_kind", ""))
	if journey_kind == JourneyState.SPRING_ROUTE:
		return state.preview_return_context(
			int(payload.get("deposit", 0)),
			int(payload.get("pollinations", 0))
		)
	if journey_kind == JourneyState.SIGN_INCIDENT:
		return state.preview_incident_return_context(
			int(payload.get("deposit", 0)),
			int(payload.get("signs_resolved", 0)),
			int(payload.get("honey_lost", 0))
		)
	return state.preview_seasonal_return_context(payload)


func _show_result_story_card(payload: Dictionary) -> void:
	match String(payload.get("journey_kind", "")):
		JourneyState.SIGN_INCIDENT:
			_show_story_card(
				"春 · 花儿要传粉\n花标归位 3 / 3　带回 %d / 6 滴\n最后一块花标搭在蚊庄主背上，你和老师傅一起归巢。"
				% int(payload.get("deposit", 0)),
				5.2
			)
		JourneyState.SUMMER_RECOVERY:
			_show_story_card(
				"夏 · 花田有点忙\n找回 %d / 8 份　接货蜂收下 %d 份　雨路留下 %d 份\n油葫芦收齐家当，小蜂房重新能歇脚。"
				% [
					int(payload.get("recovered_honey", 0)),
					int(payload.get("deposit", 0)),
					int(payload.get("honey_lost", 0)),
				],
				5.2
			)
		JourneyState.AUTUMN_HARVEST:
			_show_story_card(
				"秋 · 把花田收好\n收蜜 %d 朵　留种 %d 朵　听声种壳 3 / 3\n短花梗和种头一起留在花田里，风过来时都看得见。"
				% [int(payload.get("harvested", 0)), int(payload.get("seeded", 0))],
				5.2
			)
		JourneyState.WINTER_WARMTH:
			_show_story_card(
				"冬 · 大家一起收工\n续暖 4 / 4　挡风木 3 / 3\n大熊推最沉的一段，修补蜂把三处绳扣收紧。",
				5.2
			)
		JourneyState.FINALE_HANDOFF:
			_show_story_card(
				"老师傅：这回你来。\n你把散粉送进同形花心，又把归巢方向指给新蜂。\n你：一会儿巢里见。",
				6.0
			)
	var term_line := _latest_solar_term_line(String(payload.get("journey_kind", "")))
	if not term_line.is_empty():
		story_card_label.text += "\n%s" % term_line


func _latest_solar_term_line(return_kind: String) -> String:
	var entries: Array[Dictionary] = state.solar_terms.latest_unlock_entries()
	if entries.is_empty():
		return ""
	var names := PackedStringArray()
	for entry in entries:
		if String(entry.unlock_return) == return_kind:
			names.append(String(entry.name))
	if names.is_empty():
		return ""
	return "巢内纪事添了：%s" % "、".join(names)


func _on_field_status(snapshot: Dictionary) -> void:
	if router.current_area_id != "spring_field":
		return
	current_status = snapshot.duplicate(true)
	_position_side_panel(false)
	area_label.text = String(snapshot.get("area", "春野"))
	carried_label.text = "随身蜜 %d / %d" % [int(snapshot.get("carried", 0)), int(snapshot.get("capacity", 8))]
	energy_label.text = "体力 %d" % roundi(float(snapshot.get("energy", 0.0)))
	reserve_label.text = "巢中蜜 %d" % int(snapshot.get("reserve", state.reserve))
	var pollinated := int(snapshot.get("pollinated", 0))
	var pollination_goal := int(snapshot.get("pollination_goal", 2))
	var delivered := int(snapshot.get("delivered", 0))
	var delivery_goal := int(snapshot.get("delivery_goal", 6))
	if pollinated >= pollination_goal and delivered >= delivery_goal:
		objective_label.text = (
			"两朵花开始结籽\n%d / %d\n\n花蜜已经送够\n%d / %d\n\n回主蜂巢停稳收工"
			% [pollinated, pollination_goal, delivered, delivery_goal]
		)
	elif bool(snapshot.get("story_intro_active", false)):
		objective_label.text = (
			"老师傅先飞一遍\n跟着看花心\n\n同形散粉  %d / %d\n带蜜返巢  %d / %d\n可选歇脚：未启用"
			% [pollinated, pollination_goal, delivered, delivery_goal]
		)
	else:
		objective_label.text = (
			"送散粉到同形花心\n%d / %d\n\n带蜜回主蜂巢\n%d / %d\n\n可选歇脚：%s"
			% [
				pollinated, pollination_goal,
				delivered, delivery_goal,
				_relay_label(String(snapshot.get("relay_state", "dormant")))
			]
		)
	message_label.text = String(snapshot.get("message", ""))
	primary_button.visible = false
	action_button.visible = true
	action_button.text = "采蜜 / 传粉"
	return_button.visible = true
	return_button.text = "归巢"


func _on_incident_status(snapshot: Dictionary) -> void:
	if router.current_area_id != "spring_sign_incident":
		return
	current_status = snapshot.duplicate(true)
	_position_side_panel(false)
	area_label.text = String(snapshot.get("area", "春野 · 花标路"))
	var carried := int(snapshot.get("carried", 0))
	var capacity := int(snapshot.get("capacity", 6))
	carried_label.text = "随身蜜 %d / %d" % [carried, capacity]
	energy_label.text = "体力 %d" % roundi(float(snapshot.get("energy", 0.0)))
	reserve_label.text = "巢中蜜 %d" % int(snapshot.get("reserve", state.reserve))
	var resolved := int(snapshot.get("signs_resolved", 0))
	var goal := int(snapshot.get("sign_goal", 3))
	var open_windows: Array = snapshot.get("open_sign_windows", [])
	var open_text := "正起风：%s 号" % _join_numbers(open_windows) if not open_windows.is_empty() else "正起风：等半拍"
	objective_label.text = (
		"花标归位  %d / %d\n%s\n\n最后一标：%s\n一起归巢：%s"
		% [
			resolved,
			goal,
			open_text,
			"在蚊庄主背上" if bool(snapshot.get("final_sign_on_back", false)) else "完成第 3 处时发生",
			"完成" if bool(snapshot.get("returned_with_mentor", false)) else "理完后从左侧巢门返回",
		]
	)
	message_label.text = String(snapshot.get("message", ""))
	primary_button.visible = false
	action_button.visible = true
	action_button.text = "借风理标"
	return_button.visible = true
	return_button.text = "回巢口"


func _on_seasonal_status(snapshot: Dictionary) -> void:
	var journey_kind := String(snapshot.get("journey_kind", ""))
	var expected_area := String(SEGMENT_AREAS.get(journey_kind, ""))
	if expected_area.is_empty() or router.current_area_id != expected_area:
		return
	current_status = snapshot.duplicate(true)
	_position_side_panel(false)
	area_label.text = String(snapshot.get("area", "花田"))
	energy_label.text = "体力 %d" % roundi(float(snapshot.get("energy", 0.0)))
	reserve_label.text = "巢中蜜 %d" % int(snapshot.get("reserve", state.reserve))
	message_label.text = String(snapshot.get("message", ""))
	primary_button.visible = false
	action_button.visible = true
	return_button.visible = true
	match journey_kind:
		JourneyState.SUMMER_RECOVERY:
			var carried := int(snapshot.get("carried", 0))
			var recovered := int(snapshot.get("recovered_honey", 0))
			var honey_goal := int(snapshot.get("honey_goal", 6))
			var lost := int(snapshot.get("honey_lost", 0))
			var belongings := int(snapshot.get("belongings_recovered", 0))
			var belongings_goal := int(snapshot.get("belongings_goal", 3))
			carried_label.text = "散落花蜜 %d / 8" % carried
			objective_label.text = (
				"找回花蜜  %d / 8\n蜜囊至少  %d / %d（现有 %d）\n雨路落下  %d\n\n油葫芦家当  %d / %d\n小蜂房  %s\n路线  %s"
				% [
					recovered,
					mini(carried, honey_goal),
					honey_goal,
					carried,
					lost,
					belongings,
					belongings_goal,
					"已修好" if bool(snapshot.get("rest_hive_repaired", false)) else "待收齐家当后修",
					"正迎雨，长荫路安全" if bool(snapshot.get("storm_active", false)) else "雨歇，可走远路",
				]
			)
			action_button.text = "拾取 / 修理"
			return_button.text = "归巢"
		JourneyState.AUTUMN_HARVEST:
			var resolved := int(snapshot.get("flowers_resolved", 0))
			var flower_goal := int(snapshot.get("flower_goal", 8))
			var harvested := int(snapshot.get("harvested", 0))
			var seeded := int(snapshot.get("seeded", 0))
			var echoes := int(snapshot.get("echo_points", 0))
			var echo_goal := int(snapshot.get("echo_goal", 3))
			carried_label.text = "秋蜜 %d · 种头 %d" % [harvested, seeded]
			objective_label.text = (
				"逐花收尾  %d / %d\n收蜜 %d　留种 %d\n两种结果都保留\n\n听声种壳  %d / %d\n空格：收蜜 / 转正种壳\nQ：花边留种，别处归巢"
				% [resolved, flower_goal, harvested, seeded, echoes, echo_goal]
			)
			action_button.text = "收蜜 / 转正种壳"
			return_button.text = "留种 / 归巢"
		JourneyState.WINTER_WARMTH:
			var warmth := int(snapshot.get("warmth", 0))
			var links := int(snapshot.get("warmth_links", 0))
			var warmth_goal := int(snapshot.get("warmth_goal", 4))
			var walls := int(snapshot.get("windbreak_segments", 0))
			var wall_goal := int(snapshot.get("windbreak_goal", 3))
			carried_label.text = "暖意 %d / 100" % warmth
			objective_label.text = (
				"逐段续暖  %d / %d\n挡风木  %d / %d\n大熊帮忙  %s\n\n当前路线  %s\n暖意归零只减速\n全部接好后归巢"
				% [
					links,
					warmth_goal,
					walls,
					wall_goal,
					"完成" if bool(snapshot.get("bear_helped", false)) else "在最沉木段旁",
					"叶棚安全路" if bool(snapshot.get("on_safe_route", false)) else "迎风近路",
				]
			)
			action_button.text = "续暖 / 搬木"
			return_button.text = "归巢"
		JourneyState.FINALE_HANDOFF:
			var steps := int(snapshot.get("demonstration_steps", 0))
			carried_label.text = "示范 %d / 3" % steps
			objective_label.text = (
				"给下一只新蜂示范\n取同形散粉  %s\n送到开放花心  %s\n回到新蜂身边  %s\n\n老师傅：这回你来。"
				% [
					"完成" if bool(snapshot.get("pollen_taken", false)) else "0 / 1",
					"完成" if bool(snapshot.get("pollen_delivered", false)) else "0 / 1",
					"完成" if bool(snapshot.get("returned_to_new_bee", false)) else "0 / 1",
				]
			)
			action_button.text = "示范动作"
			return_button.text = "指向下一步"


func _join_numbers(values: Array) -> String:
	var parts: PackedStringArray = []
	for value in values:
		parts.append(str(int(value)))
	return "、".join(parts)


func _relay_label(state_id: String) -> String:
	return "可以休息" if state_id == "active" else "未启用"


func _refresh_hive_interface() -> void:
	if router.current_area_id != "hive_threshold":
		return
	var hive := router.current_area as HiveThresholdArea
	# Keep the authored right-hand daylight doorway visible inside the hive. The
	# same query panel moves to the quieter left floor only in this non-moving scene.
	_position_side_panel(true)
	if state.title_revealed:
		title_label.text = "一会儿巢里见"
	area_label.text = "主蜂巢 · 巢门内侧"
	carried_label.text = "随身蜜 0 / 8"
	energy_label.text = "体力 120"
	reserve_label.text = "巢中蜜 %d" % state.reserve
	objective_label.text = hive.heading()
	message_label.text = hive.body_text()
	if not checkpoint_notice.is_empty():
		message_label.text += "\n\n%s" % checkpoint_notice
	primary_button.text = hive.action_text()
	primary_button.disabled = not hive.ready_for_sortie
	primary_button.visible = true
	action_button.visible = false
	return_button.visible = false
	return_button.text = "归巢"
	if solar_term_board != null:
		solar_term_board.configure(state.solar_terms)
		solar_term_board.set_hive_available(true)
		solar_term_board.refresh()


func _on_solar_term_board_open_changed(open: bool) -> void:
	if router == null or router.current_area_id != "hive_threshold":
		return
	var hive := router.current_area as HiveThresholdArea
	if hive != null:
		hive.set_departure_input_enabled(not open)
		primary_button.disabled = open or not hive.ready_for_sortie
	title_button.disabled = open
	if open:
		story_card.visible = false


func _on_primary_button() -> void:
	if router.current_area_id != "hive_threshold":
		return
	var hive := router.current_area as HiveThresholdArea
	hive.request_sortie()


func _press_action() -> void:
	if router.current_area_id in PLAYABLE_AREA_IDS:
		Input.action_press("action")


func _release_action() -> void:
	if Input.is_action_pressed("action"):
		Input.action_release("action")


func _pulse_return() -> void:
	if router.current_area_id not in PLAYABLE_AREA_IDS:
		return
	Input.action_press("return_hive")
	await get_tree().process_frame
	Input.action_release("return_hive")


func _show_fade(caption: String, immediate: bool) -> void:
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.color.a = 1.0
	transition_label.text = caption
	if immediate:
		return


func _finish_fade(immediate: bool) -> void:
	if immediate or transition_duration <= 0.0:
		_finish_transition()
		return
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(fade, "color:a", 0.0, transition_duration)
	tween.finished.connect(_finish_transition)


func _finish_transition() -> void:
	fade.color.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_label.text = ""
	transitioning = false
	if paused_for_focus and not paused_by_menu:
		# Focus may be lost while the fade owns input. Finish the scene hand-off,
		# then open the real pause surface instead of leaving a frozen field with
		# no visible way to resume.
		call_deferred("_open_pause_menu", true)
		return
	if (
		router != null
		and router.current_area_id in PLAYABLE_AREA_IDS
		and router.current_area != null
		and router.current_area.has_method("set_input_enabled")
	):
		router.current_area.set_input_enabled(not paused_for_focus)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		paused_for_focus = true
		if sound != null:
			sound.set_enabled(false)
		_release_action()
		if Input.is_action_pressed("return_hive"):
			Input.action_release("return_hive")
		_set_field_input_enabled(false)
		if not paused_by_menu and not transitioning:
			call_deferred("_open_pause_menu", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		paused_for_focus = false
		if sound != null and not paused_by_menu:
			sound.set_enabled(true)
		if not transitioning and not paused_by_menu:
			_set_field_input_enabled(true)


func _set_field_input_enabled(enabled: bool) -> void:
	if router == null or router.current_area_id not in PLAYABLE_AREA_IDS:
		return
	var active_area := router.current_area
	if active_area != null and active_area.has_method("set_input_enabled"):
		active_area.set_input_enabled(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") and not event.is_action_pressed("pause_menu"):
		return
	if solar_term_board != null and solar_term_board.is_open():
		solar_term_board.close()
		get_viewport().set_input_as_handled()
		return
	if system_menu != null and system_menu.is_open():
		system_menu.request_cancel()
	else:
		_open_pause_menu()
	get_viewport().set_input_as_handled()


func _open_pause_menu(focus_was_lost := false) -> void:
	# A focus-out/in pair can happen within one frame while the browser transfers
	# focus between the canvas and its shell. Ignore that stale deferred request;
	# sustained focus loss still reaches this method with paused_for_focus=true.
	if focus_was_lost and not paused_for_focus:
		return
	if paused_by_menu or transitioning or system_menu == null:
		return
	if solar_term_board != null and solar_term_board.is_open():
		solar_term_board.close()
	_release_action()
	if Input.is_action_pressed("return_hive"):
		Input.action_release("return_hive")
	paused_by_menu = true
	if sound != null:
		sound.set_enabled(false)
	_set_field_input_enabled(false)
	get_tree().paused = true
	system_menu.open_pause(focus_was_lost)


func _resume_from_menu() -> void:
	if not paused_by_menu:
		return
	if paused_for_focus:
		system_menu.open_pause(true)
		return
	paused_by_menu = false
	get_tree().paused = false
	if sound != null:
		sound.set_enabled(true)
	system_menu.close()
	if not transitioning:
		_set_field_input_enabled(true)


func _return_to_title() -> void:
	_release_action()
	if paused_by_menu:
		paused_by_menu = false
		get_tree().paused = false
	if system_menu != null:
		system_menu.close()
	get_tree().change_scene_to_file(COMMERCIAL_TITLE_PATH)


func _restart_new_journey() -> void:
	var delete_error := persistence.delete_progress() if persistence != null else ERR_UNCONFIGURED
	if delete_error != OK:
		checkpoint_notice = "旧旅程没有安全清除（错误 %d）" % delete_error
		if system_menu != null:
			system_menu.open_pause(false)
		return
	persistence.request_journey_launch("new")
	if paused_by_menu:
		paused_by_menu = false
		get_tree().paused = false
	get_tree().change_scene_to_file("res://journey.tscn")


func _quit_game() -> void:
	if paused_by_menu:
		paused_by_menu = false
		get_tree().paused = false
	get_tree().quit()


func _save_checkpoint() -> Error:
	if not session_persistence_active or persistence == null:
		return OK
	var error := persistence.save_journey_state(state)
	if error == OK:
		checkpoint_notice = "已自动保存 · 下次从主蜂巢继续"
		if save_status_label != null:
			save_status_label.text = "已保存 · 主蜂巢"
	else:
		checkpoint_notice = "自动保存失败（错误 %d），请勿关闭游戏" % error
		if save_status_label != null:
			save_status_label.text = "存档失败"
	return error


func _apply_commercial_settings(next_settings: Dictionary) -> void:
	transition_duration = 0.0 if bool(next_settings.get("reduce_motion", false)) else full_motion_transition_duration
	if controls_label != null:
		controls_label.visible = bool(next_settings.get("show_control_hints", true))
	if ui_layer == null:
		return
	var ui_scale := float(next_settings.get("ui_scale", 1.0))
	_apply_side_panel_scale(ui_scale)
	for node in ui_layer.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		if not control.has_meta("commercial_base_font_size"):
			var inherited_size := control.get_theme_font_size("font_size")
			if inherited_size > 0:
				control.set_meta("commercial_base_font_size", inherited_size)
		if control.has_meta("commercial_base_font_size"):
			var base_size := int(control.get_meta("commercial_base_font_size"))
			control.add_theme_font_size_override("font_size", roundi(float(base_size) * ui_scale))


func _apply_side_panel_scale(ui_scale: float) -> void:
	if side_panel == null:
		return
	var extra_width := roundf(260.0 * maxf(0.0, ui_scale - 1.0))
	var panel_width := 232.0 + extra_width
	side_panel.size.x = panel_width
	objective_label.size.x = panel_width - 36.0
	message_label.size.x = panel_width - 36.0
	controls_label.size.x = panel_width - 36.0
	var vertical_extra := roundf(114.0 * maxf(0.0, ui_scale - 1.0))
	objective_label.size.y = 176.0 + vertical_extra
	message_label.position.y = 244.0 + vertical_extra
	message_label.size.y = maxf(88.0, 390.0 - message_label.position.y)
	var button_width := panel_width - 32.0
	var action_width := roundf(button_width * 0.63)
	action_button.size.x = action_width
	return_button.position.x = 22.0 + action_width
	return_button.size.x = button_width - action_width - 6.0
	_position_side_panel(router != null and router.current_area_id == "hive_threshold")


func _position_side_panel(in_hive: bool) -> void:
	if side_panel == null:
		return
	var extra_width := side_panel.size.x - 232.0
	side_panel.position.x = 28.0 if in_hive else 1018.0 - extra_width


func _exit_tree() -> void:
	_release_action()
	if paused_by_menu:
		paused_by_menu = false
		get_tree().paused = false
	if Input.is_action_pressed("return_hive"):
		Input.action_release("return_hive")
