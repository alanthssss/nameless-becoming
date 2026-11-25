extends RefCounted
## Wait for the actual entrance animation before exercising the menu behind it.
static func settle(game) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while game.mode == "station_entry" and Time.get_ticks_msec() < deadline:
		await game.get_tree().process_frame
