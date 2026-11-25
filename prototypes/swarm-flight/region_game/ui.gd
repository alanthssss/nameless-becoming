extends "res://nectar_harvest_ui.gd"

const CatalogDetail = preload("res://region_game/growth_catalog_detail.gd")
const SaleFlight = preload("res://region_game/sale_flight.gd")
var sale_flight
var growth_map
var zoom_readout: Label
var zoom_out: Button
var zoom_in: Button
var detail_scroll: ScrollContainer
var bay_button: Button
var bay_preview: Control
const BAY_CELLS := ["petal_trace","garland","cascade"]

func _ready() -> void:
	super._ready()
	sale_flight = SaleFlight.new()
	shop.add_child(sale_flight)
	sale_flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reword(self)
	energy_text.tooltip_text = "续航：庭院恢复，飞行、采蜜和振翅消耗"

func transition_focus() -> Vector2:
	if driver.model.at_home(): return driver.model.p
	return (driver.model.p - driver.model.camera_offset) * driver.model.MeadowLayout.FIELD_ZOOM

func _reword(node: Node) -> void:
	if node is Label:
		node.text = node.text.replace("每花 1 份 · 生物不会攻击。","花心带蜜光时，每朵可采一份。").replace("每花 1 份 · 可收集树脂。","留意木头裂口里的金色树脂。")
		node.text = node.text.replace("振翅驱离小飞虫，拾取纤维。","朝种穗振翅（Q / 右键），飞近飘绒收纤维。")
		node.text = node.text.replace("从灯球返回","从入口木牌返回")
		node.text = node.text.replace("花蜜在野外 18 秒后恢复","花蜜采走后会慢慢补回，花朵继续自己的花期")
		node.text = node.text.replace("细雨增加消耗，叶棚下可避雨。","朝裂口振翅掀皮，贴近按住 E / 左键收树脂。")
		node.text = node.text.replace(" · F 使用近道","")
		node.text = node.text.replace("0.27.0","0.32.1" if OS.has_feature("pond_feedback") else "0.29.0").replace("10 个成长节点（共 13 级）","10 个成长节点（共 14 级）")
	for child in node.get_children(): _reword(child)

func _requirements(id: String) -> String:
	var m = driver.model
	var next: String = board.next_id(id)
	if next.is_empty(): return ""
	var lines: Array[String] = []
	var needed: Array = m.upgrade(next).requires.duplicate()
	if next == "reserve": needed.append("twin")
	for prerequisite in needed:
		var name: String = m.upgrade(prerequisite).name
		lines.append(("✓ " if prerequisite in m.owned else "需 ") + name)
	match next:
		"wings1": lines.append("轻巧采蜜、舒展蜜囊任选一项")
		"meadow": lines.append("采蜜、蜜囊、双翼、触角、双簇合计 %d / 3 次；同格两级计两次。" % mini(3,m.growth_count()))
		"market","reserve":
			var goal := 6 if next == "reserve" else 1
			lines.append(("✓ " if m.visited_meadow else "需 ") + "探索紫花地")
			lines.append("已交售紫蜜 %d / %d 份" % [mini(m.rose_sold,goal),goal])
	return "\n".join(lines)

func _detail() -> void:
	if is_instance_valid(bay_button):
		bay_button.visible = board.selected in BAY_CELLS
	if CatalogDetail.update(self,board.selected): return
	super._detail()
	if is_instance_valid(board) and board.model!=null and board.selected=="beat":
		detail_effect.text = "厚壳 / 厚树皮 · 2 次 → 1 次" if board.rank_of("beat")==0 else "厚壳与厚树皮只需一次振翅"
		detail_effect.tooltip_text = "近处的薄壳一次可开；岔路和远端较牢。树脂露出后仍需贴近收取。"

	if is_instance_valid(board) and board.model!=null and board.selected=="supply" and board.rank_of("supply")==2:
		detail_effect.text = "36 处花源 · 6 处材料\n补蜜 10 秒"
		detail_effect.tooltip_text = "每朵花都有自己的花期"

	if not is_instance_valid(board) or board.model == null: return
	var rank_id: String = board.next_id(board.selected)
	if rank_id.is_empty():
		detail_hint.hide()
		return
	var entry: Dictionary = driver.model.upgrade(rank_id)
	var lines: Array[String] = []
	detail_title.text = entry.name
	var condition := _requirements(board.selected)
	if not detail_requirements.text.begins_with("还需"): detail_requirements.hide()
	if not condition.is_empty():
		lines.append(condition)
	if entry.get("fiber",0)>driver.model.materials.fiber:
		lines.append("纤维 · 池岸振开种穗，飞近接绒")
	if entry.get("resin",0)>driver.model.materials.resin:
		lines.append("树脂 · 紫花地振开树皮，贴近收取")
	detail_hint.text = "\n".join(lines)
	detail_hint.visible = not lines.is_empty()

