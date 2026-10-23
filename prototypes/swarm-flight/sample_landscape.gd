extends RefCounted
## Regional scenery plates share one art direction; weather is a separate state.
const Winter = preload("res://winter_art.gd")
const Sprites = preload("res://art_sprites.gd")
const PLATES = [preload("res://art/garden-spring.png"),preload("res://art/revision-garden.png"),preload("res://art/garden-autumn.png"),preload("res://art/garden-winter.png")]

static func background(v: Node2D, region: int, cam: float, _clock: float, weather: int, stage: int) -> void:
	var plate: Texture2D = PLATES[clampi(region,0,3)]
	v.draw_texture_rect(plate,Rect2(-clampf(cam*0.008,0,60),-30,1340,837.5),false)
	v.draw_rect(Rect2(0,0,1280,800),Color(0.96,0.98,0.85,0.12))
	# No painted obstacle enters the high/low flight corridor. Weather changes
	# light and atmosphere without selecting the wrong seasonal location.
	if weather == 2:
		v.draw_rect(Rect2(0,0,1280,800),Color(0.22,0.30,0.43,0.25))
	elif weather == 3:
		v.draw_rect(Rect2(0,0,1280,800),Color(0.96,0.73,0.42,0.10))
	elif stage%4 == 1:
		v.draw_rect(Rect2(0,0,1280,800),Color(1.0,0.94,0.71,0.06))

static func foreground(v: Node2D, cam: float, clock: float) -> void:
	for i in 4:
		var x := fposmod(i*430.0-cam*0.65,1720.0)-230.0
		var y := 782.0+sin(clock*0.7+i)*1.5
		v.draw_texture_rect_region(Winter.ATLAS if Winter.active(v) else Sprites.ATLAS,Rect2(x,y,220,61),Winter.LEAF if Winter.active(v) else Sprites.LEAF,Color.WHITE if Winter.active(v) else Color("a7c780"))
