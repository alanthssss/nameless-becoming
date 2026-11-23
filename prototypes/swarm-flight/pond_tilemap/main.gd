extends Node2D
## An isolated, discardable art/route experiment. No save or economy writes.
const Model = preload("res://region_game/model.gd")
const Field = preload("res://region_game/field.gd")
const View = preload("res://pond_tilemap/view.gd")
const TerrainScene = preload("res://pond_tilemap/terrain.tscn")
const Terrain = preload("res://pond_tilemap/terrain.gd")
var model
var terrain
var world
var label: Label
var status: Label
var held := {}
var paused := false
var finished := false
var outcome := ""
var saw_branch := false
var saw_end := false
var layout: Dictionary

func _ready() -> void:
	get_window().title = "池岸 · TileMap 手绘试做"
	terrain = TerrainScene.instantiate()
	add_child(terrain)
	layout = terrain.build_layout()
	world = View.new()
	world.area_key = "pond"
	add_child(world)
	make_hud()
	restart()
	get_window().focus_exited.connect(func(): set_paused(true))
	get_window().focus_entered.connect(func(): held.clear())

func restart() -> void:
	model = Model.new()
	model.area = "pond"
	model.phase = "field"
	model.field = Field.new()
	model.field.configure("pond",0,23)
	model.field.layout = layout
	model.field.p = Terrain.START
	model.field.stats.owned.clear()
	model.field.energy = model.max_energy()
	var template: Dictionary = model.field.flowers[0].duplicate(true)
	model.field.flowers.clear()
	var spots := [Vector2(360,470),Vector2(535,390),Vector2(680,510),Vector2(820,435),Vector2(1050,490),Vector2(1240,410),Vector2(1460,485),Vector2(905,740),Vector2(1000,810)]
	for i in spots.size():
		var flower := template.duplicate(true)
		flower.id=i; flower.p=spots[i]; flower.enabled=true
		flower.phase="ripe"; flower.phase_time=0.0; flower.phase_duration=18.0; flower.stock=1; flower.progress=0.0
		model.field.flowers.append(flower)
	var material: Dictionary = model.field.materials[0].duplicate(true)
	model.field.materials.clear()
	material.id=0; material.p=Vector2(920,900); material.anchor=material.p
	material.enabled=true; material.phase="ripe"; material.phase_time=0.0; material.phase_duration=22.0
	model.field.materials.append(material)
	model._sync_field()
	world.model=model
	world.dress(layout.coast)
	world._life_motes.clear()
	world.nectar_motes.clear()
	world.harvest_texts.clear()
	held.clear(); paused=false; finished=false; outcome=""; saw_branch=false; saw_end=false
	update_camera()

func update_camera() -> void:
	model.camera_offset = Vector2(clampf(model.p.x-640,0,512),clampf(model.p.y-400,0,352))
	model.camera_x=model.camera_offset.x
	terrain.set_camera(model.camera_offset)

func _process(delta: float) -> void:
	if model == null: return
	world.presentation_active = not paused and not finished
	if not paused and not finished:
		var movement := Vector2(float(down(KEY_D,KEY_RIGHT))-float(down(KEY_A,KEY_LEFT)),float(down(KEY_S,KEY_DOWN))-float(down(KEY_W,KEY_UP)))
		advance(minf(delta,0.05),movement,down(KEY_E,KEY_E),down(KEY_SPACE,KEY_SPACE),down(KEY_Q,KEY_Q))
	status.text = "花蜜 %d/%d   纤维 %d   体力 %d" % [model.cargo_total(),model.capacity(),int(model.materials.fiber),ceili(model.energy)]
	label.text = "已暂停 · Esc 继续" if paused else outcome if finished else "池岸试走  ·  沿蓝花走，岔路通向纤维湾"

func advance(dt: float,move: Vector2,collect := false,charge := false,pulse := false) -> void:
	var previous_field = model.field
	model.step(dt,move,collect,charge,pulse)
	for event in model.events: world.nectar_event(event)
	model.events.clear()
	if model.field == null:
		model.field=previous_field
		model.area="pond"; model.phase="field"
		model._sync_field()
		finished=true
		outcome="体力用完 · R 再走一趟"
		update_camera()
		return
	saw_branch = saw_branch or model.p.distance_to(Terrain.POCKET)<110
	saw_end = saw_end or model.p.distance_to(Terrain.END)<110
	if model.return_requested:
		model.return_requested=false
		finished=true
		outcome="已返回 · R 再走一趟"
	update_camera()

func down(a: int,b: int) -> bool: return bool(held.get(a,false)) or bool(held.get(b,false))

func set_paused(value: bool) -> void:
	paused=value
	held.clear()
	if model != null:
		model.clear_controls()
		model.v=Vector2.ZERO
		if model.field != null: model.field.v=Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		held[code]=event.pressed
		if event.pressed and not event.echo:
			if code==KEY_R: restart()
			if code==KEY_ESCAPE: set_paused(not paused)
		get_viewport().set_input_as_handled()

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position=Vector2(24,20)
	var style := StyleBoxFlat.new()
	style.bg_color=Color("f3ebd3")
	style.corner_radius_top_left=13; style.corner_radius_top_right=13
	style.corner_radius_bottom_left=13; style.corner_radius_bottom_right=13
	style.content_margin_left=17; style.content_margin_right=17
	style.content_margin_top=10; style.content_margin_bottom=10
	style.shadow_color=Color(0.12,0.2,0.12,.18); style.shadow_size=5
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var font := SystemFont.new()
	font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC","sans-serif"])
	world.feedback_font=font
	for words in ["", "", "WASD / 方向键飞行 · E采蜜/返回 · Q振翅 · 空格蓄力 · R重来"]:
		var line := Label.new()
		line.text=words
		line.add_theme_font_override("font",font)
		line.add_theme_color_override("font_color",Color("354838"))
		line.add_theme_font_size_override("font_size",17 if box.get_child_count()>0 else 20)
		box.add_child(line)
	label=box.get_child(0)
	status=box.get_child(1)
