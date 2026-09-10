extends "res://tools/spring_driver.gd"
const Year := preload("res://playtest/year/year_model.gd")

static func work(model) -> void:
 var mode: String=model.today().mode
 if mode not in Year.EXTRA_MODES:
  preload("res://tools/spring_driver.gd").work(model)
  return
 if mode in ["water","share"]:
  var quota: int=model.today().get("quota",model.today().places.size())
  while model.servings<quota:
   fly(model,model.sources()[0])
   for i in range(mini(3,quota-model.servings)): assert(model.act()=="load")
   fly(model,model.HIVE+Vector2(70,-45))
   assert(model.act()=="deliver")
  return
 for i in range(model.objects.size()):
  if mode in ["fan","wax","warm"]:
   var p: Vector2=model.objects[i].target
   if mode=="fan": fly(model,p-Vector2.from_angle(model.vent_angle(i))*90)
   fly(model,p)
   model.working=true
   for frame in range(100): model.step(1.0/60,Vector2.ZERO,true)
   model.working=false
   assert(model.objects[i].done,"Hold work incomplete: %s %d heading %f" % [mode,i,model.heading])
  elif mode=="fruit":
   var p: Vector2=model.objects[i].point
   var direction: Vector2=(model.objects[i].target-p).normalized()
   fly(model,p+direction.orthogonal()*130)
   fly(model,p-direction*110+direction.orthogonal()*130)
   fly(model,p-direction*55)
   for frame in range(2400):
    var offset: Vector2=model.objects[i].target-model.position
    model.step(1.0/60,offset.normalized(),true)
    if model.objects[i].done: break
   assert(model.objects[i].done,"Fruit must reach the grass nest: term %d day %d item %d at %s goal %s player %s" % [model.term_index,model.day,i,model.objects[i].point,model.objects[i].target,model.position])
  else:
   for frame in range(3600):
    var offset: Vector2=model.objects[i].point-model.position
    model.step(1.0/60,offset.normalized()*minf(1,offset.length()/45),true)
    if offset.length()<35: break
   assert(model.act()=="load")
   fly(model,model.objects[i].target)
   assert(model.act()=="help")

static func home(model, close_day := true) -> void:
 for sweep in range(3):
  for b in model.companions:
   if b.waiting or not b.joined: fly(model,b.position)
  fly(model,model.HIVE)
  if model.companions.is_empty() or model.home_companions()==5: break
 assert(model.work_ready(),"Year work must be ready before closing")
 if close_day:
  model.act()
  if not model.day_finished: model.act()
  assert(model.day_finished)
