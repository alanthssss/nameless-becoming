class_name PollenVisualLanguage
extends RefCounted

## One shared visual alphabet for spring pollen. Compatibility is always encoded
## twice: warm gold + round grain for variant A, rose + diamond grain for variant
## B. Flowers, the player's body, scent routes and transfer feedback all call the
## same helpers so none of them invents a second legend.

const COLORS := [Color("f2cf5b"), Color("e99aba")]
const OUTLINE := Color("26392f", 0.92)
# Stable body-surface anchors on the thorax/abdomen. They summarize
# loose pollen distributed across contact hairs so a distracted player can read
# exact 0/1/2 loads; they are not anatomical hind-leg corbiculae or HUD icons.
const LOAD_SLOTS := [Vector2(-13, -7), Vector2(4, 8)]


static func valid_variant(variant: int) -> bool:
	return variant >= 0 and variant < COLORS.size()


static func color_for(variant: int) -> Color:
	return COLORS[clampi(variant, 0, COLORS.size() - 1)]


static func motif_id(variant: int) -> String:
	return "round_cluster" if variant == 0 else "diamond_cluster"


static func load_slot(variant: int) -> Vector2:
	return LOAD_SLOTS[clampi(variant, 0, LOAD_SLOTS.size() - 1)]


static func draw_grain(canvas: CanvasItem, center: Vector2, variant: int, scale := 1.0, alpha := 1.0) -> void:
	if not valid_variant(variant):
		return
	var color := Color(color_for(variant), clampf(alpha, 0.0, 1.0))
	var outline := Color(OUTLINE, clampf(alpha * 0.92, 0.0, 1.0))
	if variant == 0:
		canvas.draw_circle(center, 5.0 * scale, outline)
		canvas.draw_circle(center, 3.45 * scale, color)
		return
	var outer_radius := 5.8 * scale
	var inner_radius := 4.0 * scale
	canvas.draw_colored_polygon(_diamond(center, outer_radius), outline)
	canvas.draw_colored_polygon(_diamond(center, inner_radius), color)


static func draw_cluster(canvas: CanvasItem, center: Vector2, variant: int, count: int, scale := 1.0, alpha := 1.0) -> void:
	var visible_count := clampi(count, 0, 2)
	if visible_count <= 0:
		return
	var offsets := [Vector2.ZERO] if visible_count == 1 else [Vector2(-5.0, 0), Vector2(5.0, 0)]
	for offset in offsets:
		draw_grain(canvas, center + offset * scale, variant, scale, alpha)


static func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0)
	])
