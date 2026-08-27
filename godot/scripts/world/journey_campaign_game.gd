class_name JourneyCampaignGame
extends Node

const CampaignStateScript := preload("res://scripts/world/journey_campaign_state.gd")
const CampaignRouterScript := preload("res://scripts/world/journey_campaign_area_router.gd")
const PersistenceScript := preload("res://scripts/system/commercial_persistence.gd")
const CommercialMenuScript := preload("res://scripts/ui/commercial_system_menu.gd")
const COMMERCIAL_TITLE_PATH := "res://commercial_title.tscn"
const CAMPAIGN_SCENE_PATH := "res://campaign.tscn"

var state = CampaignStateScript.new()
var router: JourneyCampaignAreaRouter
var area_host: Node2D
var persistence: CommercialPersistenceService
var system_menu: CommercialSystemMenu
var sound: SoundFeedback
var transitioning := false
var transition_duration := 0.28
var full_transition_duration := 0.28
var paused_by_menu := false
var paused_for_focus := false
var session_persistence_active := false
var current_status: Dictionary = {}
var story_time := 0.0
var failed_level_id := ""
var failed_replay := false
var failed_token := -1
var last_checkpoint_error := OK
var unsaved_exit_confirmation := ""

var ui_layer: CanvasLayer
var top_panel: ColorRect
var title_label: Label
var area_label: Label
var energy_label: Label
var reserve_label: Label
var timer_label: Label
var save_label: Label
var pause_button: Button
var board_panel: ColorRect
var board_heading: Label
var board_progress: Label
var board_detail_title: Label
var board_detail_body: Label
var board_detail_trace: Label
var board_primary_button: Button
var level_buttons: Dictionary = {}
var field_panel: ColorRect
var field_heading_label: Label
var objective_label: Label
var message_label: Label
var action_button: Button
var return_button: Button
var controls_label: Label
var story_card: ColorRect
var story_label: Label
var failure_panel: ColorRect
var failure_label: Label
var retry_button: Button
var back_hive_button: Button
var fade: ColorRect
var fade_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not state.is_ready():
		push_error("24 关战役目录无法加载：%s" % state.catalog.catalog_error)
		return
	sound = get_node_or_null("SoundFeedback") as SoundFeedback
	if sound == null:
		push_error("正式战役缺少共享动作音效节点")
		return
	persistence = get_node_or_null("/root/CommercialPersistence") as CommercialPersistenceService
	if persistence == null:
		persistence = PersistenceScript.new()
		persistence.name = "LocalCommercialPersistence"
		add_child(persistence)
	var developer_no_persistence := "--developer-no-persistence" in OS.get_cmdline_user_args()
	var launch_requested := persistence.has_pending_launch_request() and not developer_no_persistence
	var running_as_product_scene := get_tree().current_scene == self
	session_persistence_active = not developer_no_persistence and (launch_requested or running_as_product_scene)
	var launch_mode := "new" if developer_no_persistence else persistence.consume_journey_launch(
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
	router = CampaignRouterScript.new()
	router.name = "AreaRouter"
	add_child(router)
	if router.configure(area_host) != OK:
		push_error("无法建立正式战役场景入口")
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
	persistence.settings_changed.connect(_apply_settings)
	_apply_settings(persistence.settings_snapshot())
	var audio := get_node_or_null("JourneyAudioDirector") as JourneyAudioDirector
	if audio != null:
		audio.bind_router(router)
	_show_hive(false, true)
	if restore_error != OK:
		_show_story("存档没有安全载入，已经从立春重新开始（错误 %d）。" % restore_error, 5.0)
	elif state.legacy_journey_completed:
		_show_story("上一版的四季短旅程已收进纪念格。正式二十四关从立春开始，每一关都等你亲自飞完。", 6.0)
	if session_persistence_active:
		_save_checkpoint()


func _build_interface() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "CampaignInterface"
	add_child(ui_layer)
	top_panel = ColorRect.new()
	top_panel.position = Vector2(18, 14)
	top_panel.size = Vector2(1244, 76)
	top_panel.color = Color("f4e8c8", 0.96)
	ui_layer.add_child(top_panel)
	title_label = _label(top_panel, "一会儿巢里见", Vector2(18, 6), Vector2(365, 36), 24, Color("263a31"))
	area_label = _label(top_panel, "主蜂巢 · 二十四趟", Vector2(20, 44), Vector2(340, 22), 12, Color("687166"))
	energy_label = _label(top_panel, "体力 —", Vector2(390, 20), Vector2(170, 34), 16, Color("4c4535"))
	reserve_label = _label(top_panel, "巢中储备 0", Vector2(575, 20), Vector2(170, 34), 16, Color("4c4535"))
	timer_label = _label(top_panel, "", Vector2(750, 20), Vector2(160, 34), 16, Color("4c4535"))
	save_label = _label(top_panel, "巢里已记好", Vector2(900, 24), Vector2(185, 28), 11, Color("687166"))
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pause_button = _button(top_panel, "暂停 / 菜单", Vector2(1092, 12), Vector2(134, 50), _open_pause_menu, false, 14)

	_build_board()
	_build_field_panel()
	_build_story_card()
	_build_failure_panel()

	fade = ColorRect.new()
	fade.position = Vector2.ZERO
	fade.size = Vector2(1280, 720)
	fade.color = Color("20372f", 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(fade)
	fade_label = _label(fade, "", Vector2(260, 300), Vector2(760, 92), 29, Color("fff0b5"))
	fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_board() -> void:
	board_panel = ColorRect.new()
	board_panel.position = Vector2(32, 106)
	board_panel.size = Vector2(930, 586)
	board_panel.color = Color("f4edda", 0.955)
	board_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(board_panel)
	board_heading = _label(board_panel, "二十四趟花田小事", Vector2(38, 14), Vector2(520, 38), 25, Color("2b4036"))
	board_progress = _label(board_panel, "0 / 24", Vector2(710, 18), Vector2(170, 30), 15, Color("667166"))
	board_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var season_names := ["春", "夏", "秋", "冬"]
	for row in 4:
		var season_label := _label(board_panel, season_names[row], Vector2(18, 76 + row * 82), Vector2(36, 48), 20, Color("6d6048"))
		season_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for entry in state.catalog.levels():
		var number := int(entry.number)
		var row := (number - 1) / 6
		var column := (number - 1) % 6
		var level_id := String(entry.id)
		var button := _button(
			board_panel,
			"%02d  %s" % [number, String(entry.term_name)],
			Vector2(62 + column * 141, 70 + row * 82),
			Vector2(128, 58),
			func(): _select_level(level_id),
			false,
			13
		)
		var season_fill: Color = [Color("f0d6c7"), Color("ece2aa"), Color("ead3b3"), Color("d7e4e1")][row]
		button.add_theme_stylebox_override("disabled", _button_style(Color(season_fill, 0.76), Color("8b816d", 0.48)))
		button.add_theme_color_override("font_disabled_color", Color("6f7169", 0.72))
		button.tooltip_text = String(entry.intro)
		level_buttons[level_id] = button
	var divider := ColorRect.new()
	divider.position = Vector2(34, 406)
	divider.size = Vector2(862, 2)
	divider.color = Color("b9a77c", 0.58)
	board_panel.add_child(divider)
	board_detail_title = _label(board_panel, "", Vector2(38, 420), Vector2(540, 35), 21, Color("2b4036"))
	board_detail_body = _label(board_panel, "", Vector2(38, 458), Vector2(575, 92), 14, Color("4a584f"))
	board_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_detail_trace = _label(board_panel, "", Vector2(625, 420), Vector2(268, 80), 12, Color("6b715d"))
	board_detail_trace.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_primary_button = _button(board_panel, "出发", Vector2(645, 508), Vector2(230, 54), _request_hive_sortie, true, 17)


func _build_field_panel() -> void:
	field_panel = ColorRect.new()
	field_panel.position = Vector2(1008, 106)
	field_panel.size = Vector2(254, 586)
	field_panel.color = Color("f4edda", 0.94)
	field_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(field_panel)
	field_heading_label = _label(field_panel, "这一趟", Vector2(18, 16), Vector2(218, 26), 13, Color("6a705e"))
	objective_label = _label(field_panel, "", Vector2(18, 50), Vector2(218, 190), 15, Color("29382f"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label = _label(field_panel, "", Vector2(18, 252), Vector2(218, 150), 13, Color("4d594f"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_button = _button(field_panel, "情境动作", Vector2(15, 421), Vector2(132, 58), _press_field_action, true, 15)
	return_button = _button(field_panel, "归巢", Vector2(154, 421), Vector2(84, 58), _press_return, false, 14)
	controls_label = _label(field_panel, "WASD / 左摇杆移动\n空格 / A 互动 · Q / Y 归巢", Vector2(18, 502), Vector2(218, 58), 11, Color("737866"))
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_story_card() -> void:
	story_card = ColorRect.new()
	story_card.position = Vector2(245, 218)
	story_card.size = Vector2(720, 230)
	story_card.color = Color("f7eed3", 0.985)
	story_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_card.visible = false
	ui_layer.add_child(story_card)
	story_label = _label(story_card, "", Vector2(42, 30), Vector2(636, 170), 21, Color("2f4238"))
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_failure_panel() -> void:
	failure_panel = ColorRect.new()
	failure_panel.position = Vector2(300, 180)
	failure_panel.size = Vector2(680, 350)
	failure_panel.color = Color("f5e9ca", 0.992)
	failure_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	failure_panel.visible = false
	ui_layer.add_child(failure_panel)
	var heading := _label(failure_panel, "这趟先回巢理一理", Vector2(50, 35), Vector2(580, 48), 29, Color("2c4137"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_label = _label(failure_panel, "", Vector2(85, 100), Vector2(510, 105), 17, Color("4b5b51"))
	failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_button = _button(failure_panel, "再飞一次", Vector2(110, 240), Vector2(210, 58), _retry_failed_level, true, 17)
	back_hive_button = _button(failure_panel, "先回主巢", Vector2(360, 240), Vector2(210, 58), _leave_failed_level, false, 16)


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


func _button(
	parent: Node,
	text: String,
	position: Vector2,
	size: Vector2,
	callback: Callable,
	primary := false,
	font_size := 15
) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", font_size)
	button.set_meta("commercial_base_font_size", font_size)
	button.add_theme_color_override("font_color", Color("273c32"))
	button.add_theme_color_override("font_disabled_color", Color("8b8a7d"))
	button.add_theme_stylebox_override("normal", _button_style(Color("dfbb5d") if primary else Color("e8ddbd"), Color("6d5b38")))
	button.add_theme_stylebox_override("hover", _button_style(Color("f0cf72") if primary else Color("f4e9c9"), Color("405d50"), 3))
	button.add_theme_stylebox_override("pressed", _button_style(Color("cda84c") if primary else Color("d8cba8"), Color("334b40"), 3))
	button.add_theme_stylebox_override("focus", _button_style(Color("000000", 0.0), Color("fff0a8"), 4))
	button.add_theme_stylebox_override("disabled", _button_style(Color("ded5bc", 0.82), Color("8b806b", 0.42)))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _button_style(fill: Color, border: Color, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _process(delta: float) -> void:
	if story_time > 0.0 and not get_tree().paused:
		story_time = maxf(0.0, story_time - delta)
		if story_time <= 0.0:
			story_card.visible = false


func _show_hive(returning: bool, immediate := false) -> void:
	if transitioning and not immediate:
		return
	transitioning = true
	_show_fade("巢里见" if returning else "主蜂巢", immediate)
	var error := router.change_area("hive_threshold", state.hive_context(returning))
	if error != OK:
		push_error("主蜂巢场景切换失败：%d" % error)
		_finish_transition()
		return
	_connect_hive(router.current_area as JourneyCampaignHive)
	board_panel.visible = true
	field_panel.visible = false
	failure_panel.visible = false
	_refresh_hive_interface()
	_finish_fade(immediate)


func _connect_hive(hive: JourneyCampaignHive) -> void:
	if hive == null:
		return
	hive.sortie_requested.connect(_begin_level)
	hive.presentation_finished.connect(_refresh_hive_interface)
	hive.selection_changed.connect(_on_hive_selection_changed)


func _refresh_hive_interface() -> void:
	var hive := router.current_area as JourneyCampaignHive
	if hive == null:
		return
	board_heading.text = hive.heading()
	board_progress.text = "%d / %d · 储备 %d" % [state.completed_count(), JourneyLevelCatalog.TOTAL_LEVELS, state.reserve]
	title_label.text = "一会儿巢里见"
	area_label.text = "主蜂巢 · 四季接货台"
	energy_label.text = "体力 —"
	reserve_label.text = "巢中储备 %d" % state.reserve
	timer_label.text = ""
	_refresh_level_buttons()
	_on_hive_selection_changed(hive.selected_entry())


func _refresh_level_buttons() -> void:
	for entry in state.level_select_entries():
		var button := level_buttons.get(String(entry.id)) as Button
		if button == null:
			continue
		var prefix := "✓" if bool(entry.completed) else ("→" if bool(entry.available) else "·")
		var suffix := " ★" if String(entry.kind) == "climax" else ""
		button.text = "%s %02d %s%s" % [prefix, int(entry.number), String(entry.term_name), suffix]
		button.disabled = not bool(entry.available)


func _on_hive_selection_changed(entry: Dictionary) -> void:
	if entry.is_empty():
		board_detail_title.text = "先选一趟"
		board_detail_body.text = "亮着的下一关可以推进；打勾的关卡可以重飞。"
		board_detail_trace.text = ""
		board_primary_button.disabled = true
		return
	var replay := bool(entry.get("completed", false))
	board_detail_title.text = "%02d · %s · %s" % [int(entry.number), String(entry.term_name), "季节大忙 · 三回" if String(entry.kind) == "climax" else "日常一趟"]
	board_detail_body.text = String(entry.intro)
	var best: Dictionary = entry.get("best", {})
	var best_line := ""
	if not best.is_empty():
		best_line = "\n最好用时 %s" % _format_time(float(best.get("elapsed_seconds", 0.0)))
	board_detail_trace.text = ("已留下：" if replay else "会留下：") + String(entry.world_trace) + best_line
	board_primary_button.text = "重飞 %s" % String(entry.term_name) if replay else "出发去 %s" % String(entry.term_name)
	board_primary_button.disabled = not bool(entry.get("available", false))


func _select_level(level_id: String) -> void:
	var hive := router.current_area as JourneyCampaignHive
	if hive != null and hive.select_level(level_id):
		_on_hive_selection_changed(hive.selected_entry())


func _request_hive_sortie() -> void:
	var hive := router.current_area as JourneyCampaignHive
	if hive != null:
		hive.request_selected_sortie()


func _begin_level(level_id: String, replay: bool) -> void:
	if transitioning:
		return
	var token := state.begin_level(level_id, replay)
	if token < 0:
		var hive := router.current_area as JourneyCampaignHive
		if hive != null:
			hive.set_departure_input_enabled(true)
		return
	var context := state.active_level_context()
	context["sound_feedback"] = sound
	var level: Dictionary = context.level
	transitioning = true
	_show_fade("%02d · %s" % [int(level.number), String(level.term_name)], false)
	var error := router.change_area(String(level.scene_key), context)
	if error != OK:
		state.abandon_attempt(token)
		push_error("关卡场景切换失败：%d" % error)
		_show_hive(false, true)
		return
	var field := router.current_area as JourneyCampaignField
	field.set_input_enabled(false)
	field.status_changed.connect(_on_field_status)
	field.journey_completed.connect(_on_level_completed)
	field.attempt_failed.connect(_on_attempt_failed)
	board_panel.visible = false
	field_panel.visible = true
	_on_field_status(field.status_snapshot())
	_finish_fade(false)


func _on_field_status(snapshot: Dictionary) -> void:
	current_status = snapshot.duplicate(true)
	var climax := bool(snapshot.get("is_climax", false))
	if climax:
		title_label.text = "%02d · %s · %s" % [
			int(snapshot.get("level_number", 1)),
			String(snapshot.get("term_name", "花田")),
			String(snapshot.get("display_name", "季节大忙")),
		]
		title_label.add_theme_font_size_override("font_size", 20)
		field_heading_label.text = "季节大忙 · 第 %d / 3 回" % int(snapshot.get("phase", 1))
	else:
		title_label.text = "%02d · %s" % [int(snapshot.get("level_number", 1)), String(snapshot.get("term_name", "花田"))]
		title_label.add_theme_font_size_override("font_size", 24)
		field_heading_label.text = "这一趟"
	area_label.text = String(snapshot.get("area", "四季花田"))
	energy_label.text = "体力 %d / %d" % [roundi(float(snapshot.get("energy", 0.0))), roundi(float(snapshot.get("energy_cap", 360.0)))]
	reserve_label.text = "巢中储备 %d" % state.reserve
	timer_label.text = "天气窗 %s" % _format_time(float(snapshot.get("time_remaining", 0.0)))
	var lines: Array = snapshot.get("objective_lines", [])
	objective_label.text = "\n".join(lines)
	if climax:
		objective_label.text += "\n\n" + String(snapshot.get("phase_instruction", ""))
	if bool(snapshot.get("has_collection", false)):
		objective_label.text += "\n\n蜜囊 %d / %d · 已交 %d" % [
			int(snapshot.get("honey_cargo", 0)),
			int(snapshot.get("capacity", 4)),
			int(snapshot.get("delivered_cargo", 0)),
		]
	message_label.text = String(snapshot.get("message", ""))
	if bool(snapshot.get("hazard_active", false)):
		message_label.text += "\n\n天气正在过路；叶棚内更稳。"
	action_button.text = String(snapshot.get("action_label", "看看最近花标"))
	action_button.disabled = not bool(snapshot.get("action_enabled", true))
	return_button.text = String(snapshot.get("return_label", "指路回巢"))


func _press_field_action() -> void:
	var field := router.current_area as JourneyCampaignField
	if field != null:
		field.request_primary_action()


func _press_return() -> void:
	var field := router.current_area as JourneyCampaignField
	if field != null:
		field.request_secondary_action()


func _on_level_completed(payload: Dictionary) -> void:
	call_deferred("_settle_and_return", payload.duplicate(true))


func _settle_and_return(payload: Dictionary) -> void:
	if transitioning or not state.can_settle_level(payload):
		return
	transitioning = true
	_set_field_input_enabled(false)
	var level: Dictionary = state.catalog.level_by_id(String(payload.level_id))
	_show_fade("回巢交接 · %s" % String(level.term_name), false)
	# Load the safe home scene before mutating permanent state. If scene creation
	# ever fails, the field and token remain available for a clean retry.
	var preview_context := state.hive_context(false)
	preview_context["returning"] = true
	preview_context["return_level_id"] = String(payload.level_id)
	var route_error := router.change_area("hive_threshold", preview_context)
	if route_error != OK:
		push_error("结算前无法载入主蜂巢：%d" % route_error)
		var failed_area := router.current_area
		if failed_area != null and failed_area.has_method("resume_after_failed_transition"):
			failed_area.resume_after_failed_transition()
		_finish_transition()
		return
	var settlement := state.settle_level(payload)
	if settlement.is_empty():
		push_error("关卡结算合同在场景切换后失效")
		return
	var hive := router.current_area as JourneyCampaignHive
	hive.configure(state.hive_context(true))
	_connect_hive(hive)
	board_panel.visible = true
	field_panel.visible = false
	failure_panel.visible = false
	_refresh_hive_interface()
	if sound != null:
		sound.play_cue("complete")
	_save_checkpoint()
	var story := "%s · %s\n%s" % [String(level.term_name), String(level.chronicle_title), String(level.world_trace)]
	if bool(settlement.replay):
		story = "%s重飞完成。储备没有重复增加，最好用时已照实比较。" % String(level.term_name)
	elif bool(settlement.journey_complete):
		story = "大寒 · 最后一墙立稳啦\n你给新蜂示范了回巢路线。老师傅往旁边让了一步：这回你来。\n你：一会儿巢里见。"
	_show_story(story, 6.0 if bool(settlement.journey_complete) else 4.8)
	_finish_fade(false)


func _on_attempt_failed(reason: String, snapshot: Dictionary) -> void:
	if transitioning or router.current_area == null:
		return
	failed_level_id = String(snapshot.get("level_id", state.active_level_id))
	failed_replay = state.active_run_mode == JourneyCampaignState.RUN_REPLAY
	failed_token = state.active_token
	state.abandon_attempt(failed_token)
	failure_label.text = reason + "\n已经完成的关卡、储备与纪事都不会受影响。"
	failure_panel.visible = true
	field_panel.visible = false
	retry_button.grab_focus()


func _retry_failed_level() -> void:
	if failed_level_id.is_empty():
		return
	failure_panel.visible = false
	var retry_level := failed_level_id
	var replay := failed_replay
	failed_level_id = ""
	_begin_level(retry_level, replay)


func _leave_failed_level() -> void:
	failure_panel.visible = false
	failed_level_id = ""
	_show_hive(false, false)


func _show_story(text: String, duration := 4.0) -> void:
	story_label.text = text
	story_card.visible = true
	story_time = maxf(0.1, duration)


func _show_fade(caption: String, immediate: bool) -> void:
	fade_label.text = caption
	fade.color.a = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if immediate:
		fade.color.a = 0.0
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _finish_fade(immediate: bool) -> void:
	if immediate or transition_duration <= 0.0:
		_finish_transition()
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade, "color:a", 0.0, transition_duration)
	tween.finished.connect(_finish_transition)


func _finish_transition() -> void:
	fade.color.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_label.text = ""
	transitioning = false
	if paused_for_focus and not paused_by_menu:
		call_deferred("_open_pause_menu", true)
		return
	_set_field_input_enabled(not paused_for_focus and not paused_by_menu)


func _set_field_input_enabled(enabled: bool) -> void:
	var field: JourneyCampaignField
	if router != null:
		field = router.current_area as JourneyCampaignField
	if field != null:
		field.set_input_enabled(enabled)


func _format_time(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		paused_for_focus = true
		if sound != null:
			sound.set_enabled(false)
		_set_field_input_enabled(false)
		if not paused_by_menu and not transitioning:
			call_deferred("_open_pause_menu", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		paused_for_focus = false
		if sound != null and not paused_by_menu:
			sound.set_enabled(true)
		if not transitioning and not paused_by_menu:
			_set_field_input_enabled(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		if system_menu != null and system_menu.is_open():
			system_menu.request_cancel()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	# The game host processes while SceneTree is paused so it can own the pause
	# surface. Never let the same ALWAYS mode send an action through that surface
	# to the hive behind it.
	if paused_by_menu or paused_for_focus or (system_menu != null and system_menu.is_open()):
		if event.is_action_pressed("action"):
			get_viewport().set_input_as_handled()
		return
	if router != null and router.current_area_id == "hive_threshold" and event.is_action_pressed("action"):
		_request_hive_sortie()
		get_viewport().set_input_as_handled()


func _open_pause_menu(focus_was_lost := false) -> void:
	if focus_was_lost and not paused_for_focus:
		return
	if paused_by_menu or transitioning or system_menu == null:
		return
	paused_by_menu = true
	if sound != null:
		sound.set_enabled(false)
	_set_field_input_enabled(false)
	get_tree().paused = true
	system_menu.open_pause(focus_was_lost)
	if last_checkpoint_error != OK:
		system_menu.show_pause_notice(
			"自动保存还没有成功（错误 %d）。请先腾出存储空间或检查权限；返回标题或退出时会再试一次。"
			% last_checkpoint_error
		)


func _resume_from_menu() -> void:
	if not paused_by_menu:
		return
	if paused_for_focus:
		system_menu.open_pause(true)
		return
	paused_by_menu = false
	unsaved_exit_confirmation = ""
	get_tree().paused = false
	if sound != null:
		sound.set_enabled(true)
	system_menu.close()
	if not transitioning:
		_set_field_input_enabled(true)


func _return_to_title() -> void:
	if not _checkpoint_allows_exit("return_to_title"):
		return
	if paused_by_menu:
		paused_by_menu = false
		get_tree().paused = false
	if system_menu != null:
		system_menu.close()
	get_tree().change_scene_to_file(COMMERCIAL_TITLE_PATH)


func _restart_new_journey() -> void:
	var delete_error := persistence.delete_progress() if persistence != null else ERR_UNCONFIGURED
	if delete_error != OK:
		if system_menu != null:
			system_menu.open_pause(false)
		return
	persistence.request_journey_launch("new")
	if paused_by_menu:
		paused_by_menu = false
		get_tree().paused = false
	get_tree().change_scene_to_file(CAMPAIGN_SCENE_PATH)


func _quit_game() -> void:
	if not _checkpoint_allows_exit("quit"):
		return
	if paused_by_menu:
		paused_by_menu = false
		get_tree().paused = false
	get_tree().quit()


func _save_checkpoint() -> Error:
	if not session_persistence_active or persistence == null:
		last_checkpoint_error = OK
		unsaved_exit_confirmation = ""
		return OK
	var error := persistence.save_journey_state(state)
	last_checkpoint_error = error
	if error == OK:
		save_label.text = "已保存 · 主蜂巢"
		unsaved_exit_confirmation = ""
	else:
		save_label.text = "存档失败 · 请暂停重试"
	return error


func _checkpoint_allows_exit(action: String) -> bool:
	if not session_persistence_active or last_checkpoint_error == OK:
		return true
	var already_confirmed := unsaved_exit_confirmation == action
	if _save_checkpoint() == OK:
		return true
	if already_confirmed:
		return true
	unsaved_exit_confirmation = action
	if system_menu != null:
		var action_name := "返回标题" if action == "return_to_title" else "退出游戏"
		system_menu.show_pause_notice(
			"自动保存再次失败（错误 %d），本次返巢后的进度还只在内存里。\n再按一次“%s”会明确放弃这部分进度；也可以继续游戏，处理存储空间后再试。"
			% [last_checkpoint_error, action_name]
		)
	return false


func _apply_settings(next_settings: Dictionary) -> void:
	transition_duration = 0.0 if bool(next_settings.get("reduce_motion", false)) else full_transition_duration
	if controls_label != null:
		controls_label.visible = bool(next_settings.get("show_control_hints", true))
	if ui_layer == null:
		return
	var scale := float(next_settings.get("ui_scale", 1.0))
	for node in ui_layer.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null and control.has_meta("commercial_base_font_size"):
			control.add_theme_font_size_override("font_size", roundi(float(control.get_meta("commercial_base_font_size")) * scale))