func refresh() -> void:
	super.refresh()
	if driver == null or not is_instance_valid(board): return
	tree_progress.text = "六向 41 格 · 75 档　|　" + tree_progress.text
	pond_info.text = "蓝花蜜 · 每份 1 金币\n振松种穗，飞近收纤维 · 可织轻盈双翼。"
	meadow_info.text = "紫花蜜 · 每份 3 金币\n"+("振开树皮，贴近收树脂 · 可修远行双翼。" if "meadow" in driver.model.owned else "在成长手册中开放这条花路。")
	var field = driver.model.field
	if field != null:
		# Action prompts belong to the nearby flower, seed head, seam or sign.
		# Reserve the lower HUD for a whole-trip constraint.
		help_text.text = ""
		if not driver.model.energy_is_low() and driver.model.cargo_total()>=driver.model.capacity(): help_text.text = "蜜囊已满 · 仍可取材"
		help_text.visible = not help_text.text.is_empty()

func show_toast(words: String, seconds: float) -> void:
	super.show_toast(words,seconds)
	if driver.mode == "tree":
		anchored(toast_panel,Rect2(0,1,.665,0),Rect2(75,-120,-97,44))

func show_mode(mode: String) -> void:
	if is_instance_valid(sale_flight) and mode != "shop":
		sale_flight.stop()
	super.show_mode(mode)

func create_growth_board():
	return preload("res://region_game/growth_catalog_board.gd").new()

func add_growth_paper() -> void:
	# Compose the existing painted spread at its actual map/detail split.
	# The centre binding stays between the map and the entry at every scale.
	var pages := preload("res://art/nectar-growth-journal.png")
	var half := Vector2(pages.get_width()*.5,pages.get_height())
	for side in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = pages
		atlas.region = Rect2(Vector2(side*half.x,0),half)
		atlas.filter_clip = true
		var art := TextureRect.new()
		art.texture = atlas
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tree.add_child(art)
		if side == 0:
			anchored(art,Rect2(0,0,.665,1),Rect2(10,12,-10,-24))
		else:
			anchored(art,Rect2(.665,0,.335,1),Rect2(0,12,-10,-24))

func _build_tree() -> void:
	super._build_tree()
	growth_map = preload("res://region_game/growth_map_view.gd").new()
	tree.add_child(growth_map)
	anchored(growth_map,Rect2(0,0,.665,1),Rect2(86,148,-112,-317))
	growth_map.attach(board)
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tree.add_child(detail_scroll)
	anchored(detail_scroll,Rect2(.665,0,.335,1),Rect2(12,157,-61,-272))
	detail_card.reparent(detail_scroll,false)
	detail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CatalogDetail.add_rank_controls(self)
	bay_button = action(buy_button.get_parent(),"去花湾演示",_open_bay)
	bay_button.tooltip_text = "试用这项成长 · P / 手柄 Y"
	bay_button.visible = false
	var tools := row(tree,8)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	anchored(tools,Rect2(0,1,.665,0),Rect2(80,-159,-100,37))
	zoom_out = _map_button(tools,"−","缩小 · 减号 / LT",func(): growth_map.zoom_selected(1.0/growth_map.STEP))
	zoom_readout = text_line(tools,"100%",17,INK)
	zoom_readout.custom_minimum_size.x = 51
	zoom_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_in = _map_button(tools,"＋","放大 · 加号 / RT",func(): growth_map.zoom_selected(growth_map.STEP))
	_map_button(tools,"全图","看全图 · Home / 按下右摇杆",growth_map.reset_view)
	growth_map.magnification_changed.connect(_show_zoom)
	_show_zoom(growth_map.magnification)
	tree_footer.text = "滚轮缩放 · 拖空白移图 · 方向选格 · Enter / A 成长"
	tree_footer.tooltip_text = "左摇杆选格 · 右摇杆移图 · LT / RT 缩放 · [ ] / X 换档 · Esc / B 返回"
	anchored(tree_footer,Rect2(0,1,.665,0),Rect2(75,-119,-97,25))

func _map_button(parent: Control, label: String, hint: String, callback: Callable) -> Button:
	var b := action(parent,label,callback)
	b.custom_minimum_size = Vector2(46,36)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = hint
	var frame := style(Color("f7e4b496"),Color("b6935a"),1,6)
	frame.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal",frame)
	return b

func _show_zoom(value: float) -> void:
	zoom_readout.text = "%d%%" % roundi(value*100)
	zoom_out.disabled = is_equal_approx(value,1)
	zoom_in.disabled = is_equal_approx(value,growth_map.MAX_ZOOM)

func _place_detail() -> void:
	# The right column is laid out by its scroll container.
	pass

func _selected(id: String) -> void:
	super._selected(id)
	if is_instance_valid(detail_scroll): detail_scroll.scroll_vertical = 0

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
	if event.button_index not in directions and event.button_index not in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_Y,JOY_BUTTON_X]: return
	get_viewport().set_input_as_handled()
	if not event.pressed: return
	if event.button_index in directions:
		board.navigate(directions[event.button_index])
	elif event.button_index == JOY_BUTTON_A:
		_buy_selected()
	elif event.button_index == JOY_BUTTON_X:
		var rank: Dictionary = board.inspect_data()
		board.shift_rank(1 if rank.rank_index+1<rank.rank_count else -rank.rank_index)
	elif event.button_index == JOY_BUTTON_Y:
		_open_bay()
	else:
		driver.close_tree()
