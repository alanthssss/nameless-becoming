extends RefCounted
var active := false
var age := 0.0
var duration := 5.5
var term := 0
var day := 5
var seen: Array = []
var last_id := ""

func begin(chapter: int, completed_day: int, replay := false) -> bool:
 if completed_day % 5 != 0: return false
 var id := "%d:%d" % [chapter,completed_day]
 if not replay and seen.has(id): return false
 term=chapter
 day=completed_day
 duration=24.0 if chapter==5 and day==15 else (9.0 if chapter%6==5 and day==15 else 5.5)
 last_id=id
 if not seen.has(id): seen.append(id)
 age=0
 active=true
 return true

func advance(delta: float, paused: bool) -> void:
 if active and not paused:
  age=minf(duration,age+maxf(0,delta))
  if age>=duration: active=false

func skip() -> void:
 active=false

func replay() -> bool:
 if last_id.is_empty(): return false
 var parts:=last_id.split(":")
 return begin(int(parts[0]),int(parts[1]),true)

static func valid_seen(value) -> bool:
 if not value is Array or value.size()>72: return false
 var unique: Array=[]
 for id in value:
  if not id is String or unique.has(id): return false
  var p=id.split(":")
  if p.size()!=2 or not p[0].is_valid_int() or not p[1].is_valid_int(): return false
  if int(p[0])<0 or int(p[0])>=24 or int(p[1]) not in [5,10,15]: return false
  if id!="%d:%d" % [int(p[0]),int(p[1])]: return false
  unique.append(id)
 return true
