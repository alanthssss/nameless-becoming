extends Control
## Compact field HUD, contextual selling, and an illustrated field-journal growth screen.
const Board = preload("res://nectar_growth_board.gd")
const UIArt = preload("res://nectar_ui_art.gd")
const LANDMARKS: Texture2D = preload("res://art/garden-landmarks.png")
const HudIcon = preload("res://nectar_hud_icon.gd")
const INK := Color("294d40")
const PAPER := Color("f5edcf")
const GOLD := Color("eccb7c")
const MUTED := Color("a9beac")
var driver
var font := SystemFont.new()
var hud: Control
var hud_status: PanelContainer
var menu_guide: Button
var pond_info: Label
var meadow_info: Label
var bag_text: Label
var energy_text: Label
var coins_text: Label
var fiber_text: Label
var resin_text: Label
var tree_fiber: Label
var tree_resin: Label
var detail_card: PanelContainer
var detail_preview
var detail_costs := {}
var detail_cost_row: HBoxContainer
var hud_values := {}
var hud_tweens := {}
var energy_pulse: Tween
var low_energy := false
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
var shop_recap: Label
var shop_value: Label
var sell_button: Button
var leave_button: Button
var tree_button: Button
var upgrade_buttons := {}
var tree: Control
var board
var tree_coins: Label
var tree_progress: Label
var tree_footer: Label
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
var regions: Control
var region_title: Label
var region_hint: Label
var pond_button: Button
var meadow_button: Button
var home_button: Button
var region_back: Button
var region_cards: HBoxContainer
var region_caption: Label
var region_meadow_art: TextureRect
var transition_layer: ColorRect
var transition_label: Label
var transition_hint: Label
var journal: Control
var journal_status: Label
var journal_back: Button
var settings: Control
var settings_motion: Button
var settings_dance: Button
var settings_sound: Button
var settings_back: Button
var menu_settings: Button

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	_build_regions()
	_build_transition()
	_build_menu()
	_build_journal()
	_build_settings()
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

func painted_style(texture: Texture2D, region: Rect2, tint := Color.WHITE, inset := Vector2(24,20)) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	var painted := StyleBoxTexture.new()
	painted.texture = atlas
	painted.modulate_color = tint
	painted.content_margin_left = inset.x
	painted.content_margin_right = inset.x
	painted.content_margin_top = inset.y
	painted.content_margin_bottom = inset.y
	return painted

func card(parent: Node, fill := PAPER, edge := Color("81957a")) -> PanelContainer:
	var p := PanelContainer.new()
	if fill.r > .65:
		# One cropped page from the same painted book: no giant flat white panels.
		p.add_theme_stylebox_override("panel",painted_style(UIArt.JOURNAL,Rect2(35,48,715,900),Color.WHITE,Vector2(26,24)))
	else:
		# Field HUD stays compact/translucent; its icons use the painted material set.
		p.add_theme_stylebox_override("panel",style(fill,edge))
	parent.add_child(p)
	return p

