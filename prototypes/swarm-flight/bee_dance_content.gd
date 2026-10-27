extends "res://event_data.gd"
const Builder = preload("res://chapter_data.gd")
static func build() -> Dictionary:
	var beat := encounter("花簇与蜡脾",1600,[],500,"可以在花上停一停，再到蜡脾边看看")
	beat["direct_route"] = [Vector2(420,420),Vector2(1030,500),Vector2(1420,500)]
	var source := {"title":"把花路告诉你","region":0,"theme":0,"music":0,"base_bees":1,"storm":false,"exit_kind":"arch","entry":"花还开着。蜡脾边，有两只等着出门的蜂。","arrival":"花园里的路，又被谁记住了。","npc":"","neighbor_stops":[],"encounters":[beat]}
	var result: Dictionary = Builder.build_source(source)
	result.encounters[0]["act"] = 0
	result.encounters[0]["act_name"] = "花路"
	return result
