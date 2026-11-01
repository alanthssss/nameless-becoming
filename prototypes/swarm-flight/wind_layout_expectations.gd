extends RefCounted
## Independent declared delta; all unlisted save fields must remain identical.
const M=preload("res://spring_journey_model.gd")
static func upgraded(old: Dictionary) -> Dictionary:
	var expected=old.duplicate(true)
	expected.wind_layout_revision=1
	if int(old.stage)==2:
		for state in [expected.state,expected.state.checkpoint]:
			state.rings[0].pos=M.pack(Vector2(2760,280))
			state.rings[0].direction=M.pack(Vector2(120,-100).normalized())
	return expected
