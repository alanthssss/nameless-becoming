extends "res://long_journey_model.gd"
## One authored weather relationship, not global seasonal simulation.
const WeatherContent = preload("res://weather_window_content.gd")
const ENV_SAVE_PATH := "user://weather_window_sample_v1.json"
const WARNING_SECONDS := 2.4
const WINDOW_ID := "flower-bridge-wax-window"
var weather_phase := "dry"
var warning_elapsed := 0.0
var color_step := 0
var checkpoint_environment: Dictionary = {}

func journey_id() -> String:
	return "weather-window-sample-v1"

func journey_stage_count() -> int:
	return 1

func build_stage(_index: int) -> Dictionary:
	return WeatherContent.build()

func record_sample_approach(_before: Vector2) -> void:
	pass

func load_stage(index: int) -> void:
	weather_phase = "dry"
	warning_elapsed = 0.0
	color_step = 0
	super.load_stage(index)

func environment_state() -> Dictionary:
	return {"scene_id":WINDOW_ID,"phase":weather_phase,"warning_elapsed":warning_elapsed,"color_step":color_step}

func apply_environment(state: Dictionary) -> void:
	weather_phase = state.phase
	warning_elapsed = float(state.warning_elapsed)
	color_step = int(state.color_step)

func advance(direction: Vector2, dt: float) -> void:
	# Authored landmarks commit progression. Waiting or backtracking alone does
	# not cycle the window, and no calendar dates are consulted.
	if started:
		if weather_phase == "dry" and p.x >= 650.0:
			weather_phase = "warning"
			emit("weather_warning",p)
		if weather_phase == "warning":
			warning_elapsed = minf(WARNING_SECONDS,warning_elapsed+dt)
			if warning_elapsed >= WARNING_SECONDS:
				weather_phase = "rain"
				emit("weather_rain",p)
		if p.x >= 1850.0: color_step = maxi(color_step,1)
		if p.x >= 3100.0 and weather_phase != "after":
			weather_phase = "after"
			color_step = 2
			drops.clear()
			emit("weather_after",p)
	super.advance(direction,dt)

func advance_rain(dt: float) -> void:
	if weather_phase == "rain": super.advance_rain(dt)

func rain_floor_at(x: float) -> float:
	var floor_y := 750.0
	for obstacle in walls:
		var rect: Rect2 = obstacle.rect
		if obstacle.kind == "terrain" and x >= rect.position.x and x <= rect.end.x:
			floor_y = minf(floor_y,rect.position.y)
	for leaf in shelters:
		if absf(x-leaf.pos.x) < float(leaf.half_width)+7.0:
			floor_y = minf(floor_y,leaf.pos.y-95.0)
	return floor_y

func save_checkpoint(position := Vector2(180,420)) -> void:
	super.save_checkpoint(position)
	checkpoint_environment = environment_state()

func restore_checkpoint(reason := "manual") -> void:
	super.restore_checkpoint(reason)
	apply_environment(checkpoint_environment)
	# A fresh attempt restarts the forecast; a live suspend does not.
	if weather_phase == "rain" or weather_phase == "warning":
		weather_phase = "warning"
		warning_elapsed = 0.0

func save_payload() -> Dictionary:
	var payload := super.save_payload()
	payload["environment"] = pack(environment_state())
	payload["checkpoint_environment"] = pack(checkpoint_environment)
	return payload

static func valid_environment(value) -> bool:
	if not value is Dictionary or value.size() != 4: return false
	if value.get("scene_id") != WINDOW_ID or value.get("phase") not in ["dry","warning","rain","after"]: return false
	if not number(value.get("warning_elapsed")) or value.warning_elapsed < 0 or value.warning_elapsed > WARNING_SECONDS: return false
	if not number(value.get("color_step")) or value.color_step != floor(value.color_step) or value.color_step < 0 or value.color_step > 2: return false
	if value.phase == "dry" and (value.warning_elapsed != 0 or value.color_step != 0): return false
	if value.phase == "rain" and value.warning_elapsed != WARNING_SECONDS: return false
	if value.phase == "after" and value.color_step != 2: return false
	return true

func restore_payload(payload: Dictionary) -> bool:
	var state = unpack(payload.get("environment"))
	var checkpoint_state = unpack(payload.get("checkpoint_environment"))
	if not valid_environment(state) or not valid_environment(checkpoint_state): return false
	if not super.restore_payload(payload): return false
	apply_environment(state)
	checkpoint_environment = typed_copy(checkpoint_state,environment_state())
	return true

func objective() -> String:
	if weather_phase == "after": return "雨停了，窗边的光也移了位置"
	if weather_phase == "warning": return "雨要来了，前面的叶棚下留着通路"
	if weather_phase == "rain": return "沿叶棚下穿行，或从露天借冲刺过去"
	return "先看见叶棚内外，再选自己的路"
