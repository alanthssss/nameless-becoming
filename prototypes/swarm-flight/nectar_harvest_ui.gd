extends Control
## Compact field HUD, contextual selling, and an abstract growth map.
const Board = preload("res://nectar_growth_board.gd")
const INK := Color("294d40")
const PAPER := Color("f5edcf")
const GOLD := Color("eccb7c")
const MUTED := Color("a9beac")
var driver
var font := SystemFont.new()
var hud: Control
var bag_text: Label
var energy_text: Label
var coins_text: Label
var trip_text: Label
var goal_text: Label
var help_text: Label
var toast: Label
var toast_panel: PanelContainer
var bag_bar: ProgressBar
var energy_bar: ProgressBar
var shop: Control
var shop_coins: Label
var shop_cargo: Label
var shop_story: Label
var shop_value: Label
var sell_button: Button
var leave_button: Button
var tree_button: Button
var upgrade_buttons := {}
var tree: Control
var board
var tree_coins: Label
var tree_progress: Label
var detail_title: Label
var detail_level: Label
var detail_effect: Label
var detail_requirements: Label
var detail_hint: Label
var buy_button: Button
var tree_back: Button
var menu: Control
var menu_title: Label
var menu_body: Label
var menu_primary: Button
var menu_restart: Button
var menu_quit: Button
var restart_dialog: ConfirmationDialog
var muted := false
var enter_held := false
var purchase_double_click := false
var last_purchase_msec := -1000
var shop_cache := ""
var toast_timer: Timer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["PingFang SC","Hiragino Sans GB","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	var theme_data := Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 20
	theme = theme_data
	_build_hud()
	_build_shop()
	_build_tree()
	_build_menu()
	_build_toast()
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "重新开始采蜜"
	restart_dialog.dialog_text = "当前采蜜进度会备份，再开始新的一轮。\n旧的池岸归途进度不会改变。"
	restart_dialog.ok_button_text = "备份并重新开始"
	restart_dialog.cancel_button_text = "取消"
	restart_dialog.confirmed.connect(driver.restart_game)
	add_child(restart_dialog)
	if driver.has_signal("presentation_changed"): driver.presentation_changed.connect(refresh)

func style(fill: Color, edge := Color("81957a"), thickness := 1, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(thickness)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

func card(parent: Node, fill := PAPER, edge := Color("81957a")) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(fill,edge))
	parent.add_child(p)
	return p

func anchored(node: Control, anchors: Rect2, offsets: Rect2) -> void:
	node.set_anchor(SIDE_LEFT,anchors.position.x)
	node.set_anchor(SIDE_TOP,anchors.position.y)
	node.set_anchor(SIDE_RIGHT,anchors.end.x)
	node.set_anchor(SIDE_BOTTOM,anchors.end.y)
	node.offset_left = offsets.position.x
	node.offset_top = offsets.position.y
	node.offset_right = offsets.end.x
	node.offset_bottom = offsets.end.y

func screen(parent: Node) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

func shade(parent: Node, tint: Color) -> void:
	var c := ColorRect.new()
	c.color = tint
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func column(parent: Node, gap := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",gap)
	parent.add_child(v)
	return v

func row(parent: Node, gap := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation",gap)
	parent.add_child(h)
	return h

func text_line(parent: Node, words: String, pixels := 20, tint := INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size",pixels)
	l.add_theme_color_override("font_color",tint)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func action(parent: Node, words: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(0,52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",20)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,INK)
	b.add_theme_color_override("font_disabled_color",Color("8c9a87"))
	b.add_theme_stylebox_override("normal",style(GOLD if primary else Color("f7f3df")))
	b.add_theme_stylebox_override("hover",style(Color("fff1bd"),Color("a68b49"),2))
	b.add_theme_stylebox_override("pressed",style(Color("d8bc76"),INK,2))
	b.add_theme_stylebox_override("disabled",style(Color("dce2d4"),Color("aab7a0")))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color("c18b38"),3))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func bar(parent: Node, tint: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size.y = 8
	p.show_percentage = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [["background",Color("345649")],["fill",tint]]:
		var bar_style := style(pair[1],Color.TRANSPARENT,0,4)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: bar_style.set_content_margin(side,0)
		p.add_theme_stylebox_override(pair[0],bar_style)
	parent.add_child(p)
	return p

func spacer(parent: Node) -> void:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func _build_hud() -> void:
	hud = screen(self)
	var resources := card(hud,Color("254a3eef"),Color("79947b"))
	anchored(resources,Rect2(0,0,0,0),Rect2(24,22,202,86))
	var rv := column(resources,4)
	coins_text = text_line(rv,"",26,GOLD)
	trip_text = text_line(rv,"",17,Color("d1ddc1"))
	var target := card(hud,Color("f5edcfe8"))
	anchored(target,Rect2(1,0,0,0),Rect2(-354,22,330,95))
	text_line(column(target,5),"下一步",15,Color("7e8868"))
	goal_text = text_line(target.get_child(0),"",19,INK,true)
	var status := card(hud,Color("24483ef2"),Color("86a181"))
	anchored(status,Rect2(.5,1,0,0),Rect2(-260,-89,520,65))
	var hr := row(status,24)
	var bag := column(hr,5)
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_text = text_line(bag,"",19,PAPER)
	bag_bar = bar(bag,GOLD)
	var energy := column(hr,5)
	energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_text = text_line(energy,"",19,PAPER)
	energy_bar = bar(energy,Color("a5c791"))
	help_text = text_line(hud,"",19,INK)
	anchored(help_text,Rect2(.5,1,0,0),Rect2(-500,-139,1000,32))
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_color_override("font_shadow_color",Color("f5edcfff"))
	help_text.add_theme_constant_override("shadow_offset_x",1)
	help_text.add_theme_constant_override("shadow_offset_y",1)
	var controls := text_line(hud,"WASD 飞行   空格 冲刺   Esc 暂停",15,INK)
	controls.add_theme_color_override("font_shadow_color",PAPER)
	controls.add_theme_constant_override("shadow_offset_x",1)
	controls.add_theme_constant_override("shadow_offset_y",1)
	anchored(controls,Rect2(0,1,0,0),Rect2(25,-38,330,24))

func _build_shop() -> void:
	shop = screen(self)
	shade(shop,Color(.08,.17,.12,.23))
	var p := card(shop,PAPER,Color("a7a77c"))
	anchored(p,Rect2(1,.5,0,0),Rect2(-535,-350,500,700))
	var v := column(p,12)
	text_line(v,"池岸收购点",17,Color("7b895f"))
	text_line(v,"这一趟，收获不错。",30)
	shop_story = text_line(v,"带回花蜜，就能换取下一次成长。",19,Color("768064"),true)
	var cargo_card := card(v,Color("e5e8d0"),Color("bec8a5"))
	var cargo_v := column(cargo_card,12)
	shop_cargo = text_line(cargo_v,"",22)
	shop_value = text_line(cargo_v,"",27,Color("9a6c28"))
	sell_button = action(v,"全部交付",driver.sell_cargo,true)
	shop_coins = text_line(v,"",19,Color("718160"))
	spacer(v)
	tree_button = action(v,"查看成长树  →",driver.open_tree,true)
	leave_button = action(v,"继续出发",driver.close_shop)
	text_line(v,"Esc 返回花园 · 交付立即结算",16,Color("839071"))

func _build_tree() -> void:
	tree = screen(self)
	shade(tree,Color("183e35fa"))
	var margin := MarginContainer.new()
	tree.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var layout := column(margin,14)
	var header := row(layout,20)
	var titles := column(header,3)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_line(titles,"成长",34,PAPER)
	tree_progress = text_line(titles,"",18,MUTED)
	tree_coins = text_line(header,"",26,GOLD)
	tree_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tree_back = action(header,"返回收购点",driver.close_tree)
	tree_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	tree_back.custom_minimum_size.x = 180
	var split := row(layout,18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board = Board.new()
	board.font = font
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(640,570)
	split.add_child(board)
	board.selected_changed.connect(_selected)
	var detail := card(split,PAPER,Color("b5b58c"))
	detail.custom_minimum_size.x = 326
	var dv := column(detail,16)
	detail_level = text_line(dv,"",17,Color("7a8865"))
	detail_title = text_line(dv,"",29)
	detail_effect = text_line(dv,"",22,INK,true)
	var line := HSeparator.new()
	dv.add_child(line)
	text_line(dv,"成长条件",17,Color("7b8968"))
	detail_requirements = text_line(dv,"",18,INK,true)
	spacer(dv)
	detail_hint = text_line(dv,"",18,Color("758365"),true)
	buy_button = action(dv,"",_purchase_button_activated,true)
	buy_button.gui_input.connect(_purchase_button_input)
	text_line(dv,"每次确认提升一级",16,Color("8a9477"))
	var foot := text_line(layout,"点击节点查看 · Enter 升级 · ↑↓ 选节点 · ←→ 换分区 · Tab 依次浏览 · Esc 返回",17,MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for data in Board.NODES:
		for id in data.ranks: upgrade_buttons[id] = board.buttons[data.id]

func _build_menu() -> void:
	menu = screen(self)
	shade(menu,Color(.09,.20,.15,.36))
	var panel := card(menu,PAPER,Color("9fa97b"))
	anchored(panel,Rect2(.5,.5,0,0),Rect2(-300,-274,600,548))
	var v := column(panel,14)
	text_line(v,"BEFORE THE RAIN",16,Color("7a865e"))
	menu_title = text_line(v,"采蜜小店",43)
	menu_body = text_line(v,"",21,INK,true)
	menu_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_primary = action(v,"开始采蜜",driver.start_game,true)
	var bottom := row(v,14)
	menu_restart = action(bottom,"新的一轮",ask_restart)
	menu_quit = action(bottom,"保存并退出",driver.quit_game)
	text_line(v,"0.20 · WASD 飞行 / E 采集 / Esc 暂停",16,Color("8a9175"))

func _build_toast() -> void:
	toast_panel = card(self,Color("204438f2"),Color("b2ac70"))
	anchored(toast_panel,Rect2(.5,0,0,0),Rect2(-380,130,760,60))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast = text_line(toast_panel,"",20,PAPER,true)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.hide()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(toast_panel.hide)
	add_child(toast_timer)

func show_toast(words: String, seconds: float) -> void:
	toast.text = words
	if driver.mode == "tree": anchored(toast_panel,Rect2(.5,1,0,0),Rect2(-380,-60,760,54))
	elif driver.mode == "shop": anchored(toast_panel,Rect2(0,0,0,0),Rect2(24,24,680,60))
	else: anchored(toast_panel,Rect2(.5,0,0,0),Rect2(-380,130,760,60))
	toast_panel.show()
	toast_timer.start(seconds)

func show_mode(mode: String) -> void:
	hud.visible = mode == "play"
	shop.visible = mode == "shop"
	tree.visible = mode == "tree"
	menu.visible = mode in ["title","pause","complete"]
	enter_held = false
	shop_cache = ""
	toast_panel.hide()
	if mode == "shop":
		refresh()
		if not sell_button.disabled: sell_button.grab_focus()
		else: tree_button.grab_focus()
	elif mode == "tree":
		refresh()
		board.select_node(board.selected)
	elif menu.visible:
		if mode == "title":
			menu_title.text = "采蜜小店"
			menu_body.text = "雨来之前，带回一份丰收。\n\n飞进花丛，收集花蜜；回到池岸交付，\n让每一次成长带你去得更远。"
			menu_primary.text = "继续采蜜" if driver.has_save else "从蜂巢出发"
		elif mode == "pause":
			menu_title.text = "歇一会儿"
			menu_body.text = "这一趟的收获与成长都记下了。\n\nWASD / 方向键：飞行\n按住 E / 鼠标：采蜜\n空格蓄力，松开冲刺"
			menu_primary.text = "继续这趟出行"
		else:
			menu_title.text = "花蜜，备好了"
			menu_body.text = "这段采蜜生活有了成果。\n\n花还开着。你可以继续探索，\n也可以挑选尚未获得的成长。"
			menu_primary.text = "再去花园转转"
		if driver.save_blocked:
			menu_body.text = "这份采蜜进度暂时无法读取或升级。\n原文件仍保留。可备份后开始新的一轮。"
			menu_primary.text = "备份并重新开始"
		elif driver.save_warning:
			menu_body.text = "保存暂时失败，当前进度仍在。\n请继续后重试，或检查保存位置。"
		menu_restart.visible = driver.has_save or driver.save_blocked
		menu_primary.grab_focus()
	refresh()

func _selected(_id: String) -> void:
	_detail()

func _requirements(id: String) -> String:
	var m = driver.model
	match id:
		"gather", "bag": return "✓ 一级随时可选\n二级需要先获得一级"
		"wings": return "采蜜技巧 1级 或 蜜囊容量 1级\n二级需要先获得一级"
		"reach": return "采蜜技巧至少 1级"
		"twin": return "同时满足：\n采蜜技巧 2级\n花香触角已获得"
		"meadow": return "基础能力成长  %d / 3 次\n同一能力升两级，计两次" % mini(3,m.growth_count())
		"shortcut": return "紫花地已开放"
		"market": return "已经探索紫花地\n已交售紫蜜  %d / 1 份" % mini(1,m.rose_sold)
		"reserve": return "已经探索紫花地\n已交售紫蜜  %d / 18 份\n\n任选其一：\n双簇采蜜 或 叶间近道" % mini(18,m.rose_sold)
	return ""

func _detail() -> void:
	if board.model == null: return
	var id: String = board.selected
	var data: Dictionary = board.definition(id)
	var rank: int = board.rank_of(id)
	var next: String = board.next_id(id)
	var m = driver.model
	detail_title.text = data.title
	detail_level.text = ["采集","出行","花路与收益","阶段成果"][int(data.group)]+"  ·  %d / %d" % [rank,data.ranks.size()]
	detail_requirements.text = _requirements(id)
	if next.is_empty():
		var current_effects := {"gather":"每秒采蜜 11 份", "bag":"最多携带 48 份花蜜", "wings":"续航上限 145", "reach":"采集范围 155", "twin":"同时采集范围内的两朵花", "meadow":"远方紫花地已开放", "shortcut":"池岸与紫花地可双向通行", "market":"每次交付获得额外 25% 金币", "reserve":"已经为蜂巢备好花蜜"}
		detail_effect.text = current_effects[id]
		buy_button.text = "✓ 已满级"
		buy_button.disabled = true
		detail_hint.text = "效果会一直保留，继续挑选其他成长吧。"
	else:
		var def: Dictionary = m.upgrade(next)
		detail_effect.text = def.description
		buy_button.text = ("完成储备" if id == "reserve" else "开放花地" if id == "meadow" else "升级")+"  ·  %d 金币" % def.cost
		buy_button.disabled = not m.can_buy(next)
		detail_hint.text = m.locked_reason(next) if buy_button.disabled else "下一趟就能感受到变化。"
		if id == "reserve" and not buy_button.disabled: detail_hint.text = "完成这一段采蜜生活，之后仍可继续探索。"
		if id == "market" and not buy_button.disabled: detail_hint.text = "适合继续积累的长期投资；完成阶段不必购买。"

func _purchase_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		purchase_double_click = event.double_click

func _purchase_button_activated() -> void:
	if purchase_double_click:
		purchase_double_click = false
		return
	_buy_selected()

func _buy_selected() -> void:
	if driver.mode != "tree" or buy_button.disabled: return
	var now := Time.get_ticks_msec()
	if now-last_purchase_msec < 350: return
	last_purchase_msec = now
	var id: String = board.next_id(board.selected)
	if not id.is_empty(): driver.buy_upgrade(id)

func tree_key(event: InputEventKey) -> bool:
	if driver.mode != "tree": return false
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if key in [KEY_ENTER,KEY_KP_ENTER]:
		if not event.pressed: enter_held = false
		elif not event.echo and not enter_held:
			enter_held = true
			_buy_selected()
		return true
	if event.pressed and not event.echo and key in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		board.navigate(key,event.shift_pressed)
		return true
	return false

func refresh() -> void:
	if driver == null or not is_instance_valid(board): return
	var m = driver.model
	bag_text.text = "蜜囊  %d / %d" % [m.cargo_total(),m.capacity()]
	bag_bar.max_value = m.capacity()
	bag_bar.value = m.cargo_total()
	energy_text.text = "续航  %d / %d" % [int(ceil(m.energy)),int(m.max_energy())]
	energy_bar.max_value = m.max_energy()
	energy_bar.value = m.energy
	coins_text.text = "金币  %d" % m.coins
	trip_text.text = ("蜂巢旁" if m.at_home() else "紫花地" if m.p.x > m.GATE_X else "池岸花丛")+" · 第 %d 趟" % maxi(1,m.trip_index)
	goal_text.text = m.goal_text()
	if m.at_home(): help_text.text = "E  进入收购点，交付花蜜       向右飞，开始下一趟"
	elif m.cargo_total() >= m.capacity(): help_text.text = "蜜囊满了 · 带着花蜜回蜂巢，按 E 交付"
	elif m.p.x > 1610 and "meadow" not in m.owned: help_text.text = "前面是紫花地 · 在成长树中查看开放条件"
	elif m.rain_exposed(): help_text.text = "细雨会消耗更多续航 · 可以从花地低处绕行"
	else: help_text.text = "靠近花心，按住 E / 鼠标采蜜"
	shop_coins.text = "当前金币  %d" % m.coins
	shop_cargo.text = "蓝花蜜    %d 份\n紫花蜜    %d 份" % [m.cargo.blue,m.cargo.rose]
	shop_value.text = "本趟可售  %d 金币" % m.cargo_value()
	sell_button.text = "全部交付  +%d 金币" % m.cargo_value() if m.cargo_total() else "花蜜已交付"
	sell_button.disabled = m.cargo_total() == 0
	shop_story.text = "紫花地的收获也带回来了。\n交付后，看看下一趟想改善什么。" if m.rose_sold > 0 else "你带回来的花蜜，我都收。\n换取成长，再去花园看看。"
	board.refresh(m)
	tree_coins.text = "金币  %d" % m.coins
	tree_progress.text = "紫花地已开放 · 按自己的节奏继续成长" if "meadow" in m.owned else "下一片花地  ·  基础能力成长 %d / 3" % mini(3,m.growth_count())
	_detail()

func ask_restart() -> void:
	restart_dialog.popup_centered(Vector2i(540,220))

func toggle_sound() -> void:
	muted = not muted
	driver.sound.set_muted(muted)
	driver.message("声音已关闭" if muted else "声音已开启",2)
