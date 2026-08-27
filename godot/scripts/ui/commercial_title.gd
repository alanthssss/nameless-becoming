class_name CommercialTitle
extends Node

## Standalone product title. The historical Main scene remains a regression
## fixture, but ordinary players no longer load it or its prototype UI first.

const PersistenceScript := preload("res://scripts/system/commercial_persistence.gd")
const CommercialMenuScript := preload("res://scripts/ui/commercial_system_menu.gd")
const JOURNEY_SCENE := preload("res://journey.tscn")
const SPRING_GROUND := preload("res://assets/art/commercial/spring_world_ground_v1.png")
const MAIN_HIVE := preload("res://assets/art/commercial/main_hive_exterior_v1.png")
const PLAYER_BEE := preload("res://assets/art/commercial/player_bee_topdown_states_v1.png")
const MENTOR_BEE := preload("res://assets/art/commercial/mentor_bee_topdown_v1.png")

var persistence: CommercialPersistenceService
var system_menu: CommercialSystemMenu
var root_control: Control
var title_panel: ColorRect
var continue_button: Button
var new_button: Button
var settings_button: Button
var credits_button: Button
var status_label: Label
var dream_card: ColorRect
var dream_start_button: Button
var dream_back_button: Button
var player_bee: TextureRect
var mentor_bee: TextureRect
var _new_journey_armed := false
var _motion_time := 0.0
var _reduce_motion := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	persistence = get_node_or_null("/root/CommercialPersistence") as CommercialPersistenceService
	if persistence == null:
		persistence = PersistenceScript.new()
		persistence.name = "LocalCommercialPersistence"
		add_child(persistence)
	_build_title()
	system_menu = CommercialMenuScript.new()
	system_menu.name = "CommercialSystemMenu"
	system_menu.configure(persistence)
	add_child(system_menu)
	system_menu.menu_closed.connect(_on_system_menu_closed)
	system_menu.quit_requested.connect(func(): get_tree().quit())
	persistence.settings_changed.connect(_apply_settings)
	_apply_settings(persistence.settings_snapshot())
	_refresh_slot()


