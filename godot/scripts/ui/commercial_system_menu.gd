class_name CommercialSystemMenu
extends CanvasLayer

## Reusable title/pause settings surface. It deliberately owns no story state;
## callers decide when a new journey is safe to start and when SceneTree pauses.

signal resume_requested
signal return_to_title_requested
signal new_journey_requested
signal quit_requested
signal menu_closed

const PersistenceScript := preload("res://scripts/system/commercial_persistence.gd")
const CREDITS_PATH := "res://data/credits_and_licenses.json"
const FONT_LICENSE_PATH := "res://fonts/OFL-NotoSansCJK.txt"
const BUILD_PROVENANCE_PATH := "res://data/build_provenance.json"

var persistence: CommercialPersistenceService
var overlay: ColorRect
var pause_panel: Control
var settings_panel: Control
var credits_panel: Control
var pause_title: Label
var pause_note: Label
var resume_button: Button
var new_journey_button: Button
var quit_button: Button
var settings_back_button: Button
var credits_back_button: Button
var music_slider: HSlider
var music_value: Label
var music_mute: CheckButton
var sfx_slider: HSlider
var sfx_value: Label
var sfx_mute: CheckButton
var fullscreen_toggle: CheckButton
var ui_scale_selector: OptionButton
var reduce_motion_toggle: CheckButton
var screen_shake_toggle: CheckButton
var control_hints_toggle: CheckButton
var settings_status: Label
var credits_text: RichTextLabel
var build_identity_label: Label

var _view := "closed"
var _settings_return_view := "closed"
var _new_journey_armed := false
var _syncing_settings := false


func configure(service: CommercialPersistenceService) -> Error:
	if persistence != null or service == null:
		return ERR_ALREADY_IN_USE if persistence != null else ERR_INVALID_PARAMETER
	persistence = service
	return OK


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	if persistence == null:
		persistence = get_node_or_null("/root/CommercialPersistence") as CommercialPersistenceService
	if persistence == null:
		persistence = PersistenceScript.new()
		persistence.name = "LocalCommercialPersistence"
		add_child(persistence)
	_build_interface()
	if not persistence.settings_changed.is_connected(_on_settings_changed):
		persistence.settings_changed.connect(_on_settings_changed)
	_sync_setting_controls(persistence.settings_snapshot())
	_show_view("closed")


func is_open() -> bool:
	return overlay != null and overlay.visible


func current_view() -> String:
	return _view


func show_pause_notice(text: String) -> void:
	## Hosts use this for actionable persistence warnings without reaching into
	## the menu's controls. The notice remains visible while the pause view is up.
	if pause_note != null:
		pause_note.text = text


func open_pause(focus_was_lost := false) -> void:
	_settings_return_view = "pause"
	_new_journey_armed = false
	pause_title.text = "已经替你停好了" if focus_was_lost else "蜂翼歇一会儿"
	pause_note.text = (
		"窗口失去焦点时已安全暂停。\n返回后请亲自选择继续。"
		if focus_was_lost
		else "玩法时钟与危险已经暂停。\n进度在每次返巢交接后自动保存；野外离开会从本趟起点重来。"
	)
	new_journey_button.text = "重新开始新旅程"
	_show_view("pause")
	call_deferred("_focus_control", resume_button)


func open_settings_only() -> void:
	_settings_return_view = "closed"
	_sync_setting_controls(persistence.settings_snapshot())
	_show_view("settings")
	call_deferred("_focus_control", music_slider)


func open_credits_only() -> void:
	_settings_return_view = "closed"
	_show_view("credits")
	call_deferred("_focus_control", credits_back_button)


func request_cancel() -> void:
	match _view:
		"settings", "credits":
			if _settings_return_view == "pause":
				_show_view("pause")
				call_deferred("_focus_control", resume_button)
			else:
				close()
		"pause":
			resume_requested.emit()
		_:
			pass


func close() -> void:
	var was_open := is_open()
	_new_journey_armed = false
	_show_view("closed")
	if was_open:
		menu_closed.emit()


