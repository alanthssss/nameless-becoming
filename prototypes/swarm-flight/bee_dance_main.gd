extends "res://main.gd"
const DanceModel = preload("res://bee_dance_model.gd")
const DanceWorld = preload("res://bee_dance_view.gd")
func _ready() -> void:
	super._ready()
	get_window().title = "雨来之前 · 把花路告诉你 0.15.2"
func use_long_journey() -> bool: return true
func create_journey_model(): return DanceModel.new()
func create_world(): return DanceWorld.new()
func journey_save_path() -> String: return DanceModel.DANCE_SAVE_PATH
func journey_titles() -> Array[String]: return ["把花路告诉你"]
func build_ui() -> void:
	super.build_ui()
	menu_kicker.text = "BEFORE THE RAIN     /     0.15.2"
func show_title() -> void:
	super.show_title()
	heading.text = "把花路告诉你"
	description.text = "蓝花簇开着，蜡脾边有两只等着出门的蜂。
方向键 / WASD 飞行，空格蓄力后松开冲刺。
停在花心尝一口，再到蜡脾上分享花路。
也可以直接向前，Esc 随时暂停保存。"
	main_button.text = "飞进花园"
	secondary_button.text = "再看一眼" if saved_payload.get("completed",false) else "回到保存的位置"
func resume_game() -> void:
	super.resume_game()
	resume_charge_guard = resume_charge_guard or model.share_state == "armed"
	refresh_hud()
func refresh_hud() -> void:
	super.refresh_hud()
	hud_bees.text = "花路"
	if resume_charge_guard and model.share_state == "armed":
		hud_hint.text = "分享仍暂停 · 按住空格接住，松开开始；方向键取消"
func _unhandled_input(event: InputEvent) -> void:
	# Share selection resumed without held keys must not fabricate a release.
	var effective_key: int = (event.physical_keycode if event.physical_keycode != 0 else event.keycode) if event is InputEventKey else 0
	if event is InputEventKey and event.pressed and not event.echo and mode == "play" and resume_charge_guard and model.share_state == "armed" and effective_key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]:
		model.cancel_dance()
		resume_charge_guard = false
	super._unhandled_input(event)
func show_transition() -> void:
	super.show_transition()
	handoff_heading.text = "花园里的路还在向前。"
	handoff_detail.text = "Enter 继续 · Esc 歇一会儿"
func show_ending() -> void:
	super.show_ending()
	heading.text = "它们也有了自己的去处。" if model.message_revision > 0 else "花还开着。"
	description.text = ("两只蜂已经听过那条花路。" if model.message_revision > 0 else "你飞过花园，蜡脾边仍有人等着下一条消息。")+"\n这趟旅程可以在这里歇一歇。"
	main_button.text = "再走一次"