func _build_title() -> void:
	root_control = Control.new()
	root_control.name = "CommercialTitleInterface"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var ground := TextureRect.new()
	ground.name = "SpringGround"
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.texture = SPRING_GROUND
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ground.modulate = Color("dfe7c9")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(ground)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color("183229", 0.25)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(veil)

	var hive := TextureRect.new()
	hive.name = "MainHive"
	hive.position = Vector2(820, 102)
	hive.size = Vector2(350, 438)
	hive.texture = MAIN_HIVE
	hive.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hive.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hive.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(hive)

	mentor_bee = _sprite(MENTOR_BEE, Vector2(1020, 520), Vector2(118, 118))
	mentor_bee.rotation = -0.12
	root_control.add_child(mentor_bee)
	player_bee = _atlas_sprite(PLAYER_BEE, Rect2(0, 0, 256, 256), Vector2(890, 535), Vector2(126, 126))
	player_bee.rotation = 0.08
	root_control.add_child(player_bee)

	title_panel = ColorRect.new()
	title_panel.name = "TitlePanel"
	title_panel.position = Vector2(54, 44)
	title_panel.size = Vector2(596, 632)
	title_panel.color = Color("f7efd8", 0.965)
	title_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(title_panel)

	var eyebrow := _label(title_panel, "四季邻里动作冒险", Vector2(52, 35), Vector2(492, 30), 14, Color("7b6845"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(title_panel, "一会儿巢里见", Vector2(42, 76), Vector2(512, 76), 47, Color("243d33"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var english := _label(title_panel, "SEE YOU AT THE HIVE", Vector2(52, 148), Vector2(492, 28), 15, Color("597064"))
	english.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tagline := _label(title_panel, "花田有事，搭把翅膀。\n飞一圈，巢里见。", Vector2(78, 194), Vector2(440, 68), 19, Color("3f5148"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	continue_button = _button(title_panel, "继续旅程", Vector2(128, 290), Vector2(340, 58), _continue_journey, true)
	new_button = _button(title_panel, "开始新旅程", Vector2(128, 360), Vector2(340, 54), _prepare_new_journey)
	settings_button = _button(title_panel, "设置", Vector2(128, 430), Vector2(160, 48), _open_settings)
	credits_button = _button(title_panel, "制作人员与许可", Vector2(308, 430), Vector2(160, 48), _open_credits)
	var quit_button := _button(title_panel, "退出", Vector2(218, 490), Vector2(160, 46), func(): get_tree().quit())
	quit_button.visible = not OS.has_feature("web")
	status_label = _label(title_panel, "", Vector2(62, 548), Vector2(472, 48), 12, Color("6b745f"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var build := _label(title_panel, _build_identity(), Vector2(62, 602), Vector2(472, 18), 9, Color("8b927f"))
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_dream_card()


func _build_dream_card() -> void:
	dream_card = ColorRect.new()
	dream_card.name = "DreamOpeningCard"
	dream_card.position = Vector2(255, 188)
	dream_card.size = Vector2(770, 344)
	dream_card.color = Color("f8f0d8", 0.992)
	dream_card.mouse_filter = Control.MOUSE_FILTER_STOP
	dream_card.visible = false
	root_control.add_child(dream_card)
	var heading := _label(dream_card, "今晚的梦很具体", Vector2(55, 36), Vector2(660, 48), 29, Color("263d34"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label(
		dream_card,
		"你成了一只第一次独立出门的新蜂。\n巢门外正好有活，老师傅已经在门边等你。",
		Vector2(92, 102), Vector2(586, 86), 19, Color("40544a")
	)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dream_start_button = _button(dream_card, "好，先飞一圈", Vector2(235, 220), Vector2(300, 56), _start_new_journey, true)
	dream_back_button = _button(dream_card, "返回", Vector2(305, 286), Vector2(160, 42), _close_dream_card)


func _sprite(texture: Texture2D, position: Vector2, size: Vector2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.position = position
	sprite.size = size
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


func _atlas_sprite(texture: Texture2D, region: Rect2, position: Vector2, size: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return _sprite(atlas, position, size)


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


func _button(parent: Node, text: String, position: Vector2, size: Vector2, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17 if primary else 15)
	button.set_meta("commercial_base_font_size", 17 if primary else 15)
	button.add_theme_color_override("font_color", Color("243d33"))
	button.add_theme_color_override("font_hover_color", Color("1f3c31"))
	button.add_theme_color_override("font_pressed_color", Color("1b322a"))
	button.add_theme_color_override("font_focus_color", Color("243d33"))
	button.add_theme_color_override("font_disabled_color", Color("77786f"))
	button.add_theme_stylebox_override("normal", _button_style(Color("dcb95a") if primary else Color("e8ddbd"), Color("6d5b38")))
	button.add_theme_stylebox_override("hover", _button_style(Color("f0cf72") if primary else Color("f4e9c9"), Color("405d50"), 3))
	button.add_theme_stylebox_override("pressed", _button_style(Color("cda84c") if primary else Color("d8cba8"), Color("334b40"), 3))
	button.add_theme_stylebox_override("focus", _button_style(Color("000000", 0.0), Color("fff0a8"), 4))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _button_style(fill: Color, border: Color, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style


func _refresh_slot() -> void:
	_new_journey_armed = false
	var file_present := persistence.progress_file_exists()
	var can_continue := persistence.has_progress()
	continue_button.disabled = not can_continue
	new_button.text = "重新开始新旅程" if file_present else "开始新旅程"
	if can_continue:
		var summary := persistence.progress_summary()
		status_label.text = "主蜂巢检查点 · 巢中蜜 %d" % int(summary.get("reserve", 0))
		if bool(summary.get("recovered_from_backup", false)):
			status_label.text += " · 已从安全备份恢复"
	elif file_present:
		status_label.text = "这个存档暂时无法安全读取；本版本不会覆盖它。"
	else:
		status_label.text = "单机买断游戏 · 进度只保存在本机"
	continue_button.grab_focus() if can_continue else new_button.grab_focus()


func _continue_journey() -> void:
	if not persistence.has_progress():
		_refresh_slot()
		return
	persistence.request_journey_launch("continue")
	get_tree().change_scene_to_packed(JOURNEY_SCENE)


func _prepare_new_journey() -> void:
	if persistence.progress_file_exists() and not _new_journey_armed:
		_new_journey_armed = true
		new_button.text = "再按一次：从立春重新开始"
		status_label.text = "旧旅程会在你确认起飞时清除；设置会保留。"
		new_button.grab_focus()
		return
	_show_dream_card()


func _show_dream_card() -> void:
	title_panel.visible = false
	dream_card.visible = true
	dream_start_button.grab_focus()


func _close_dream_card() -> void:
	dream_card.visible = false
	title_panel.visible = true
	_refresh_slot()


func _start_new_journey() -> void:
	var error := persistence.delete_progress()
	if error != OK:
		dream_card.visible = false
		title_panel.visible = true
		status_label.text = "旧旅程没有安全清除（错误 %d），没有开始新旅程。" % error
		new_button.grab_focus()
		return
	persistence.request_journey_launch("new")
	get_tree().change_scene_to_packed(JOURNEY_SCENE)


func _open_settings() -> void:
	system_menu.open_settings_only()


func _open_credits() -> void:
	system_menu.open_credits_only()


func _on_system_menu_closed() -> void:
	_apply_settings(persistence.settings_snapshot())
	settings_button.grab_focus()


func _apply_settings(next_settings: Dictionary) -> void:
	_reduce_motion = bool(next_settings.get("reduce_motion", false))
	var scale := float(next_settings.get("ui_scale", 1.0))
	for node in root_control.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null and control.has_meta("commercial_base_font_size"):
			control.add_theme_font_size_override(
				"font_size",
				roundi(float(control.get_meta("commercial_base_font_size")) * scale)
			)


func _process(delta: float) -> void:
	if _reduce_motion:
		player_bee.position.y = 535.0
		mentor_bee.position.y = 520.0
		return
	_motion_time += maxf(0.0, delta)
	player_bee.position.y = 535.0 + sin(_motion_time * 2.2) * 6.0
	mentor_bee.position.y = 520.0 + sin(_motion_time * 1.8 + 1.1) * 4.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if system_menu != null and system_menu.is_open():
		system_menu.request_cancel()
	elif dream_card.visible:
		_close_dream_card()
	get_viewport().set_input_as_handled()


func _build_identity() -> String:
	return CommercialMenuScript.build_identity()
