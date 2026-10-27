extends "res://main.gd"
const KeeperModel = preload("res://sign_keeper_model.gd")
const KeeperWorld = preload("res://sign_keeper_view.gd")
func _ready() -> void:
	super._ready()
	get_window().title = "雨来之前 · 牌挤到路中间了 0.15.3"
func use_long_journey() -> bool: return true
func create_journey_model(): return KeeperModel.new()
func create_world(): return KeeperWorld.new()
func journey_save_path() -> String: return KeeperModel.KEEPER_SAVE_PATH
func journey_titles() -> Array[String]: return ["牌挤到路中间了"]
func build_ui() -> void:
	super.build_ui()
	menu_kicker.text = "BEFORE THE RAIN     /     0.15.3"
func show_title() -> void:
	super.show_title()
	heading.text = "牌挤到路中间了"
	description.text = "荫边的蚊守着花位，前面有人忙着数花牌。
方向键 / WASD 飞行，空格蓄力后松开冲刺。
看它什么时候停下来，绳结也会跟着松开。
Esc 随时暂停并保存；R 回最近落脚点。"
	main_button.text = "沿花篱出发"
	secondary_button.text = "再看一眼" if saved_payload.get("completed",false) else "回到保存的位置"
func refresh_hud() -> void:
	super.refresh_hud()
	hud_bees.text = "牌架边"
func event_message(kind: String,text: String,seconds: float,tint := Color("ffe7a3")) -> void:
	if kind=="hit":
		for event in model.events:
			if event.kind=="hit" and event.get("reason")=="mosquito": text="撞了一下 · 体力 −8；换层或冲刺甩开它"
	if kind=="blocked" and model.p.distance_to(KeeperModel.KNOT)<120: text="绳已松 · 按住空格蓄力，松开冲过叶结" if model.keeper.state=="counting" else "牌绳还绷着 · 它停下盘点时再试"
	if kind=="gate": text="干叶结松开了 · 花牌让出通路"
	if kind=="recover_manual": text="回到落脚点"+(" · 已打开的通口保留" if model.passage_open else " · 可以重新观察它的动作")
	if kind in ["recover_rain","recover_exhaustion"]: text="体力耗尽，回到落脚点"+(" · 已打开的通口保留" if model.passage_open else " · 重新出发")
	super.event_message(kind,text,seconds,tint)
func show_transition() -> void:
	super.show_transition()
	handoff_heading.text = "这回，路留出来了。"
	handoff_detail.text = "Enter 继续 · Esc 歇一会儿"
func show_ending() -> void:
	super.show_ending()
	heading.text = "“我可没挂错……哦，在这儿。”"
	description.text = "他把背上那块牌翻了过来。
花牌仍是他的，通路却宽了。"
	main_button.text = "再走一次"
