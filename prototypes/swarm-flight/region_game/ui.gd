extends "res://region_game/regional_pages.gd"

const CatalogDetail = preload("res://region_game/growth_catalog_detail.gd")
const GrowthRequirements = preload("res://region_game/growth_requirements.gd")
const SaleFlight = preload("res://region_game/sale_flight.gd")
var field_hud := preload("res://region_game/field_hud.gd").new()
var notes := preload("res://region_game/field_notes_style.gd").new()
var reading_book := false
var at_counter := false
var last_denied_msec := -1000
var sale_flight
var growth_map
var zoom_readout: Label
var zoom_out: Button
var zoom_in: Button
var detail_scroll: ScrollContainer
var skill_note: Control
var note_open := false
var controls_hint: Button
var cost_stock := {}
var conditions: GrowthRequirements
var return_to_goal: Button
var goal_history: Array[Dictionary] = []
var bay_button: Button
var bay_preview: Control
var controls_page
var controls_button: Button
const BAY_CELLS := ["petal_trace","garland","cascade"]

func _ready() -> void:
	super._ready()
	controls_page = preload("res://region_game/controls_page.gd").new()
	add_child(controls_page)
	controls_page.setup(self)
	driver.controls_changed.connect(_refresh_control_hints)
	sale_flight = SaleFlight.new()
	shop.add_child(sale_flight)
	sale_flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reword(self)
	toast_timer.timeout.connect(func(): _update_tree_footer(get_viewport().gui_get_focus_owner()))
	energy_text.tooltip_text = "续航：庭院恢复，飞行、采蜜和振翅消耗"

func _build_hud() -> void:
	super._build_hud()
	hud.add_child(field_hud)
	field_hud.setup(self)

func _fit_caption(label: Label) -> void:
	var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,notes.BODY).x + 34
	label.offset_left = -width * .5
	label.offset_right = width * .5

func transition_focus() -> Vector2:
	if driver.model.at_home(): return driver.model.p
	return (driver.model.p - driver.model.camera_offset) * driver.model.MeadowLayout.FIELD_ZOOM

func _reword(node: Node) -> void:
	if node is Label:
		node.text = node.text.replace("每花 1 份 · 生物不会攻击。","花心带蜜光时，每朵可采一份。").replace("每花 1 份 · 可收集树脂。","留意木头裂口里的金色树脂。")
		node.text = node.text.replace("振翅驱离小飞虫，拾取纤维。","朝种穗振翅，飞近飘绒收纤维。")
		node.text = node.text.replace("从灯球返回","从入口木牌返回")
		node.text = node.text.replace("花蜜在野外 18 秒后恢复","花蜜采走后会慢慢补回，花朵继续自己的花期")
		node.text = node.text.replace("细雨增加消耗，叶棚下可避雨。","朝裂口振翅掀皮，贴近并持续采集树脂。")
		node.text = node.text.replace(" · F 使用近道","")
		node.text = node.text.replace("0.27.0","0.32.7" if OS.has_feature("pond_feedback") else "0.29.0").replace("10 个成长节点（共 13 级）","10 个成长节点（共 14 级）")
	for child in node.get_children(): _reword(child)

func _requirements(_id: String) -> String:
	# The regional journal shows the interactive condition list on the right.
	return ""

