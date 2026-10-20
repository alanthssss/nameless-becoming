extends Control
const Merge = preload("res://merge_model.gd")
const Match = preload("res://match_model.gd")
const Board = preload("res://board_view.gd")
const Sound = preload("res://sound.gd")
const INK := Color("#304735")
var font := SystemFont.new()
var model
var kind := "merge"
var mode := "title"
var seed_value := 0
var elapsed := 0.0
var started := false
var muted := false
var cursor := 0
var selected := -1
var busy := false
var frames: Array[Dictionary] = []
var frame_time := 0.0
var shown_collected := 0
var board
var sound
var game_root: Control
var title_root: Control
var modal: Control
var modal_heading: Label
var modal_body: Label
var modal_buttons: VBoxContainer
var goal_label: Label
var counter_label: Label
var turns_label: Label
var help_label: Label
var feedback: Label
var progress: ProgressBar
var undo_button: Button
var arrows: Control
var sound_button: Button
var heading: Label
var menu_buttons: Array[Button] = []
var menu_index := 0
var capture_path := ""
var capture_after := -1.0
var qa_seed := -1

func _ready() -> void:
	font.font_names = PackedStringArray(["PingFang SC","Hiragino Sans GB","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	self.theme = theme
	sound = Sound.new()
	add_child(sound)
	build_ui()
	show_title()
	var initial := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): qa_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--mode="): initial = arg.trim_prefix("--mode=")
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-after="): capture_after = float(arg.trim_prefix("--capture-after="))
	if initial in ["merge","match"]: start_game(initial,qa_seed)
	queue_redraw()

func box(fill: Color, border := Color("#b9c7a8"), width := 2, radius := 18) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	return b

func text_label(words: String, font_size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(words: String, action: Callable, height := 48) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size.y = height
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_disabled_color",Color("#87917d"))
	b.add_theme_stylebox_override("normal",box(Color("#fff9e8")))
	b.add_theme_stylebox_override("hover",box(Color("#f7e6ab"),Color("#9b813d")))
	b.add_theme_stylebox_override("pressed",box(Color("#ead08b"),Color("#6f7039")))
	b.add_theme_stylebox_override("disabled",box(Color("#e5e5d8"),Color("#d1d8c8")))
	b.pressed.connect(action)
	return b

func margins(parent: Node, amount: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: m.add_theme_constant_override("margin_"+edge,amount)
	parent.add_child(m)
	return m

func column(parent: Node, separation := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",separation)
	parent.add_child(v)
	return v

func build_ui() -> void:
	game_root = Control.new()
	game_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_root)
	var root_margin := margins(game_root,36)
	var root_col := column(root_margin,18)
	var top := HBoxContainer.new()
	root_col.add_child(top)
	heading = text_label("",29)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	sound_button = button("声音开 · M",toggle_sound)
	sound_button.custom_minimum_size.x = 154
	top.add_child(sound_button)
	var pause_button := button("暂停 · Esc",pause_game)
	pause_button.custom_minimum_size.x = 160
	top.add_child(pause_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_col.add_child(row)
	var info := PanelContainer.new()
	info.custom_minimum_size.x = 352
	info.add_theme_stylebox_override("panel",box(Color("#edf0dc")))
	row.add_child(info)
	var info_margin := margins(info,20)
	var info_col := column(info_margin,12)
	info_col.add_child(text_label("这一局的目标",17,Color("#627659")))
	goal_label = text_label("",37)
	info_col.add_child(goal_label)
	counter_label = text_label("",23)
	info_col.add_child(counter_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 14
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background",box(Color("#d3ddbf"),Color.TRANSPARENT,0,7))
	progress.add_theme_stylebox_override("fill",box(Color("#85a967"),Color.TRANSPARENT,0,7))
	info_col.add_child(progress)
	turns_label = text_label("",24)
	info_col.add_child(turns_label)
	help_label = text_label("",20)
	help_label.custom_minimum_size.y = 98
	info_col.add_child(help_label)
	feedback = text_label("",20,Color("#716532"))
	feedback.custom_minimum_size.y = 64
	feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_col.add_child(feedback)
	undo_button = button("撤回一步 · Z",undo_merge)
	info_col.add_child(undo_button)
	var arrow_col := HBoxContainer.new()
	arrow_col.add_theme_constant_override("separation",8)
	info_col.add_child(arrow_col)
	arrows = arrow_col
	for item in [["←",Vector2i.LEFT],["↑",Vector2i.UP],["↓",Vector2i.DOWN],["→",Vector2i.RIGHT]]:
		var b := button(item[0],merge_move.bind(item[1]),42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arrow_col.add_child(b)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(aspect)
	board = Board.new()
	board.font = font
	aspect.add_child(board)
	board.cell_clicked.connect(choose_cell)
	board.cell_dragged.connect(drag_cells)
	var footer := text_label("每次只玩一种规则。没有倒计时，慢慢想也没关系。",17,Color("#718064"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_col.add_child(footer)
	build_title()
	build_modal()

func build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins(title_root,56).add_child(center)
	var col := column(center,22)
	col.custom_minimum_size.x = 1040
	var kicker := text_label("GARDEN PLAYROOM     /     0.1.0",16,Color("#718064"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	var title := text_label("今天，玩哪一种？",46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var subtitle := text_label("两种简单玩法，每一种都能完整玩一局。",23)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	col.add_child(row)
	for item in [["合成 128\n\n2 + 2 → 4，一路合出 128\n\n方向键滑动 · 可以撤回","merge"],["花朵三消\n\n相邻交换，三个相同就消除\n\n鼠标交换 · 18 步消掉 60 朵","match"]]:
		var b := button(item[0],start_game.bind(item[1],-1),270)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",24)
		row.add_child(b)
		b.set_meta("menu",true)
	var hint := text_label("← → 选择，Enter 开始；也可以直接点击。  M 声音",18,Color("#718064"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

func build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.14,0.23,0.17,0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 510
	panel.add_theme_stylebox_override("panel",box(Color("#fff8e6"),Color("#71865b"),3,24))
	center.add_child(panel)
	var col := column(margins(panel,30),18)
	modal_heading = text_label("",36)
	modal_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(modal_heading)
	modal_body = text_label("",21)
	modal_body.custom_minimum_size = Vector2(450,100)
	modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(modal_body)
	modal_buttons = column(col,12)
	col.add_child(text_label("↑ ↓ 选择 · Enter 确认",16,Color("#718064")))

func find_title_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button and child.has_meta("menu"): menu_buttons.append(child)
		find_title_buttons(child)

func show_title() -> void:
	mode = "title"
	busy = false
	frames.clear()
	selected = -1
	game_root.hide()
	modal.hide()
	title_root.show()
	menu_buttons.clear()
	find_title_buttons(title_root)
	menu_index = 0
	style_menu()

func style_menu() -> void:
	for i in menu_buttons.size():
		var chosen := i == menu_index
		menu_buttons[i].add_theme_stylebox_override("normal",box(Color("#f6e4ab") if chosen else Color("#fff9e8"),Color("#8d8749") if chosen else Color("#b9c7a8"),3 if chosen else 2))

func start_game(which: String, requested_seed := -1) -> void:
	kind = which
	seed_value = requested_seed if requested_seed >= 0 else (qa_seed if qa_seed >= 0 else int(randi()%1000000000))
	model = Merge.new() if kind == "merge" else Match.new()
	model.reset(seed_value)
	mode = "play"
	elapsed = 0
	started = false
	selected = -1
	cursor = 0
	shown_collected = 0
	busy = false
	frames.clear()
	title_root.hide()
	modal.hide()
	game_root.show()
	board.kind = kind
	board.cursor = cursor
	board.selected = -1
	board.frame = {}
	board.values = model.board.duplicate()
	board.interactive = true
	board.queue_redraw()
	sound.set_stage(0 if kind == "merge" else 1)
	feedback.text = "先试着向一个方向滑动。" if kind == "merge" else "点击一朵花，再点击旁边一朵。\n也可以直接拖到相邻格。"
	refresh_hud()

func refresh_hud() -> void:
	if model == null: return
	heading.text = "01  合成 128" if kind == "merge" else "02  花朵三消"
	goal_label.text = "合出 128" if kind == "merge" else "消掉 60 朵"
	progress.max_value = 128 if kind == "merge" else 60
	if kind == "merge":
		var best: int = model.board.max()
		counter_label.text = "最大数字  %d" % best
		progress.value = best
		turns_label.text = "已经滑动  %d 次" % model.moves
		help_label.text = "方向键 / WASD 滑动全盘\n相同数字相遇就合并\n每步会在空位长出新数字\n无法移动时，这一局结束"
	else:
		counter_label.text = "已消除  %d / 60 朵" % mini(shown_collected,60)
		progress.value = shown_collected
		turns_label.text = "还剩  %d 步" % model.moves_left
		help_label.text = "相邻交换，横竖三个就消除\n无效交换不扣步数\n键盘：方向键选格，Enter 确认"
	undo_button.visible = kind == "merge"
	undo_button.disabled = kind != "merge" or busy or not model.can_undo()
	arrows.visible = kind == "merge"
	board.interactive = mode == "play" and not busy

func merge_move(direction: Vector2i) -> void:
	if mode != "play" or busy or kind != "merge": return
	var result: Dictionary = model.move(direction)
	if not result.valid:
		feedback.text = "这个方向挪不动，试试另一边。\n无效移动不会生成新数字。"
		sound.play_event("charge_cancel")
		return
	started = true
	feedback.text = "合并了！给下一步留些空位。" if not result.merged.is_empty() else "挪出空间，准备下一次合并。"
	schedule([{"kind":"slide","values":result.before,"slides":result.slides,"duration":0.14},{"kind":"pop","values":result.after,"merged":result.merged,"spawned":result.spawned,"duration":0.16,"sound":"dew" if not result.merged.is_empty() else ""}])

func choose_cell(index: int) -> void:
	if mode != "play" or busy or kind != "match" or index < 0 or index >= 36: return
	cursor = index
	board.cursor = cursor
	if selected == index:
		selected = -1
	elif selected >= 0 and adjacent(selected,index):
		attempt_swap(selected,index)
		return
	else:
		selected = index
		feedback.text = "已选这朵花。\n再选相邻的一格交换。"
	board.selected = selected
	board.queue_redraw()

func adjacent(a: int,b: int) -> bool:
	return absi(a%6-b%6)+absi(a/6-b/6) == 1

func drag_cells(a: int,b: int) -> void:
	if mode != "play" or busy or kind != "match": return
	if adjacent(a,b): attempt_swap(a,b)
	else:
		selected = -1
		choose_cell(b)

func falling_tiles(step: Dictionary) -> Array:
	var result: Array = []
	for x in 6:
		var row := 5
		for y in range(5,-1,-1):
			var i := y*6+x
			if i in step.cleared: continue
			result.append({"to":row*6+x,"from_row":float(y),"value":step.board[i]})
			row -= 1
		for y in range(row,-1,-1):
			result.append({"to":y*6+x,"from_row":float(y-row-1),"value":step.after[y*6+x]})
	return result

func attempt_swap(a: int,b: int) -> void:
	if mode != "play" or busy: return
	selected = -1
	cursor = b
	board.selected = -1
	board.cursor = cursor
	var result: Dictionary = model.swap(a,b)
	var sequence: Array[Dictionary] = [{"kind":"swap","values":result.before,"a":a,"b":b,"duration":0.15}]
	if not result.valid:
		feedback.text = "交换后要连成三个相同花朵。\n这次不扣步数，再试试。"
		sequence.append({"kind":"swap","values":result.swapped,"a":a,"b":b,"duration":0.15,"sound":"charge_cancel"})
	else:
		started = true
		var chain := 0
		for step in result.steps:
			chain += 1
			sequence.append({"kind":"clear","values":step.board,"cleared":step.cleared,"duration":0.22,"award":step.cleared.size(),"sound":"dew" if chain==1 else "ring","message":"消除了 %d 朵" % step.cleared.size() if chain==1 else "连消 %d 次！再收 %d 朵" % [chain,step.cleared.size()]})
			sequence.append({"kind":"fall","values":step.after,"falls":falling_tiles(step),"duration":0.20})
		if result.shuffled:
			sequence.append({"kind":"pop","values":result.after,"duration":0.3,"message":"没有可交换的三连，已免费重排。"})
	schedule(sequence)

func schedule(sequence: Array) -> void:
	frames.assign(sequence)
	busy = true
	begin_frame()
	refresh_hud()

func begin_frame() -> void:
	if frames.is_empty():
		busy = false
		board.frame = {}
		board.values = model.board.duplicate()
		if kind == "match": shown_collected = model.collected
		board.queue_redraw()
		refresh_hud()
		if model.phase != "playing": show_result()
		return
	frame_time = 0
	board.frame = frames[0]
	board.values = frames[0].values
	board.progress = 0
	if frames[0].has("message"): feedback.text = frames[0].message
	if frames[0].get("sound","") != "": sound.play_event(frames[0].sound)
	board.queue_redraw()

func tick(delta: float) -> void:
	if mode != "play": return
	if started: elapsed += delta
	if not busy: return
	frame_time += delta
	board.progress = minf(1.0,frame_time/float(frames[0].duration))
	board.queue_redraw()
	if board.progress >= 1:
		shown_collected += int(frames[0].get("award",0))
		frames.pop_front()
		begin_frame()
		refresh_hud()

func _process(delta: float) -> void:
	tick(minf(delta,0.1))
	if capture_after >= 0:
		capture_after -= delta
		if capture_after < 0 and not capture_path.is_empty(): capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	print("CAPTURED: "+capture_path)
	get_tree().quit()

func undo_merge() -> void:
	if kind != "merge" or busy or mode not in ["play","result"]: return
	if not model.undo(): return
	mode = "play"
	modal.hide()
	board.values = model.board.duplicate()
	board.frame = {}
	board.queue_redraw()
	feedback.text = "已经撤回一步。\n换个方向试试。"
	refresh_hud()

func set_modal(title: String, description: String, actions: Array) -> void:
	modal_heading.text = title
	modal_body.text = description
	for child in modal_buttons.get_children():
		modal_buttons.remove_child(child)
		child.queue_free()
	menu_buttons.clear()
	for item in actions:
		var b := button(item[0],item[1],52)
		modal_buttons.add_child(b)
		menu_buttons.append(b)
	menu_index = 0
	style_menu()
	modal.show()
	board.interactive = false

func pause_game() -> void:
	if mode != "play": return
	mode = "pause"
	set_modal("歇一会儿","棋盘和动画都留在这里。\nEsc / Enter 继续。",[["继续这一局",resume_game],["重新开始本局",func(): start_game(kind,seed_value)],["选择另一个小样",show_title]])

func resume_game() -> void:
	if mode != "pause": return
	mode = "play"
	modal.hide()
	refresh_hud()

func show_result() -> void:
	mode = "result"
	var won: bool = model.phase == "won"
	var title := ("合出 128 了！" if kind=="merge" else "花朵收齐了！") if won else ("棋盘满了" if kind=="merge" else "步数用完了")
	var description := ("最大数字 %d · 滑动 %d 次" % [model.board.max(),model.moves]) if kind=="merge" else ("消除了 %d / 60 朵 · 用了 %d 步" % [model.collected,18-model.moves_left])
	description += "\n这一局用时 %d 分 %02d 秒" % [int(elapsed)/60,int(elapsed)%60]
	description += "\n" + ("想试试另一种玩法吗？" if won else "这一局结束了，随时可以再试。")
	var actions: Array = [["再玩一局",func(): start_game(kind,-1)],["选择另一个小样",show_title]]
	if kind == "merge" and not won and model.can_undo(): actions.insert(0,["撤回一步，继续试",undo_merge])
	set_modal(title,description,actions)
	sound.play_event("finish" if won else "charge_cancel")

func toggle_sound() -> void:
	muted = not muted
	sound.set_muted(muted)
	sound_button.text = ("声音关" if muted else "声音开")+" · M"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(modal): pause_game()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_M: toggle_sound()
	elif mode != "play":
		if key == KEY_ESCAPE and mode == "pause": resume_game()
		elif key in [KEY_LEFT,KEY_UP,KEY_A,KEY_W,KEY_RIGHT,KEY_DOWN,KEY_D,KEY_S,KEY_TAB] and not menu_buttons.is_empty():
			menu_index = posmod(menu_index+(-1 if key in [KEY_LEFT,KEY_UP,KEY_A,KEY_W] else 1),menu_buttons.size())
			style_menu()
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE] and not menu_buttons.is_empty(): menu_buttons[menu_index].pressed.emit()
	elif key == KEY_ESCAPE:
		if selected >= 0:
			selected = -1
			board.selected = -1
			board.queue_redraw()
		else: pause_game()
	elif key == KEY_Z: undo_merge()
	elif not busy:
		var direction := Vector2i.ZERO
		if key in [KEY_LEFT,KEY_A]: direction = Vector2i.LEFT
		elif key in [KEY_RIGHT,KEY_D]: direction = Vector2i.RIGHT
		elif key in [KEY_UP,KEY_W]: direction = Vector2i.UP
		elif key in [KEY_DOWN,KEY_S]: direction = Vector2i.DOWN
		if direction != Vector2i.ZERO:
			if kind == "merge": merge_move(direction)
			else:
				cursor = clampi(cursor/6+direction.y,0,5)*6+clampi(cursor%6+direction.x,0,5)
				board.cursor = cursor
				board.queue_redraw()
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE] and kind == "match": choose_cell(cursor)
	get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#f5f1e3"))
	# Quiet garden framing keeps the board as the main visual focus.
	draw_circle(Vector2(50,size.y+120),230,Color("#dfe6cd"))
	draw_circle(Vector2(size.x-60,size.y+190),310,Color("#e8dec4"))
	for i in 12:
		var x := 25.0+i*113
		draw_line(Vector2(x,size.y),Vector2(x+16,size.y-24),Color("#9caf86"),2,true)
