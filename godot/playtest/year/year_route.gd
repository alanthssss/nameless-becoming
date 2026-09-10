extends "res://playtest/spring/spring_route.gd"
const YearModel := preload("res://playtest/year/year_model.gd")
const Cinema := preload("res://playtest/year/year_cinema.gd")
const YEAR_SAVE := "user://year_route_v1.json"
var import_path := "user://spring_route_v1.json"
var cinema := Cinema.new()
var cinema_canvas: Node2D
var year_calendar: Array = JSON.parse_string(FileAccess.get_file_as_string("res://playtest/year/year_calendar.json")).chapters
var import_spring := true

func _init() -> void:
 spring_save_path=YEAR_SAVE

func term_names() -> Array:
 return ["立春","雨水","惊蛰","春分","清明","谷雨","立夏","小满","芒种","夏至","小暑","大暑","立秋","处暑","白露","秋分","寒露","霜降","立冬","小雪","大雪","冬至","小寒","大寒"]

func chapter_count() -> int: return 24
func journey_title() -> String: return "四季"
func landscape_script() -> Script: return preload("res://playtest/year/year_landscape.gd")

func make_model(index: int):
 if index==1: return Model.new()
 var result=YearModel.new()
 result.configure(index,world)
 return result

func _ready() -> void:
 if spring_save_enabled and import_spring and not FileAccess.file_exists(spring_save_path) and FileAccess.file_exists(import_path):
  model=make_model(0)
  var data=JSON.parse_string(FileAccess.get_file_as_string(import_path))
  if data is Dictionary and int(data.get("term",-1)) in range(6) and restore_spring(data):
   _save_dawn()
  else:
   push_warning("春季存档未导入，原文件保留。全年从立春开始。")
 super._ready()
 var layer:=CanvasLayer.new()
 layer.layer=10
 add_child(layer)
 cinema_canvas=Node2D.new()
 cinema_canvas.set_script(preload("res://playtest/year/year_cinema_canvas.gd"))
 cinema_canvas.route=self
 layer.add_child(cinema_canvas)
 var skip_surface:=Control.new()
 skip_surface.size=Vector2(1280,720)
 skip_surface.mouse_filter=Control.MOUSE_FILTER_STOP
 skip_surface.gui_input.connect(func(event: InputEvent):
  if event is InputEventMouseButton and event.pressed: cinema.skip())
 cinema_canvas.add_child(skip_surface)
 _season_music()

func spring_snapshot() -> Dictionary:
 var data:=super.spring_snapshot()
 data["cinema_seen"]=cinema.seen.duplicate()
 return data

func restore_spring(data: Dictionary) -> bool:
 if not Cinema.valid_seen(data.get("cinema_seen",[])): return false
 if not super.restore_spring(data): return false
 cinema.seen=data.get("cinema_seen",[]).duplicate()
 cinema.last_id=str(cinema.seen.back()) if not cinema.seen.is_empty() else ""
 return true

func _season_music() -> void:
 music.stream=load("res://assets/music/%s_explore.wav" % ["spring","summer","autumn","winter"][int(term_index/6)])
 music.play()

func _next_term() -> void:
 if cinema.active: return
 super._next_term()
 _season_music()

func _next_day() -> void:
 if cinema.active: return
 super._next_day()

func _act() -> void:
 if cinema.active:
  cinema.skip()
  return
 var was_finished: bool=model.day_finished
 super._act()
 if not was_finished and model.day_finished and cinema.begin(term_index,model.day):
  pointer_active=false
  _save_dawn()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_C:
  if not paused: cinema.replay()
  return
 if cinema.active:
  if event.is_action_pressed("action"): cinema.skip()
  elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: _toggle_pause()
  return
 super._unhandled_input(event)

func _physics_process(delta: float) -> void:
 if term_index!=1: model.working=not paused and not cinema.active and (Input.is_action_pressed("action") or action_button.button_pressed)
 if is_instance_valid(cinema_canvas): cinema_canvas.visible=cinema.active
 if cinema.active:
  cinema.advance(delta,paused)
  for control in [status,action_button,brake_button,next_button,result_controls,hint_label]: control.visible=false
  cinema_canvas.queue_redraw()
  queue_redraw()
  return
 super._physics_process(delta)
 if is_instance_valid(cinema_canvas): cinema_canvas.queue_redraw()
 if term_index>=18: hint_label.text="WASD / 方向键 / 点地面 行走   Shift 慢行   R 重来   C 回看"

func _draw() -> void:
 if not cinema.active: super._draw()

func cargo_hud_label() -> String:
 if term_index!=1 and model.today().mode in YearModel.EXTRA_MODES:
  return {"water":"携带清水","share":"携带储蜜","seed":"携带种子","clean":"携带碎屑"}.get(model.today().mode,"手边工作")
 return super.cargo_hud_label()

func cargo_hud_value() -> String:
 if term_index!=1 and model.today().mode in ["fan","wax","warm","fruit"]:
  return "%d / %d" % [model.objects_done(),model.objects.size()]
 if term_index!=1 and model.today().mode in ["clean","seed"]: return "1 / 1" if model.carried>=0 else "0 / 1"
 return super.cargo_hud_value()

func companion_hud_title() -> String:
 return "暖好" if term_index!=1 and model.today().mode=="warm" else super.companion_hud_title()

func companion_hud_count() -> int:
 return model.objects_done() if term_index!=1 and model.today().mode=="warm" else super.companion_hud_count()