func _detail() -> void:
	if not is_instance_valid(board) or board.model == null: return
	if is_instance_valid(bay_button):
		bay_button.visible = board.selected in BAY_CELLS
	var rank: Dictionary = board.inspect_data()
	if not CatalogDetail.update(self,board.selected):
		super._detail()
		detail_title.text = rank.name
		if board.selected=="reserve":
			detail_effect.text = "封存花蜜，备作雨前口粮。"
		if board.selected=="beat":
			detail_effect.text = "厚壳 / 厚树皮 · 2 次 → 1 次"
			detail_effect.tooltip_text = "近处的薄壳一次可开；岔路和远端较牢。树脂露出后仍需贴近收取。"
		detail_hint.hide()
	detail_requirements.hide()
	CatalogDetail.update_cost_stock(self,rank)
	if not is_instance_valid(conditions): return
	conditions.display(rank)
	detail_card.tooltip_text = ""
	_update_note_wallet()
	detail_level.text = {"owned":"已学会","planned":"后续预览","preview":"尚未学到"}.get(str(rank.state),"")
	detail_level.visible = not detail_level.text.is_empty()
	detail_hint.hide()
	detail_cost_row.visible = rank.state!="owned"
	buy_button.visible = not buy_button.disabled
	if buy_button.visible:
		buy_button.tooltip_text = "购买这一档成长"
	return_to_goal.visible = not goal_history.is_empty()
	if return_to_goal.visible:
		return_to_goal.text = "← 返回「%s」" % goal_history.back().title
	_update_tree_footer(get_viewport().gui_get_focus_owner())

func _update_tree_footer(owner: Control) -> void:
	if not is_instance_valid(controls_hint) or not tree.visible: return
	tree_footer.visible = controls_hint.button_pressed
	var pad: bool = driver.input_device=="pad"
	if owner is Button and owner in conditions.links:
		tree_footer.text = "L3 下一项 · A 查看 · B 返回" if pad else "F 下一项 · Enter 查看 · Esc 返回"
	elif not skill_note.visible:
		tree_footer.text = "左摇杆选格 · A 查看 · LT / RT 缩放" if pad else "点选技能 · 拖动移图 · 滚轮缩放"
	else:
		tree_footer.text = "L3 查条件 · 视图键收签" if pad else "F 查条件 · I 收签"
		if not buy_button.disabled: tree_footer.text += " · A 成长" if pad else " · Enter 成长"

func follow_growth_rank(rank_id: String) -> void:
	if driver.mode!="tree" or not board.ranks_by_id.has(rank_id): return
	var current: Dictionary = board.inspect_data()
	if current.id==rank_id: return
	goal_history.append({"view":growth_map.capture_view(),"title":current.name,
		"completed":conditions.show_completed,"remaining":conditions.show_remaining,
		"group":conditions.open_group,"scroll":detail_scroll.scroll_vertical})
	board.select_rank(rank_id)
	growth_map.center_selection()

func back_growth_target() -> bool:
	if goal_history.is_empty(): return false
	var target: Dictionary = goal_history.pop_back()
	growth_map.restore_view(target.view)
	conditions.show_completed = target.completed
	conditions.show_remaining = target.remaining
	conditions.open_group = target.group
	conditions._render()
	_detail()
	detail_scroll.set_deferred("scroll_vertical",target.scroll)
	return true

func refresh() -> void:
	super.refresh()
	if driver == null or not is_instance_valid(board): return
	tree_progress.hide()
	var home: bool = driver.model.at_home()
	hud_status.visible = home
	hud_status.position.x = 178.0
	pause_button.visible = home
	field_hud.refresh()
	if not home: help_text.hide()

func show_toast(words: String, seconds: float) -> void:
	var flying: bool = driver.mode == "play" and driver.model.field != null
	if flying and words in ["体力偏低","蜜囊已满"]:
		# The persistent sign by the bee already gives the warning and the way home.
		return
	super.show_toast(words,seconds)
	toast.remove_theme_stylebox_override("normal")
	toast.add_theme_constant_override("outline_size",3)
	if flying:
		notes.field_caption(toast)
		var width := clampf(toast.get_theme_font("font").get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,notes.BODY).x+40,150,550)
		anchored(toast_panel,Rect2(.5,0,0,0),Rect2(-width/2,66,width,44))
	if menu.visible and driver.save_warning:
		menu_body.text = "保存失败，当前进度仍在。请检查保存位置。"
	if driver.mode == "tree":
		anchored(toast_panel,Rect2(.5,1,0,0),Rect2(-265,-120,530,44))

