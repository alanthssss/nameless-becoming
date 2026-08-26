class_name JourneyGame
extends Node

const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const JourneyAreaRouterScript := preload("res://scripts/world/journey_area_router.gd")
const LEGACY_TITLE_PATH := "res://main.tscn"

var state = JourneyStateScript.new()
var router: JourneyAreaRouter
var area_host: Node2D
var transitioning := false
var transition_duration := 0.28
var current_status: Dictionary = {}
var paused_for_focus := false

var ui_layer: CanvasLayer
var title_label: Label
var area_label: Label
var carried_label: Label
var energy_label: Label
var reserve_label: Label
var objective_label: Label
var message_label: Label
var primary_button: Button
var action_button: Button
var return_button: Button
var title_button: Button
var fade: ColorRect
var transition_label: Label


func _ready() -> void:
	area_host = Node2D.new()
	area_host.name = "AreaHost"
	add_child(area_host)
	router = JourneyAreaRouterScript.new()
	router.name = "AreaRouter"
	add_child(router)
	var router_error := router.configure(area_host)
	if router_error != OK:
		push_error("无法建立旅程场景入口：%d" % router_error)
		return
	_build_interface()
	_show_hive(false, true)


func _build_interface() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "JourneyInterface"
	add_child(ui_layer)

	var top := ColorRect.new()
	top.position = Vector2(20, 16)
	top.size = Vector2(1230, 74)
	top.color = Color("f3e5bd", 0.94)
	ui_layer.add_child(top)
	title_label = _label(top, "一会儿巢里见", Vector2(20, 9), Vector2(270, 34), 25, Color("26342b"))
	area_label = _label(top, "主蜂巢", Vector2(22, 42), Vector2(300, 24), 12, Color("66705d"))
	carried_label = _label(top, "随身蜜 0 / 8", Vector2(345, 18), Vector2(190, 34), 17, Color("4b3e2a"))
	energy_label = _label(top, "体力 120", Vector2(560, 18), Vector2(150, 34), 17, Color("4b3e2a"))
	reserve_label = _label(top, "巢中蜜 0", Vector2(735, 18), Vector2(150, 34), 17, Color("4b3e2a"))
	title_button = Button.new()
	title_button.text = "返回标题"
	title_button.position = Vector2(1080, 16)
	title_button.size = Vector2(130, 40)
	title_button.focus_mode = Control.FOCUS_ALL
	title_button.pressed.connect(_return_to_title)
	top.add_child(title_button)

	var side := ColorRect.new()
	side.position = Vector2(1018, 108)
	side.size = Vector2(232, 574)
	side.color = Color("f4edda", 0.93)
	side.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(side)
	_label(side, "这一趟", Vector2(18, 16), Vector2(190, 25), 12, Color("6b715e"))
	objective_label = _label(side, "", Vector2(18, 48), Vector2(196, 176), 16, Color("28352d"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	message_label = _label(side, "", Vector2(18, 244), Vector2(196, 122), 13, Color("4d574b"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	action_button = Button.new()
	action_button.text = "情境动作"
	action_button.position = Vector2(16, 410)
	action_button.size = Vector2(126, 56)
	action_button.button_down.connect(_press_action)
	action_button.button_up.connect(_release_action)
	side.add_child(action_button)
	return_button = Button.new()
	return_button.text = "归巢"
	return_button.position = Vector2(148, 410)
	return_button.size = Vector2(68, 56)
	return_button.pressed.connect(_pulse_return)
	side.add_child(return_button)
	var controls := _label(side, "WASD / 点击移动\n空格互动 · Q 归巢", Vector2(18, 492), Vector2(196, 58), 11, Color("737866"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	primary_button = Button.new()
	primary_button.position = Vector2(410, 590)
	primary_button.size = Vector2(310, 62)
	primary_button.add_theme_font_size_override("font_size", 20)
	primary_button.pressed.connect(_on_primary_button)
	ui_layer.add_child(primary_button)

	fade = ColorRect.new()
	fade.position = Vector2.ZERO
	fade.size = Vector2(1280, 720)
	fade.color = Color("25372d", 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(fade)
	transition_label = _label(fade, "", Vector2(300, 300), Vector2(680, 90), 30, Color("fff1bd"))
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(parent: Node, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
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
	var field_context := state.next_field_context()
	transitioning = true
	_release_action()
	_show_fade("出巢 · 春野", false)
	var error := router.change_area("spring_field", field_context)
	if error != OK:
		push_error("春野场景切换失败：%d" % error)
		var hive := router.current_area as HiveThresholdArea
		if hive != null:
			hive.ready_for_sortie = true
			_refresh_hive_interface()
		_finish_transition()
		return
	var committed_token: int = state.begin_sortie()
	assert(committed_token == int(field_context.journey_token))
	var field := router.current_area as SpringJourneyField
	field.set_input_enabled(false)
	field.status_changed.connect(_on_field_status)
	field.journey_completed.connect(_on_journey_completed)
	_on_field_status(field.status_snapshot())
	_finish_fade(false)


func _on_journey_completed(payload: Dictionary) -> void:
	call_deferred("_settle_and_show_hive", payload.duplicate(true))


func _settle_and_show_hive(payload: Dictionary) -> void:
	var token := int(payload.get("journey_token", -1))
	var deposit := int(payload.get("deposit", -1))
	var pollinations := int(payload.get("pollinations", -1))
	if not state.can_settle_return(token, deposit, pollinations):
		return
	transitioning = true
	_release_action()
	_show_fade("巢里见", false)
	var error := router.change_area("hive_threshold", state.preview_return_context(deposit, pollinations))
	if error != OK:
		push_error("蜂巢场景切换失败：%d" % error)
		var field := router.current_area as SpringJourneyField
		if field != null:
			field.resume_after_failed_transition()
		_finish_transition()
		return
	var accepted := state.settle_return(token, deposit, pollinations)
	assert(accepted)
	var hive := router.current_area as HiveThresholdArea
	hive.sortie_requested.connect(_begin_sortie)
	hive.presentation_finished.connect(_refresh_hive_interface)
	_refresh_hive_interface()
	_finish_fade(false)


func _on_field_status(snapshot: Dictionary) -> void:
	if router.current_area_id != "spring_field":
		return
	current_status = snapshot.duplicate(true)
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
	return_button.visible = true


func _relay_label(state_id: String) -> String:
	return "可以休息" if state_id == "active" else "未启用"


func _refresh_hive_interface() -> void:
	if router.current_area_id != "hive_threshold":
		return
	var hive := router.current_area as HiveThresholdArea
	area_label.text = "主蜂巢 · 巢门内侧"
	carried_label.text = "随身蜜 0 / 8"
	energy_label.text = "体力 120"
	reserve_label.text = "巢中蜜 %d" % state.reserve
	objective_label.text = hive.heading()
	message_label.text = hive.body_text()
	primary_button.text = hive.action_text()
	primary_button.disabled = not hive.ready_for_sortie
	primary_button.visible = true
	action_button.visible = false
	return_button.visible = false


func _on_primary_button() -> void:
	if router.current_area_id != "hive_threshold":
		return
	var hive := router.current_area as HiveThresholdArea
	hive.request_sortie()


func _press_action() -> void:
	if router.current_area_id == "spring_field":
		Input.action_press("action")


func _release_action() -> void:
	if Input.is_action_pressed("action"):
		Input.action_release("action")


func _pulse_return() -> void:
	if router.current_area_id != "spring_field":
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
	if router != null and router.current_area_id == "spring_field":
		var field := router.current_area as SpringJourneyField
		if field != null:
			field.set_input_enabled(not paused_for_focus)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		paused_for_focus = true
		_release_action()
		if Input.is_action_pressed("return_hive"):
			Input.action_release("return_hive")
		_set_field_input_enabled(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		paused_for_focus = false
		if not transitioning:
			_set_field_input_enabled(true)


func _set_field_input_enabled(enabled: bool) -> void:
	if router == null or router.current_area_id != "spring_field":
		return
	var field := router.current_area as SpringJourneyField
	if field != null:
		field.set_input_enabled(enabled)


func _return_to_title() -> void:
	_release_action()
	get_tree().change_scene_to_file(LEGACY_TITLE_PATH)


func _exit_tree() -> void:
	_release_action()
	if Input.is_action_pressed("return_hive"):
		Input.action_release("return_hive")
