extends "res://bee_dance_main.gd"
const SpringModel=preload("res://spring_journey_model.gd")
const SpringView=preload("res://spring_journey_view.gd")
func _ready() -> void:
	super._ready()
	get_window().title="雨来之前 · 池岸归途 03—05 0.16.1"
func create_journey_model(): return SpringModel.new()
func create_world(): return SpringView.new()
func journey_save_path() -> String: return SpringModel.SPRING_SAVE_PATH
func journey_titles() -> Array[String]: return ["03 池边小径","04 雨中停走","05 归巢之路"]
func build_ui() -> void:
	super.build_ui()
	menu_kicker.text="BEFORE THE RAIN     /     0.16.1"
func show_title() -> void:
	super.show_title()
	heading.text="池岸归途"
	description.text="从池边蓝花出发，绕过雨廊，再回到熟悉的归路。
方向键 / WASD 飞行，空格蓄力后松开冲刺。
花心可以停一停，叶下可以歇一歇。
Esc 保存并暂停；R 回最近落脚点。"
	main_button.text="沿池岸出发"
func refresh_hud() -> void:
	super.refresh_hud()
	hud_bees.text="第%02d关" % (model.stage+3)
	hud_title.text="%s · %s   ·   晨露 %d/%d" % [titles[model.stage],model.encounter_name(),model.garden_awards[model.stage],model.stage_dew_total()]
	var cue: Dictionary=model.context_cue()
	if cue_panel.visible:
		# Keep the actual bee and its shield/readiness ring readable at every cue.
		# A perched dancer is drawn away from its fixed simulation position.
		var player_screen: Vector2=model.p+(model.dance_pose() if model.perched else Vector2.ZERO)-Vector2(model.camera_x,0)
		var player_bounds:=Rect2(player_screen-Vector2(62,52),Vector2(124,104))
		var reserved: Array[Rect2]=[player_bounds]
		for box in world.active_caption_rects():
			reserved.append(Rect2(box.position-Vector2(model.camera_x,0),box.size).grow(8))
		if reserved.any(func(rect): return cue_panel.get_rect().intersects(rect)):
			var alternatives: Array=[]
			if model.stage==0 and cue.get("kind","")=="friend":
				var friend_screen: Vector2=model.DEPARTURE_FRIEND-Vector2(model.camera_x,0)
				alternatives=[friend_screen.y+72.0,friend_screen.y-205.0,190.0]
			alternatives.append_array([player_bounds.position.y-cue_panel.size.y-12.0,player_bounds.end.y+12.0])
			for rect in reserved:
				alternatives.append_array([rect.position.y-cue_panel.size.y-8.0,rect.end.y+8.0])
			var placed:=false
			for y in alternatives:
				var candidate:=Rect2(Vector2(cue_panel.position.x,clampf(y,190,652)),cue_panel.size)
				if reserved.all(func(rect): return not candidate.intersects(rect)):
					cue_panel.position=candidate.position
					placed=true
					break
			# Brief local guidance can yield to an active action/damage result.
			cue_panel.visible=placed
	if is_instance_valid(sound):
		var rain_here: bool=model.stage==1 and model.weather_phase=="rain" and model.rain_fields.any(func(field): return model.p.x>=field.rect.position.x and model.p.x<=field.rect.end.x)
		var covered: bool=model.shelter_index_at(model.p)>=0 or model.rain_floor_at(model.p.x)<model.p.y
		sound.set_pond_context(rain_here,covered,model.share_state=="dancing",mode=="pause",mode in ["play","arrival","ending"])
func show_transition() -> void:
	super.show_transition()
	handoff_heading.text=["沿池岸绕到叶棚那一侧。","那簇蓝花，又出现在归路旁。","灯就在前面，这回可以歇一歇了。"][model.stage]
	handoff_detail.text="Enter 看结尾 · Esc 暂停" if model.phase=="ending" else "即将自动出发 · Enter 提前进入下一关 · Esc 暂停"
func show_ending() -> void:
	super.show_ending()
	heading.text="路留出来了，花也还开着。"
	var shared: bool=model.message_revision>0
	description.text="你替庄主留下了通路，他终于可以收拾那些花牌。