func _buy_selected() -> void:
	if driver.mode=="tree" and (not note_open or not skill_note.visible):
		growth_map.center_selection(false)
		_set_note(true)
		return
	if not buy_button.disabled:
		super._buy_selected()
		return
	if driver.mode != "tree": return
	var id: String = board.next_id(board.selected)
	if id.is_empty() or driver.model.can_buy(id): return
	var now := Time.get_ticks_msec()
	if now - last_denied_msec < 350: return
	last_denied_msec = now
	driver.sound.play_event("denied")
	driver.message(driver.model.locked_reason(id), 3)

func _purchase_button_input(event: InputEvent) -> void:
	super._purchase_button_input(event)
	if buy_button.disabled and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.double_click:
			_buy_selected()

func refresh_settings() -> void:
	super.refresh_settings()
	if is_instance_valid(settings): settings.sync_motion()

func show_mode(mode: String) -> void:
	var was_reading := reading_book
	if was_reading and mode != "tree":
		growth_map.close_book()
		goal_history.clear()
	if at_counter != (mode == "shop"):
		at_counter = mode == "shop"
		driver.sound.play_event("shop_open" if at_counter else "shop_close")
	if reading_book != (mode == "tree"):
		reading_book = mode == "tree"
		driver.sound.play_event("book_open" if reading_book else "book_close")
	if is_instance_valid(sale_flight) and mode != "shop":
		sale_flight.stop()
	var leaving_slots := is_instance_valid(slots) and slots.visible
	var from_settings := settings.visible
	var from_guide := journal.visible
	super.show_mode(mode)
	complete.visible = mode == "complete"
	if complete.visible:
		complete_cost.text = "已花费 %d 金币" % driver.model.upgrade("reserve").cost
		if from_settings: complete_settings.grab_focus()
		else: complete_primary.grab_focus()
	if menu.visible:
		if from_settings: menu_settings.grab_focus()
		elif from_guide: menu_guide.grab_focus()
		elif leaving_slots: menu_slots.grab_focus()
	if not was_reading and mode == "tree":
		growth_map.open_book(driver.saved_path)
		_set_note(false)
		controls_hint.button_pressed = false
		tree_footer.hide()
	if is_instance_valid(controls_page):
		controls_page.visible = mode == "controls"
	_refresh_control_hints()
	if not is_instance_valid(slots): return
	slots.visible = mode == "slots"
	if slots.visible: _show_slots()

func _open_controls() -> void:
	if driver.mode != "settings": return
	driver.release_controls()
	driver.mode = "controls"
	show_mode("controls")
	controls_page.open(driver.input_device)

func close_controls() -> void:
	driver.mode = "settings"
	show_mode("settings")
	controls_button.grab_focus()

func controls_input(event: InputEvent) -> bool:
	return is_instance_valid(controls_page) and controls_page.handle_input(event)

func _refresh_journal_hints() -> void:
	var collect: String = driver.control_hint("interact")
	var pulse: String = driver.control_hint("pulse")
	journal_controls.text = ("靠近紫花，按住 %s。" if journal_meadow else "花心发亮时，按住 %s。") % collect
	journal_material_hint.text = ("%s 掀开树皮，贴近后按住 %s。" % [pulse,collect]) if journal_meadow else ("%s 振翅，飞近飘绒。" % pulse)

func _journal_return_text() -> String:
	return "从入口木牌返程。续航耗尽会损失一半花蜜，材料、金币与成长保留。"

func _refresh_control_hints() -> void:
	if not is_instance_valid(journal_controls): return
	var dash: String = driver.control_hint("dash")
	_refresh_journal_hints()
	transition_hint.text = "%s 跳过蜂舞" % dash
	notes.field_caption(transition_hint)
	_fit_caption(transition_hint)
	var pad: bool = driver.input_device == "pad"
	var back := "B" if pad else "Esc"
	region_back.tooltip_text = back+" 返回"
	leave_button.tooltip_text = "%s 返回庭院" % back
	pause_button.tooltip_text = "暂停与操作说明 · " + driver.control_hint("pause")
	menu_key.text = (back+"  返回") if driver.mode=="pause" else (("A" if pad else "Enter")+"  确认")
	if slots_keys: slots_keys.text = ("A   选择档位                         B   返回" if pad else "Enter   选择档位                     Esc   返回")
	if driver.mode == "tree":
		_update_tree_footer(get_viewport().gui_get_focus_owner())
	if hub_action.visible:
		_update_station_key()

