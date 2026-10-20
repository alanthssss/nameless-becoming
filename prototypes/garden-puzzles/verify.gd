extends SceneTree

const MergeModel = preload("res://merge_model.gd")
const MatchModel = preload("res://match_model.gd")
const SAMPLE_SEEDS := 32
const MERGE_MOVE_CAP := 500
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
const SNAKE: Array[int] = [16, 15, 14, 13, 9, 10, 11, 12, 8, 7, 6, 5, 1, 2, 3, 4]
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_merge_rules()
	_test_match_rules()
	_test_complete_games()
	if not failures.is_empty():
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)
	else:
		print("GARDEN PUZZLES RULES VERIFIED: %d checks" % checks)
		quit(0)


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)


func _test_merge_rules() -> void:
	var model = MergeModel.new()
	model.reset(20261020)
	check(model.board.size() == 16 and model.board.count(0) == 14, "merge starts with exactly two tiles")
	check(model.phase == "playing" and model.moves == 0 and model.score == 0, "merge fresh counters")
	var original: Array[int] = model.board.duplicate()
	var original_rng: int = model.rng.state
	check(not model.move(Vector2i(1, 1)).valid and not model.move(Vector2i.ZERO).valid, "merge rejects non-cardinal vectors")
	check(model.board == original and model.rng.state == original_rng, "invalid directions do not mutate or consume randomness")
	check(not model.can_undo() and not model.undo(), "undo is unavailable before a valid move")
	model.board.assign([2, 2, 4, 4, 2, 2, 2, 2, 0, 4, 0, 4, 0, 0, 0, 2])
	var preview: Dictionary = model.simulate_move(Vector2i.LEFT)
	check(preview.after == [4, 8, 0, 0, 4, 4, 0, 0, 8, 0, 0, 0, 2, 0, 0, 0], "merge each original tile participates once")
	check(preview.gained == 28 and preview.merged == [0, 1, 4, 5, 8], "merge score and destination metadata")
	check(preview.slides.size() == 11 and preview.spawned == -1, "merge preview reports every source tile without spawn")
	check(model.moves == 0 and model.rng.state == original_rng, "preview has no side effects")
	var before_move: Array[int] = model.board.duplicate()
	var mass := _mass(before_move)
	var result: Dictionary = model.move(Vector2i.LEFT)
	check(result.valid and model.moves == 1 and model.score == 28, "valid merge counts one move and exact score")
	check(result.spawned >= 0 and (model.board[result.spawned] == 2 or model.board[result.spawned] == 4), "valid merge adds a 2 or 4")
	check(_mass(model.board) == mass + model.board[result.spawned], "merge conserves tile value except reported spawn")
	var after_move: Array[int] = model.board.duplicate()
	var after_rng: int = model.rng.state
	check(model.undo() and model.board == before_move and model.moves == 0 and model.score == 0, "undo restores board and counters")
	check(model.rng.state == original_rng and model.phase == "playing" and not model.can_undo(), "undo restores randomness and consumes one snapshot")
	model.move(Vector2i.LEFT)
	check(model.board == after_move and model.rng.state == after_rng, "replaying after undo reproduces the same tile")
	model.reset(7)
	model.board.assign([2, 4, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	original_rng = model.rng.state
	check(not model.move(Vector2i.LEFT).valid, "blocked slide is not a move")
	check(model.moves == 0 and model.board.count(0) == 12 and model.rng.state == original_rng, "blocked slide consumes no turn or randomness")
	check(model.simulate_move(Vector2i.RIGHT).after.slice(0, 4) == [2, 4, 8, 16], "full distinct row does not shift")
	model.board.assign([2, 0, 0, 0, 2, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0])
	check(model.simulate_move(Vector2i.UP).after == [4, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "vertical merge moves upward")
	check(model.simulate_move(Vector2i.DOWN).after == [0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 8, 0, 0, 0], "vertical merge moves downward")
	model.board.assign([64, 64, 2, 4, 8, 16, 32, 2, 4, 8, 16, 32, 2, 4, 8, 16])
	model.move(Vector2i.LEFT)
	check(model.phase == "won" and model.board.has(128), "target merge wins")
	check(not model.move(Vector2i.DOWN).valid, "won merge game stops accepting moves")
	check(model.undo() and model.phase == "playing" and not model.board.has(128), "undo can reopen a won merge game")
	model.board.assign([2, 4, 8, 16, 4, 8, 16, 2, 8, 16, 2, 4, 16, 2, 4, 8])
	check(not model.can_move(), "alternating full merge board has no legal move")
	# The sole empty square fills after this slide, leaving no adjacent equal pair.
	model.board.assign([0, 2, 4, 8, 4, 8, 16, 32, 8, 16, 32, 64, 16, 32, 64, 2])
	model.move(Vector2i.LEFT)
	check(model.phase == "lost" and not model.can_move(), "a valid move ending in a blocked full board loses")
	check(model.undo() and model.phase == "playing" and model.can_move(), "undo can reopen a lost merge game")


func _test_match_rules() -> void:
	var model = MatchModel.new()
	model.reset(20261020)
	check(model.board.size() == 36 and model.find_matches().is_empty(), "match starts stable")
	check(not model.legal_moves().is_empty(), "match starts with a legal exchange")
	check(model.moves_left == 18 and model.collected == 0 and model.phase == "playing", "match fresh counters")
	var original: Array[int] = model.board.duplicate()
	var original_rng: int = model.rng.state
	for pair in [Vector2i(-1, 0), Vector2i(0, 36), Vector2i(5, 6), Vector2i(0, 7), Vector2i(0, 0)]:
		check(not model.swap(pair.x, pair.y).valid, "match rejects out-of-range, wraparound, diagonal, or same-cell exchange %s" % pair)
	check(model.board == original and model.rng.state == original_rng and model.moves_left == 18, "invalid match exchange cannot consume resources")
	var invalid := _first_invalid_pair(model)
	var rejected: Dictionary = model.swap(invalid.x, invalid.y)
	check(invalid.x >= 0 and not rejected.valid, "adjacent non-match exchange is rejected")
	check(rejected.swapped[invalid.x] == original[invalid.y] and rejected.swapped[invalid.y] == original[invalid.x], "rejected exchange keeps attempted snapshot for continuous bounce-back animation")
	check(model.board == original and model.collected == 0 and model.moves_left == 18, "non-match board is restored exactly")
	model.board.assign(_dead_board())
	check(model.find_matches().is_empty() and model.legal_moves().is_empty(), "known dead board is stable but has no move")
	model.moves_left = 11
	model.collected = 23
	model.reshuffle()
	check(model.find_matches().is_empty() and not model.legal_moves().is_empty(), "free reshuffle creates stable playable board")
	check(model.moves_left == 11 and model.collected == 23, "free reshuffle preserves counters")
	model.board.assign(_dead_board())
	for index in [2, 8, 12, 13, 14]:
		model.board[index] = 4
	check(model.find_matches() == [2, 8, 12, 13, 14], "crossing matches count their intersection once")
	model.reset(31)
	var legal: Array[Vector2i] = model.legal_moves()
	original = model.board.duplicate()
	original_rng = model.rng.state
	check(model.legal_moves() == legal and model.board == original and model.rng.state == original_rng, "move search has no state or RNG side effects")
	var result: Dictionary = model.swap(legal[0].x, legal[0].y)
	check(result.valid and model.moves_left == 17, "one valid exchange charges exactly one step including cascades")
	check(result.before == original and result.swapped != original and result.after == model.board, "swap returns consistent animation snapshots")
	var cleared := 0
	for step in result.steps:
		cleared += step.cleared.size()
		check(step.board.size() == 36 and step.after.size() == 36 and step.cleared.size() >= 3, "every cascade includes stable-size snapshots and at least three tiles")
		var unique: Dictionary = {}
		for index in step.cleared:
			unique[index] = true
		check(unique.size() == step.cleared.size(), "cascade clear indices are deduplicated")
	check(model.collected == cleared and cleared >= 3, "collected counter equals exact total of cleared cells")
	check(model.find_matches().is_empty() and not model.board.has(-1), "cascade resolution ends full and stable")
	check(model.phase != "playing" or not model.legal_moves().is_empty(), "active game cannot remain deadlocked")
	model.reset(31)
	model.moves_left = 1
	model.collected = 59
	legal = model.legal_moves()
	model.swap(legal[0].x, legal[0].y)
	check(model.phase == "won" and model.moves_left == 0 and model.collected >= 60, "last-step target wins before move exhaustion")
	original = model.board.duplicate()
	check(not model.swap(0, 1).valid and model.board == original, "won match game refuses exchanges")
	model.reset(31)
	model.moves_left = 1
	legal = model.legal_moves()
	model.swap(legal[0].x, legal[0].y)
	check(model.phase == "lost" and model.moves_left == 0, "last step below target loses")
	model.reset(31)
	check(model.phase == "playing" and model.moves_left == 18 and model.collected == 0, "retry resets the whole match round")


func _test_complete_games() -> void:
	var report := {
		"evidence": "simulation; production Godot models, no player or enjoyment evidence",
		"seeds": "1..%d" % SAMPLE_SEEDS,
		"merge_target": MergeModel.TARGET, "match_target": MatchModel.TARGET,
		"match_move_limit": MatchModel.MOVE_LIMIT, "merge_move_cap": MERGE_MOVE_CAP,
		"merge_greedy": [], "merge_random": [], "match_greedy": [], "match_random": [],
	}
	var won_merge := false
	var won_match := false
	var automatic_shuffles := 0
	for seed_value in range(1, SAMPLE_SEEDS + 1):
		for greedy in [true, false]:
			var merge = MergeModel.new()
			merge.reset(seed_value)
			var policy_rng := RandomNumberGenerator.new()
			policy_rng.seed = 100000 + seed_value
			var trace: Array[int] = []
			while merge.phase == "playing" and merge.moves < MERGE_MOVE_CAP:
				var selected := _merge_choice(merge, greedy, policy_rng)
				if selected < 0:
					break
				var mass_before := _mass(merge.board)
				var result: Dictionary = merge.move(DIRECTIONS[selected])
				check(result.valid and _mass(merge.board) == mass_before + merge.board[result.spawned], "complete merge run conserves value seed %d" % seed_value)
				trace.append(selected)
			check(merge.phase != "playing", "merge sample completes within cap seed %d" % seed_value)
			report["merge_greedy" if greedy else "merge_random"].append({
				"seed": seed_value, "phase": merge.phase, "moves": merge.moves,
				"score": merge.score, "maximum": merge.board.max(),
			})
			if greedy and not won_merge and merge.phase == "won":
				won_merge = true
				report.merge_complete_win = {"seed": seed_value, "directions": trace, "legend": ["left", "up", "right", "down"]}
			var match_game = MatchModel.new()
			match_game.reset(seed_value)
			var swaps: Array[Vector2i] = []
			while match_game.phase == "playing":
				var pair := _match_choice(match_game, greedy, policy_rng)
				var previous_moves: int = match_game.moves_left
				var result: Dictionary = match_game.swap(pair.x, pair.y)
				check(result.valid and match_game.moves_left == previous_moves - 1, "complete match run charges one move seed %d" % seed_value)
				check(match_game.find_matches().is_empty(), "complete match run remains stable seed %d" % seed_value)
				automatic_shuffles += 1 if result.shuffled else 0
				swaps.append(pair)
			report["match_greedy" if greedy else "match_random"].append({
				"seed": seed_value, "phase": match_game.phase,
				"moves": MatchModel.MOVE_LIMIT - match_game.moves_left, "collected": match_game.collected,
			})
			if greedy and not won_match and match_game.phase == "won":
				won_match = true
				var packed_swaps: Array = []
				for pair in swaps:
					packed_swaps.append([pair.x, pair.y])
				report.match_complete_win = {"seed": seed_value, "swaps": packed_swaps}
	check(won_merge and won_match, "both games have a complete fixed-seed victory from reset")
	check(automatic_shuffles > 0, "fixed-seed complete rounds cover an automatic deadlock reshuffle")
	report.automatic_shuffles = automatic_shuffles
	for key in ["merge_greedy", "merge_random", "match_greedy", "match_random"]:
		var rows: Array = report[key]
		var wins := 0
		var moves: Array[int] = []
		for row in rows:
			wins += 1 if row.phase == "won" else 0
			moves.append(row.moves)
		moves.sort()
		print("SIMULATION %s: %d/%d wins; moves p10=%d median=%d p90=%d (all runs)" % [key, wins, rows.size(), moves[3], moves[15], moves[28]])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var path := argument.trim_prefix("--report=")
			var file := FileAccess.open(path, FileAccess.WRITE)
			check(file != null, "simulation report can be written")
			if file:
				file.store_string(JSON.stringify(report, "\t") + "\n")
	print("SIMULATION automatic free reshuffles: %d" % automatic_shuffles)


func _merge_choice(model, greedy: bool, policy_rng: RandomNumberGenerator) -> int:
	var legal: Array[int] = []
	var best := -1
	var best_score := -INF
	for index in DIRECTIONS.size():
		var result: Dictionary = model.simulate_move(DIRECTIONS[index])
		if not result.valid:
			continue
		legal.append(index)
		var quality := float(result.after.count(0)) * 200.0 + float(result.gained) * 2.0
		for cell in result.after.size():
			quality += float(result.after[cell] * SNAKE[cell])
		if quality > best_score:
			best_score = quality
			best = index
	return best if greedy or legal.is_empty() else legal[policy_rng.randi_range(0, legal.size() - 1)]


func _match_choice(model, greedy: bool, policy_rng: RandomNumberGenerator) -> Vector2i:
	var legal: Array[Vector2i] = model.legal_moves()
	if not greedy:
		return legal[policy_rng.randi_range(0, legal.size() - 1)]
	var best: Vector2i = legal[0]
	var best_count := -1
	for pair in legal:
		var first: int = model.board[pair.x]
		model.board[pair.x] = model.board[pair.y]
		model.board[pair.y] = first
		var count: int = model.find_matches().size()
		model.board[pair.y] = model.board[pair.x]
		model.board[pair.x] = first
		if count > best_count:
			best_count = count
			best = pair
	return best


func _first_invalid_pair(model) -> Vector2i:
	var legal: Array[Vector2i] = model.legal_moves()
	for row in MatchModel.SIZE:
		for column in MatchModel.SIZE - 1:
			var pair := Vector2i(row * MatchModel.SIZE + column, row * MatchModel.SIZE + column + 1)
			if not legal.has(pair):
				return pair
	return Vector2i(-1, -1)


func _dead_board() -> Array[int]:
	var values: Array[int] = []
	for row in MatchModel.SIZE:
		for column in MatchModel.SIZE:
			values.append((column + 2 * row) % MatchModel.TYPES)
	return values


func _mass(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
