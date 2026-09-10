extends RefCounted

# G-FICTION: readable six-bee flight choreography, not a natural flight formation.
const OFFSETS := [Vector2(62, -42), Vector2(76, 42), Vector2(126, -53), Vector2(141, 51), Vector2(183, -8)]
const DURATION := 6.4
var trail: Array[Vector2] = []
var source := Vector2.ZERO
var dance_age := -1.0
var dance_kind := ""
var entry := Vector2.ZERO
var reported_sources: Array[Vector2] = []

func reset() -> void:
	trail.clear()
	reported_sources.clear()
	source = Vector2.ZERO
	dance_age = -1

func remember_forage(point: Vector2) -> void:
	source = point

func can_dance(model) -> bool:
	return source != Vector2.ZERO and model.position.distance_to(model.HIVE) < 150 and not model.day_finished

func offer_report(model) -> bool:
	return false if source in reported_sources else begin_dance(model)

func begin_dance(model) -> bool:
	if not can_dance(model):
		return false
	dance_kind = "round" if source.distance_to(model.HIVE) < 1200 else "waggle"
	dance_age = 0
	if source not in reported_sources:
		reported_sources.append(source)
	entry = model.position
	return true

func anchor(model) -> Vector2:
	return model.HIVE + Vector2(0, -22)

func listener(model, index: int) -> Vector2:
	return anchor(model) + Vector2.from_angle(-PI / 2 + index * TAU / 5) * 78

func dance_point(model, time: float) -> Vector2:
	var local: Vector2
	if dance_kind == "round":
		var phase := fposmod(time, 3.0)
		var angle := phase * TAU / 1.5 if phase < 1.5 else (3.0 - phase) * TAU / 1.5
		local = Vector2(cos(angle), sin(angle)) * 24
	else:
		var phase := fposmod(time, 2.8) / 2.8
		if phase < 0.25 or (phase >= 0.5 and phase < 0.75):
			var run := fposmod(phase, 0.5) * 4
			local = Vector2(lerpf(-25, 25, run), sin(run * TAU * 5) * 3)
		else:
			var turn := (fposmod(phase, 0.5) - 0.25) * 4 * PI
			local = Vector2(cos(turn) * 25, sin(turn) * (28 if phase < 0.5 else -28))
		# Map direction is an accessible game translation, not solar/gravity calibration.
		local = local.rotated((source - model.HIVE).angle())
	return anchor(model) + local

func step_dance(model, delta: float, steering: Vector2) -> bool:
	if dance_age < 0:
		return false
	if steering.length() > 0.08 or model.day_finished:
		dance_age = -1
		return false
	dance_age += delta
	if dance_age >= DURATION:
		dance_age = -1
		return false
	var point := dance_point(model, maxf(0, dance_age - 0.6))
	if dance_age < 0.6:
		point = entry.lerp(point, smoothstep(0, 0.6, dance_age))
	var movement: Vector2 = point - model.position
	if movement.length() > 0.01:
		model.heading = lerp_angle(model.heading, movement.angle(), 1 - exp(-18 * delta))
	model.position = point
	model.velocity = Vector2.ZERO
	return true

func record_path(position: Vector2) -> void:
	if trail.is_empty() or position.distance_to(trail[0]) > 280:
		trail.assign([position])
	elif position.distance_to(trail[0]) > 7:
		trail.push_front(position)
	while trail.size() > 70:
		trail.pop_back()

func target(model, index: int) -> Vector2:
	if dance_age >= 0:
		return listener(model, index)
	if model.position.distance_to(model.HIVE) < 85 and model.velocity.length() < 130:
		return model.HIVE + Vector2.from_angle(-PI / 2 + index * TAU / 5) * 84
	var offset: Vector2 = OFFSETS[index % OFFSETS.size()]
	var remaining := offset.x
	var p: Vector2 = model.position
	var direction := Vector2.from_angle(model.heading)
	var followed_trail: Array = [] if model.velocity.length() < 15 else trail
	for next: Vector2 in followed_trail:
		var distance := p.distance_to(next)
		if distance > 0.1:
			direction = (p - next).normalized()
			if distance >= remaining:
				p = p.move_toward(next, remaining)
				remaining = 0
				break
			remaining -= distance
		p = next
	p -= direction * remaining
	var side := direction.orthogonal() * offset.y
	# Keep the offset inside real shelter when the centreline is protected.
	if model.sheltered(p) and not model.sheltered(p + side):
		side *= 0.35
	return (p + side).clamp(model.BOUNDS.position, model.BOUNDS.end)