func _refresh_hub_action() -> void:
	super._refresh_hub_action()
	if not hub_action.visible: return
	if hub_action_kind == "tree":
		anchored(hub_action,Rect2(Vector2(781,304)/Vector2(1280,800),Vector2.ZERO),Rect2(-81,-29,162,58))
	_update_station_key()

func _update_station_key() -> void:
	var binding: String = driver.bindings.label("interact", "pad" if driver.input_device == "pad" else "key")
	var short_label := binding.get_slice("（", 0)
	var cap := hub_action_key.get_parent() as PanelContainer
	var width := maxf(30, font.get_string_size(short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 12)
	cap.offset_right = cap.offset_left + width
	hub_action_key.text = short_label
	hub_action_key.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		hub_action.get_theme_stylebox(state).content_margin_left = cap.offset_right + 10
	hub_action.tooltip_text = "%s · %s" % [driver.control_hint("interact"), hub_action.text]

func create_growth_board():
	return preload("res://region_game/growth_catalog_board.gd").new()

func add_growth_paper() -> void:
	var sheet := preload("res://region_game/growth_parchment.gd").new()
	tree.add_child(sheet)
	anchored(sheet,Rect2(0,0,1,1),Rect2(16,14,-32,-28))

func _build_tree() -> void:
	super._build_tree()
	growth_map = preload("res://region_game/growth_map_view.gd").new()
	tree.add_child(growth_map)
	anchored(growth_map,Rect2(0,0,1,1),Rect2(68,110,-136,-224))
	growth_map.input_used.connect(driver.track_device)
	growth_map.attach(board)
	var header: HBoxContainer = tree_back.get_parent()
	anchored(header,Rect2(0,0,1,0),Rect2(78,48,-156,48))
	tree_progress.hide()
	skill_note = preload("res://region_game/growth_parchment.gd").new()
	skill_note.name = "SkillNote"
	skill_note.small_note = true
	skill_note.mouse_filter = Control.MOUSE_FILTER_STOP
	tree.add_child(skill_note)
	growth_map.detail_overlay = skill_note
	growth_map.blank_clicked.connect(_set_note.bind(false))
	growth_map.overview_requested.connect(_set_note.bind(false))
	board.item_rect_changed.connect(_place_detail)
	growth_map.resized.connect(_place_detail)
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skill_note.add_child(detail_scroll)
	detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_card.reparent(detail_scroll,false)
	detail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := action(detail_title.get_parent(),"×",_set_note.bind(false))
	close.custom_minimum_size = Vector2(30,32)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.tooltip_text = "收起技能说明"
	close.accessibility_name = close.tooltip_text
	CatalogDetail.add_rank_controls(self)
	CatalogDetail.add_cost_stock(self)
	var detail_column := detail_requirements.get_parent()
	return_to_goal = action(detail_column,"",back_growth_target)
	return_to_goal.custom_minimum_size.y = 30
	return_to_goal.add_theme_font_size_override("font_size",16)
	return_to_goal.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return_to_goal.tooltip_text = "返回查看前置前的目标 · Esc / B"
	return_to_goal.hide()
	detail_column.move_child(return_to_goal,0)
	conditions = GrowthRequirements.new()
	conditions.name = "GrowthRequirements"
	conditions.ui = self
	conditions.add_theme_constant_override("separation",4)
	detail_column.add_child(conditions)
	detail_column.move_child(conditions,buy_button.get_index()+1)
	detail_scroll.follow_focus = true
	get_viewport().gui_focus_changed.connect(_update_tree_footer)
	bay_button = action(buy_button.get_parent(),"去花湾演示",_open_bay)
	bay_button.tooltip_text = "试用这项成长 · P / 手柄 Y"
	bay_button.visible = false
	var tools := row(tree,8)
	tools.alignment = BoxContainer.ALIGNMENT_BEGIN
	anchored(tools,Rect2(0,1,0,0),Rect2(76,-94,300,40))
	zoom_out = _map_button(tools,"−","缩小 · 减号 / LT",func(): growth_map.zoom_selected(1.0/growth_map.STEP))
	zoom_readout = text_line(tools,"100%",17,INK)
	zoom_readout.custom_minimum_size.x = 51
	zoom_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_in = _map_button(tools,"＋","放大 · 加号 / RT",func(): growth_map.zoom_selected(growth_map.STEP))
	_map_button(tools,"全图","看全图 · Home / 按下右摇杆",growth_map.reset_view)
	growth_map.magnification_changed.connect(_show_zoom)
	_show_zoom(growth_map.magnification)
	controls_hint = _map_button(tools,"?","查看操作",func(): _update_tree_footer(get_viewport().gui_get_focus_owner()))
	controls_hint.toggle_mode = true
	controls_hint.accessibility_name = "查看操作"
	tree_footer.text = "点技能查看 · 拖动移图 · 滚轮缩放 · F / L3 查条件 · Enter / A 确认"
	tree_footer.tooltip_text = "I / 手柄视图键 收起或查看 · [ ] / X 换档 · Esc / B 返回"
	tree_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	anchored(tree_footer,Rect2(0,1,1,0),Rect2(394,-92,-472,36))
	tree_footer.hide()
	_set_note(false)

func _map_button(parent: Control, label: String, hint: String, callback: Callable) -> Button:
	var b := action(parent,label,callback)
	b.custom_minimum_size = Vector2(46,36)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = hint
	return b

func _show_zoom(value: float) -> void:
	zoom_readout.text = "%d%%" % roundi(value*100)
	zoom_out.disabled = is_equal_approx(value,1)
	zoom_in.disabled = is_equal_approx(value,growth_map.MAX_ZOOM)

func _place_detail() -> void:
	if not is_instance_valid(skill_note) or not is_instance_valid(detail_scroll) or not note_open or not board.model: return
	var bounds := Rect2(growth_map.position,growth_map.size)
	var point: Vector2 = bounds.position+board.position+board.point(board.selected)*growth_map.magnification
	skill_note.visible = bounds.has_point(point)
	if not skill_note.visible: return
	var width := minf(316.0,bounds.size.x-24.0)
	var height := minf(detail_card.get_combined_minimum_size().y+4.0,bounds.size.y-10.0)
	var right := point.x+84.0
	var x := right if right+width<=bounds.end.x else point.x-84.0-width
	skill_note.size = Vector2(width,height)
	skill_note.position = Vector2(clampf(x,bounds.position.x,bounds.end.x-width),
		clampf(point.y-48.0,bounds.position.y,bounds.end.y-height))

func _set_note(visible_: bool) -> void:
	if not is_instance_valid(skill_note): return
	note_open = visible_
	if visible_:
		_place_detail()
	else:
		var owner := get_viewport().gui_get_focus_owner()
		if owner!=null and skill_note.is_ancestor_of(owner):
			board.buttons[board.selected].grab_focus()
		skill_note.hide()
	_update_note_wallet()

func _update_note_wallet() -> void:
	var costs := {}
	if note_open and is_instance_valid(board) and board.model:
		var rank: Dictionary = board.inspect_data()
		if rank.state!="owned": costs = rank.cost
	tree_coins.get_parent().visible = costs.get("coins",0)>0
	tree_fiber.get_parent().visible = costs.get("fiber",0)>0
	tree_resin.get_parent().visible = costs.get("resin",0)>0

func _reveal_note() -> void:
	var at: Vector2 = board.position+board.point(board.selected)*growth_map.magnification
	if not Rect2(Vector2.ZERO,growth_map.size).has_point(at):
		growth_map.center_selection(false)
	_set_note(true)

func _selected(id: String) -> void:
	super._selected(id)
	if is_instance_valid(detail_scroll):
		detail_scroll.scroll_vertical = 0
		_set_note(true)

func _open_bay() -> void:
	if driver.mode != "tree" or board.selected not in BAY_CELLS or is_instance_valid(bay_preview): return
	growth_map.suspend(true)
	driver.mode = "growth_preview"
	bay_preview = preload("res://region_game/honey_growth_bay_preview.gd").new()
	bay_preview.reduced_motion = driver.reduced_motion
	bay_preview.setup(board.inspect_data().id)
	bay_preview.closed.connect(_close_bay)
	add_child(bay_preview)

func _close_bay() -> void:
	if not is_instance_valid(bay_preview): return
	bay_preview.hide()
	bay_preview.queue_free()
	bay_preview = null
	driver.mode = "tree"
	growth_map.suspend(false)
	board.buttons[board.selected].grab_focus()

func tree_key(event: InputEventKey) -> bool:
	if driver.mode == "tree":
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key==KEY_I:
			if event.pressed and not event.echo:
				if skill_note.visible: _set_note(false)
				else: _reveal_note()
			return true
		if key==KEY_F:
			if event.pressed and not event.echo:
				_reveal_note()
				conditions.cycle_link(event.shift_pressed)
			return true
		if key==KEY_ESCAPE and not goal_history.is_empty():
			if event.pressed and not event.echo: back_growth_target()
			return true
		var owner := get_viewport().gui_get_focus_owner()
		if key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE] and owner is Button and owner in conditions.links:
			# Opening a link moves focus to the map before the key is released.
			# Only Enter also confirms a purchase there.
			if key == KEY_SPACE:
				if event.pressed and not event.echo: conditions.activate_link()
			elif not event.pressed:
				enter_held = false
			elif not event.echo and not enter_held:
				enter_held = true
				conditions.activate_link()
			return true
		if key in [KEY_BRACKETLEFT,KEY_PAGEUP,KEY_BRACKETRIGHT,KEY_PAGEDOWN]:
			if event.pressed and not event.echo:
				board.shift_rank(-1 if key in [KEY_BRACKETLEFT,KEY_PAGEUP] else 1)
			return true
		if key == KEY_P and board.selected in BAY_CELLS:
			if event.pressed and not event.echo: _open_bay()
			return true
	return super.tree_key(event)

