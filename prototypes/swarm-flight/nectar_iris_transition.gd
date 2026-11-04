extends ColorRect
## A focal iris closes over the real departure point; only its opaque middle
## covers the scene commit. The bee silhouette is built from our own atlas.
const Art = preload("res://art_sprites.gd")
var silhouette: Node2D
var wing_a: Polygon2D
var wing_b: Polygon2D
var trail: Array[Polygon2D] = []
var shade_material: ShaderMaterial

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec2 canvas_size = vec2(1280.0,800.0);
uniform vec2 focus = vec2(640.0,400.0);
uniform float radius = 1600.0;
uniform float fade = -1.0;
void fragment() {
 float cover = smoothstep(radius-1.5,radius+1.5,distance(UV*canvas_size,focus));
 if (fade >= 0.0) { cover = fade; }
 COLOR = vec4(0.025,0.055,0.039,cover);
}"""
	shade_material = ShaderMaterial.new()
	shade_material.shader = shader
	material = shade_material
	silhouette = Node2D.new()
	add_child(silhouette)
	wing_a = _wing(PackedVector2Array([Vector2(-5,-3),Vector2(-34,-46),Vector2(-47,-39),Vector2(-43,-17),Vector2(-12,4)]))
	wing_b = _wing(PackedVector2Array([Vector2(0,-3),Vector2(-10,-55),Vector2(-27,-58),Vector2(-34,-39),Vector2(-10,5)]))
	var body := Sprite2D.new()
	body.texture = Art.ATLAS
	body.region_enabled = true
	body.region_rect = Art.BEE
	body.scale = Vector2.ONE*(74.0/Art.BEE.size.x)
	body.position = Vector2(4,-5)
	var white := Shader.new()
	white.code = "shader_type canvas_item; void fragment(){ COLOR=vec4(vec3(1.0),texture(TEXTURE,UV).a); }"
	var ink := ShaderMaterial.new()
	ink.shader = white
	body.material = ink
	silhouette.add_child(body)
	for i in 5:
		var mote := Polygon2D.new()
		var points := PackedVector2Array()
		for j in 10: points.append(Vector2(cos(j*TAU/10),sin(j*TAU/10))*4)
		mote.polygon = points
		mote.color = Color("fff7de")
		silhouette.add_child(mote)
		trail.append(mote)
	silhouette.hide()

func _wing(points: PackedVector2Array) -> Polygon2D:
	var wing := Polygon2D.new()
	wing.polygon = points
	wing.color = Color("fff7de")
	silhouette.add_child(wing)
	return wing

func configure(alpha: float, focus: Vector2, reduced: bool, elapsed: float) -> void:
	if shade_material == null: return
	modulate.a = 1.0
	shade_material.set_shader_parameter("canvas_size",size)
	shade_material.set_shader_parameter("focus",focus)
	var reach := maxf(focus.length(),maxf((focus-Vector2(size.x,0)).length(),maxf((focus-Vector2(0,size.y)).length(),(focus-size).length())))+4.0
	shade_material.set_shader_parameter("radius",lerpf(reach,-3.0,smoothstep(0.0,1.0,alpha)))
	shade_material.set_shader_parameter("fade",alpha if reduced else -1.0)
	silhouette.visible = not reduced and alpha > 0.97
	silhouette.position = size*.5+Vector2(sin(elapsed*5)*16,sin(elapsed*8)*4)
	silhouette.modulate.a = clampf((alpha-.97)/.03,0,1)
	wing_a.scale.y = .7+sin(elapsed*45)*.25
	wing_b.scale.y = .8+cos(elapsed*45)*.2

	for i in trail.size():
		var t := fposmod(elapsed*2+i*.2,1.0)
		trail[i].position = Vector2(-35-t*100,sin(t*PI*3)*9+5)
		trail[i].scale = Vector2.ONE*(1.0-t*.65)
		trail[i].modulate.a = 1.0-t