"+("你告诉了它们那簇蓝花的方向。" if shared else "蜡脾边仍有人等着下一条花路；你可以按自己的方式回家。")+"
03—05这段归途已走完。
旅程 "+clock_text(played_seconds)+" · 返回落脚点 "+str(model.recoveries)+" 次"
	main_button.text="再走一次"
func tick(delta: float) -> void:
	var observed_before: bool=model.observation_valid()
	var greeted_before: bool=model.bird_greeted
	# The last optional report remains a live information chain after arrival.
	# On an explicit pause it freezes with the rest of the exact snapshot.
	if model.stage==2 and model.phase=="ending" and mode in ["arrival","ending"]:
		var before: Dictionary=model.story_state()
		model.advance_listeners(minf(delta,0.1))
		model.advance_tidy(minf(delta,0.1))
		# End-state actors still act; consume their new events once in this branch.
		for event in model.events:
			world.emit_event(event.kind,event.pos,event)
			sound.play_event(event.kind,event.pos.distance_to(model.p))
		model.events.clear()
		if before!=model.story_state() and model.keeper.state=="settled" and model.listeners.all(func(bee): return bee.state in ["waiting","foraging"]): persist_progress()
	super.tick(delta)
	if model.observation_valid() and not observed_before: event_message("source_observed","",2.6)
	elif model.bird_greeted and not greeted_before: event_message("bird_greeting","",2.2)
func event_message(kind: String,text: String,seconds: float,tint := Color("ffe7a3")) -> void:
	if kind=="bird_greeting": text="画眉抬头回应了你，转身望向叶棚"
	if kind=="source_observed": text="尝到花蜜，记住了这簇蓝花的位置 · 回巢时可以告诉同伴"
	if kind=="hit":
		for event in model.events:
			if event.kind=="hit" and event.get("reason")=="mosquito": text="撞了一下 · 体力 −8；换层或冲刺甩开它"
	if kind=="blocked" and model.p.distance_to(SpringModel.KNOT)<120: text="绳已松 · 按住空格蓄力，松开冲过叶结" if model.keeper.state=="counting" else "牌绳还绷着 · 它停下盘点时再试"
	if kind=="blocked" and model.front_open and not model.passage_open and model.p.x>2700:
		text="这是厚木牌 · 从上方或下方绕过去" if model.p.x<SpringModel.FRONT_SIGN.end.x else "背面只有叶结能解开 · 对准中间冲刺"
	if kind=="gate": text="背面的通口开了 · 花牌让出归路" if model.passage_open else "第一道牌绳松开了 · 前面的风花能送你抬升"
	if kind=="recover_manual": text="回到落脚点"+(" · 已打开的通口保留" if model.passage_open else " · 可以重新观察它的动作")
	if kind in ["recover_rain","recover_exhaustion"]: text="体力耗尽，回到落脚点"+(" · 已打开的通口保留" if model.passage_open else " · 重新出发")
	super.event_message(kind,text,seconds,tint)

func on_secondary() -> void:
	super.on_secondary()
	if mode=="pause" and model.events.any(func(e): return e.kind=="recover_geometry"):
		heading.text="已回到安全的落脚点"
		description.text=titles[model.stage]+" · 叶棚的边缘已更新。\n已记住的旅程保留，从最近的落脚点继续。\n按 Enter 或 Esc 出发。"

func preserve_legacy_save() -> bool:
	var path:=save_path()
	if not FileAccess.file_exists(path): return true
	var raw:=FileAccess.get_file_as_bytes(path)
	var parser:=JSON.new()
	var original=parser.data if parser.parse(raw.get_string_from_utf8())==OK else null
	if original is Dictionary and original.get("route_geometry_revision")==SpringModel.ROUTE_GEOMETRY_REVISION and original.get("preparation_revision")==SpringModel.PREPARATION_REVISION and create_journey_model().restore_payload(original): return true
	var backup:=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
	if DirAccess.dir_exists_absolute(backup): return false
	if FileAccess.file_exists(backup): return FileAccess.get_file_as_bytes(backup)==raw
	return DirAccess.copy_absolute(path,backup)==OK and FileAccess.get_file_as_bytes(backup)==raw

func persist_progress() -> bool:
	if not test_mode and not preserve_legacy_save():
		has_saved=false
		if not save_warning:
			save_warning=true
			message("旧进度备份暂时失败 · 可以继续玩，请暂时不要退出。",5.0,Color("ffd3b6"),5)
		return false
	return super.persist_progress()
