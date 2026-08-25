class_name AutumnMixAudition
extends SceneTree

const MainScene := preload("res://main.tscn")
const EphemeralSaveManagerScript := preload("res://tools/ephemeral_save_manager.gd")

const MODE_EXPLORE := "explore"
const MODE_BOSS := "boss"
const VALID_MODES: Array[String] = [MODE_EXPLORE, MODE_BOSS]
const BOSS_AUDITION_ENERGY := 99999.0

var requested_mode := ""
var game


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not VALID_MODES.has(String(arguments[0])):
		push_error("用法：scripts/run_autumn_mix_audition.sh <explore|boss>")
		quit(64)
		return
	requested_mode = String(arguments[0])
	call_deferred("_start_audition")


static func target_stage_index(stages: Array, mode: String) -> int:
	if mode == MODE_EXPLORE:
		for index in stages.size():
			var stage = stages[index]
			if stage is Dictionary and not stage.has("boss") and String(stage.get("flower_set", "")) == "autumn":
				return index
	elif mode == MODE_BOSS:
		for index in stages.size():
			var stage = stages[index]
			if stage is Dictionary and String(stage.get("boss", "")) == "thrush":
				return index
	return -1


static func mode_name(mode: String) -> String:
	return "秋野" if mode == MODE_EXPLORE else "秋 Boss"


static func banner_text(mode: String, provenance: String) -> String:
	return "内部音乐复查 · 不计玩法/流程通过 · %s · %s" % [mode_name(mode), provenance]


static func prepare_target_state(target_game, mode: String) -> void:
	if mode != MODE_BOSS:
		return
	# The real thrush can exhaust an unattended default bee in a few seconds.
	# Preserve damage cues but extend energy so two music loops can be heard
	# without turning the tool into a difficulty or progression test.
	target_game.bee.max_energy = BOSS_AUDITION_ENERGY
	target_game.bee.energy = BOSS_AUDITION_ENERGY


func _start_audition() -> void:
	game = MainScene.instantiate()
	# main._ready() reads settings as soon as the node enters the tree. Replace
	# the manager before add_child so even that read stays in memory.
	game.save_manager = EphemeralSaveManagerScript.new()
	game.persistence_enabled = false
	root.add_child(game)
	await process_frame

	game.tutorial_complete = true
	game.context_lessons_seen = {"sense": true, "danger": true, "low_energy": true}
	game.start_game()
	var stage_index := target_stage_index(game.stages, requested_mode)
	if stage_index < 0:
		push_error("当前数据中找不到音乐复查目标：%s" % requested_mode)
		quit(65)
		return
	game.spawn_stage(stage_index)
	prepare_target_state(game, requested_mode)
	_add_watermark()
	game.update_interface()
	print("AUTUMN MIX AUDITION READY: %s stage=%d track=%s" % [requested_mode, stage_index, game.music.current_track_path()])


func _add_watermark() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.name = "InternalMixAuditionWatermark"
	root.add_child(layer)

	var label := Label.new()
	label.name = "WatermarkLabel"
	label.text = banner_text(requested_mode, game.build_provenance_text())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 16.0
	label.offset_top = 10.0
	label.offset_right = -16.0
	label.offset_bottom = 44.0
	label.add_theme_color_override("font_color", Color("fff1bf"))
	label.add_theme_font_size_override("font_size", 15)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("b8241fe6")
	background.border_color = Color("ffd45c")
	background.set_border_width_all(2)
	background.set_corner_radius_all(8)
	label.add_theme_stylebox_override("normal", background)
	layer.add_child(label)