func picture(parent: Node, texture: Texture2D, height: float) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(0,height)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

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
	b.custom_minimum_size = Vector2(240 if primary else 0,52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if primary else Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",20)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,Color("503d23") if primary else INK)
	b.add_theme_color_override("font_disabled_color",Color("84846b"))
	if primary:
		for key in ["normal","hover","pressed","disabled"]:
			var tint := Color("d8cfb6") if key == "disabled" else Color("fff1c7") if key == "hover" else Color("dfbd80") if key == "pressed" else Color.WHITE
			b.add_theme_stylebox_override(key,painted_style(LANDMARKS,Rect2(671,908,537,214),tint,Vector2(28,12)))
	else:
		b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover",style(Color("e7d6a74d"),Color("b7a575"),0,8))
		b.add_theme_stylebox_override("pressed",style(Color("d5bc7e70"),Color.TRANSPARENT,0,8))
		b.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color("a98040"),2,8))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func bar(parent: Node, tint: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size.y = 8
	p.show_percentage = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [["background",Color("ead8ae")],["fill",tint]]:
		var bar_style := style(pair[1],Color.TRANSPARENT,0,4)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: bar_style.set_content_margin(side,0)
		p.add_theme_stylebox_override(pair[0],bar_style)
	parent.add_child(p)
	return p

func spacer(parent: Node) -> void:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func hud_symbol(parent: Node, kind: String, hint: String) -> void:
	var symbol := HudIcon.new()
	symbol.kind = kind
	symbol.custom_minimum_size = Vector2(32,32)
	symbol.tooltip_text = hint
	parent.add_child(symbol)

func _build_hud() -> void:
	hud = screen(self)
	hud_status = card(hud,Color("254a3eef"),Color("79947b"))
	hud_status.add_theme_stylebox_override("panel",painted_style(LANDMARKS,Rect2(671,908,537,214),Color.WHITE,Vector2(22,14)))
	anchored(hud_status,Rect2(0,1,0,0),Rect2(24,-104,690,80))
	var hr := row(hud_status,16)
	var money := row(hr,4)
	hud_symbol(money,"coin","金币：交付花蜜后获得，用于成长")
	coins_text = text_line(money,"",22,Color("503d23"))
	coins_text.custom_minimum_size.x = 55
	coins_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var materials := column(hr,0)
	var fr := row(materials,3)
	hud_symbol(fr,"fiber","纤维：振翅后拾取，用于成长；救援时保留")
	fiber_text = text_line(fr,"0",18,Color("503d23"))
	var rr := row(materials,3)
	hud_symbol(rr,"resin","树脂：振翅后拾取，用于成长；救援时保留")
	resin_text = text_line(rr,"0",18,Color("503d23"))
	var bag := column(hr,4)
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var br := row(bag,4)
	hud_symbol(br,"bag","携带花蜜 / 蜜囊容量")
	bag_text = text_line(br,"",20,Color("503d23"))
	bag_bar = bar(bag,Color("b97524"))
	var energy := column(hr,4)
	energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var er := row(energy,4)
	hud_symbol(er,"wings","续航：庭院恢复，外出和淋雨消耗")
	energy_text = text_line(er,"",20,Color("503d23"))
	energy_bar = bar(energy,Color("39765c"))
	for value_label in [coins_text,fiber_text,resin_text,bag_text,energy_text]:
		value_label.add_theme_color_override("font_outline_color",Color("fff0d0"))
		value_label.add_theme_constant_override("outline_size",2)
	goal_text = text_line(hud,"",18)
	goal_text.hide()
	trip_text = text_line(hud,"",18)
	trip_text.hide()
	help_text = text_line(hud,"",19,INK)
	anchored(help_text,Rect2(.5,1,0,0),Rect2(-350,-151,700,32))
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_color_override("font_shadow_color",PAPER)
	help_text.add_theme_constant_override("shadow_offset_y",1)
	var pause := action(hud,"Ⅱ",driver.pause_game,true)
	pause.custom_minimum_size = Vector2(56,56)
	for key in ["normal","hover","pressed","disabled"]:
		pause.add_theme_stylebox_override(key,painted_style(LANDMARKS,Rect2(671,908,537,214),Color.WHITE,Vector2(12,10)))
	pause.tooltip_text = "暂停与操作说明 · Esc"
	anchored(pause,Rect2(1,1,0,0),Rect2(-80,-80,56,56))

func _build_shop() -> void:
	shop = screen(self)
	shade(shop,Color(.08,.17,.12,.23))
	var p := card(shop,PAPER,Color("a7a77c"))
	anchored(p,Rect2(1,.5,0,0),Rect2(-535,-350,500,700))
	var v := column(p,12)
	text_line(v,"庭院蜜铺 · 收购员",17,Color("7b895f")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_line(v,"这一趟，收获不错。",30).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_story = text_line(v,"带回花蜜，就能换取下一次成长。",19,Color("768064"),true)
	shop_recap = text_line(v,"",18,INK,true)
	shop_recap.hide()
	var cargo_card := card(v,Color("e5e8d0"),Color("bec8a5"))
	cargo_card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var cargo_v := column(cargo_card,12)
	shop_cargo = text_line(cargo_v,"",22)
	shop_value = text_line(cargo_v,"",27,Color("9a6c28"))
	sell_button = action(v,"全部交付",driver.sell_cargo,true)
	shop_coins = text_line(v,"",19,Color("718160"))
	spacer(v)
	leave_button = action(v,"回到庭院",driver.close_shop)
	tree_button = leave_button # Compatibility alias for the single return action.
	text_line(v,"Esc 返回庭院 · 交付立即结算",16,Color("839071")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_regions() -> void:
	regions = screen(self)
	shade(regions,Color("193c329c"))
	var v := column(regions,14)
	anchored(v,Rect2(.5,.5,0,0),Rect2(-450,-310,900,620))
	region_title = text_line(v,"这次去哪里？",32,PAPER)
	region_title.add_theme_color_override("font_shadow_color",INK)
	region_title.add_theme_constant_override("shadow_offset_y",2)
	region_hint = text_line(v,"",19,PAPER,true)
	region_cards = row(v,22)
	region_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pond_card := card(region_cards)
	pond_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pond_card.custom_minimum_size.x = 435
	var pv := column(pond_card,12)
	picture(pv,preload("res://art/nectar-pond-oblique.png"),210)
	pond_button = action(pv,"池岸花丛",func(): driver.request_transition("pond"),true)
	pond_info = text_line(pv,"每花 1 份 · 每份 1 金币 · 晴",18,INK,true)
	var meadow_card := card(region_cards)
	meadow_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meadow_card.custom_minimum_size.x = 435
	var mv := column(meadow_card,12)
	region_meadow_art = picture(mv,preload("res://art/nectar-meadow-oblique.png"),210)
	meadow_button = action(mv,"紫花地",func(): driver.request_transition("meadow"),true)
	meadow_info = text_line(mv,"每花 1 份 · 每份 3 金币 · 局部细雨",18,INK,true)
	home_button = action(mv,"回到蜂巢庭院",func(): driver.request_transition("hub"),true)
	region_caption = text_line(mv,"花蜜与材料随身带回。",18,INK,true)
	region_back = action(v,"先留在这里  ·  Esc",driver.close_regions)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: region_back.add_theme_color_override(key,PAPER)

func _build_transition() -> void:
	transition_layer = preload("res://nectar_iris_transition.gd").new()
	add_child(transition_layer)
	transition_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_layer.color = Color("183d34")
	transition_label = text_line(transition_layer,"",30,PAPER)
	anchored(transition_label,Rect2(.5,.5,0,0),Rect2(-300,-30,600,60))
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.hide()
	transition_hint = text_line(self,"空格 跳过",17,Color("c0cbb1"))
	anchored(transition_hint,Rect2(.5,1,0,0),Rect2(-280,-88,560,40))
	transition_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_hint.add_theme_color_override("font_shadow_color",INK)
	transition_hint.add_theme_constant_override("shadow_offset_y",2)
	transition_hint.hide()
	transition_layer.hide()

func set_transition(alpha: float, words: String) -> void:
	transition_layer.configure(alpha,driver.model.p-Vector2(driver.model.camera_x,0),driver.transition_short,driver.transition_elapsed)
	transition_label.text = words
	move_child(transition_layer,get_child_count()-1)
	move_child(transition_hint,get_child_count()-1)

func _build_tree() -> void:
	tree = screen(self)
	shade(tree,Color("314d38d9"))
	var journal_art := TextureRect.new()
	journal_art.texture = preload("res://art/nectar-growth-journal.png")
	journal_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	journal_art.stretch_mode = TextureRect.STRETCH_SCALE
	journal_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.add_child(journal_art)
	anchored(journal_art,Rect2(0,0,1,1),Rect2(10,12,-20,-24))
	var header := row(tree,18)
	anchored(header,Rect2(0,0,1,0),Rect2(120,78,-200,66))
	var titles := column(header,2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_line(titles,"成长手册",30,INK)
	tree_progress = text_line(titles,"",16,Color("798054"))
	var balance := row(header,5)
	hud_symbol(balance,"coin","金币")
	tree_coins = text_line(balance,"",23,INK)
	tree_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for kind in ["fiber","resin"]:
		var resource := row(header,4)
		hud_symbol(resource,kind,"纤维" if kind == "fiber" else "树脂")
		var count := text_line(resource,"0",21,INK)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if kind == "fiber": tree_fiber = count
		else: tree_resin = count
	tree_back = action(header,"返回",driver.close_tree)
	tree_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	tree_back.custom_minimum_size.x = 100
	board = Board.new()
	board.font = font
	tree.add_child(board)
	anchored(board,Rect2(0,0,.7,1),Rect2(70,180,-80,-300))
	board.selected_changed.connect(_selected)
	board.resized.connect(_place_detail)
	detail_card = card(tree,PAPER,Color("b5b58c"))
	var page_detail := StyleBoxEmpty.new()
	page_detail.content_margin_left = 18
	page_detail.content_margin_right = 18
	page_detail.content_margin_top = 14
	page_detail.content_margin_bottom = 14
	detail_card.add_theme_stylebox_override("panel",page_detail)
	detail_card.custom_minimum_size = Vector2(280,0)
	detail_card.size = Vector2(280,260)
	detail_card.resized.connect(func(): _place_detail.call_deferred())
	var dv := column(detail_card,8)
	var title_row := row(dv,8)
	detail_title = text_line(title_row,"",25)
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_level = text_line(title_row,"",16,Color("7a8865"))
	detail_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_effect = text_line(dv,"",24,INK,true)
	detail_effect.custom_minimum_size.x = 244
	detail_effect.size.x = 244
	detail_preview = HudIcon.new()
	detail_preview.preview = true
	detail_preview.custom_minimum_size = Vector2(0,46)
	detail_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dv.add_child(detail_preview)
	detail_cost_row = row(dv,14)
	for kind in ["coin","fiber","resin"]:
		var cost := row(detail_cost_row,3)
		hud_symbol(cost,kind,{"coin":"金币","fiber":"纤维","resin":"树脂"}[kind])
		var count := text_line(cost,"",19,INK)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		detail_costs[kind] = count
	detail_requirements = text_line(dv,"",16,Color("85683f"),true)
	detail_requirements.custom_minimum_size.x = 244
	detail_requirements.size.x = 244
	detail_hint = text_line(dv,"",16,Color("758365"),true)
	detail_hint.hide()
	buy_button = action(dv,"",_purchase_button_activated,true)
	buy_button.custom_minimum_size.y = 46
	buy_button.gui_input.connect(_purchase_button_input)
	var foot := text_line(tree,"方向键 选择   ·   Enter 成长   ·   Esc 返回",16,Color("65704a"))
	tree_footer = foot
	anchored(foot,Rect2(0,1,0,0),Rect2(90,-105,500,26))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.tooltip_text = "↑↓ 同区选择 · ←→ 换区 · Tab 依次浏览 · 每次确认提升一级"
	foot.mouse_filter = Control.MOUSE_FILTER_PASS
	for data in Board.NODES:
		for id in data.ranks: upgrade_buttons[id] = board.buttons[data.id]

func _place_detail() -> void:
	if not is_instance_valid(detail_card) or not is_instance_valid(board) or not tree.visible: return
	# The right margin is reserved for the selected entry. It never covers the
	# botanical nodes or changes position while browsing the book.
	var box := Vector2(280,maxf(242,detail_card.get_combined_minimum_size().y))
	detail_card.size = box
	detail_card.position = Vector2(size.x-348,180)

func _build_menu() -> void:
	menu = screen(self)
	shade(menu,Color(.09,.20,.15,.24))
	var panel := card(menu)
	panel.add_theme_stylebox_override("panel",painted_style(UIArt.JOURNAL,Rect2(35,48,715,900),Color.WHITE,Vector2(38,38)))
	anchored(panel,Rect2(0,.5,0,0),Rect2(76,-286,440,572))
	var v := column(panel,16)
	menu_title = text_line(v,driver.DISPLAY_NAME,34)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_body = text_line(v,"",20,INK,true)
	menu_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_primary = action(v,"开始采蜜",driver.start_game,true)
	var middle := row(v,12)
	menu_settings = action(middle,"设置",driver.open_settings)
	menu_guide = action(middle,"花路手册",driver.open_journal)
	var bottom := row(v,12)
	menu_restart = action(bottom,"新的一轮",ask_restart)
	menu_quit = action(bottom,"保存并退出",driver.quit_game)
	text_line(v,"Demo 0.27.0  ·  Esc 返回",16,Color("7d7a56")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_toast() -> void:
	toast_panel = card(self,Color("204438f2"),Color("b2ac70"))
	anchored(toast_panel,Rect2(.5,0,0,0),Rect2(-380,130,760,84))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast = text_line(toast_panel,"",20,PAPER,true)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.hide()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(toast_panel.hide)
	toast_timer.timeout.connect(func(): tree_footer.show())
	add_child(toast_timer)

func show_toast(words: String, seconds: float) -> void:
	# Completion already presents the result and next actions in its own card.
	# Duplicating that message above it covered the heading (0.26 review P3).
	if driver.mode == "complete":
		if "花费 " in words:
			menu_body.text = words+"\n\n同伴们在蜂舞广场等你。\n也可以继续探索和成长。"
		toast_panel.hide()
		return
	toast.text = words
	if driver.mode == "tree":
		anchored(toast_panel,Rect2(0,1,0,0),Rect2(90,-153,490,74))
		tree_footer.hide()
	elif driver.mode == "shop": anchored(toast_panel,Rect2(0,0,0,0),Rect2(24,24,680,84))
	else: anchored(toast_panel,Rect2(.5,0,0,0),Rect2(-380,130,760,84))
	toast_panel.show()
	toast_timer.start(minf(seconds,3.0) if words.length()<35 else seconds)

func show_mode(mode: String) -> void:
	hud.visible = mode == "play"
	shop.visible = mode == "shop"
	tree.visible = mode == "tree"
	menu.visible = mode in ["title","pause","complete"]
	regions.visible = mode == "regions"
	transition_layer.visible = mode == "transition"
	transition_hint.visible = mode == "transition"
	journal.visible = mode == "journal"
	settings.visible = mode == "settings"
	menu_guide.visible = mode == "pause"
	if mode == "journal":
		journal_status.text = "紫花地已记录 · 已交付紫蜜 %d 份" % driver.model.rose_sold if driver.model.visited_meadow else "池岸已备好 · 紫花地待探索"
		journal_back.grab_focus()
	if mode == "settings":
		refresh_settings()
		settings_motion.grab_focus()
	if mode == "regions":
		refresh()
		pond_button.grab_focus()
	enter_held = false
	shop_cache = ""
	toast_panel.hide()
	if mode == "shop":
		refresh()
		if not sell_button.disabled: sell_button.grab_focus()
		else: leave_button.grab_focus()
	elif mode == "tree":
		refresh()
		board.select_node(board.selected)
	elif menu.visible:
		if mode == "title":
			menu_title.text = driver.DISPLAY_NAME
			menu_body.text = "在蜂舞广场选一条花路，带着花蜜回来。\n交付、成长，再去更远的地方。"
			menu_primary.text = "继续采蜜" if driver.has_save else "从蜂巢出发"
		elif mode == "pause":
			menu_title.text = "歇一会儿"
			menu_body.text = driver.model.goal_text()+"\n\nWASD 飞行  ·  E 采蜜\nQ 振翅  ·  空格蓄力冲刺\n\n详细操作与花路，翻看手册。"
			menu_primary.text = "继续这趟出行"
		else:
			menu_title.text = "花蜜，备好了"
			menu_body.text = "Demo 的花蜜储备已完成。\n\n同伴们在蜂舞广场等你庆祝。\n花还开着，也可以继续探索和成长。"
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
		"reach", "beat": return "采蜜技巧至少 1级"
		"twin": return "同时满足：\n采蜜技巧 2级\n花香触角已获得"
		"meadow": return "基础能力成长  %d / 3 次\n同一能力升两级，计两次" % mini(3,m.growth_count())
		"shortcut": return "紫花地已开放"
		"market": return "已经探索紫花地\n已交售紫蜜  %d / 1 份" % mini(1,m.rose_sold)
		"reserve": return "已经探索紫花地\n已交售紫蜜  %d / 6 份\n\n任选其一：\n双簇采蜜 或 叶间近道" % mini(6,m.rose_sold)
	return ""

func _detail() -> void:
	if board.model == null: return
	var id: String = board.selected
	var data: Dictionary = board.definition(id)
	var rank: int = board.rank_of(id)
	var next: String = board.next_id(id)
	var m = driver.model
	detail_title.text = data.title
	detail_level.text = "%d / %d" % [rank,data.ranks.size()]
	detail_card.tooltip_text = _requirements(id)
	detail_cost_row.visible = not next.is_empty()
	var previews := {
		"gather":[[1.8,1.2,.8][rank],[1.8,1.2,.8][mini(rank+1,2)]],
		"bag":[[6,10,16][rank],[6,10,16][mini(rank+1,2)]],
		"wings":[[36,50,70][rank],[36,50,70][mini(rank+1,2)]],
		"reach":[100 if rank == 0 else 155,155], "beat":[1 if rank == 0 else 2,2], "twin":[1 if rank == 0 else 2,2]}
	detail_preview.visible = id in previews and not next.is_empty()
	detail_preview.kind = id
	detail_preview.reduced_motion = driver.reduced_motion
	if id in previews:
		detail_preview.current_value = float(previews[id][0])
		detail_preview.next_value = float(previews[id][1])
	detail_preview.tooltip_text = "上：现在 · 下：成长后"+("；每条走完获得一份" if id == "gather" else "")
	detail_preview.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_preview.queue_redraw()
	if next.is_empty():
		var effects := {"gather":"0.8 秒 / 份", "bag":"16 份", "wings":"70 续航", "reach":"采蜜 155 · 振翅 205", "beat":"振翅强度 2\n纤维 1次 · 树脂 2次", "twin":"同时采 2 朵", "meadow":"紫花地已开放", "shortcut":"双向近道已点亮", "market":"售卖 +25%", "reserve":"花蜜已备好"}
		detail_effect.text = effects[id]
		buy_button.text = "✓ 已成长"
		buy_button.disabled = true
		detail_requirements.text = ""
		detail_hint.text = "效果已保留"
	else:
		var definition: Dictionary = m.upgrade(next)
		var effects := {"gather":definition.description,"bag":definition.description,"wings":definition.description,"reach":"采蜜 100 → 155\n振翅 150 → 205","beat":"振翅强度 1 → 2\n纤维：2次 → 1次\n树脂：3次 → 2次","twin":"1 → 2 朵","meadow":"解锁紫花蜜","shortcut":"两片花地直接往返","market":"售卖 +25%","reserve":"备好雨前储粮"}
		detail_effect.text = effects[id]
		detail_effect.tooltip_text = definition.description+("；振翅半径 150 → 205" if id == "reach" else "")
		detail_effect.mouse_filter = Control.MOUSE_FILTER_PASS
		for kind in detail_costs:
			var cost: int = definition.cost if kind == "coin" else int(definition.get(kind,0))
			var held: int = m.coins if kind == "coin" else int(m.materials[kind])
			detail_costs[kind].get_parent().visible = cost > 0
			detail_costs[kind].text = str(cost)
			detail_costs[kind].add_theme_color_override("font_color",Color("a06042") if held < cost else INK)
		buy_button.text = "完成储备" if id == "reserve" else "开放花地" if id == "meadow" else "成长"
		buy_button.disabled = not m.can_buy(next)
		detail_requirements.text = m.locked_reason(next) if buy_button.disabled else ""
		detail_hint.text = detail_requirements.text
		buy_button.tooltip_text = _requirements(id)
	detail_requirements.visible = not detail_requirements.text.is_empty()
	_place_detail.call_deferred()

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
	_number(bag_text,"%d / %d" % [m.cargo_total(),m.capacity()],m.cargo_total())
	bag_bar.max_value = m.capacity()
	bag_bar.value = m.cargo_total()
	energy_text.text = "%d / %d" % [int(ceil(m.energy)),int(m.max_energy())]
	energy_bar.max_value = m.max_energy()
	energy_bar.value = m.energy
	_number(coins_text,str(m.coins),m.coins)
	_number(fiber_text,str(m.materials.fiber),m.materials.fiber)
	_number(resin_text,str(m.materials.resin),m.materials.resin)
	_energy_attention(m.energy < m.max_energy()*.25 and not m.at_home())
	trip_text.text = driver.area_name(m.area)+(" · 安全生活区" if m.at_home() else " · 第 %d 趟" % maxi(1,m.trip_index))
	goal_text.text = m.goal_text()
	help_text.text = ""
	if not m.at_home():
		if driver.has_harvest_hint(): help_text.text = "按住 E  采蜜"
		elif driver.has_material_hint(): help_text.text = "Q  振翅"
		elif m.cargo_total() >= m.capacity(): help_text.text = "蜜囊已满"
	help_text.visible = not help_text.text.is_empty()
	var from_hub: bool = m.area == "hub"
	region_title.text = "这次去哪里？" if from_hub else "带着收获回去"
	region_hint.text = "蜜囊 %d / %d · 续航 %d" % [m.cargo_total(),m.capacity(),m.max_energy()] if from_hub else "花蜜与材料随身带回。"
	pond_button.text = "池岸花丛 · 蓝花蜜" if from_hub else "返回池岸花丛"
	meadow_button.visible = from_hub
	meadow_info.visible = from_hub
	pond_info.visible = true
	pond_info.text = "每份 1 金币 · 晴\n近岸采蜜，草岸回弯取纤维。" if from_hub else "回到池岸花丛，继续这一趟。"
	region_meadow_art.texture = preload("res://art/nectar-meadow-oblique.png") if from_hub else preload("res://art/nectar-courtyard-oblique.png")
	region_caption.visible = not from_hub
	meadow_button.disabled = "meadow" not in m.owned
	meadow_button.text = "紫花地 · 紫花蜜" if "meadow" in m.owned else "紫花地 · 尚未开放"
	meadow_info.text = "每份 3 金币 · 局部细雨\n"+("穿雨或绕叶棚，取蜜与树脂。" if "meadow" in m.owned else "在成长手册中开放这条花路。")
	home_button.visible = not from_hub
	shop_coins.text = "当前金币  %d" % m.coins
	shop_recap.text = "\n".join([driver.home_return_summary,driver.home_sale_summary]).strip_edges()
	shop_recap.visible = not shop_recap.text.is_empty()
	shop_cargo.text = "蓝花蜜    %d 份\n紫花蜜    %d 份" % [m.cargo.blue,m.cargo.rose]
	shop_value.text = "本趟可售  %d 金币" % m.cargo_value()
	sell_button.text = "全部交付  +%d 金币" % m.cargo_value() if m.cargo_total() else "花蜜已交付"
	sell_button.disabled = m.cargo_total() == 0
	if m.completed: shop_story.text = "雨前的储备已经够了。\n同伴们在蜂舞广场等你庆祝，花园仍欢迎你。"
	elif m.rose_sold > 0: shop_story.text = "货架上也有紫花蜜了。\n这一趟改善采集、出行，还是先留钱备粮？"
	elif m.sold_total > 0: shop_story.text = "你带回的花蜜已摆上货架。\n去书屋挑一项成长，再从广场出发吧。"
	else: shop_story.text = "雨来前，我们一起备好花蜜。\n第一趟蓝花蜜可以换来采集或蜜囊成长。"
	board.reduced_motion = driver.reduced_motion
	board.refresh(m)
	tree_coins.text = str(m.coins)
	tree_fiber.text = str(m.materials.fiber)
	tree_resin.text = str(m.materials.resin)
	tree_progress.text = "紫花地已开放" if "meadow" in m.owned else "花路成长 %d / 3" % mini(3,m.growth_count())
	_detail()

func ask_restart() -> void:
	restart_dialog.popup_centered(Vector2i(540,220))

func toggle_sound() -> void:
	muted = not muted
	driver.sound.set_muted(muted)
	driver.save_settings()
	driver.message("声音已关闭" if muted else "声音已开启",2)

func _build_journal() -> void:
	journal = screen(self)
	shade(journal,Color("173d35d9"))
	var p := card(journal)
	anchored(p,Rect2(.5,.5,0,0),Rect2(-480,-315,960,630))
	var v := column(p,14)
	text_line(v,"花路见闻",32).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	journal_status = text_line(v,"",18,Color("7b895f"))
	var h := row(v,18)
	for entry in [
		["池岸花丛","蓝花蜜 · 每份 1 金币","每花 1 份 · 生物不会攻击。\n振翅驱离小飞虫，拾取纤维。\n采够了即可从灯球返回。"],
		["紫花地","紫花蜜 · 每份 3 金币","在成长书屋开放后出发。\n每花 1 份 · 可收集树脂。\n细雨增加消耗，叶棚下可避雨。"]]:
		var c := card(h,Color("e7e9cf"))
		c.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.x = 430
		var cv := column(c,14)
		text_line(cv,entry[0],27)
		text_line(cv,entry[1],21,Color("9a6c28"))
		text_line(cv,entry[2],20,INK,true)
	text_line(v,"按住 E / 左键采蜜 · Q / 右键振翅 · 空格蓄力冲刺。",19,INK,true)
	text_line(v,"花蜜在野外 18 秒后恢复，暂停时停止计时。续航耗尽损失一半花蜜，材料、金币与成长保留。",19,INK,true)
	spacer(v)
	journal_back = action(v,"返回",driver.close_journal,true)

func _build_settings() -> void:
	settings = screen(self)
	shade(settings,Color("173d35ee"))
	var p := card(settings)
	anchored(p,Rect2(.5,.5,0,0),Rect2(-350,-340,700,680))
	var scroll := ScrollContainer.new()
	p.add_child(scroll)
	var v := column(scroll,14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_line(v,"设置与旅途说明",30).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_motion = action(v,"",func():
		driver.reduced_motion = not driver.reduced_motion
		driver.save_settings())
	settings_dance = action(v,"",func():
		driver.dance_style = "side_step" if driver.dance_style == "waggle" else "waggle"
		driver.save_settings())
	settings_sound = action(v,"",toggle_sound)
	text_line(v,"WASD / 方向键飞行 · E 交互，花丛中按住 E 或鼠标采蜜\nQ / 右键振翅（2 续航） · 空格蓄力冲刺 · F 使用近道 · M 静音 · Esc 暂停\n成长图：方向键、Tab 选节点，Enter 确认一级；蜂舞中空格跳过。",18,INK,true)
	text_line(v,"关于 Demo",23)
	text_line(v,"%s 0.27.0\n一处庭院、两片花地、两种材料、10 个成长节点（共 13 级）。\n完成花蜜储备后仍可继续探索。进度自动保存，菜单可保存退出。" % driver.DISPLAY_NAME,18,INK,true)
	text_line(v,"制作：Alan × Codex · Godot Engine（MIT）\n画面含 AI 辅助生成的预制美术，运行时不调用生成式 AI。\n蜂舞为通信动作启发的幻想演绎；侧步摆肩为项目原创动作。\n设计研究参考 Shelldiver，未使用其图像、音乐或代码。",17,Color("687957"),true)
	text_line(v,"键鼠版 · macOS 候选构建；手柄支持与 Steam 平台功能尚未完成。",17,Color("687957"),true)
	settings_back = action(v,"返回",driver.close_settings,true)

func refresh_settings() -> void:
	if not is_instance_valid(settings_motion): return
	settings_motion.text = "简化动画：开启 · 短淡变，关闭灯束与群舞" if driver.reduced_motion else "简化动画：关闭 · 完整蜂舞与柔光"
	settings_dance.text = "舞蹈：侧步摆肩 · 原创拟人小组合" if driver.dance_style == "side_step" else "舞蹈：摆尾回环 · 蜜蜂通信启发"
	settings_dance.disabled = driver.reduced_motion
	settings_sound.text = "声音：关闭" if muted else "声音：开启"

func _number(label: Label, words: String, value: int) -> void:
	var key := label.get_instance_id()
	var gained: bool = hud_values.has(key) and value > int(hud_values[key])
	hud_values[key] = value
	label.text = words
	if not gained or driver.reduced_motion: return
	if hud_tweens.has(key): hud_tweens[key].kill()
	label.pivot_offset = label.size*.5
	label.scale = Vector2(1.15,1.15)
	var tween := create_tween()
	tween.tween_property(label,"scale",Vector2.ONE,.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hud_tweens[key] = tween

func _energy_attention(warning: bool) -> void:
	warning = warning and not driver.reduced_motion
	if warning == low_energy: return
	low_energy = warning
	if energy_pulse: energy_pulse.kill()
	energy_bar.modulate = Color.WHITE
	energy_text.modulate = Color.WHITE
	if warning:
		energy_pulse = create_tween().set_loops()
		energy_pulse.tween_property(energy_bar,"modulate",Color("efb678"),.6)
		energy_pulse.tween_property(energy_bar,"modulate",Color.WHITE,.6)

func _exit_tree() -> void:
	if energy_pulse: energy_pulse.kill()
	energy_pulse = null
	for tween in hud_tweens.values(): tween.kill()
	hud_tweens.clear()
