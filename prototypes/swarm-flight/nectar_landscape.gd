extends RefCounted
## A continuous oblique ground plane. Upright props are rendered by depth in the view.
## Background art has no collider; the bee can fly over garden edges and water.
const COURTYARD: Texture2D = preload("res://art/nectar-courtyard-oblique.png")
const POND: Texture2D = preload("res://art/nectar-pond-oblique.png")
const MEADOW: Texture2D = preload("res://art/nectar-meadow-oblique.png")

static func background(v: Node2D, area: String) -> void:
	var rect := Rect2(0,0,1280,800)
	var texture: Texture2D = COURTYARD
	if area == "pond":
		texture = POND
		rect = Rect2(400-v.model.camera_x,0,1320,800)
	elif area == "meadow":
		texture = MEADOW
		rect = Rect2(1840-v.model.camera_x,0,1680,800)
	v.draw_texture_rect(texture,rect,false)

static func terrain(v: Node2D, area: String, _cam: float, clock: float) -> void:
	# The pond's ripples stay on its painted water in world coordinates.
	if area != "pond" or v.reduced_motion: return
	for i in 3:
		var at := Vector2(545+i*84,175+i*31)
		var phase: float = fposmod(clock*.28+i*.34,1.0)
		v._ellipse(at,Vector2(17+phase*14,3+phase*3),Color(.84,.98,.81,sin(phase*PI)*.13))
