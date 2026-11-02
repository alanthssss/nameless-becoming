extends Control
## Canvas-sized HUD and an intentionally calm, pause-safe hive shop.
const INK := Color("284b3e")
const PAPER := Color("f6edcf")
const GOLD := Color("efca67")
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
var bag_bar: ProgressBar
var energy_bar: ProgressBar
var shop: Control
var shop_coins: Label
var shop_cargo: Label
var shop_story: Label
var sell_button: Button
var leave_button: Button
var upgrade_buttons := {}
var upgrade_states := {}
var menu: Control
var menu_title: Label
var menu_body: Label
var menu_primary: Button
var menu_restart: Button
var menu_quit: Button
var restart_dialog: ConfirmationDialog
var muted := false
var shop_cache := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["PingFang SC","Hiragino Sans GB","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	_build_hud()
	_build_shop()
	_build_menu()
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "重新开始采蜜"
	restart_dialog.dialog_text = "当前采蜜进度会备份，再开始新的一轮。\n旧的池岸归途进度不会改变。"
	restart_dialog.ok_button_text = "备份并重新开始"
	restart_dialog.cancel_button_text = "取消"
	restart_dialog.confirmed.connect(driver.restart_game)
	add_child(restart_dialog)

func style(fill: Color, edge := Color("71967a"), thickness := 1, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(thickness)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func box(parent: Node, rect: Rect2, fill: Color, edge := Color("71967a"), radius := 12) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",style(fill,edge,1,radius))
	parent.add_child(p)
	return p

func label(parent: Node, words: String, rect: Rect2, pixels := 20, tint := INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = words
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font",font)
	l.add_theme_font_size_override("font_size",pixels)
	l.add_theme_color_override("font_color",tint)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.add_theme_constant_override("line_spacing",-4)
	l.clip_text = true
	l.size = rect.size
	parent.add_child(l)
	# Resolve the font's queued minimum-size update before constraining CJK wrapping.
	l.set_deferred("size",rect.size)
	l.minimum_size_changed.connect(func(): l.set_deferred("size",rect.size))
	return l

func button(parent: Node, words: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = words
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",19)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,INK)
	b.add_theme_color_override("font_disabled_color",Color("859180"))
	b.add_theme_stylebox_override("normal",style(GOLD if primary else Color("fffae8")))
	b.add_theme_stylebox_override("hover",style(Color("fff1b5"),INK,2))
	b.add_theme_stylebox_override("pressed",style(Color("e5c76a"),INK,2))
	b.add_theme_stylebox_override("disabled",style(Color("e4e6d7"),Color("b5c0ad")))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color("cb8833"),3))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func bar(parent: Node, rect: Rect2, tint: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.position = rect.position
	p.size = rect.size
	p.show_percentage = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("background",style(Color("d6dfc9"),Color.TRANSPARENT,0,4))
	p.add_theme_stylebox_override("fill",style(tint,Color.TRANSPARENT,0,4))
	parent.add_child(p)
	return p

func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	box(hud,Rect2(24,20,260,76),Color("f6edcfe8"))
	label(hud,"采蜜小店",Rect2(42,28,224,31),25)
	trip_text = label(hud,"蜂巢旁 · 准备出发",Rect2(42,62,224,22),15,Color("65836b"))
	box(hud,Rect2(310,20,380,76),Color("f6edcfe8"))
	bag_text = label(hud,"蜜囊  0 / 18",Rect2(328,28,344,28),21)
	bag_bar = bar(hud,Rect2(328,70,344,8),GOLD)
	box(hud,Rect2(708,20,300,76),Color("f6edcfe8"))
	energy_text = label(hud,"续航",Rect2(726,28,264,28),21)
	energy_bar = bar(hud,Rect2(726,70,264,8),Color("6ca482"))
	box(hud,Rect2(1026,20,230,76),Color("f6edcfe8"))
	coins_text = label(hud,"金币  0",Rect2(1044,36,194,34),25)
	box(hud,Rect2(24,690,746,66),Color("f6edcfe8"))
	goal_text = label(hud,"",Rect2(42,701,710,46),19,INK,true)
	box(hud,Rect2(790,690,466,66),Color("254b40df"),Color("628269"))
	help_text = label(hud,"",Rect2(808,699,430,52),16,PAPER,true)
	label(hud,"WASD / 方向键 飞行   ·   空格蓄力，松开冲刺   ·   Esc 保存暂停   ·   M 声音",Rect2(28,768,1224,24),15,Color("244b3d"))
	toast = label(self,"",Rect2(200,111,880,48),21,Color("fff3c9"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color",Color("244636"))
	toast.add_theme_constant_override("shadow_offset_x",1)
	toast.add_theme_constant_override("shadow_offset_y",2)

func _build_shop() -> void:
	shop = Control.new()
	shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shop)
	var shade := ColorRect.new()
	shade.color = Color(0.07,0.17,0.14,0.50)
	shade.size = Vector2(1280,800)
	shop.add_child(shade)
	box(shop,Rect2(42,32,1196,734),PAPER,Color("486f54"),22)
	label(shop,"蜂巢小店",Rect2(72,51,500,44),32)
	label(shop,"带回花蜜，挑一个成长，再把花路走远一点。",Rect2(74,102,860,30),19,Color("6c7c5c"))
	shop_coins = label(shop,"",Rect2(930,103,266,30),23)
	shop_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	leave_button = button(shop,"继续出发  →",Rect2(1022,50,184,45),driver.close_shop,true)
	box(shop,Rect2(68,157,244,582),Color("e7e8ce"),Color("c2c7a8"),15)
	label(shop,"接货的同伴",Rect2(86,176,208,30),21)
	shop_story = label(shop,"雨来之前，我们想给蜂巢备好一批花蜜。\n你带回来的，我都收。",Rect2(86,218,208,115),19,INK,true)
	label(shop,"这趟带回",Rect2(86,349,208,28),16,Color("6a805f"))
	shop_cargo = label(shop,"",Rect2(86,385,208,100),22,INK,true)
	sell_button = button(shop,"交付花蜜",Rect2(86,494,208,52),driver.sell_cargo,true)
	label(shop,"交付会立即换成金币。\n每次从蜂巢出发，\n普通花源都会补满。",Rect2(86,571,208,103),17,Color("687c5d"),true)
	var headers := ["采集 · 从一朵到一簇","携带 · 从近处到远方","花路 · 蜂巢慢慢变好"]
	for col in 3:
		var x := 332+col*294
		label(shop,headers[col],Rect2(x+4,166,280,32),19)
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x+137,233),Vector2(x+137,671)])
		line.width = 3
		line.default_color = Color("aab995")
		shop.add_child(line)
	for definition in driver.model.upgrade_defs():
		var x: float = 332+int(definition.branch)*294
		var y: float = 210+int(definition.row)*130
		var id: String = definition.id
		var b := button(shop,"",Rect2(x,y,276,113),driver.buy_upgrade.bind(id))
		var name_label := label(b,definition.name,Rect2(13,8,250,29),20)
		label(b,definition.description,Rect2(13,39,250,43),14,Color("62795d"),true)
		var state_label := label(b,"",Rect2(13,81,250,27),14)
		upgrade_buttons[id] = b
		upgrade_states[id] = {"state":state_label,"title":name_label}

func _build_menu() -> void:
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.09,0.19,0.15,0.43)
	shade.size = Vector2(1280,800)
	menu.add_child(shade)
	box(menu,Rect2(336,148,608,504),PAPER,Color("618065"),24)
	label(menu,"BEFORE THE RAIN",Rect2(378,177,524,28),15,Color("8c8b5a"))
	menu_title = label(menu,"采蜜小店",Rect2(378,216,524,62),39)
	menu_body = label(menu,"",Rect2(378,294,524,164),18,INK,true)
	menu_primary = button(menu,"开始采蜜",Rect2(378,478,524,56),driver.start_game,true)
	menu_restart = button(menu,"新的一轮",Rect2(378,554,250,45),ask_restart)
	menu_quit = button(menu,"保存并退出",Rect2(650,554,252,45),driver.quit_game)

