extends "res://nectar_harvest_ui.gd"

const Plate = preload("res://region_game/menu_plate.gd")
var title_slot: Label
var title_status: Label
var menu_key: Label
var menu_slots: Button
var slots: Control
var slot_buttons := {}
var slot_summaries := {}
var slots_back: Button
var slots_keys: Label
var complete: Control
var complete_primary: Button
var complete_settings: Button
var complete_cost: Label
var journal_expand: Button
var map_locked: Label

func _plate(asset: String) -> Plate:
	var plate := Plate.new()
	add_child(plate)
	plate.setup(asset)
	plate.hide()
	return plate

func _build_menu() -> void:
	var page := _plate("shared")
	menu = page
	var corner := Vector2(15,26)
	page.art.position = corner
	page.art.size = Vector2(451,546)
	menu_logo = TextureRect.new()
	menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.place(menu_logo,Rect2(corner+Vector2(42,35),Vector2(43,43)))
	menu_logo.texture = preload("res://icon.png")
	menu_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	menu_title = page.label("Honey",Rect2(110,58,210,52),43,HORIZONTAL_ALIGNMENT_LEFT,true)
	var wordmark := page.face.duplicate() as SystemFont
	wordmark.font_names = ["Baskerville","Georgia","serif"]
	menu_title.add_theme_font_override("font",wordmark)
	title_slot = page.label("",Rect2(300,62,117,38),17,HORIZONTAL_ALIGNMENT_RIGHT)
	menu_body = page.label("",Rect2(55,105,365,36),16)
	menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_primary = page.button("",Rect2(53,154,170,115),driver.start_game,19,"fly",66)
	menu_guide = page.button("花路手册",Rect2(257,154,170,115),driver.open_journal,19,"map",66)
	title_status = page.label("",Rect2(277,169,148,77),18)
	menu_settings = page.button("设置",Rect2(53,270,170,115),driver.open_settings,19,"dial",66)
	menu_slots = page.button("选择存档",Rect2(257,270,170,115),driver.open_slots,19,"files",66)
	menu_restart = page.button("新的一轮",Rect2(53,386,170,115),ask_restart,19,"reel",66)
	menu_quit = page.button("",Rect2(257,386,170,115),driver.quit_game,19,"gate",66)
	menu_footer = page.label("Demo "+("0.32.7" if OS.has_feature("pond_feedback") else "0.29.0"),Rect2(55,514,170,28),15)
	menu_key = page.label("",Rect2(270,514,150,28),16,HORIZONTAL_ALIGNMENT_RIGHT)
	if driver.slots_enabled: _build_slots()
	var medal := _plate("complete")
	complete = medal
	complete_cost = medal.label("",Rect2(523,213,203,32),16)
	complete_primary = medal.button("再去花园转转",Rect2(339,363,282,47),driver.start_game,21)
	complete_settings = medal.button("设置",Rect2(248,438,132,88),driver.open_settings,16,"",52)
	medal.button("新的一轮",Rect2(414,438,132,88),ask_restart,16,"",52)
	medal.button("保存并退出",Rect2(580,438,132,88),driver.quit_game,16,"",52)

func _build_slots() -> void:
	var page := _plate("slots")
	slots = page
	slots_back = page.button("‹  返回",Rect2(729,78,91,38),driver.close_slots,17)
	for id in range(1,driver.SLOT_COUNT+1):
		var y := 146+(id-1)*97
		var b := page.button("",Rect2(416,y,390,91),driver.choose_slot.bind(id),18,"slot-available")
		slot_buttons[id] = b
		page.label("存档 %d" % id,Rect2(481,y+10,192,35),20,HORIZONTAL_ALIGNMENT_LEFT,true)
		slot_summaries[id] = page.label("",Rect2(481,y+43,308,30),16)
	slots_keys = page.label("",Rect2(438,468,360,36),16)

func _show_slots() -> void:
	var focus: Button
	for entry in driver.slot_rows():
		var b: Button = slot_buttons[entry.id]
		var current: bool = entry.id == driver.active_slot
		var asset := "blocked" if entry.status=="blocked" else ("current" if current else "available")
		for state in ["normal","hover","pressed","disabled","focus"]:
			b.get_theme_stylebox(state).texture = Plate.texture("slot-"+asset+("-focus" if state=="focus" else ""))
		b.disabled = entry.status=="blocked"
		b.focus_mode = Control.FOCUS_NONE if b.disabled else Control.FOCUS_ALL
		var summary: String = "空档　·　开始新游戏"
		if entry.status=="occupied": summary = "%s · %d 金币 · 已出行 %d 趟" % [entry.area,entry.coins,entry.trip]
		elif b.disabled: summary = "无法读取"
		slot_summaries[entry.id].text = summary
		b.tooltip_text = "存档 %d　%s" % [entry.id,summary]
		b.accessibility_name = b.tooltip_text
		if not b.disabled and (focus==null or current): focus=b
	if focus: focus.grab_focus()
	else: slots_back.grab_focus()

func _build_restart_dialog() -> void:
	var page := _plate("restart")
	restart_dialog = page
	restart_title = page.label("",Rect2(367,159,429,58),32,HORIZONTAL_ALIGNMENT_LEFT,true)
	restart_body = page.label("",Rect2(370,221,420,74),20)
	restart_cancel = page.button("取消",Rect2(371,344,130,45),close_restart,20)
	page.button("备份并重新开始",Rect2(527,344,219,45),_confirm_restart,18)

func ask_restart() -> void:
	super.ask_restart()
	restart_title.text = "在存档 %d 重新开始？" % driver.active_slot
	restart_body.text = "当前存档无法读取。\n先备份原文件，再开始新的一轮。" if driver.save_blocked else "先备份当前进度，\n再开始新的一轮。"

