extends "res://main.gd"
const WeatherModel = preload("res://weather_window_model.gd")
const WeatherWorld = preload("res://weather_window_view.gd")

func _ready() -> void:
	super._ready()
	get_window().title = "雨来之前 · 叶下的光 0.15.1"

func use_long_journey() -> bool:
	return true

func create_journey_model():
	return WeatherModel.new()

func create_world():
	return WeatherWorld.new()

func journey_save_path() -> String:
	return WeatherModel.ENV_SAVE_PATH

func journey_titles() -> Array[String]:
	return ["叶下的光"]

func build_ui() -> void:
	super.build_ui()
	menu_kicker.text = "BEFORE THE RAIN     /     0.15.1"

func show_title() -> void:
	super.show_title()
	heading.text = "叶下的光"
	description.text = "先看看花桥的叶棚，再穿过一阵雨。\n方向键 / WASD 飞行，空格蓄力后松开冲刺。\nEsc 暂停并保存，退出后可以原地继续。\n窗边的光，记着你经过的地方。"
	main_button.text = "飞向花桥"
	secondary_button.text = "回看窗边" if saved_payload.get("completed",false) else "回到保存的位置"

func refresh_hud() -> void:
	super.refresh_hud()
	hud_bees.text = "花桥"

func show_transition() -> void:
	super.show_transition()
	handoff_heading.text = "雨停了。"
	handoff_detail.text = "窗边的光，和出发时不一样了。\nEnter 继续 · Esc 歇一会儿"

func show_ending() -> void:
	super.show_ending()
	heading.text = "光又落在窗边。"
	description.text = "雨留在叶棚上，花桥又亮了。\n花桥仍在身后，窗里多了一段暖光。\n旅程 "+clock_text(played_seconds)+" · 返回叶下 "+str(model.recoveries)+" 次"
	main_button.text = "再走一次花桥"
