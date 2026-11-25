extends Sprite2D
## A new regional view owns exactly one visit. The species roll uses a
## separate generator so it never consumes the field or reward RNG.
const FISH: Texture2D = preload("res://art/basin-fish.webp")
const FROG: Texture2D = preload("res://art/basin-frog.webp")
const PIGMENT = preload("res://region_game/basin_pigment.gdshader")
# Measured against the 1280 × 800 courtyard plate. The swim path occupies
# the clear water to the right of both stones; the frog sits on the nearer one.
const SWIM_CENTER := Vector2(124, 678)
const SWIM_RADIUS := Vector2(14, 6)
const FROG_FOOT := Vector2(88, 685)
const LAP_SECONDS := 7.0
const SWIM_SECONDS := 4.5

var is_fish := false

func _ready() -> void:
	var visit := RandomNumberGenerator.new()
	is_fish = visit.randi_range(0, 1) == 0
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material = ShaderMaterial.new()
	material.shader = PIGMENT
	apply_appearance()

func apply_appearance() -> void:
	texture = FISH if is_fish else FROG
	material.set_shader_parameter("submerged", is_fish)

func pose(seconds: float, reduced: bool) -> void:
	var time := 0.0 if reduced else seconds
	var base := (37.0 if is_fish else 31.0) / texture.get_width()
	if is_fish:
		var t := clampf(fposmod(time, LAP_SECONDS) / SWIM_SECONDS, 0.0, 1.0)
		var angle := smoothstep(0.0, 1.0, t) * TAU - PI * .5
		position = SWIM_CENTER + Vector2(cos(angle), sin(angle)) * SWIM_RADIUS
		var heading := Vector2(-sin(angle), cos(angle)) * SWIM_RADIUS
		flip_h = heading.x < 0.0
		rotation = atan2(heading.y, maxf(7.0, absf(heading.x))) * (-1.0 if flip_h else 1.0)
		scale = Vector2.ONE * base
		material.set_shader_parameter("tail_bend", sin(time * 12.0) * sin(t * PI) * .12)
	else:
		var breath := (1.0 - cos(time * 2.1)) * .025
		scale = Vector2(1.0 - breath * .4, 1.0 + breath) * base
		position = FROG_FOOT - Vector2(0, texture.get_height() * scale.y * .5)
