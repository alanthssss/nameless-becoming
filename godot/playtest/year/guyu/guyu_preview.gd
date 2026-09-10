extends Node2D
const Cinema:=preload("res://playtest/year/year_cinema.gd")
var cinema:=Cinema.new()
var font: Font=preload("res://fonts/NotoSansCJKsc-ProjectSubset.otf")
var visual_time:=0.0
var paused:=false
var film_preview:=true
var film: Node2D
var music: AudioStreamPlayer
func _ready() -> void:
 DisplayServer.window_set_title("一会儿巢里见 · 谷雨过场 · 最后一张花牌")
 film=Node2D.new()
 film.set_script(preload("res://playtest/year/guyu/guyu_film.gd"))
 film.route=self
 add_child(film)
 music=AudioStreamPlayer.new()
 music.stream=preload("res://assets/music/spring_explore.wav")
 music.bus=&"Music"
 music.volume_db=-15
 add_child(music)
 music.play()
 cinema.begin(5,15)
func _process(delta: float) -> void:
 cinema.advance(delta,paused)
 visual_time=cinema.age
 music.stream_paused=paused
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE: paused=not paused
  elif event.keycode==KEY_C or event.is_action_pressed("action") and not cinema.active:
   paused=false;cinema.replay()
  elif event.is_action_pressed("action"):
   cinema.age=cinema.duration;cinema.skip()
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  if cinema.active: cinema.age=cinema.duration;cinema.skip()
  else: cinema.replay()
func _exit_tree() -> void:
 if is_instance_valid(film): film.route=null