func _build_interface() -> void:
	overlay = ColorRect.new()
	overlay.name = "CommercialSystemOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color("17231f", 0.91)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var frame := ColorRect.new()
	frame.name = "MenuFrame"
	frame.position = Vector2(238, 54)
	frame.size = Vector2(804, 612)
	frame.color = Color("f2e8cb", 0.985)
	overlay.add_child(frame)

	pause_panel = Control.new()
	pause_panel.position = Vector2(42, 32)
	pause_panel.size = Vector2(720, 548)
	frame.add_child(pause_panel)
	pause_title = _label(pause_panel, "蜂翼歇一会儿", Vector2(40, 10), Vector2(640, 54), 34, Color("26362f"))
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_note = _label(pause_panel, "", Vector2(75, 76), Vector2(570, 72), 15, Color("526158"))
	pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume_button = _button(pause_panel, "继续出巢", Vector2(220, 166), Vector2(280, 56), _on_resume_pressed)
	_button(pause_panel, "设置", Vector2(220, 232), Vector2(280, 52), _open_settings_from_pause)
	_button(pause_panel, "制作人员 · 许可 · 隐私", Vector2(220, 294), Vector2(280, 52), _open_credits_from_pause)
	new_journey_button = _button(pause_panel, "重新开始新旅程", Vector2(220, 356), Vector2(280, 52), _on_new_journey_pressed)
	_button(pause_panel, "返回标题（保留检查点）", Vector2(220, 418), Vector2(280, 52), _on_return_to_title_pressed)
	quit_button = _button(pause_panel, "退出游戏", Vector2(220, 480), Vector2(280, 48), _on_quit_pressed)
	quit_button.visible = not OS.has_feature("web")

	settings_panel = Control.new()
	settings_panel.position = Vector2(42, 26)
	settings_panel.size = Vector2(720, 560)
	frame.add_child(settings_panel)
	var settings_title := _label(settings_panel, "设置", Vector2(30, 0), Vector2(660, 44), 30, Color("26362f"))
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_volume_row(settings_panel, "音乐", 58, true)
	_build_volume_row(settings_panel, "音效与环境", 132, false)
	fullscreen_toggle = _check(settings_panel, "全屏", Vector2(68, 208), Vector2(260, 44), _on_fullscreen_toggled)
	if OS.has_feature("web"):
		fullscreen_toggle.disabled = true
		fullscreen_toggle.text = "全屏由浏览器管理"
	_label(settings_panel, "文字与界面大小", Vector2(370, 208), Vector2(160, 34), 15, Color("35463d"))
	ui_scale_selector = OptionButton.new()
	ui_scale_selector.position = Vector2(535, 204)
	ui_scale_selector.size = Vector2(126, 44)
	ui_scale_selector.add_theme_font_size_override("font_size", 15)
	ui_scale_selector.add_theme_color_override("font_color", Color("26362f"))
	ui_scale_selector.add_theme_color_override("font_hover_color", Color("1f3c31"))
	ui_scale_selector.add_theme_color_override("font_pressed_color", Color("1b322a"))
	ui_scale_selector.add_theme_color_override("font_focus_color", Color("26362f"))
	ui_scale_selector.add_theme_stylebox_override("normal", _menu_control_style(Color("e8ddbd")))
	ui_scale_selector.add_theme_stylebox_override("hover", _menu_control_style(Color("f4e9c9"), 3))
	ui_scale_selector.add_theme_stylebox_override("pressed", _menu_control_style(Color("d8cba8"), 3))
	ui_scale_selector.set_meta("commercial_base_font_size", 15)
	for spec in [["90%", 0.9], ["100%", 1.0], ["115%", 1.15], ["130%", 1.3]]:
		ui_scale_selector.add_item(String(spec[0]))
		ui_scale_selector.set_item_metadata(ui_scale_selector.item_count - 1, float(spec[1]))
	ui_scale_selector.item_selected.connect(_on_ui_scale_selected)
	settings_panel.add_child(ui_scale_selector)
	reduce_motion_toggle = _check(settings_panel, "减少转场动态", Vector2(68, 270), Vector2(260, 44), _on_reduce_motion_toggled)
	screen_shake_toggle = _check(settings_panel, "允许屏幕震动", Vector2(370, 270), Vector2(260, 44), _on_screen_shake_toggled)
	control_hints_toggle = _check(settings_panel, "显示操作提示", Vector2(68, 324), Vector2(260, 44), _on_control_hints_toggled)
	var controls := _label(
		settings_panel,
		"键盘：WASD / 方向键，空格行动，Q 归巢，Esc 暂停\n手柄：左摇杆移动，A 行动，Y 归巢，Start 暂停\n触屏：点地面移动；右侧大按钮行动与归巢",
		Vector2(68, 374), Vector2(590, 72), 13, Color("59675e")
	)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_status = _label(settings_panel, "设置会自动保存在本机", Vector2(68, 452), Vector2(590, 34), 12, Color("7a6a4a"))
	settings_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_back_button = _button(settings_panel, "返回", Vector2(250, 500), Vector2(220, 48), _on_settings_back)

	credits_panel = Control.new()
	credits_panel.position = Vector2(42, 26)
	credits_panel.size = Vector2(720, 560)
	frame.add_child(credits_panel)
	var credits_title := _label(credits_panel, "制作人员 · 许可 · 隐私", Vector2(30, 0), Vector2(660, 44), 29, Color("26362f"))
	credits_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_text = RichTextLabel.new()
	credits_text.position = Vector2(42, 56)
	credits_text.size = Vector2(636, 430)
	credits_text.bbcode_enabled = false
	credits_text.fit_content = false
	credits_text.scroll_active = true
	credits_text.add_theme_font_size_override("normal_font_size", 14)
	credits_text.add_theme_color_override("default_color", Color("35463d"))
	credits_text.text = _load_credits_text()
	credits_panel.add_child(credits_text)
	credits_back_button = _button(credits_panel, "返回", Vector2(250, 500), Vector2(220, 48), _on_credits_back)

	build_identity_label = _label(frame, build_identity(), Vector2(52, 588), Vector2(700, 16), 9, Color("8b927f"))
	build_identity_label.name = "BuildIdentityLabel"
	build_identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func build_identity() -> String:
	var project_version := String(ProjectSettings.get_setting("application/config/version", "unknown"))
	var document = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PROVENANCE_PATH))
	return build_identity_from_document(document, project_version)