func show_mode(mode: String) -> void:
	hud.visible = mode == "play"
	shop.visible = mode == "shop"
	menu.visible = mode in ["title","pause","complete"]
	shop_cache = ""
	if mode == "shop":
		refresh()
		if not sell_button.disabled: sell_button.grab_focus()
		else: leave_button.grab_focus()
	elif menu.visible:
		if mode == "title":
			menu_title.text = "采蜜小店"
			menu_body.text = "雨来之前，给蜂巢备好一批花蜜。\n飞去采集，带回出售，再挑选成长。\n\nWASD 飞行 · 按住 E / 鼠标采蜜\n回到树洞旁按 E，进入蜂巢小店。"
			menu_primary.text = "继续采蜜" if driver.has_save else "从蜂巢出发"
		elif mode == "pause":
			menu_title.text = "歇一会儿"
			menu_body.text = "花蜜、金币和成长都记下了。\n可以继续这趟出行，也可以下次再来。\n\nWASD 飞行 · E / 鼠标采蜜\n空格蓄放冲刺 · 回巢按 E 交付"
			menu_primary.text = "继续这趟出行"
		else:
			menu_title.text = "蜂巢的花蜜备好了"
			menu_body.text = "同伴把最后一罐花蜜摆进了巢里。\n紫花地的路也已经走通了。\n\n这段采蜜生活有了成果。\n花还开着，你可以继续探索和成长。"
			menu_primary.text = "再去花园转转"
		if driver.save_blocked:
			menu_body.text = "这份采蜜进度暂时无法读取。\n可以备份它，再开始新的一轮。\n原来的池岸归途存档不会改变。"
			menu_primary.text = "备份并重新开始"
		elif driver.save_warning:
			menu_body.text = "保存暂时失败，当前进度仍在。\n请继续游玩后重试，或检查保存位置。"
		menu_restart.visible = driver.has_save or driver.save_blocked
		menu_primary.grab_focus()