func _build_regions() -> void:
	var page := _plate("routes")
	regions = page
	region_title = page.label("",Rect2(98,95,345,56),36,HORIZONTAL_ALIGNMENT_LEFT,true)
	region_hint = page.label("",Rect2(420,99,382,42),16,HORIZONTAL_ALIGNMENT_RIGHT)
	pond_button = page.button("池岸花丛",Rect2(107,174,328,223),func(): driver.request_transition("pond"),28,"",169)
	meadow_button = page.button("紫花地",Rect2(519,174,328,223),func(): driver.request_transition("meadow"),28,"",169)
	home_button = page.button("回到蜂巢庭院",Rect2(519,174,328,223),func(): driver.request_transition("hub"),27,"",169)
	for b in [pond_button,meadow_button,home_button]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for state in ["normal","hover","pressed","disabled","focus"]:
			b.get_theme_stylebox(state).content_margin_left=18
	for b in [pond_button,meadow_button]:
		var ring := StyleBoxTexture.new()
		ring.texture = Plate.texture("pond-focus" if b==pond_button else "meadow-focus")
		ring.set_content_margin_all(0)
		b.add_theme_stylebox_override("focus",ring)
	map_locked = page.label("尚未开放",Rect2(652,355,150,38),16)
	pond_info = page.label("",Rect2(128,395,354,68),17)
	meadow_info = page.label("",Rect2(542,395,335,68),17)
	region_back = page.button("‹  先留在这里",Rect2(84,498,178,45),driver.close_regions)

func _refresh_regions() -> void:
	var m = driver.model
	var home: bool = m.at_home()
	var locked: bool = "meadow" not in m.owned
	var art := Plate.texture("routes" if home and locked else "routes-open")
	if regions.art.texture != art: regions.art.texture = art
	region_title.text = "选择花路" if home else "带着收获回去"
	region_hint.text = "蜜囊 %d / %d　·　续航 %d" % [m.cargo_total(),m.capacity(),ceili(m.energy)]
	meadow_button.visible = home
	meadow_button.disabled = locked
	map_locked.visible = home and locked
	home_button.visible = not home
	pond_info.text = "蓝花蜜　·　每份 1 金币\n振松种穗，飞近收纤维。"
	meadow_info.text = "紫花蜜　·　每份 3 金币\n"+("在成长手册解锁这条花路。" if locked else "掀开树皮，贴近后收集树脂。") if home else "花蜜与材料随身带回。"

func _build_journal() -> void:
	var page := _plate("guide")
	journal = page
	for i in 2:
		var tab := page.button(["池岸花丛","紫花地"][i],Rect2(92+i*137,164,119,32),_select_journal_region.bind(i==1),16)
		journal_regions.append(tab)
	journal_status = page.label("",Rect2(147,404,249,76),17)
	journal_back = page.button("‹  返回",Rect2(776,90,87,40),driver.close_journal,17)
	journal_controls = page.label("",Rect2(622,181,249,41),16)
	journal_material_hint = page.label("",Rect2(622,297,244,64),16)
	for caption in [journal_material_hint,journal_controls]:
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_expand = page.button("归途须知　＋",Rect2(499,374,214,36),_toggle_return,18)
	journal_return_notes = page.label("",Rect2(502,416,365,67),16)
	journal_return_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_return_notes.hide()

func _toggle_return() -> void:
	journal_return_notes.visible = not journal_return_notes.visible
	journal_expand.text = "归途须知　−" if journal_return_notes.visible else "归途须知　＋"

func _select_journal_region(meadow: bool) -> void:
	journal_meadow = meadow
	journal.art.texture = Plate.texture("guide-violet" if meadow else "guide")
	for i in journal_regions.size():
		var tint := Color("fcf1d5") if (i==1)==meadow else Plate.INK
		for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color"]:
			journal_regions[i].add_theme_color_override(state,tint)
	journal_status.text = "紫花地已记录\n已交付紫蜜 %d 份" % driver.model.rose_sold if driver.model.visited_meadow else "池岸已备好\n紫花地待探索"
	journal_return_notes.text = _journal_return_text()
	_refresh_journal_hints()

func uses_shared_menu(mode: String) -> bool:
	return mode in ["title","pause"]

func active_menu() -> Control:
	return complete if complete.visible else menu

func _show_menu(mode: String) -> void:
	menu_logo.show()
	menu_title.text = "Honey"
	menu_body.text = driver.model.goal_text() if mode=="pause" else "飞进花地采蜜，带着收获回庭院。"
	menu_primary.text = "继续采蜜" if mode=="pause" or driver.has_save else "从蜂巢出发"
	if driver.save_blocked:
		menu_body.text = "这份进度无法读取。可先备份原文件。"
		menu_primary.text = "备份并重新开始"
	elif driver.save_warning:
		menu_body.text = "保存失败，当前进度仍在。请检查保存位置。"
	menu_restart.visible = mode=="pause" or driver.has_save or driver.save_blocked
	menu_slots.visible = driver.slots_enabled
	title_slot.text = "存档 %d" % driver.active_slot if driver.slots_enabled else ""
	title_status.visible = mode=="title"
	title_status.text = "存档状态\n无法读取" if driver.save_blocked else ("当前进度\n"+driver.area_name(driver.model.area) if driver.has_save else "新存档\n尚未出行")
	menu_quit.text = "退出游戏" if mode=="title" else "保存并退出"
	menu_primary.grab_focus()

func _build_settings() -> void:
	settings = preload("res://region_game/options_page.gd").new()
	add_child(settings)
	settings.setup(self)
