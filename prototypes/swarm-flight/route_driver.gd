extends RefCounted
## A known-answer developer route using ordinary eight-way/Space inputs only.
## It never changes model state, positions, health, time or authored geometry.
const Data = preload("res://chapter_data.gd")
var model
var collecting := false
var skip_shields := false
var wait_for_full := true
var stage := -1
var commands: Array = []
var cursor := 0
var ticks_in_command := 0
var burst_phase := 0
var burst_ticks := 0
var seen_recoveries := 0
var error := ""

func _init(source,collect_optional := false,without_shields := false) -> void:
	model = source
	collecting = collect_optional
	skip_shields = without_shields

func output(direction := Vector2.ZERO,held := false,done := false) -> Dictionary:
	return {"direction":direction,"held":held,"done":done,"error":error}

func next_input() -> Dictionary:
	if not error.is_empty(): return output()
	if model.phase == "ending": return output(Vector2.ZERO,false,true)
	if model.phase != "playing": return output()
	if model.stage != stage:
		stage = model.stage
		var data: Dictionary = model.chapter
		commands = data.optional_route if collecting else data.route
		if skip_shields:
			# Explicit ordinary-flight alternate paths stay clear of pickup radii.
			# Geometry, collision, weather and stamina are never changed.
			for leaf in data.shields:
				for j in commands.size():
					if commands[j].kind != "move" or commands[j].target != leaf.pos: continue
					if stage == 2:
						commands[j] = Data.move_to(leaf.pos+Vector2(-130,-110))
						commands[j+1] = Data.move_to(leaf.pos+Vector2(300,-110))
					else:
						commands[j] = Data.move_to(leaf.pos+Vector2(-180,-130))
						commands.insert(j+1,Data.move_to(leaf.pos+Vector2(180,-130)))
					break
		cursor = resume_cursor()
		ticks_in_command = 0
		burst_phase = 0
		seen_recoveries = model.recoveries
	if model.recoveries != seen_recoveries:
		seen_recoveries = model.recoveries
		cursor = resume_cursor()
		ticks_in_command = 0
		burst_phase = 0
		return output()
	for skip in 8:
		if cursor >= commands.size():
			return output()
		var command: Dictionary = commands[cursor]
		ticks_in_command += 1
		if ticks_in_command > 1800:
			error = "stage %d command %d (%s), pos %s" % [stage,cursor,command.kind,str(model.p)]
			return output()
		match command.kind:
			"move":
				var offset: Vector2 = command.target-model.p
				if offset.length() < 16:
					advance_command()
					continue
				return output(Vector2(signf(offset.x) if absf(offset.x)>8 else 0,signf(offset.y) if absf(offset.y)>8 else 0).normalized())
			"jet_window":
				var matching := -1
				for i in model.jets.size():
					if absf(model.jets[i].rect.position.x-command.jet_x) < 0.1: matching = i; break
				if matching < 0: error = "Missing authored jet at "+str(command.jet_x); return output()
				if model.jet_quiet_remaining(matching) < float(command.get("travel_seconds",1.2)): return output()
				advance_command()
				continue
			"burst":
				if burst_phase == 0:
					# Authored review input observes the real keeper state; it never
					# advances that state, opens a gate or changes the playable rules.
					if command.get("wait_for_keeper_counting",false) and (model.keeper.state!="counting" or model.keeper.elapsed>1.2): return output()
					burst_phase = 1
					burst_ticks = 0
					return output(command.direction)
				if burst_phase == 1:
					burst_ticks += 1
					if burst_ticks <= 27: return output(Vector2.ZERO,true)
					burst_phase = 2
					return output()
				if model.burst_left > 0 or not model.velocity.is_zero_approx(): return output()
				advance_command()
				continue
			"rest":
				if wait_for_full and (model.stamina < 99.9 or not model.velocity.is_zero_approx()): return output()
				if model.checkpoint_index < command.section:
					error = "Stage %d reached leaf %d with saved %d at %s, pods %s" % [model.stage,command.section,model.checkpoint_index,str(model.p),str(model.pods)]
					return output()
				advance_command()
				continue
	return output()

func advance_command() -> void:
	cursor += 1
	ticks_in_command = 0
	burst_phase = 0

func resume_cursor() -> int:
	if model.checkpoint_index >= model.sections.size()-1: return commands.size()-1
	var section: int = model.checkpoint_index+1
	return model.sections[section].optional_route_index if collecting else model.sections[section].route_index
