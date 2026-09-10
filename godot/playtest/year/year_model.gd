extends "res://playtest/spring/spring_model.gd"

const EXTRA_MODES := ["water", "fan", "wax", "clean", "warm", "seed", "fruit", "share"]
const ROOMS := {
 "门前": Vector2(560,900), "树桩": Vector2(940,540), "亮叶": Vector2(920,1480),
 "近花": Vector2(1100,970), "池岸": Vector2(1580,630), "叶台": Vector2(1810,1020),
 "池花": Vector2(2440,980), "远花": Vector2(3150,1050), "草地": Vector2(2150,1510),
 "甲虫家": Vector2(1520,1440), "北路": Vector2(2030,470), "北花": Vector2(2850,490)
}
var working := false
var heat := 0.0
var task_progress: Array[float] = []
var servings := 0

func calendar_path() -> String:
 return "res://playtest/year/year_calendar.json"

func chapter_count() -> int:
 return 24

func season_index() -> int:
 return int(term_index / 6)

func indoor() -> bool:
 return season_index() == 3

func place_point(name: String) -> Vector2:
 return ROOMS[name] if indoor() else super.place_point(name)

func start_day() -> void:
 super.start_day()
 working = false
 heat = 0
 servings = 0
 task_progress.clear()
 for item in objects:
  task_progress.append(0.0)
  if today().mode in ["clean", "seed"]:
   item.point = item.target
   item.origin = item.point
   item.target = (HIVE + Vector2(140,180)) if today().mode == "clean" else item.point + Vector2(260,110)
  if today().mode == "fruit":
   item.point = item.target + Vector2(-260,85)
   item.origin = item.point
 if today().mode == "warm":
  companions.clear()
  var target: Vector2 = place_point(today().places[0])
  for i in range(5):
   var p := target + Vector2.from_angle(i * TAU / 5) * (125 if today().get("variation") == "spread" else 80)
   companions.append({"position":p,"waiting":false,"joined":true,"exposure":0.0,"grace":0.0,"heading":0.0})
  objects.clear()
  task_progress.clear()
  for b in companions:
   objects.append({"point":b.position,"origin":b.position,"target":b.position,"done":false,"shape":0})
   task_progress.append(0.0)
 dawn_state = snapshot()

func rain_strength() -> float:
 if term_index<6: return super.rain_strength()
 if indoor(): return 0
 var weather: String = today().get("weather", "clear")
 return {"clear":0.0,"breeze":0.0,"hot":0.0,"gust":0.08,"rain":0.48,"mist":0.12}.get(weather,0.0)

func wind_force() -> float:
 if term_index<6: return super.wind_force()
 if indoor(): return 0
 var force: float = {"clear":8.0,"breeze":32.0,"hot":14.0,"gust":115.0,"rain":65.0,"mist":20.0}.get(today().get("weather","clear"),8.0)
 return sin(day_clock * 0.32 + day) * force

func sheltered(point: Vector2) -> bool:
 return true if indoor() else super.sheltered(point)

func raining(point: Vector2) -> bool:
 return false if today().mode in ["water","share","fruit"] else super.raining(point)

func maximum_speed() -> float:
 var speed := super.maximum_speed()
 if indoor(): speed *= 0.82
 if today().get("variation") == "wide" and carried >= 0: speed *= 0.78
 return speed * lerpf(1.0,0.78,heat)

func step(delta: float, steering: Vector2, braking: bool) -> void:
 if day_finished or complete or delta <= 0: return
 super.step(delta, steering, braking)
 if today().get("weather") == "hot":
  heat = move_toward(heat,0.0 if sheltered(position) else 1.0,delta * (0.4 if sheltered(position) else 0.045))
 var mode: String = today().mode
 for i in range(objects.size()):
  if objects[i].done: continue
  var item: Dictionary = objects[i]
  if mode == "seed" and carried != i and today().get("variation") == "drift":
   item.point = item.origin + Vector2(sin(day_clock * 0.65 + i) * 65, cos(day_clock * 0.5 + i) * 25)
  if mode == "fruit":
   var offset: Vector2 = item.point - position
   if offset.length() < 70 and velocity.dot(offset.normalized()) > 12:
    var groove: Vector2 = (item.target - item.point).normalized()
    var push_speed: float = maxf(0, velocity.dot(groove))
    item.point += groove * push_speed * delta
   if (item.point as Vector2).distance_to(item.target) < 65:
    finish_item(i, "果子稳稳滚进草窝")
  if mode in ["fan","wax","warm"]:
   var point: Vector2 = item.target
   var aligned := true
   if mode == "fan":
    aligned = Vector2.from_angle(heading).dot(Vector2.from_angle(vent_angle(i))) > 0.45
   if working and position.distance_to(point) < 72 and velocity.length() < 100 and aligned:
    task_progress[i] = minf(1.0, task_progress[i] + delta / (1.3 if mode == "fan" else 0.85))
    if task_progress[i] >= 1:
     finish_item(i, {"fan":"气流通了，水珠慢慢散开","wax":"缝隙合上，巢脾稳了","warm":"伙伴暖起来，靠在你身边"}[mode])