func refresh() -> void:
	if driver == null: return
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
	if m.at_home(): help_text.text = "E  进入小店，交付花蜜\n向右飞，开始下一趟"
	elif m.cargo_total() >= m.capacity(): help_text.text = "蜜囊满了 · 向左回蜂巢\n到树洞旁按 E 交付"
	elif m.p.x > 1610 and "meadow" not in m.owned: help_text.text = "前面是紫花地\n回巢购买「开往紫花地」"
	elif m.rain_exposed(): help_text.text = "细雨会多消耗续航\n可从花地低处绕行"
	else: help_text.text = "按住 E / 鼠标  采集附近花蜜\n靠近花心，蜜滴会飞进蜜囊"
	toast.text = driver.toast_text
	toast.visible = driver.toast_left > 0
	if not shop.visible: return
	var key := str(m.coins)+str(m.cargo)+str(m.owned)+str(m.rose_sold)
	if key == shop_cache: return
	shop_cache = key
	shop_coins.text = "金币  %d" % m.coins
	shop_cargo.text = "蓝花蜜  %d\n紫花蜜  %d" % [m.cargo.blue,m.cargo.rose]
	sell_button.text = "全部交付  +%d" % m.cargo_value() if m.cargo_total() else "先带些花蜜回来"
	sell_button.disabled = m.cargo_total() == 0
	shop_story.text = "紫花蜜也收到了。\n把这片花地的收获，慢慢变成蜂巢的储粮吧。" if m.rose_sold > 0 else "雨来之前，我们想给蜂巢备好一批花蜜。\n你带回来的，我都收。"
	for definition in m.upgrade_defs():
		var id: String = definition.id
		var b: Button = upgrade_buttons[id]
		var owned: bool = id in m.owned
		var available: bool = m.can_buy(id)
		b.disabled = not available
		upgrade_states[id].state.text = "✓ 已拥有" if owned else "%d 金币 · 点击购买" % definition.cost if available else m.locked_reason(id)
		upgrade_states[id].state.add_theme_color_override("font_color",Color("3b8060") if owned else INK if available else Color("859180"))
		if owned: b.add_theme_stylebox_override("disabled",style(Color("dce8c7"),Color("8eb17c"),1))
		else: b.add_theme_stylebox_override("disabled",style(Color("e4e6d7"),Color("b5c0ad"),1))

func ask_restart() -> void:
	restart_dialog.popup_centered(Vector2i(510,200))

func toggle_sound() -> void:
	muted = not muted
	driver.sound.set_muted(muted)
	driver.message("声音已关闭" if muted else "声音已开启",2)
