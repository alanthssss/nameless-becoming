extends Node2D
const Model = preload("res://game_model.gd")
const ORIGIN := Vector2(54,179)
const CELL := 73.0
const ACTION_DURATION := 0.85
const INK := Color("e6ede0")
const MUTED := Color("9db4a6")
const GOLD := Color("f3c86b")
const GREEN := Color("66b69e")
const RED := Color("ef8776")
var font: SystemFont
var state: Dictionary
var previous: Dictionary
var history: Array = []
var scores: Array = []
var chapter := 0
var mode := "title"
var hover := Vector2i(-1,-1)
var keyboard_aim := false
var anim := 0.0
var clock := 0.0
var action_target := Vector2.ZERO
var buttons: Array[Button] = []
var perch_button: Button
var wait_button: Button
var undo_button: Button
var restart_button: Button
var next_button: Button
var home_button: Button
var note := ""
var capture_path := ""

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	perch_button = make_button("栖停  ·  空格", Rect2(54,730,155,44), func(): act({"kind":"perch"}))
	wait_button = make_button("等一拍  ·  W", Rect2(221,730,155,44), func(): act({"kind":"wait"}))
	undo_button = make_button("撤回  ·  Z", Rect2(388,730,145,44), undo)
	restart_button = make_button("重来  ·  R", Rect2(545,730,145,44), restart)
	next_button = make_button("开始这段冒险", Rect2(480,598,320,54), proceed)
	home_button = make_button("回到开场", Rect2(548,666,184,40), func(): mode = "title"; refresh())
	state = Model.start(0)
	previous = state.duplicate(true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="):
			chapter = clampi(int(arg.split("=")[1]),0,3)
			state = Model.start(chapter)
			previous = state.duplicate(true)
			mode = "play"
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
	refresh()
	if not capture_path.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("CAPTURE SAVED: " + capture_path)
		get_tree().quit()

func make_button(label: String, bounds: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.position = bounds.position
	button.size = bounds.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_disabled_color",Color("627c72"))
	for which in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1b3c36") if which == "normal" else Color("2d5749")
		if which == "disabled": style.bg_color = Color("152b27")
		style.set_corner_radius_all(10)
		style.set_border_width_all(1 if which != "focus" else 2)
		style.border_color = GOLD if which in ["hover","focus"] else Color("36534a")
		button.add_theme_stylebox_override(which,style)
	button.pressed.connect(callback)
	add_child(button)
	buttons.append(button)
	return button

func refresh() -> void:
	for b in [perch_button,wait_button,undo_button,restart_button]: b.visible = mode == "play"
	perch_button.disabled = anim > 0.0 or not Model.can_perch(state,state.player)
	wait_button.disabled = anim > 0.0
	undo_button.disabled = anim > 0.0 or history.is_empty()
	restart_button.disabled = anim > 0.0
	next_button.visible = mode != "play"
	home_button.visible = mode in ["paused","ending","lost"]
	match mode:
		"title": next_button.text = "开始这段冒险  →"
		"intro": next_button.text = "试试自己的办法  →"
		"result": next_button.text = "进入新花地  →" if chapter == 3 else "继续往前  →"
		"lost": next_button.text = "撤回最后一着  ·  Z"
		"paused": next_button.text = "继续这一着  ·  Esc"
		"ending": next_button.text = "再走一条不同的路"
	queue_redraw()

func proceed() -> void:
	if anim > 0.0: return
	match mode:
		"title", "ending":
			chapter = 0
			scores.clear()
			start_chapter()
		"intro": mode = "play"
		"result":
			scores.append({"turns":state.turn,"broken":state.broken,"hp":state.hp})
			if chapter == 3: mode = "ending"
			else:
				chapter += 1
				start_chapter()
		"lost": undo()
		"paused": mode = "play"
	refresh()

func start_chapter() -> void:
	state = Model.start(chapter)
	previous = state.duplicate(true)
	history.clear()
	reset_aim()
	note = ""
	mode = "intro"

func restart() -> void:
	if anim > 0.0: return
	state = Model.start(chapter)
	previous = state.duplicate(true)
	history.clear()
	reset_aim()
	note = ""
	mode = "play"
	refresh()

func undo() -> void:
	if anim > 0.0 or history.is_empty(): return
	state = history.pop_back()
	previous = state.duplicate(true)
	reset_aim()
	note = "回到刚才。试试另一种走法。"
	mode = "play"
	refresh()

func act(action: Dictionary) -> void:
	if mode != "play" or anim > 0.0: return
	var result: Dictionary = Model.advance(state,action)
	if result.turn == state.turn:
		note = "这里没有可栖停的叶片。" if action.kind == "perch" else "这条飞行路线被挡住了。"
		queue_redraw()
		return
	history.append(state.duplicate(true))
	previous = state.duplicate(true)
	action_target = Vector2(action.get("to",state.player))
	state = result
	reset_aim()
	anim = ACTION_DURATION
	note = ""
	refresh()

func reset_aim() -> void:
	hover = state.player if keyboard_aim else Vector2i(-1,-1)

func aim(direction: Vector2i) -> void:
	if mode != "play" or anim > 0.0: return
	if not keyboard_aim: hover = state.player
	keyboard_aim = true
	hover = Vector2i(clampi(hover.x+direction.x,0,Model.W-1),clampi(hover.y+direction.y,0,Model.H-1))
	note = ""
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	if anim > 0.0:
		anim = maxf(0.0,anim-delta)
		if anim == 0.0:
			if state.won: mode = "result"
			elif state.lost: mode = "lost"
			refresh()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		keyboard_aim = false
		hover = Vector2i(floori((event.position.x-ORIGIN.x)/CELL),floori((event.position.y-ORIGIN.y)/CELL))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		keyboard_aim = false
		hover = Vector2i(floori((event.position.x-ORIGIN.x)/CELL),floori((event.position.y-ORIGIN.y)/CELL))
		if mode == "play" and Model.inside(hover): act({"kind":"fly","to":hover})
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if anim == 0.0 and mode in ["play","paused"]:
					mode = "paused" if mode == "play" else "play"
					refresh()
			KEY_ENTER, KEY_KP_ENTER:
				if mode == "play":
					if keyboard_aim: act({"kind":"fly","to":hover})
				else: proceed()
			KEY_Z:
				if mode in ["play","lost","result"]: undo()
			KEY_R:
				if mode in ["play","lost"]: restart()
			KEY_SPACE:
				if mode == "play": act({"kind":"perch"})
			KEY_W:
				if mode == "play": act({"kind":"wait"})
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				if mode == "play":
					var direction := Vector2i.ZERO
					if event.keycode == KEY_LEFT: direction.x = -1
					if event.keycode == KEY_RIGHT: direction.x = 1
					if event.keycode == KEY_UP: direction.y = -1
					if event.keycode == KEY_DOWN: direction.y = 1
					aim(direction)

func pos(p: Vector2) -> Vector2:
	return ORIGIN + (p+Vector2(0.5,0.5))*CELL

func text(value: String, p: Vector2, size: int = 20, color: Color = INK) -> void:
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func wrapped(value: String, p: Vector2, width: float, size: int = 19, color: Color = INK, line_gap: float = 1.55) -> float:
	var line := ""
	var y := p.y
	for ch in value:
		if ch == "\n" or (not line.is_empty() and font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width):
			text(line,Vector2(p.x,y),size,color)
			line = "" if ch == "\n" else ch
			y += size*line_gap
		else: line += ch
	if not line.is_empty(): text(line,Vector2(p.x,y),size,color)
	return y+size*line_gap

func panel(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	draw_style_box(style,rect)

func ellipse(center: Vector2, radii: Vector2, color: Color, tilt: float = 0.0) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var a := TAU*i/32.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y).rotated(tilt))
	draw_colored_polygon(points,color)

func bee(center: Vector2, scale_value: float = 1.0, alpha: float = 1.0, landed: bool = false) -> void:
	var wing := Color(0.82,0.94,0.9,alpha*0.75)
	var bob := 0.0 if landed else sin(clock*9.0)*2.0*scale_value
	var c := center+Vector2(0,bob)
	ellipse(c+Vector2(-8,-9)*scale_value,Vector2(10,6)*scale_value,wing,-0.8)
	ellipse(c+Vector2(7,-10)*scale_value,Vector2(10,6)*scale_value,wing,0.7)
	ellipse(c,Vector2(15,10)*scale_value,Color(0.95,0.77,0.4,alpha),0.1)
	for x in [-6,1]: draw_line(c+Vector2(x,-8)*scale_value,c+Vector2(x-1,8)*scale_value,Color(0.19,0.23,0.18,alpha),4*scale_value,true)
	draw_circle(c+Vector2(12,-2)*scale_value,2.2*scale_value,Color(0.1,0.18,0.14,alpha))
	draw_line(c+Vector2(11,-8)*scale_value,c+Vector2(17,-15)*scale_value,Color(0.7,0.67,0.38,alpha),1.5*scale_value,true)

func _draw() -> void:
	if font == null: return
	draw_rect(Rect2(0,0,1280,800),Color("101f1d"))
	for i in range(28):
		var v := Vector2(fmod(i*173.0,1280),fmod(i*113.0+clock*2,800))
		draw_circle(v,1.3,Color(0.65,0.8,0.55,0.12))
	if mode == "title":
		draw_title()
		return
	draw_game()
	if mode != "play": draw_overlay()

func draw_title() -> void:
	text("可玩短章  /  玩法实验 01",Vector2(64,70),18,GREEN)
	text("花间一着",Vector2(112,230),76,INK)
	text("看清下一步，走出自己的路。",Vector2(118,289),28,GOLD)
	wrapped("你醒来时，已经是一只蜂。\n叶片会遮住你，风会推着你，动物各有自己的打算。\n这次，由你决定怎么从它们之间穿过去。",Vector2(119,360),620,22,MUTED,1.8)
	for i in range(5):
		var c := Vector2(845+i%2*136,240+i*54)
		ellipse(c,Vector2(63,23),Color("244b3c"),-0.5+i*0.2)
		draw_line(c-Vector2(43,0),c+Vector2(43,0),Color("497353"),2,true)
	bee(Vector2(942,330),3.5)
	text("4 段连续遭遇 · 自由思考 · 随时撤回",Vector2(426,557),18,MUTED)
	text("方向键选落点 · Enter 飞行    或鼠标点亮点    空格栖停 · W 等待 · Z 撤回",Vector2(250,744),17,MUTED)
	text("没有倒计时。还没有真人体验验证；试试看这套玩法是否成立。",Vector2(331,775),15,Color("6c897b"))

func draw_game() -> void:
	var level: Dictionary = Model.chapters()[chapter]
	text(level.subtitle,Vector2(54,49),17,GREEN)
	text(level.name,Vector2(54,95),34,INK)
	text("飞行 → 动物行动 → 风 → 下一拍",Vector2(55,132),17,MUTED)
	for i in range(4):
		var center := Vector2(1054+i*45,63)
		draw_circle(center,15,GOLD if i == chapter else Color("2a453a"))
		text(str(i+1),center+Vector2(-5,6),17,Color("173025") if i == chapter else MUTED)
	panel(Rect2(42,167,CELL*9+24,CELL*7+24),Color("142c26"),Color("2d493b"))
	var show: Dictionary = previous if anim > 0.0 else state
	var fraction := 1.0-anim/ACTION_DURATION if anim > 0.0 else 1.0
	var scenery: Dictionary = previous if anim > 0.0 and fraction < 0.66 else state
	for y in range(Model.H):
		for x in range(Model.W):
			var p := Vector2i(x,y)
			var c := pos(Vector2(p))
			var r := Rect2(c-Vector2(34,34),Vector2(68,68))
			var t: String = Model.tile(scenery,p)
			draw_rect(r,Color(0.19,0.32,0.25,0.16) if (x+y)%2 == 0 else Color(0.15,0.27,0.23,0.18))
			if t in ["o","E"]:
				ellipse(c,Vector2(28,17),Color("3c7251"),-0.35)
				draw_line(c+Vector2(-24,8),c+Vector2(23,-7),Color("7da36c"),1.5,true)
				for d in [-1,1]: draw_line(c+Vector2(0,0),c+Vector2(9,13*d),Color("608d5e"),1,true)
			if t == "E":
				for i in range(6): ellipse(c+Vector2(13,0).rotated(i*TAU/6),Vector2(11,6),Color("e7ead8"),i*TAU/6)
				draw_circle(c,6,GOLD)
			elif t in ["#","t"]:
				var color := Color("a2875a") if t == "t" else Color("47735b")
				for k in [-1,0,1]:
					var base := c+Vector2(k*13,27)
					draw_line(base,base+Vector2(4,-53),color,4,true)
					draw_line(base+Vector2(2,-23),base+Vector2(-10,-36),color,3,true)
					draw_line(base+Vector2(3,-32),base+Vector2(14,-45),color,3,true)
				if t == "t": draw_line(c+Vector2(-6,-5),c+Vector2(8,1),Color("f3d6a0"),3,true)
			if anim == 0.0 and mode == "play" and Model.legal_move(state,p):
				draw_circle(c+Vector2(0,25),2.5,Color(0.65,0.86,0.7,0.8))
	for enemy in show.enemies:
		for p in Model.footprint(enemy):
			var c := pos(Vector2(p))
			panel(Rect2(c-Vector2(32,32),Vector2(64,64)),Color(0.86,0.35,0.29,0.14),Color(0.9,0.43,0.35,0.5),8)
			text("!",c+Vector2(23,-17),15,RED)
	for i in range(show.enemies.size()):
		var enemy: Dictionary = show.enemies[i]
		var c := pos(Vector2(enemy.pos))
		if anim > 0.0 and enemy.kind == "cricket":
			var leap := smoothstep(0.4,0.7,fraction)
			c = c.lerp(pos(Vector2(state.enemies[i].pos)),leap)
			c.y -= sin(leap*PI)*35.0
		elif anim > 0.0 and enemy.kind == "bird" and enemy.phase == 0:
			var peck := sin(smoothstep(0.4,0.7,fraction)*PI)
			c = c.lerp(pos(Vector2(enemy.target)),peck)
		if enemy.kind == "cricket":
			ellipse(c,Vector2(19,10),Color("b09d6d"),-0.25)
			for d in [-1,1]:
				draw_polyline(PackedVector2Array([c+Vector2(-5,4),c+Vector2(-22,15*d),c+Vector2(-29,4*d)]),Color("c6b57d"),3,true)
				draw_line(c+Vector2(10,-3),c+Vector2(22,-22+d*5),Color("d2bd85"),1,true)
			draw_circle(c+Vector2(13,-4),3,Color("28372a"))
		else:
			ellipse(c,Vector2(26,20),Color("b9a080"),0.2)
			ellipse(c+Vector2(-10,4),Vector2(17,12),Color("795f4f"),-0.4)
			draw_colored_polygon(PackedVector2Array([c+Vector2(23,-5),c+Vector2(40,0),c+Vector2(23,4)]),GOLD)
			draw_line(c+Vector2(8,-12),c+Vector2(23,-10),Color("ede0be"),3,true)
			draw_circle(c+Vector2(17,-7),3,Color("282d24"))
	if mode == "play" and anim == 0.0 and Model.legal_move(state,hover):
		var target := pos(Vector2(hover))
		var preview: Dictionary = Model.advance(state,{"kind":"fly","to":hover})
		var final := pos(Vector2(preview.player))
		var color := RED if preview.hp < state.hp else GOLD
		draw_line(pos(Vector2(state.player)),target,color,2,true)
		draw_circle(target,27,color,false,2,true)
		if final != target:
			draw_line(target,final,color,3,true)
			draw_circle(final,22,color,false,2,true)
		bee(final,0.8,0.55)
	if anim == 0.0 and mode == "play" and keyboard_aim and Model.inside(hover):
		var aim_color := GOLD if Model.legal_move(state,hover) or hover == state.player else RED
		draw_rect(Rect2(pos(Vector2(hover))-Vector2(31,31),Vector2(62,62)),aim_color,false,3)
	var bee_pos := pos(Vector2(state.player))
	if anim > 0.0:
		if fraction < 0.4: bee_pos = pos(Vector2(previous.player)).lerp(pos(action_target),smoothstep(0.0,0.4,fraction))
		elif fraction < 0.7: bee_pos = pos(action_target)
		else: bee_pos = pos(action_target).lerp(pos(Vector2(state.player)),smoothstep(0.7,1.0,fraction))
		if fraction > 0.5 and state.hp < previous.hp:
			draw_circle(bee_pos,30,Color(0.95,0.3,0.22,(1.0-fraction)*0.5))
	draw_circle(bee_pos,24,Color(0.96,0.78,0.4,0.1))
	bee(bee_pos,1.05,1.0,state.landed)
	if state.landed: draw_arc(bee_pos,24,0.15,PI-0.15,20,GREEN,2,true)
	draw_sidebar(level)
	text("亮点：可飞到的位置   绿叶：可栖停   褐枝：可被撞开   白花：出口",Vector2(54,710),15,MUTED)

func wind_name(v: Vector2i) -> String:
	if v == Vector2i.ZERO: return "无风"
	return "向右 →  一格" if v.x > 0 else "向左 ←  一格"

func draw_sidebar(level: Dictionary) -> void:
	var active: Dictionary = previous if anim > 0.0 else state
	panel(Rect2(744,167,482,536),Color("182e28"),Color("31483b"))
	text("这一拍",Vector2(771,204),18,GREEN)
	text("第 %d 拍" % (active.turn+1),Vector2(771,245),30)
	for i in range(3):
		var c := Vector2(1138+i*23,237)
		draw_circle(c,6,GOLD if i < state.hp else Color("405047"))
	text("风  " + wind_name(Model.wind(active)),Vector2(771,285),21,GOLD)
	var y := 326.0
	for e in active.enemies:
		var label: String = "油葫芦 · 跳落红色十字" if e.kind == "cricket" else ["画眉 · 啄扫红色区域","画眉 · 抖翅，风向改变","画眉 · 停顿，下一拍盯住你"][e.phase]
		text(label,Vector2(771,y),18,RED if not Model.footprint(e).is_empty() else MUTED)
		y += 30
	if state.enemies.is_empty(): text("这片花叶很安静。",Vector2(771,y),18,MUTED)
	draw_line(Vector2(770,392),Vector2(1198,392),Color("3a5142"),1,true)
	wrapped(level.goal,Vector2(771,425),420,21)
	wrapped(level.hint,Vector2(771,471),420,18,MUTED)
	var preview_text: String = "方向键选落点，Enter 飞行。选点不走回合；也可鼠标点亮点。"
	var preview_color := GREEN
	if anim > 0.0: preview_text = "正在发生……"
	elif Model.legal_move(state,hover):
		var preview: Dictionary = Model.advance(state,{"kind":"fly","to":hover})
		preview_text = "飞到所指格：安全。" if preview.hp == state.hp else "飞到所指格：会受伤，请检查红区与风。"
		preview_color = GREEN if preview.hp == state.hp else RED
		if preview.broken > state.broken: preview_text += " 动物会打开新路。"
		if preview.won: preview_text = "飞到所指格：这着能抵达白花。"
	elif keyboard_aim and hover != state.player:
		preview_text = "这个位置飞不到。用方向键选亮点；选点不走回合。"
		preview_color = RED
	panel(Rect2(767,566,436,53),Color("203d32"))
	wrapped(preview_text,Vector2(781,589),408,16,preview_color,1.45)
	wrapped(note if not note.is_empty() else state.message,Vector2(771,649),420,16,MUTED,1.4)
	text("没有倒计时。你可以想清楚再走。",Vector2(771,751),18,MUTED)
	text("方向键选点 · Enter 飞行 / 鼠标点亮点 / Esc 暂停",Vector2(771,780),15,Color("718e7c"))

func draw_overlay() -> void:
	draw_rect(Rect2(0,0,1280,800),Color(0.035,0.09,0.075,0.91))
	var title := ""
	var body := ""
	var detail := ""
	match mode:
		"intro":
			title = Model.chapters()[chapter].name
			body = Model.chapters()[chapter].intro
			detail = Model.chapters()[chapter].hint + "\n方向键选落点，Enter 飞行；选点不走回合。"
		"result":
			title = "这一程，是你自己走出来的。"
			body = Model.chapters()[chapter].outro
			detail = "%d 拍抵达 · 打开 %d 处脆枝 · 余下 %d 点体力\n可以按 Z 回去，试试另一条路。" % [state.turn,state.broken,state.hp]
		"lost":
			title = "先在叶背歇一会儿。"
			body = "风和动物的动作碰到了一起。刚才的红色预告还在，回去就能换一种走法。"
			detail = "撤回没有次数限制，也没有失败惩罚。"
		"paused":
			title = "花间，停一拍。"
			body = "世界会等你。"
			detail = "飞行之后动物先行动，随后风才推动你。"
		"ending":
			title = "花开在你尚未见过的地方。"
			body = "你还不知道自己是哪一种蜂。\n但在这片花地上，你已经有了自己的走法。\n老师傅跟了上来。你们一起向花丛里飞去。"
			var total := 0
			for score in scores: total += score.turns
			detail = "短章结束 · 共走了 %d 拍\n这次最值得记住的，是哪一次由你改变的局面？" % total
	text("花间一着",Vector2(85,79),19,GREEN)
	bee(Vector2(640,197),2.2)
	var width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x
	text(title,Vector2((1280-width)/2,286),34)
	wrapped(body,Vector2(350,357),580,23,INK,1.75)
	wrapped(detail,Vector2(350,503),580,18,MUTED,1.6)
