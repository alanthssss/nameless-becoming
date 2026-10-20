extends RefCounted

const SIZE := 4
const TARGET := 128
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]

var board: Array[int] = []
var phase := "playing"
var moves := 0
var score := 0
var rng := RandomNumberGenerator.new()
var _previous: Dictionary = {}


func reset(seed_value: int) -> void:
	rng.seed = seed_value
	board.clear()
	board.resize(SIZE * SIZE)
	board.fill(0)
	phase = "playing"
	moves = 0
	score = 0
	_previous.clear()
	_spawn()
	_spawn()


func move(direction: Vector2i) -> Dictionary:
	var result: Dictionary = simulate_move(direction)
	if phase != "playing" or not result.valid:
		result.valid = false
		result.after = board.duplicate()
		return result
	_previous = {
		"board": board.duplicate(), "phase": phase, "moves": moves,
		"score": score, "rng_state": rng.state,
	}
	board.assign(result.after)
	score += int(result.gained)
	moves += 1
	result.spawned = _spawn()
	result.after = board.duplicate()
	if board.max() >= TARGET:
		phase = "won"
	elif not can_move():
		phase = "lost"
	return result


func simulate_move(direction: Vector2i) -> Dictionary:
	var after: Array[int] = []
	after.resize(SIZE * SIZE)
	after.fill(0)
	var slides: Array[Dictionary] = []
	var merged: Array[int] = []
	var result := {
		"valid": false, "before": board.duplicate(), "after": board.duplicate(),
		"slides": slides, "spawned": -1, "merged": merged, "gained": 0,
	}
	if not DIRECTIONS.has(direction) or board.size() != SIZE * SIZE:
		return result
	var gained := 0
	for line in SIZE:
		var indices: Array[int] = []
		for offset in SIZE:
			if direction == Vector2i.LEFT:
				indices.append(line * SIZE + offset)
			elif direction == Vector2i.RIGHT:
				indices.append(line * SIZE + SIZE - 1 - offset)
			elif direction == Vector2i.UP:
				indices.append(offset * SIZE + line)
			else:
				indices.append((SIZE - 1 - offset) * SIZE + line)
		var occupied: Array[int] = []
		for index in indices:
			if board[index] != 0:
				occupied.append(index)
		var cursor := 0
		var destination := 0
		while cursor < occupied.size():
			var from: int = occupied[cursor]
			var to: int = indices[destination]
			var value: int = board[from]
			var combines := cursor + 1 < occupied.size() and board[occupied[cursor + 1]] == value
			after[to] = value * 2 if combines else value
			slides.append({"from": from, "to": to, "value": value, "merged": combines})
			if combines:
				slides.append({"from": occupied[cursor + 1], "to": to, "value": value, "merged": true})
				merged.append(to)
				gained += value * 2
				cursor += 2
			else:
				cursor += 1
			destination += 1
	result.after = after
	result.valid = after != board
	result.gained = gained
	return result


func can_move() -> bool:
	if board.size() != SIZE * SIZE:
		return false
	for direction in DIRECTIONS:
		if simulate_move(direction).valid:
			return true
	return false


func can_undo() -> bool:
	return not _previous.is_empty()


func undo() -> bool:
	if not can_undo():
		return false
	board.assign(_previous.board)
	phase = _previous.phase
	moves = _previous.moves
	score = _previous.score
	rng.state = _previous.rng_state
	_previous.clear()
	return true


func _spawn() -> int:
	var empty: Array[int] = []
	for index in board.size():
		if board[index] == 0:
			empty.append(index)
	if empty.is_empty():
		return -1
	var index: int = empty[rng.randi_range(0, empty.size() - 1)]
	board[index] = 2 if rng.randf() < 0.9 else 4
	return index