func vent_angle(index: int) -> float:
 return PI if today().get("variation") == "crosswind" and index % 2 == 1 else 0.0

func _companion_target(index: int) -> Vector2:
 if today().mode == "warm" and index < objects.size() and not objects[index].done:
  return objects[index].target
 return super._companion_target(index)

func finish_item(index: int, message: String) -> void:
 objects[index].done = true
 remember(today().mode, objects[index].target, int(objects[index].shape))
 respond(objects[index].target,message)

func work_ready() -> bool:
 var mode: String = today().mode
 if mode in ["water","share"]: return servings >= int(today().get("quota",today().places.size()))
 if mode == "warm": return objects_done() == objects.size() and home_companions() == 5
 if mode in EXTRA_MODES: return objects_done() == objects.size()
 return super.work_ready()

func objective_points() -> Array:
 if work_ready(): return [HIVE]
 var mode: String = today().mode
 if mode in ["water","share"]:
  return [HIVE + Vector2(70,-45)] if cargo > 0 else sources()
 if mode in ["fan","wax","warm"]:
  var points: Array = []
  for item in objects:
   if not item.done: points.append(item.target)
  return points if not points.is_empty() else [HIVE]
 if mode in ["clean","seed","fruit"]:
  if carried >= 0: return [objects[carried].target]
  var points: Array = []
  for item in objects:
   if not item.done: points.append(item.point)
  return points
 return super.objective_points()

func act() -> String:
 if day_finished or complete: return ""
 if work_ready():
  var result := super.act()
  if result == "day_end" and term_index % 6 == 5 and day >= 11:
   world["festival:%d" % season_index()] = {"kind":"festival","x":1800.0,"y":930.0,"shape":season_index() % 3,"phase":day-10}
  return result
 var mode: String = today().mode
 if mode not in EXTRA_MODES: return super.act()
 social.dance_age = -1
 if mode in ["water","share"]:
  if cargo > 0 and position.distance_to(HIVE + Vector2(70,-45)) < 70 and velocity.length() < 115:
   servings += cargo
   remember(mode,HIVE + Vector2(70,-45))
   cargo = 0
   respond(position,"水珠交给扇风伙伴" if mode == "water" else "伙伴接到蜜，慢慢靠拢")
   return "deliver"
  for p in sources():
   if position.distance_to(p) < 65 and cargo < 3:
    cargo += 1
    food_kind = "water" if mode == "water" else "honey"
    respond(p,"停在湿润的落脚处取水" if mode == "water" else "从蜜房取一口蜜")
    return "load"
 if mode in ["clean","seed"]:
  if carried >= 0:
   if position.distance_to(objects[carried].target) < 65 and velocity.length() < 115:
    finish_item(carried,"碎屑搬到了巢门外" if mode == "clean" else "种子落进了松软的土缝")
    carried = -1
    return "help"
  else:
   for i in range(objects.size()):
    if not objects[i].done and position.distance_to(objects[i].point) < 60:
     carried = i
     return "load"
 return ""

func hint() -> String:
 if work_ready(): return super.hint()
 var mode: String = today().mode
 var tally := "%d / %d" % [objects_done(),objects.size()]
 match mode:
  "water": return "在水边湿润的落脚处取水，再交给巢门的扇风伙伴。已送 %d / %d" % [servings,int(today().get("quota",today().places.size()))]
  "share": return "去金色蜜房取蜜，再到巢门边递给伙伴。已递 %d / %d" % [servings,int(today().get("quota",today().places.size()))]
  "fan": return "靠近水珠，面向箭头方向，按住空格扇风。" + tally
  "wax": return "靠近亮色裂缝，停稳后按住空格补好。" + tally
  "warm": return "靠近还在发抖的伙伴，按住空格暖一暖，再带大家回巢。" + tally
  "fruit": return "飞到果子后面，顺着草窝方向轻轻推过去。" + tally
  "clean": return "拾起碎屑，带到巢门外的浅色收拢处。" + tally
  "seed": return "接起小种子，跟随金叶指引放到土缝。" + tally
 var result := super.hint()
 if today().get("weather") == "hot": result += " 叶下歇一下会凉快些。"
 return result

func action_label() -> String:
 if work_ready(): return super.action_label()
 match today().mode:
  "water": return "空格 · 取水 / 交水"
  "share": return "空格 · 取蜜 / 递蜜"
  "fan": return "按住空格 · 顺着箭头扇风"
  "wax": return "按住空格 · 补巢脾"
  "warm": return "按住空格 · 暖暖伙伴"
  "fruit": return "靠近果子后方 · 轻推"
  "clean","seed": return "空格 · 放下" if carried >= 0 else "空格 · 拾起"
 return super.action_label()
