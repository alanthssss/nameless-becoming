extends ColorRect
## A focal iris closes over the real departure point; only its opaque middle
## covers the scene commit. The bee silhouette is built from our own atlas.
const Art = preload("res://nectar_ui_art.gd")
var silhouette: Node2D
var bee: Node2D
var wing_opening := 1.0
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
	bee = Node2D.new()
	var white := Shader.new()
	white.code = "shader_type canvas_item; void fragment(){ COLOR.rgb = vec3(1.0); }"
	var ink := ShaderMaterial.new()
	ink.shader = white
	bee.material = ink
	bee.draw.connect(_draw_silhouette)
	silhouette.add_child(bee)
	for i in 5:
		var mote := Polygon2D.new()
		var points := PackedVector2Array()
		for j in 10: points.append(Vector2(cos(j*TAU/10),sin(j*TAU/10))*4)
		mote.polygon = points
		mote.color = Color("fff7de")
		silhouette.add_child(mote)
		trail.append(mote)
	silhouette.hide()

func _draw_silhouette() -> void:
	Art.painted_bee(bee,Rect2(-39,-49,84,84),wing_opening,Color.WHITE,false)

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
	wing_opening = .75+sin(elapsed*45)*.25
	if silhouette.visible: bee.queue_redraw()

	for i in trail.size():
		var t := fposmod(elapsed*2+i*.2,1.0)
		trail[i].position = Vector2(-35-t*100,sin(t*PI*3)*9+5)
		trail[i].scale = Vector2.ONE*(1.0-t*.65)
		trail[i].modulate.a = 1.0-t
