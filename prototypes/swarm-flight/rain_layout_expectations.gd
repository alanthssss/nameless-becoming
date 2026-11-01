extends RefCounted
## Independent declared migration delta used only by verification scripts.
const M=preload("res://spring_journey_model.gd")
static func normalized(value): return JSON.parse_string(JSON.stringify(value,"",true,true))
static func upgraded(old: Dictionary) -> Dictionary:
	var expected=old.duplicate(true)
	expected.rain_layout_revision=1
	if int(old.stage)!=1: return expected
	for entry in [[expected.state,false],[expected.state.checkpoint,true]]:
		var state: Dictionary=entry[0]
		var old_index=int(state.checkpoint_index)
		state.walls[3].rect=M.pack(Rect2(3150,310,710,85))
		state.walls.insert(4,M.pack({"kind":"terrain","material":"stem","rect":Rect2(3150,80,65,231),"broken":false}))
		state.shelters.insert(2,M.pack({"pos":Vector2(2630,600),"reached":old_index>=2,"section":2,"name":"低叶下的一处歇脚","half_width":118.0}))
		state.shelters[3].pos=M.pack(Vector2(3010,520))
		state.shelters[3].half_width=M.pack(118.0)
		state.shelters[3].section=3
		state.shelters[4].section=4
		state.dew[1].section=3
		state.dew[1].encounter=3
		state.checkpoint_index=old_index if old_index<2 else old_index+1
		if entry[1] and old_index==2 and M.unpack(state.p)==Vector2(3670,520): state.p=M.pack(Vector2(3010,520))
	return expected