static func build_identity_from_document(document: Variant, project_version: String) -> String:
	var fallback_version := project_version.strip_edges()
	if fallback_version.is_empty():
		fallback_version = "unknown"
	var invalid_identity := "v%s · invalid+dirty" % fallback_version
	if not document is Dictionary:
		return invalid_identity
	var data := document as Dictionary
	if (
		data.size() != 4
		or not data.has("schema_version")
		or not data.has("product_version")
		or not data.has("commit")
		or not data.has("dirty")
		or typeof(data.get("schema_version", null)) not in [TYPE_INT, TYPE_FLOAT]
		or float(data.get("schema_version", 0.0)) != 1.0
		or not data.get("product_version") is String
		or String(data.get("product_version", "")) != fallback_version
		or not data.get("commit") is String
		or typeof(data.get("dirty", null)) != TYPE_BOOL
	):
		return invalid_identity
	var commit := String(data.get("commit", ""))
	var commit_pattern := RegEx.new()
	if commit_pattern.compile("^[0-9a-f]{40}$") != OK or commit_pattern.search(commit) == null:
		return invalid_identity
	return "v%s · %s%s" % [fallback_version, commit.left(8), "+dirty" if bool(data.dirty) else ""]


func _build_volume_row(parent: Control, caption: String, y: float, music: bool) -> void:
	_label(parent, caption, Vector2(68, y), Vector2(112, 34), 16, Color("35463d"))
	var slider := HSlider.new()
	slider.position = Vector2(184, y - 3)
	slider.size = Vector2(286, 44)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.focus_mode = Control.FOCUS_ALL
	parent.add_child(slider)
	var value_label := _label(parent, "", Vector2(480, y), Vector2(52, 34), 14, Color("59675e"))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var mute := _check(parent, "静音", Vector2(548, y - 5), Vector2(110, 44), _on_music_mute_toggled if music else _on_sfx_mute_toggled)
	if music:
		music_slider = slider
		music_value = value_label
		music_mute = mute
		slider.value_changed.connect(_on_music_volume_changed)
	else:
		sfx_slider = slider
		sfx_value = value_label
		sfx_mute = mute
		slider.value_changed.connect(_on_sfx_volume_changed)


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


