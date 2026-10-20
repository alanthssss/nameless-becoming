extends RefCounted

const SIZE := 6
const TARGET := 60
const MOVE_LIMIT := 18
const TYPES := 5
const MAX_CASCADES := 64

var board: Array[int] = []
var phase := "playing"
var moves_left := MOVE_LIMIT
var collected := 0
var rng := RandomNumberGenerator.new()


func reset(seed_value: int) -> void:
	rng.seed = seed_value
	phase = "playing"
	moves_left = MOVE_LIMIT
	collected = 0
	_generate_playable()


func swap(a: int, b: int) -> Dictionary:
	var result := {
		"valid": false, "before": board.duplicate(), "swapped": board.duplicate(),
		"steps": [], "after": board.duplicate(), "shuffled": false,
	}
	if phase != "playing" or not _adjacent(a, b):
		return result
	_exchange(a, b)
	result.swapped = board.duplicate()
	var matched: Array[int] = find_matches()
	if matched.is_empty():
		_exchange(a, b)
		return result
	result.valid = true
	moves_left -= 1
	var steps: Array[Dictionary] = []
	var cascades := 0
	while not matched.is_empty():
		var old_board: Array[int] = board.duplicate()
		collected += matched.size()
		for index in matched:
			board[index] = -1
		_fall_and_refill()
		steps.append({"board": old_board, "cleared": matched.duplicate(), "after": board.duplicate()})
		cascades += 1
		matched = find_matches()
		if cascades >= MAX_CASCADES and not matched.is_empty():
			# Bound pathological refill chains without charging another move.
			_generate_playable()
			result.shuffled = true
			break
	result.steps = steps
	if collected >= TARGET:
		phase = "won"
	elif moves_left <= 0:
		phase = "lost"
	elif legal_moves().is_empty():
		reshuffle()
		result.shuffled = true
	result.after = board.duplicate()
	return result


func find_matches() -> Array[int]:
	var marked: Dictionary = {}
	if board.size() != SIZE * SIZE:
		return []
	for row in SIZE:
		var start := 0
		while start < SIZE:
			var finish := start + 1
			var value: int = board[row * SIZE + start]
			while finish < SIZE and board[row * SIZE + finish] == value:
				finish += 1
			if value >= 0 and finish - start >= 3:
				for column in range(start, finish):
					marked[row * SIZE + column] = true
			start = finish
	for column in SIZE:
		var start := 0
		while start < SIZE:
			var finish := start + 1
			var value: int = board[start * SIZE + column]
			while finish < SIZE and board[finish * SIZE + column] == value:
				finish += 1
			if value >= 0 and finish - start >= 3:
				for row in range(start, finish):
					marked[row * SIZE + column] = true
			start = finish
	var found: Array[int] = []
	for index in marked:
		found.append(index)
	found.sort()
	return found


func legal_moves() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if board.size() != SIZE * SIZE:
		return result
	for row in SIZE:
		for column in SIZE:
			var a := row * SIZE + column
			if column + 1 < SIZE and _makes_match(a, a + 1):
				result.append(Vector2i(a, a + 1))
			if row + 1 < SIZE and _makes_match(a, a + SIZE):
				result.append(Vector2i(a, a + SIZE))
	return result


func reshuffle() -> void:
	# Usually preserve the current tile inventory; bounded generation is the fallback.
	for attempt in 128:
		for index in range(board.size() - 1, 0, -1):
			_exchange(index, rng.randi_range(0, index))
		if find_matches().is_empty() and not legal_moves().is_empty():
			return
	_generate_playable()


func _generate_playable() -> void:
	for attempt in 32:
		board.clear()
		for row in SIZE:
			for column in SIZE:
				var choices: Array[int] = []
				for value in TYPES:
					if column >= 2 and board[row * SIZE + column - 1] == value and board[row * SIZE + column - 2] == value:
						continue
					if row >= 2 and board[(row - 1) * SIZE + column] == value and board[(row - 2) * SIZE + column] == value:
						continue
					choices.append(value)
				board.append(choices[rng.randi_range(0, choices.size() - 1)])
		if not legal_moves().is_empty():
			return
	# No triples; swapping positions 1 and 7 always clears the first three cells.
	board.clear()
	for row in SIZE:
		for column in SIZE:
			board.append((column + 2 * row) % TYPES)
	board[0] = 0
	board[1] = 1
	board[2] = 0
	board[7] = 0


func _fall_and_refill() -> void:
	for column in SIZE:
		var destination := SIZE - 1
		for row in range(SIZE - 1, -1, -1):
			var value: int = board[row * SIZE + column]
			if value >= 0:
				board[destination * SIZE + column] = value
				destination -= 1
		while destination >= 0:
			board[destination * SIZE + column] = rng.randi_range(0, TYPES - 1)
			destination -= 1


func _makes_match(a: int, b: int) -> bool:
	if board[a] == board[b]:
		return false
	_exchange(a, b)
	var valid := _cell_matches(a) or _cell_matches(b)
	_exchange(a, b)
	return valid


func _cell_matches(index: int) -> bool:
	var row := index / SIZE
	var column := index % SIZE
	var value: int = board[index]
	if value < 0:
		return false
	for axis in [Vector2i.RIGHT, Vector2i.DOWN]:
		var count := 1
		for sign_value in [-1, 1]:
			var x: int = column + axis.x * sign_value
			var y: int = row + axis.y * sign_value
			while x >= 0 and x < SIZE and y >= 0 and y < SIZE and board[y * SIZE + x] == value:
				count += 1
				x += axis.x * sign_value
				y += axis.y * sign_value
		if count >= 3:
			return true
	return false


func _adjacent(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= SIZE * SIZE or b >= SIZE * SIZE:
		return false
	return absi(a / SIZE - b / SIZE) + absi(a % SIZE - b % SIZE) == 1


func _exchange(a: int, b: int) -> void:
	var value: int = board[a]
	board[a] = board[b]
	board[b] = value
