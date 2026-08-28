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
var transition_layer: CanvasLayer
var top_panel: ColorRect
var title_label: Label
var area_label: Label
var energy_label: Label
var cargo_label: Label
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
var objective_toggle_button: Button
var toast_panel: ColorRect
var message_label: Label
var action_panel: ColorRect
var action_button: Button
var return_button: Button
var controls_label: Label
var modal_barrier: Button
var story_card: ColorRect
var story_label: Label
var story_continue_label: Label
var failure_panel: ColorRect
var failure_label: Label
var retry_button: Button
var back_hive_button: Button
var fade: ColorRect
var fade_label: Label
var field_hud_visible := false
var field_hud_collapsed := false
var controls_hint_enabled := true
var toast_time := 0.0
var last_toast_message := ""
var current_ui_scale := 1.0
var pending_hive_story_text := ""
var pending_hive_story_duration := 0.0
var energy_tutorial_version_seen := 0
var modal_action_armed := true
var captured_modal_touches: Dictionary = {}

const FIELD_TOAST_SECONDS := 4.8
const FIELD_OBJECTIVE_SIZE := Vector2(620, 118)
const FIELD_OBJECTIVE_COLLAPSED_SIZE := Vector2(56, 54)
const FIELD_OBJECTIVE_TOGGLE_SIZE := Vector2(44, 44)
const FIELD_OBJECTIVE_TOGGLE_EXPANDED_POS := Vector2(616, 108)
const FIELD_OBJECTIVE_TOGGLE_COLLAPSED_POS := Vector2(24, 109)
const FIELD_PLAY_SAFE_RIGHT := 1008.0


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
	energy_tutorial_version_seen = maxi(
		0,
		int(persistence.setting("campaign_energy_tutorial_version", 0))
	)
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
	elif not state.legacy_campaign_progress.is_empty():
		var archived_count := int(state.legacy_campaign_progress.get("completed_count", 0))
		var migration_summary := persistence.progress_summary() if session_persistence_active else {}
		var backup_note := (
			"原始旧档已另存保护。"
			if bool(migration_summary.get("protected_v2_backup", false))
			else "原始旧档会在首次保存前另存保护。"
		)
		if state.journey_complete:
			_show_story(
				"旧版 %d/24 已封存，正式 24/24 也已完成。%s" % [archived_count, backup_note],
				6.0
			)
		else:
			var next_term_name := String(state.next_level().get("term_name", "下一关"))
			_show_story(
				"旧版 %d/24 已封存，正式进度从%s继续。旧版完成不会代替新关卡里的事件；%s"
				% [archived_count, next_term_name, backup_note],
				7.0
			)
	elif state.legacy_journey_completed:
		_show_story("上一版的四季短旅程已收进纪念格。正式二十四关从立春开始，每一关都等你亲自飞完。", 6.0)
	if session_persistence_active:
		_save_checkpoint()