func _input(event: InputEvent) -> void:
	if driver == null or driver.mode != "tree" or not event is InputEventJoypadButton: return
	var directions := {JOY_BUTTON_DPAD_UP:KEY_UP,JOY_BUTTON_DPAD_DOWN:KEY_DOWN,JOY_BUTTON_DPAD_LEFT:KEY_LEFT,JOY_BUTTON_DPAD_RIGHT:KEY_RIGHT}
	if event.button_index not in directions and event.button_index not in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_Y,JOY_BUTTON_X,JOY_BUTTON_LEFT_STICK,JOY_BUTTON_BACK]: return
	driver.track_device(event)
	get_viewport().set_input_as_handled()
	if not event.pressed: return
	if event.button_index in directions:
		board.navigate(directions[event.button_index])
	elif event.button_index == JOY_BUTTON_A:
		if not conditions.activate_link(): _buy_selected()
	elif event.button_index == JOY_BUTTON_BACK:
		if skill_note.visible: _set_note(false)
		else: _reveal_note()
	elif event.button_index == JOY_BUTTON_LEFT_STICK:
		_reveal_note()
		conditions.cycle_link(false)
	elif event.button_index == JOY_BUTTON_X:
		var rank: Dictionary = board.inspect_data()
		board.shift_rank(1 if rank.rank_index+1<rank.rank_count else -rank.rank_index)
	elif event.button_index == JOY_BUTTON_Y:
		_open_bay()
	elif not back_growth_target():
		driver.close_tree()
