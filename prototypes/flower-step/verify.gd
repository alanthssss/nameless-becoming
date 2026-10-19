extends SceneTree
## Automated rule/solvability evidence, not evidence that people enjoy the game.
const Model = preload("res://game_model.gd")
const SEARCH_LIMIT := 20000
const TURN_LIMIT := 24
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	test_invalid_actions()
	test_wind_and_perching()
	test_animal_cover()
	test_resolution_order()
	test_terminal_states()
	test_all_chapters()
	if failures.is_empty():
		print("FLOWER STEP VERIFIED: %d assertions; four chapters and both final routes." % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func fixture(chapter: int = 0) -> Dictionary:
	var s: Dictionary = Model.start(chapter)
	s.enemies = []
	return s

func enemy(kind: String, target: Vector2i, phase: int = 0) -> Dictionary:
	return {"kind":kind, "pos":Vector2i(7,0), "target":target, "phase":phase}

func test_invalid_actions() -> void:
	var s := fixture()
	var before := s.duplicate(true)
	for action in [
		{"kind":"fly", "to":Vector2i(-1,3)},
		{"kind":"fly", "to":Vector2i(8,3)},
		{"kind":"fly", "to":Vector2i(2,2)},
		{"kind":"fly", "to":s.player},
		{"kind":"not-an-action"},
	]:
		expect(Model.advance(s,action) == before, "Invalid action must leave the whole state unchanged: %s" % action)
	s.player = Vector2i(1,3)
	s.landed = false
	expect(Model.advance(s,{"kind":"perch"}) == s, "Cannot perch on empty air or spend a turn trying")
	s.player = Vector2i(1,1)
	s.board[1][2] = "#"
	expect(not Model.legal_move(s,Vector2i(3,1)), "Flight cannot cross a blocking plant")
	expect(not Model.legal_move(s,Vector2i(2,2)), "Flight cannot cut a blocking plant's corner")

func test_wind_and_perching() -> void:
	var s := fixture()
	s.player = Vector2i(2,3)
	s.landed = false
	expect(Model.wind(s) == Vector2i(1,0), "First chapter starts with east wind")
	var perched: Dictionary = Model.advance(s,{"kind":"perch"})
	expect(perched.player == s.player and perched.landed, "Perching before wind anchors the bee")
	var airborne: Dictionary = Model.advance(s,{"kind":"wait"})
	expect(airborne.player == Vector2i(3,3) and not airborne.landed, "Waiting in flight permits wind drift")
	var leaf_flight: Dictionary = Model.advance(s,{"kind":"fly", "to":Vector2i(1,3)})
	expect(leaf_flight.player == Vector2i(2,3) and not leaf_flight.landed, "Being over a leaf does not automatically perch")
	expect(Model.advance(perched,{"kind":"wait"}).player == perched.player, "Waiting while already perched keeps wind protection")

func test_animal_cover() -> void:
	var s := fixture(2) # No ambient wind: isolate cover from drift.
	s.player = Vector2i(2,3)
	s.landed = false
	s.enemies = [enemy("bird",s.player)]
	var covered: Dictionary = Model.advance(s,{"kind":"perch"})
	expect(covered.hp == 3 and covered.landed, "Leaf shade blocks a bird only after perching")
	expect(Model.advance(s,{"kind":"wait"}).hp == 2, "Airborne bee above the same leaf is exposed to the bird")
	s.enemies = [enemy("cricket",s.player)]
	var stomped: Dictionary = Model.advance(s,{"kind":"perch"})
	expect(stomped.hp == 2, "Leaf shade does not stop a cricket")
	expect(stomped.board[3][2] == "." and not stomped.landed, "Cricket crushes its target leaf and dislodges the bee")
	expect(Model.footprint(enemy("cricket",Vector2i(4,3))).size() == 5, "Cricket warning is a five-cell cross")
	expect(Model.footprint(enemy("bird",Vector2i(4,3))).size() == 9, "Bird peck warning is a nine-cell square")
	expect(Model.footprint(enemy("bird",Vector2i(4,3),1)).is_empty(), "Wingbeat is not another peck")
	expect(Model.footprint(enemy("bird",Vector2i(4,3),2)).is_empty(), "Bird pause has no attack area")

func test_resolution_order() -> void:
	var s := fixture()
	s.player = Vector2i(2,3)
	s.landed = false
	s.enemies = [enemy("bird",Vector2i(4,3))]
	var into_warning: Dictionary = Model.advance(s,{"kind":"wait"})
	expect(into_warning.player == Vector2i(3,3) and into_warning.hp == 3, "Wind may enter an already-resolved attack area without a retroactive hit")
	s.player = Vector2i(3,3)
	s.enemies = [enemy("bird",Vector2i(2,3))]
	var out_of_warning: Dictionary = Model.advance(s,{"kind":"wait"})
	expect(out_of_warning.player == Vector2i(4,3) and out_of_warning.hp == 2, "Drifting away after an attack does not avoid that attack")
	s.player = Vector2i(2,3)
	s.board[3][3] = "t"
	s.enemies = [enemy("cricket",Vector2i(4,3))]
	var opened: Dictionary = Model.advance(s,{"kind":"wait"})
	expect(opened.broken == 1 and opened.board[3][3] == ".", "Animal attack opens the fragile branch")
	expect(opened.player == Vector2i(3,3) and opened.hp == 3, "Wind can use the passage opened earlier in the same turn")
	var original := s.duplicate(true)
	var predicted: Dictionary = Model.advance(s,{"kind":"wait"})
	expect(s == original, "Preview transition must not mutate the current board or enemies")
	expect(predicted == Model.advance(s,{"kind":"wait"}), "Preview and committed action use a deterministic transition")

func test_terminal_states() -> void:
	var s := fixture(2)
	s.player = Vector2i(7,1)
	s.hp = 1
	s.enemies = [enemy("bird",s.goal)]
	var lost: Dictionary = Model.advance(s,{"kind":"fly", "to":s.goal})
	expect(lost.player == s.goal and lost.lost and not lost.won, "Lethal arrival at the flower is a loss, never a win")
	expect(Model.advance(lost,{"kind":"wait"}) == lost, "Loss freezes subsequent turns")
	s.enemies = []
	var won: Dictionary = Model.advance(s,{"kind":"fly", "to":s.goal})
	expect(won.won and not won.lost, "A surviving arrival wins")
	expect(Model.advance(won,{"kind":"wait"}) == won, "Win freezes subsequent turns")

func test_all_chapters() -> void:
	expect(Model.chapters().size() == 4, "The short chapter contains four encounters")
	for chapter in range(3):
		check_solution(chapter,"any")
	var detour := check_solution(3,"preserve")
	var shortcut := check_solution(3,"shortcut")
	if not detour.is_empty() and not shortcut.is_empty():
		expect(shortcut.size() < detour.size(), "The broken-branch route is shorter than the verified intact-branch detour")

func check_solution(chapter: int, route: String) -> Array:
	var found := search(chapter,route)
	expect(not found.is_empty(), "Chapter %d has a surviving solution (%s) within the explicit search bounds" % [chapter+1,route])
	if found.is_empty():
		return []
	var s: Dictionary = Model.start(chapter)
	var passed_bottom := false
	var crossed_open_branch := false
	var readable := PackedStringArray()
	for action in found:
		expect(action in Model.actions(s), "Search replay uses a currently legal action")
		var next: Dictionary = Model.advance(s,action)
		expect(next.turn == s.turn + 1 and not next.lost, "Every replay action advances one surviving turn")
		passed_bottom = passed_bottom or next.player.y == Model.H - 1
		# The shortcut stays above the only original gap; x=4 used to be all branches.
		crossed_open_branch = crossed_open_branch or (next.player.x >= 4 and next.player.y < Model.H - 1)
		readable.append("%s%s" % [action.kind, str(action.to) if action.has("to") else ""])
		s = next
	expect(s.won and not s.lost, "Replayed solution reaches the flower alive")
	if route == "preserve":
		expect(s.broken == 0 and passed_bottom, "Final detour keeps every fragile branch and uses the bottom gap")
	elif route == "shortcut":
		expect(s.broken > 0 and crossed_open_branch and not passed_bottom, "Final shortcut uses a broken passage without visiting the bottom detour")
	print("SOLUTION chapter=%d route=%s turns=%d hp=%d broken=%d: %s" % [chapter+1,route,s.turn,s.hp,s.broken," -> ".join(readable)])
	return found

func search(chapter: int, route: String) -> Array:
	# Bounded weighted best-first search: proof of these paths, not optimality or
	# exhaustive balance analysis. State key retains board, animal intent and wind phase.
	var initial: Dictionary = Model.start(chapter)
	var nodes: Array = [{"state":initial,"parent":-1,"action":{}}]
	var heap: Array = []
	var best: Dictionary = {Model.key(initial):0}
	push_heap(heap,{"index":0,"score":score(initial,route)})
	var expanded := 0
	while not heap.is_empty() and expanded < SEARCH_LIMIT:
		var index: int = pop_heap(heap).index
		var s: Dictionary = nodes[index].state
		if s.turn != best[Model.key(s)]:
			continue
		if s.won and (route != "shortcut" or s.broken > 0):
			var path: Array = []
			while nodes[index].parent != -1:
				path.push_front(nodes[index].action)
				index = nodes[index].parent
			print("SEARCH chapter=%d route=%s expanded=%d" % [chapter+1,route,expanded])
			return path
		if s.turn >= TURN_LIMIT:
			continue
		expanded += 1
		for action in Model.actions(s):
			var next: Dictionary = Model.advance(s,action)
			if next.lost or (route == "preserve" and next.broken != 0):
				continue
			if route == "shortcut" and next.player.y == Model.H - 1:
				continue
			var state_key: String = Model.key(next)
			if best.has(state_key) and best[state_key] <= next.turn:
				continue
			best[state_key] = next.turn
			nodes.append({"state":next,"parent":index,"action":action})
			push_heap(heap,{"index":nodes.size()-1,"score":score(next,route)})
	printerr("SEARCH exhausted chapter=%d route=%s expanded=%d limit=%d turns=%d" % [chapter+1,route,expanded,SEARCH_LIMIT,TURN_LIMIT])
	return []

func score(s: Dictionary, route: String) -> float:
	var d: Vector2i = s.goal - s.player
	var distance := absi(d.x)+absi(d.y)
	if route == "preserve" and s.player.x < 4:
		# Intact x=4 branches make the bottom gap mandatory. Guide the search
		# there instead of repeatedly exploring the inaccessible upper exit.
		var to_gap: Vector2i = Vector2i(4,Model.H-1) - s.player
		var from_gap: Vector2i = s.goal - Vector2i(4,Model.H-1)
		distance = absi(to_gap.x)+absi(to_gap.y)+absi(from_gap.x)+absi(from_gap.y)
	return float(s.turn) + float(distance)*0.75 + float(3-s.hp)*0.25

func push_heap(heap: Array, item: Dictionary) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent].score <= item.score:
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = item

func pop_heap(heap: Array) -> Dictionary:
	var first: Dictionary = heap[0]
	var last: Dictionary = heap.pop_back()
	if heap.is_empty():
		return first
	var i := 0
	while i * 2 + 1 < heap.size():
		var child := i * 2 + 1
		if child + 1 < heap.size() and heap[child+1].score < heap[child].score:
			child += 1
		if last.score <= heap[child].score:
			break
		heap[i] = heap[child]
		i = child
	heap[i] = last
	return first