func _build_interface() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "CampaignInterface"
	add_child(ui_layer)
	transition_layer = CanvasLayer.new()
	transition_layer.name = "CampaignTransitionLayer"
	transition_layer.layer = 100
	add_child(transition_layer)
	top_panel = ColorRect.new()
	top_panel.position = Vector2(18, 14)
	top_panel.size = Vector2(1244, 76)
	top_panel.color = Color("f4e8c8", 0.96)
	ui_layer.add_child(top_panel)
	title_label = _label(top_panel, "一会儿巢里见", Vector2(18, 6), Vector2(250, 36), 24, Color("263a31"))
	area_label = _label(top_panel, "主蜂巢 · 二十四趟", Vector2(20, 44), Vector2(248, 22), 12, Color("687166"))
	# The reason text is part of the stamina contract, so reserve enough width for
	# states such as "休息点 · 快速回满" even at 130% UI scale.
	energy_label = _label(top_panel, "体力 —", Vector2(280, 20), Vector2(274, 34), 13, Color("4c4535"))
	cargo_label = _label(top_panel, "蜜囊 —", Vector2(562, 20), Vector2(120, 34), 16, Color("4c4535"))
	reserve_label = _label(top_panel, "储备 0", Vector2(690, 20), Vector2(110, 34), 16, Color("4c4535"))
	timer_label = _label(top_panel, "", Vector2(808, 20), Vector2(120, 34), 16, Color("4c4535"))
	save_label = _label(top_panel, "巢里已记好", Vector2(936, 24), Vector2(128, 28), 11, Color("687166"))
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pause_button = _button(top_panel, "暂停 / 菜单", Vector2(1082, 12), Vector2(144, 50), _open_pause_menu, false, 14)
	var top_labels: Array[Label] = [title_label, area_label, energy_label, cargo_label, reserve_label, timer_label, save_label]
	for top_label in top_labels:
		_prepare_single_line_label(top_label)

	_build_board()
	_build_field_panel()
	_build_modal_barrier()
	_build_story_card()
	_build_failure_panel()

	fade = ColorRect.new()
	fade.position = Vector2.ZERO
	fade.size = Vector2(1280, 720)
	fade.color = Color("20372f", 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_layer.add_child(fade)
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
		# The fixed detail pane below is the only long-form explanation surface.
		# Native hover tooltips float across the board and obscure other terms.
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
	field_panel.name = "CurrentObjectiveCard"
	field_panel.position = Vector2(18, 104)
	field_panel.size = FIELD_OBJECTIVE_SIZE
	field_panel.color = Color("f4edda", 0.92)
	# The card is visual decoration except for its explicit toggle. Empty paper
	# must not steal a mouse/touch destination from the field underneath.
	field_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(field_panel)
	field_heading_label = _label(field_panel, "当前", Vector2(18, 8), Vector2(520, 26), 13, Color("6a705e"))
	field_heading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prepare_single_line_label(field_heading_label)
	objective_label = _label(field_panel, "", Vector2(18, 35), Vector2(574, 76), 14, Color("29382f"))
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.max_lines_visible = 3
	objective_label.clip_text = true
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Keep the actual control outside the click-through decoration subtree so its
	# keyboard, mouse and touch behavior is explicit on every Godot backend.  The
	# arrow is visually small, while its full 44px square remains easy to tap.
	objective_toggle_button = _button(
		ui_layer,
		"→",
		FIELD_OBJECTIVE_TOGGLE_EXPANDED_POS,
		FIELD_OBJECTIVE_TOGGLE_SIZE,
		_toggle_field_hud,
		false,
		16
	)
	objective_toggle_button.name = "ObjectiveToggleButton"
	objective_toggle_button.tooltip_text = "收起当前目标；操作按钮和资源状态会继续保留"
	objective_toggle_button.pivot_offset = FIELD_OBJECTIVE_TOGGLE_SIZE * 0.5
	objective_toggle_button.rotation_degrees = -90.0
	_style_objective_toggle()

	toast_panel = ColorRect.new()
	toast_panel.name = "FieldMessageToast"
	toast_panel.position = Vector2(250, 586)
	toast_panel.size = Vector2(630, 62)
	toast_panel.color = Color("283d34", 0.91)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	ui_layer.add_child(toast_panel)
	message_label = _label(toast_panel, "", Vector2(20, 7), Vector2(590, 48), 13, Color("fff4d2"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = 2
	message_label.clip_text = true
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	action_panel = ColorRect.new()
	action_panel.name = "FieldActionTray"
	# Campaign fields clamp all actors and work markers at x=1008. Keep the
	# entire interactive tray to the right of that same authoritative boundary.
	action_panel.position = Vector2(FIELD_PLAY_SAFE_RIGHT + 10.0, 514)
	action_panel.size = Vector2(244, 188)
	action_panel.color = Color("f4edda", 0.94)
	action_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(action_panel)
	action_button = _button(action_panel, "情境动作", Vector2(10, 10), Vector2(224, 76), _press_field_action, true, 15)
	return_button = _button(action_panel, "指路回巢", Vector2(10, 102), Vector2(224, 76), _press_return, false, 14)
	_prepare_button_text(action_button)
	_prepare_button_text(return_button)

	controls_label = _label(
		ui_layer,
		"WASD/摇杆 移动 · 双击方向 急转 · 空格/A 主动作 · Q/Y 次动作",
		Vector2(18, 672),
		Vector2(850, 30),
		11,
		Color("f7edcf")
	)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prepare_single_line_label(controls_label)
	_set_field_hud_visible(false)


func _build_modal_barrier() -> void:
	# The barrier sits above ordinary HUD and below story/failure controls. Mouse
	# confirms on button-down, so a release after result -> story cannot advance a
	# second layer. Native touch is routed explicitly in _unhandled_input because
	# this project deliberately disables touch-to-mouse emulation.
	modal_barrier = Button.new()
	modal_barrier.name = "ModalInputBarrier"
	modal_barrier.position = Vector2.ZERO
	modal_barrier.size = Vector2(1280, 720)
	modal_barrier.flat = true
	modal_barrier.self_modulate = Color(1, 1, 1, 0)
	modal_barrier.focus_mode = Control.FOCUS_NONE
	modal_barrier.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_barrier.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	modal_barrier.visible = false
	modal_barrier.pressed.connect(_confirm_active_modal)
	ui_layer.add_child(modal_barrier)


func _build_story_card() -> void:
	story_card = ColorRect.new()
	story_card.position = Vector2(245, 218)
	story_card.size = Vector2(720, 230)
	story_card.color = Color("f7eed3", 0.985)
	story_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_card.visible = false
	ui_layer.add_child(story_card)
	story_label = _label(story_card, "", Vector2(42, 24), Vector2(636, 150), 21, Color("2f4238"))
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_continue_label = _label(
		story_card,
		"按空格 / A，或轻点继续",
		Vector2(42, 184),
		Vector2(636, 28),
		12,
		Color("6a705e")
	)
	story_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prepare_single_line_label(story_continue_label)


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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("commercial_base_font_size", font_size)
	parent.add_child(label)
	return label


func _prepare_single_line_label(label: Label) -> void:
	if label == null:
		return
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _prepare_button_text(button: Button) -> void:
	if button == null:
		return
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


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
	button.add_theme_color_override("font_hover_color", Color("1f3c31"))
	button.add_theme_color_override("font_pressed_color", Color("1b322a"))
	button.add_theme_color_override("font_focus_color", Color("273c32"))
	button.add_theme_color_override("font_disabled_color", Color("8b8a7d"))
	button.add_theme_stylebox_override("normal", _button_style(Color("dfbb5d") if primary else Color("e8ddbd"), Color("6d5b38")))
	button.add_theme_stylebox_override("hover", _button_style(Color("f0cf72") if primary else Color("f4e9c9"), Color("405d50"), 3))
	button.add_theme_stylebox_override("pressed", _button_style(Color("cda84c") if primary else Color("d8cba8"), Color("334b40"), 3))
	button.add_theme_stylebox_override("focus", _button_style(Color("000000", 0.0), Color("fff0a8"), 4))
	button.add_theme_stylebox_override("disabled", _button_style(Color("ded5bc", 0.82), Color("8b806b", 0.42)))
	_prepare_button_text(button)
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


func _style_objective_toggle() -> void:
	if objective_toggle_button == null:
		return
	objective_toggle_button.add_theme_stylebox_override(
		"normal", _button_style(Color("f4edda", 0.18), Color("6d5b38", 0.0), 0)
	)
	objective_toggle_button.add_theme_stylebox_override(
		"hover", _button_style(Color("f4e9c9", 0.82), Color("405d50", 0.72), 2)
	)
	objective_toggle_button.add_theme_stylebox_override(
		"pressed", _button_style(Color("d8cba8", 0.88), Color("334b40", 0.78), 2)
	)
	objective_toggle_button.add_theme_stylebox_override(
		"focus", _button_style(Color("000000", 0.0), Color("fff0a8"), 3)
	)


func _process(delta: float) -> void:
	# Duration remains useful for authored pacing and tests, but story is a modal
	# acknowledgement rather than a toast. Reaching zero never hides it.
	if story_time > 0.0 and not get_tree().paused:
		story_time = maxf(0.0, story_time - delta)
	if toast_time > 0.0 and not get_tree().paused:
		toast_time = maxf(0.0, toast_time - delta)
		if toast_time <= 0.0 and toast_panel != null:
			toast_panel.visible = false


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
	_set_field_hud_visible(false)
	failure_panel.visible = false
	_sync_modal_input_state()
	_refresh_hive_interface()
	_finish_fade(immediate)


func _connect_hive(hive: JourneyCampaignHive) -> void:
	if hive == null:
		return
	hive.sortie_requested.connect(_begin_level)
	hive.presentation_finished.connect(_on_hive_presentation_finished)
	hive.selection_changed.connect(_on_hive_selection_changed)


func _on_hive_presentation_finished() -> void:
	_refresh_hive_interface()
	if pending_hive_story_text.is_empty():
		_sync_modal_input_state()
		return
	var text := pending_hive_story_text
	var duration := pending_hive_story_duration
	pending_hive_story_text = ""
	pending_hive_story_duration = 0.0
	_show_story(text, duration)


func _queue_hive_story(text: String, duration: float) -> void:
	pending_hive_story_text = text
	pending_hive_story_duration = maxf(0.1, duration)
	# The result illustration and receiving line get their full beat first. The
	# story timer starts only from presentation_finished, so no reading time is
	# consumed behind that presentation.
	story_time = 0.0
	if story_card != null:
		story_card.visible = false
	_sync_modal_input_state()


func _refresh_hive_interface() -> void:
	var hive := router.current_area as JourneyCampaignHive
	if hive == null:
		return
	var keepsake_line := hive.legacy_keepsake_text()
	board_heading.text = hive.heading() if hive.presentation_time > 0.0 or keepsake_line.is_empty() else keepsake_line
	_set_base_font_size(board_heading, 17 if board_heading.text == keepsake_line else 25)
	board_progress.text = "%d / %d · 储备 %d" % [state.completed_count(), JourneyLevelCatalog.TOTAL_LEVELS, state.reserve]
	title_label.text = "一会儿巢里见"
	_set_base_font_size(title_label, 24)
	area_label.text = "主蜂巢 · 四季接货台"
	energy_label.text = "体力 —"
	cargo_label.text = "蜜囊 —"
	reserve_label.text = "储备 %d" % state.reserve
	timer_label.text = ""
	_refresh_level_buttons()
	_on_hive_selection_changed(hive.selected_entry())
	if hive.presentation_time > 0.0:
		board_detail_title.text = hive.heading()
		board_detail_body.text = hive.body_text()
		board_detail_trace.text = "结果演出结束后，再显示这一趟的纪事。"
		board_primary_button.text = hive.action_text()
		board_primary_button.disabled = false


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
	if _confirm_active_modal():
		return
	var hive := router.current_area as JourneyCampaignHive
	if hive != null and hive.select_level(level_id):
		_on_hive_selection_changed(hive.selected_entry())


func _request_hive_sortie() -> void:
	if _confirm_active_modal():
		return
	var hive := router.current_area as JourneyCampaignHive
	if hive != null:
		hive.request_selected_sortie()


func _begin_level(level_id: String, replay: bool) -> void:
	if transitioning or _modal_input_active():
		return
	pending_hive_story_text = ""
	pending_hive_story_duration = 0.0
	story_time = 0.0
	if story_card != null:
		story_card.visible = false
	var token := state.begin_level(level_id, replay)
	if token < 0:
		_sync_modal_input_state()
		return
	var context := state.active_level_context()
	context["sound_feedback"] = sound
	context["campaign_energy_tutorial_version"] = energy_tutorial_version_seen
	var level: Dictionary = context.level
	transitioning = true
	_sync_modal_input_state()
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
	field.event_checkpoint_reached.connect(_on_event_checkpoint_reached)
	board_panel.visible = false
	_set_field_hud_visible(true)
	_on_field_status(field.status_snapshot())
	_finish_fade(false)


func _on_field_status(snapshot: Dictionary) -> void:
	current_status = snapshot.duplicate(true)
	var climax := bool(snapshot.get("is_climax", false))
	var event_runtime: Dictionary = snapshot.get("event_runtime", {})
	if climax:
		title_label.text = "%02d · %s · %s" % [
			int(snapshot.get("level_number", 1)),
			String(snapshot.get("term_name", "花田")),
			String(snapshot.get("display_name", "季节大忙")),
		]
		_set_base_font_size(title_label, 20)
		field_heading_label.text = "第%d/3回" % int(snapshot.get("phase", 1))
	else:
		title_label.text = "%02d · %s" % [int(snapshot.get("level_number", 1)), String(snapshot.get("term_name", "花田"))]
		_set_base_font_size(title_label, 24)
		field_heading_label.text = "当前"
	if not event_runtime.is_empty():
		field_heading_label.text = "%s %02d/%02d" % [
			"自选" if bool(event_runtime.get("optional", false)) else "主线",
			int(event_runtime.get("current_event_number", 1)),
			int(event_runtime.get("event_count", 15)),
		]
	area_label.text = String(snapshot.get("area", "四季花田"))
	energy_label.text = "体力 %d / %d" % [roundi(float(snapshot.get("energy", 0.0))), roundi(float(snapshot.get("energy_cap", 100.0)))]
	var energy_state := _single_line_text(String(snapshot.get("energy_state", "")))
	if not energy_state.is_empty():
		energy_label.text += " · %s" % energy_state
	if bool(snapshot.get("has_collection", false)):
		cargo_label.text = "蜜囊 %d / %d" % [int(snapshot.get("honey_cargo", 0)), int(snapshot.get("capacity", 4))]
	else:
		cargo_label.text = "蜜囊 —"
	reserve_label.text = "储备 %d" % state.reserve
	timer_label.text = "天气 %s" % _format_time(float(snapshot.get("time_remaining", 0.0)))
	objective_label.text = _current_objective_text(snapshot)
	var toast_text := _field_toast_text(snapshot, objective_label.text)
	_show_field_toast(toast_text)
	_acknowledge_energy_tutorial_if_visible(snapshot, toast_text)
	action_button.text = String(snapshot.get("action_label", "看看最近花标"))
	action_button.disabled = not bool(snapshot.get("action_enabled", true))
	return_button.text = String(snapshot.get("return_label", "指路回巢"))
	controls_label.text = _field_controls_text(action_button.text, return_button.text)


func _current_objective_text(snapshot: Dictionary) -> String:
	if bool(snapshot.get("ready_to_return", false)):
		return "回主蜂巢，把这一趟工作交给接货蜂"
	var event_runtime: Dictionary = snapshot.get("event_runtime", {})
	if not event_runtime.is_empty():
		var title := _single_line_text(String(event_runtime.get("current_event_title", "")))
		var instruction := _single_line_text(String(snapshot.get(
			"player_instruction",
			event_runtime.get("player_instruction", event_runtime.get("ui_hint", ""))
		)))
		var progress := _single_line_text(String(snapshot.get(
			"progress_label",
			event_runtime.get("progress_label", "")
		)))
		var has_explicit_progress := snapshot.has("progress_label") or event_runtime.has("progress_label")
		if progress.is_empty() and not has_explicit_progress:
			var required := maxi(1, int(event_runtime.get("required", 1)))
			progress = "已完成 %d/%d" % [clampi(int(event_runtime.get("progress", 0)), 0, required), required]
		var lines: Array[String] = []
		if not title.is_empty():
			lines.append(title)
		if not instruction.is_empty() and instruction != title:
			lines.append(instruction)
		if not progress.is_empty() and progress != instruction and progress != title:
			lines.append(progress)
		if lines.is_empty():
			return "看看最近发亮的花标"
		return "\n".join(lines)
	if bool(snapshot.get("is_climax", false)):
		var phase_instruction := _single_line_text(String(snapshot.get("phase_instruction", "")))
		if not phase_instruction.is_empty():
			return phase_instruction
	var lines: Array = snapshot.get("objective_lines", [])
	var counts: Array = snapshot.get("objective_counts", [])
	var goals: Array = snapshot.get("objective_goals", [])
	var active_index := int(snapshot.get("active_objective_index", -1))
	if (
		active_index >= 0
		and active_index < lines.size()
		and active_index < counts.size()
		and active_index < goals.size()
		and int(counts[active_index]) < int(goals[active_index])
	):
		return _single_line_text(String(lines[active_index]))
	for index in mini(lines.size(), mini(counts.size(), goals.size())):
		if int(counts[index]) < int(goals[index]):
			return _single_line_text(String(lines[index]))
	for line in lines:
		var candidate := _single_line_text(String(line))
		if not candidate.is_empty() and not candidate.begins_with("✓") and not _objective_line_complete(candidate):
			return candidate
	if not lines.is_empty():
		return _single_line_text(String(lines[0]))
	return "看看最近发亮的花标"


func _single_line_text(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " · ").replace("  ", " ").strip_edges()


func _field_toast_text(snapshot: Dictionary, objective_text: String) -> String:
	var text := _single_line_text(String(snapshot.get("message", "")))
	if text.is_empty():
		return ""
	var event_runtime: Dictionary = snapshot.get("event_runtime", {})
	if event_runtime.is_empty():
		return text
	# Event setup used to put the same authored title + hint in both the objective
	# card and the transient toast. Keep the card as the single source of that
	# instruction; reserve the toast for a new consequence, warning or reaction.
	var title := _single_line_text(String(event_runtime.get("current_event_title", "")))
	var hint := _single_line_text(String(event_runtime.get("ui_hint", "")))
	var authored_instruction := title if hint.is_empty() else "%s · %s" % [title, hint]
	for repeated_text in [objective_text, authored_instruction, title, hint]:
		var phrase := _single_line_text(String(repeated_text))
		if phrase.is_empty():
			continue
		if text == phrase:
			return ""
		if text.ends_with(phrase):
			# Completion messages deliberately append the next objective so movement
			# can continue immediately. Remove only that repeated suffix; never hide
			# the consequence that precedes it.
			return text.trim_suffix(phrase).strip_edges()
	return text


func _field_controls_text(primary_label: String, secondary_label: String) -> String:
	var primary := _single_line_text(primary_label)
	var secondary := _single_line_text(secondary_label)
	if primary.is_empty():
		primary = "主动作"
	if secondary.is_empty():
		secondary = "次动作"
	return "WASD/摇杆 移动 · 双击方向 急转 · 空格/A %s · Q/Y %s" % [primary, secondary]


func _objective_line_complete(text: String) -> bool:
	var halves := text.split("/", false, 1)
	if halves.size() != 2:
		return false
	var left_tokens := String(halves[0]).strip_edges().split(" ", false)
	var right_tokens := String(halves[1]).strip_edges().split(" ", false)
	if left_tokens.is_empty() or right_tokens.is_empty():
		return false
	var current_text := String(left_tokens[left_tokens.size() - 1])
	var goal_text := String(right_tokens[0])
	if not current_text.is_valid_int() or not goal_text.is_valid_int():
		return false
	return int(current_text) >= int(goal_text)


func _show_field_toast(text: String) -> void:
	if message_label == null or toast_panel == null:
		return
	if text.is_empty():
		message_label.text = ""
		last_toast_message = ""
		toast_time = 0.0
		toast_panel.visible = false
		return
	message_label.text = text
	if text != last_toast_message:
		last_toast_message = text
		toast_time = FIELD_TOAST_SECONDS
		toast_panel.visible = field_hud_visible


func _acknowledge_energy_tutorial_if_visible(
	snapshot: Dictionary,
	toast_text: String
) -> void:
	var delivery_version := int(snapshot.get("energy_tutorial_delivery_version", 0))
	var delivery_text := String(snapshot.get("energy_tutorial_delivery_text", ""))
	if delivery_version <= energy_tutorial_version_seen or delivery_text.is_empty():
		return
	if (
		toast_text != delivery_text
		or message_label == null
		or toast_panel == null
		or not field_hud_visible
		or not toast_panel.visible
		or message_label.text != delivery_text
	):
		return
	# A signal is not proof that the player received the lesson. Persist it only
	# after the production label confirms every wrapped line fits the visible cap.
	var rendered_lines := message_label.get_line_count()
	if rendered_lines <= 0 or rendered_lines > message_label.max_lines_visible:
		return
	energy_tutorial_version_seen = delivery_version
	if persistence != null:
		var save_error := persistence.set_setting(
			"campaign_energy_tutorial_version",
			delivery_version
		)
		if save_error != OK:
			push_error("体力教学已经完整显示，但确认状态无法保存：%d" % save_error)


func _set_field_hud_visible(visible: bool) -> void:
	field_hud_visible = visible
	if not visible:
		toast_time = 0.0
		last_toast_message = ""
		if message_label != null:
			message_label.text = ""
	if field_panel != null:
		field_panel.visible = visible
	if objective_toggle_button != null:
		objective_toggle_button.visible = visible
	if action_panel != null:
		action_panel.visible = visible
	if controls_label != null:
		controls_label.visible = visible and controls_hint_enabled
	if toast_panel != null:
		toast_panel.visible = visible and toast_time > 0.0 and not last_toast_message.is_empty()


func _toggle_field_hud() -> void:
	if _confirm_active_modal():
		return
	field_hud_collapsed = not field_hud_collapsed
	if field_panel == null:
		return
	field_panel.size = FIELD_OBJECTIVE_COLLAPSED_SIZE if field_hud_collapsed else FIELD_OBJECTIVE_SIZE
	field_heading_label.visible = not field_hud_collapsed
	objective_label.visible = not field_hud_collapsed
	objective_toggle_button.text = "→"
	objective_toggle_button.rotation_degrees = 90.0 if field_hud_collapsed else -90.0
	objective_toggle_button.position = (
		FIELD_OBJECTIVE_TOGGLE_COLLAPSED_POS
		if field_hud_collapsed
		else FIELD_OBJECTIVE_TOGGLE_EXPANDED_POS
	)
	objective_toggle_button.size = FIELD_OBJECTIVE_TOGGLE_SIZE
	objective_toggle_button.tooltip_text = (
		"展开当前目标" if field_hud_collapsed else "收起当前目标；操作按钮和资源状态会继续保留"
	)


func _set_base_font_size(control: Control, font_size: int) -> void:
	if control == null:
		return
	control.set_meta("commercial_base_font_size", font_size)
	control.add_theme_font_size_override("font_size", roundi(float(font_size) * current_ui_scale))


func _press_field_action() -> void:
	if _confirm_active_modal():
		return
	var field := router.current_area as JourneyCampaignField
	if field != null:
		field.request_primary_action()


func _press_return() -> void:
	if _confirm_active_modal():
		return
	var field := router.current_area as JourneyCampaignField
	if field != null:
		field.request_secondary_action()


func _on_level_completed(payload: Dictionary) -> void:
	call_deferred("_settle_and_return", payload.duplicate(true))


func _on_event_checkpoint_reached(checkpoint: Dictionary) -> void:
	if not state.record_event_checkpoint(state.active_token, checkpoint):
		push_error("候级检查点没有通过 Campaign 状态合同")
		return
	_save_checkpoint("第%d候" % int(checkpoint.get("pentads_completed", 0)))


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
	var return_context := state.hive_context(true)
	return_context["return_replay"] = bool(settlement.replay)
	hive.configure(return_context)
	_connect_hive(hive)
	board_panel.visible = true
	_set_field_hud_visible(false)
	failure_panel.visible = false
	_refresh_hive_interface()
	_save_checkpoint()
	var story := "%s · %s\n%s" % [String(level.term_name), String(level.chronicle_title), String(level.world_trace)]
	if bool(settlement.replay):
		story = "%s重飞完成。储备没有重复增加，最好用时已照实比较。" % String(level.term_name)
	elif bool(settlement.journey_complete):
		story = "大寒 · 最后一墙立稳啦\n你给新蜂示范了回巢路线。老师傅往旁边让了一步：这回你来。\n你：一会儿巢里见。"
	_queue_hive_story(story, 6.0 if bool(settlement.journey_complete) else 4.8)
	_sync_modal_input_state()
	_finish_fade(false)


func _on_attempt_failed(reason: String, snapshot: Dictionary) -> void:
	if transitioning or router.current_area == null:
		return
	failed_level_id = String(snapshot.get("level_id", state.active_level_id))
	failed_replay = state.active_run_mode == JourneyCampaignState.RUN_REPLAY
	failed_token = state.active_token
	state.abandon_attempt(failed_token)
	failure_label.text = reason + "\n已完成的关卡不会受影响；若本关已有整候检查点，会从下一候继续。"
	failure_panel.visible = true
	_set_field_hud_visible(false)
	_sync_modal_input_state()


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
	_sync_modal_input_state()


func _dismiss_story() -> void:
	story_time = 0.0
	if story_card != null:
		story_card.visible = false
	_sync_modal_input_state()


func _hive_presentation_active() -> bool:
	if router == null:
		return false
	var hive := router.current_area as JourneyCampaignHive
	return hive != null and hive.presentation_time > 0.0


func _modal_input_active() -> bool:
	return (
		(story_card != null and story_card.visible)
		or (failure_panel != null and failure_panel.visible)
		or _hive_presentation_active()
	)


func _confirm_active_modal() -> bool:
	# Failure requires a deliberate choice; outside input is consumed without
	# silently choosing for the player.
	if failure_panel != null and failure_panel.visible:
		return true
	if story_card != null and story_card.visible:
		_dismiss_story()
		return true
	var hive := router.current_area as JourneyCampaignHive if router != null else null
	if hive != null and hive.presentation_time > 0.0:
		# Directly skip exactly this presentation. The signal may reveal story
		# synchronously, but this input path returns without touching that new layer.
		hive.skip_receiving_presentation()
		_sync_modal_input_state()
		return true
	return false


func _field_input_should_be_enabled() -> bool:
	return (
		not transitioning
		and not paused_for_focus
		and not paused_by_menu
		and not _modal_input_active()
		and (system_menu == null or not system_menu.is_open())
	)


func _sync_modal_input_state() -> void:
	var modal_active := _modal_input_active()
	if modal_barrier != null:
		modal_barrier.visible = modal_active
	var hive := router.current_area as JourneyCampaignHive if router != null else null
	if hive != null:
		hive.set_departure_input_enabled(
			not modal_active
			and not transitioning
			and not paused_by_menu
			and not paused_for_focus
			and (system_menu == null or not system_menu.is_open())
		)
	# A stale focused HUD button can receive Space/A before _unhandled_input. Only
	# the failure panel keeps focus because it owns two explicit choices.
	if modal_active and not paused_by_menu and not paused_for_focus:
		var focus_owner := get_viewport().gui_get_focus_owner()
		var failure_active := failure_panel != null and failure_panel.visible
		if failure_active:
			if (
				retry_button != null
				and (focus_owner == null or not failure_panel.is_ancestor_of(focus_owner))
			):
				retry_button.grab_focus()
		elif focus_owner != null:
			focus_owner.release_focus()
	_set_field_input_enabled(_field_input_should_be_enabled())


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
	_sync_modal_input_state()


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
		_sync_modal_input_state()
		if not paused_by_menu and not transitioning:
			call_deferred("_open_pause_menu", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		paused_for_focus = false
		if sound != null and not paused_by_menu:
			sound.set_enabled(true)
		if not transitioning and not paused_by_menu:
			_sync_modal_input_state()


func _fresh_action_press(event: InputEvent) -> bool:
	if not event.is_action_pressed("action"):
		return false
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	if not modal_action_armed:
		return false
	modal_action_armed = false
	return true


func _handle_native_modal_touch(event: InputEvent) -> bool:
	if event is InputEventScreenDrag:
		return (
			captured_modal_touches.has((event as InputEventScreenDrag).index)
			or transitioning
			or _modal_input_active()
		)
	if not event is InputEventScreenTouch:
		return false
	var touch := event as InputEventScreenTouch
	if captured_modal_touches.has(touch.index):
		if not touch.pressed:
			captured_modal_touches.erase(touch.index)
		return true
	# Until every finger from the current gesture is up, additional fingers are
	# captured but cannot confirm a newly revealed layer or act in the world.
	if touch.pressed and not captured_modal_touches.is_empty():
		captured_modal_touches[touch.index] = true
		return true
	# The transition curtain is visually above every modal. Capture a touch that
	# begins there so its later release cannot become a confirmation after fade-out.
	if transitioning:
		if touch.pressed:
			captured_modal_touches[touch.index] = true
		return true
	if not _modal_input_active():
		return false
	# A finger that started before this modal may release over it. Swallow that
	# release, but never treat release as a confirmation.
	if not touch.pressed:
		return true
	captured_modal_touches[touch.index] = true
	if failure_panel != null and failure_panel.visible:
		_handle_failure_touch_press(touch.position)
	else:
		_confirm_active_modal()
	return true


func _input(event: InputEvent) -> void:
	# _input runs before Control GUI dispatch. This is the reliable native-touch
	# path when pointing/emulate_mouse_from_touch is disabled; _unhandled_input is
	# retained as a defensive fallback and for keyboard/gamepad ownership.
	if paused_by_menu or paused_for_focus or (system_menu != null and system_menu.is_open()):
		return
	if _handle_native_modal_touch(event):
		get_viewport().set_input_as_handled()


func _handle_failure_touch_press(position: Vector2) -> void:
	if (
		retry_button != null
		and retry_button.visible
		and not retry_button.disabled
		and retry_button.get_global_rect().has_point(position)
	):
		_retry_failed_level()
		return
	if (
		back_hive_button != null
		and back_hive_button.visible
		and not back_hive_button.disabled
		and back_hive_button.get_global_rect().has_point(position)
	):
		_leave_failed_level()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("action"):
		modal_action_armed = true
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
			_fresh_action_press(event)
			get_viewport().set_input_as_handled()
		return
	if _handle_native_modal_touch(event):
		get_viewport().set_input_as_handled()
		return
	if _modal_input_active():
		if _fresh_action_press(event):
			_confirm_active_modal()
		get_viewport().set_input_as_handled()
		return
	if transitioning:
		if event.is_action_pressed("action"):
			_fresh_action_press(event)
		get_viewport().set_input_as_handled()
		return
	if router != null and router.current_area_id == "hive_threshold" and event.is_action_pressed("action"):
		if _fresh_action_press(event):
			_request_hive_sortie()
		get_viewport().set_input_as_handled()


func _open_pause_menu(focus_was_lost := false) -> void:
	if focus_was_lost and not paused_for_focus:
		return
	if paused_by_menu or transitioning or system_menu == null:
		return
	paused_by_menu = true
	captured_modal_touches.clear()
	if sound != null:
		sound.set_enabled(false)
	_sync_modal_input_state()
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
		_sync_modal_input_state()


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


func _save_checkpoint(checkpoint_label := "主蜂巢") -> Error:
	if not session_persistence_active or persistence == null:
		last_checkpoint_error = OK
		unsaved_exit_confirmation = ""
		return OK
	var error := persistence.save_journey_state(state)
	last_checkpoint_error = error
	if error == OK:
		save_label.text = "已保存 · %s" % checkpoint_label
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
			"自动保存再次失败（错误 %d），最近一次检查点还只在内存里。\n再按一次“%s”会明确放弃这部分进度；也可以继续游戏，处理存储空间后再试。"
			% [last_checkpoint_error, action_name]
		)
	return false


func _apply_settings(next_settings: Dictionary) -> void:
	transition_duration = 0.0 if bool(next_settings.get("reduce_motion", false)) else full_transition_duration
	controls_hint_enabled = bool(next_settings.get("show_control_hints", true))
	if controls_label != null:
		controls_label.visible = field_hud_visible and controls_hint_enabled
	if ui_layer == null:
		return
	current_ui_scale = clampf(float(next_settings.get("ui_scale", 1.0)), 0.9, 1.3)
	for node in ui_layer.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null and control.has_meta("commercial_base_font_size"):
			control.add_theme_font_size_override("font_size", roundi(float(control.get_meta("commercial_base_font_size")) * current_ui_scale))
