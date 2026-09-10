extends SceneTree
const Film:=preload("res://playtest/year/guyu/guyu_film.gd")
const Cinema:=preload("res://playtest/year/year_cinema.gd")
const Preview:=preload("res://playtest/year/guyu/guyu_preview.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var c:=Cinema.new()
 assert(c.begin(5,15) and c.duration==24)
 assert(Film.shot_at(4.9)==0 and Film.shot_at(5)==1 and Film.shot_at(10)==2 and Film.shot_at(16)==3)
 assert(Film.card_phase(11.9)=="attached" and Film.card_phase(12)=="carried" and Film.card_phase(15)=="placed")
 assert(Film.card_position(12)==Vector2(764,337) and Film.card_position(15)==Vector2(405,470))
 var last:=Film.card_position(12)
 for frame in range(1,181):
  var next:=Film.card_position(12+frame/60.0)
  assert(last.distance_to(next)<9,"Card must move continuously rather than teleport")
  last=next
 c.advance(11,false)
 c.advance(5,true);assert(c.age==11)
 c.skip();assert(not c.active)
 assert(c.replay() and c.age==0 and c.seen.size()==1)
 var preview=Preview.instantiate()
 root.add_child(preview)
 preview.set_process(false)
 await process_frame
 assert(preview.cinema.active and preview.cinema.duration==24)
 var key:=InputEventKey.new();key.pressed=true;key.keycode=KEY_ESCAPE
 preview._unhandled_input(key);assert(preview.paused)
 key.keycode=KEY_C;preview._unhandled_input(key)
 assert(not preview.paused and preview.cinema.age==0)
 preview.queue_free()
 await process_frame
 print("YEAR GUYU FILM TEST PASSED: four shots, continuous card arc, pause, skip, replay, isolated preview")
 quit()
