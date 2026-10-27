extends "res://event_data.gd"
const Builder = preload("res://chapter_data.gd")
static func build() -> Dictionary:
	var small := encounter("荫边的花位",1440,[terrain(870,270,80,300,"stem")],500,"换一层飞，或用花篱隔开短短的追近")
	small["direct_route"] = [Vector2(620,600),Vector2(1000,620),Vector2(1260,500)]
	small["alternate_route"] = [Vector2(620,200),Vector2(1000,200),Vector2(1260,500)]
	var keeper := encounter("挤满通路的花牌",1650,[terrain(910,80,42,315,"stem"),terrain(910,535,42,225,"stem"),{"kind":"curtain","x":910.0,"y":465.0,"height":140.0}],500,"庄主停下盘点时，牌绳会松下来")
	keeper["direct_route"] = [Vector2(650,570),Vector2(760,465),Vector2(1040,465),Vector2(1470,500)]
	var source := {"title":"牌挤到路中间了","region":0,"theme":0,"music":0,"base_bees":1,"storm":false,"exit_kind":"arch","entry":"荫边有只蚊，正守着自己的花位。","arrival":"花牌挪开了，路也留出来了。","npc":"","neighbor_stops":[],"encounters":[small,keeper]}
	var result: Dictionary = Builder.build_source(source)
	for i in result.encounters.size():
		result.encounters[i]["act"] = i
		result.encounters[i]["act_name"] = ["荫边","牌架边"][i]
	return result