func _button(parent: Node, text: String, position: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("26362f"))
	button.add_theme_color_override("font_hover_color", Color("1f3c31"))
	button.add_theme_color_override("font_pressed_color", Color("1b322a"))
	button.add_theme_color_override("font_focus_color", Color("26362f"))
	button.add_theme_color_override("font_disabled_color", Color("77786f"))
	button.add_theme_stylebox_override("normal", _menu_control_style(Color("e8ddbd")))
	button.add_theme_stylebox_override("hover", _menu_control_style(Color("f4e9c9"), 3))
	button.add_theme_stylebox_override("pressed", _menu_control_style(Color("d8cba8"), 3))
	button.add_theme_stylebox_override("focus", _menu_control_style(Color("000000", 0.0), 4, Color("dcb95a")))
	button.set_meta("commercial_base_font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _check(parent: Node, text: String, position: Vector2, size: Vector2, callback: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.position = position
	check.size = size
	check.focus_mode = Control.FOCUS_ALL
	check.add_theme_font_size_override("font_size", 15)
	check.add_theme_color_override("font_color", Color("35463d"))
	check.add_theme_color_override("font_hover_color", Color("1f3c31"))
	check.add_theme_color_override("font_pressed_color", Color("1b322a"))
	check.add_theme_color_override("font_focus_color", Color("35463d"))
	check.add_theme_color_override("font_disabled_color", Color("77786f"))
	check.set_meta("commercial_base_font_size", 15)
	check.toggled.connect(callback)
	parent.add_child(check)
	return check


func _menu_control_style(fill: Color, width := 2, border := Color("6d5b38")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style


func _show_view(view: String) -> void:
	_view = view
	overlay.visible = view != "closed"
	pause_panel.visible = view == "pause"
	settings_panel.visible = view == "settings"
	credits_panel.visible = view == "credits"
	if view != "closed":
		_apply_menu_text_scale()


func _open_settings_from_pause() -> void:
	_settings_return_view = "pause"
	_sync_setting_controls(persistence.settings_snapshot())
	_show_view("settings")
	call_deferred("_focus_control", music_slider)


func _open_credits_from_pause() -> void:
	_settings_return_view = "pause"
	_show_view("credits")
	call_deferred("_focus_control", credits_back_button)


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_return_to_title_pressed() -> void:
	return_to_title_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _on_new_journey_pressed() -> void:
	if not _new_journey_armed:
		_new_journey_armed = true
		new_journey_button.text = "再按一次：清除单存档"
		pause_note.text = "旧旅程会被清除；声音、显示与无障碍设置会保留。\n若不想清除，请按 Esc 或选择其他项目。"
		new_journey_button.grab_focus()
		return
	new_journey_requested.emit()


func _on_settings_back() -> void:
	request_cancel()


func _on_credits_back() -> void:
	request_cancel()


func _on_music_volume_changed(value: float) -> void:
	music_value.text = "%d%%" % roundi(value)
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("music_volume", value / 100.0))


func _on_sfx_volume_changed(value: float) -> void:
	sfx_value.text = "%d%%" % roundi(value)
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("sfx_volume", value / 100.0))


func _on_music_mute_toggled(value: bool) -> void:
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("music_muted", value))


func _on_sfx_mute_toggled(value: bool) -> void:
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("sfx_muted", value))


func _on_fullscreen_toggled(value: bool) -> void:
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("fullscreen", value))


