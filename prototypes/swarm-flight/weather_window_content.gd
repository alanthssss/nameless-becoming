extends "res://event_data.gd"
const Builder = preload("res://chapter_data.gd")

static func build() -> Dictionary:
	var first := encounter("叶下与叶上",800,[],520,"沿着花桥飞行，看看叶棚内外的路")
	first["direct_route"] = [Vector2(390,520),Vector2(620,520)]
	var bridge := encounter("同一座花桥",2200,[terrain(20,330,980,95),terrain(1250,330,750,95),weather(0,2200),dew(1110,520,"短缺口后的共用补给")],520,"雨点落下来时，叶棚下面仍然有路")
	bridge["direct_route"] = [Vector2(950,520),Vector2(1110,520),Vector2(1300,520),Vector2(1950,520)]
	bridge["alternate_route"] = [Vector2(-60,220),Vector2(1110,220),Vector2(1110,520),Vector2(1300,520),Vector2(1950,520)]
	var after := encounter("窗边又有了光",700,[],420,"继续飞向花铃，也可以回头看看刚才的窗")
	after["direct_route"] = [Vector2(240,520),Vector2(400,420)]
	var source := {"title":"叶下的光","region":1,"theme":1,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch","entry":"小满：云过来了。刚才看见的叶棚，还在前面。","arrival":"雨停了，窗边又有了光。","npc":"bee","npc_line":"","neighbor_stops":[],"encounters":[first,bridge,after]}
	var result: Dictionary = Builder.build_source(source)
	for i in result.encounters.size():
		result.encounters[i]["act"] = i
		result.encounters[i]["act_name"] = "花桥"
	return result