func _on_ui_scale_selected(index: int) -> void:
	if _syncing_settings or index < 0:
		return
	_report_setting_error(persistence.set_setting("ui_scale", float(ui_scale_selector.get_item_metadata(index))))


func _on_reduce_motion_toggled(value: bool) -> void:
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("reduce_motion", value))


func _on_screen_shake_toggled(value: bool) -> void:
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("screen_shake", value))


func _on_control_hints_toggled(value: bool) -> void:
	if not _syncing_settings:
		_report_setting_error(persistence.set_setting("show_control_hints", value))


func _on_settings_changed(next_settings: Dictionary) -> void:
	_sync_setting_controls(next_settings)
	_apply_menu_text_scale()


func _sync_setting_controls(next_settings: Dictionary) -> void:
	if music_slider == null:
		return
	_syncing_settings = true
	music_slider.value = float(next_settings.get("music_volume", 0.78)) * 100.0
	music_mute.button_pressed = bool(next_settings.get("music_muted", false))
	sfx_slider.value = float(next_settings.get("sfx_volume", 0.82)) * 100.0
	sfx_mute.button_pressed = bool(next_settings.get("sfx_muted", false))
	fullscreen_toggle.button_pressed = bool(next_settings.get("fullscreen", false)) and not OS.has_feature("web")
	var target_scale := float(next_settings.get("ui_scale", 1.0))
	var best_index := 0
	var best_distance := INF
	for index in ui_scale_selector.item_count:
		var distance := absf(float(ui_scale_selector.get_item_metadata(index)) - target_scale)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	ui_scale_selector.select(best_index)
	reduce_motion_toggle.button_pressed = bool(next_settings.get("reduce_motion", false))
	screen_shake_toggle.button_pressed = bool(next_settings.get("screen_shake", true))
	screen_shake_toggle.disabled = bool(next_settings.get("reduce_motion", false))
	control_hints_toggle.button_pressed = bool(next_settings.get("show_control_hints", true))
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
	_syncing_settings = false


func _report_setting_error(error: Error) -> void:
	if settings_status == null:
		return
	if error == OK:
		settings_status.text = "设置已保存在本机"
	elif error == ERR_UNAVAILABLE:
		settings_status.text = "浏览器环境由浏览器管理全屏"
	else:
		settings_status.text = "设置未能写入（错误 %d），本次改动已撤回" % error


func _apply_menu_text_scale() -> void:
	if overlay == null or persistence == null:
		return
	var scale := float(persistence.setting("ui_scale", 1.0))
	for node in overlay.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.has_meta("commercial_base_font_size"):
			continue
		var base_size := int(control.get_meta("commercial_base_font_size"))
		control.add_theme_font_size_override("font_size", roundi(float(base_size) * scale))
	credits_text.add_theme_font_size_override("normal_font_size", roundi(14.0 * scale))


func _focus_control(control: Control) -> void:
	if control != null and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()


func _load_credits_text() -> String:
	var document = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	if not document is Dictionary:
		return "制作人员与许可资料暂时无法读取。"
	var data := document as Dictionary
	var lines: PackedStringArray = []
	lines.append(String(data.get("product", "一会儿巢里见")))
	lines.append("")
	lines.append("制作人员")
	for credit in data.get("credits", []):
		if credit is Dictionary:
			lines.append("%s：%s" % [String(credit.get("role", "")), String(credit.get("name", ""))])
	lines.append("")
	lines.append("隐私")
	lines.append(String(data.get("privacy", "")))
	lines.append("")
	lines.append(String(data.get("build_notice", "")))
	for notice in data.get("third_party", []):
		if not notice is Dictionary:
			continue
		lines.append("")
		lines.append("%s — %s" % [String(notice.get("name", "")), String(notice.get("license", ""))])
		lines.append(String(notice.get("copyright", "")))
		if notice.has("text"):
			lines.append(String(notice.text))
		elif String(notice.get("license_file", "")) == FONT_LICENSE_PATH:
			lines.append(FileAccess.get_file_as_string(FONT_LICENSE_PATH))
	return "\n".join(lines)
