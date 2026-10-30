extends SceneTree
## Developer baseline: production scene and keyboard path, never player acceptance.
const Scene = preload("res://spring_journey.tscn")
const Model = preload("res://spring_journey_model.gd")
const Sprites = preload("res://art_sprites.gd")
var folder := OS.get_environment("SWARM_CANOPY_QA_DIR")
var game
var rows: Array = []
var held: Key = KEY_NONE
func _initialize() -> void: call_deferred("run")
func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	root.push_input(e)
func position(point: Vector2) -> void:
	if held != KEY_NONE: key(held,false)
	held = KEY_NONE
	game.model.p = point
	game.model.velocity = Vector2.ZERO
	game.model.clear_input()
	game.model.stamina = 100.0
func column_y(image: Image, x: int, first: bool) -> int:
	for i in int(Sprites.LEAF.size.y):
		var y := int(Sprites.LEAF.position.y)+(i if first else int(Sprites.LEAF.size.y)-1-i)
		if image.get_pixel(x,y).a >= 0.6: return y
	return -1
func measurements() -> Array:
	var image := Image.load_from_file("res://art/revision-atlas.png")
	var result: Array = []
	for half in [118.0,180.0]:
		for fraction in [-0.85,-0.5,0.0,0.5,0.85]:
			var m := Model.new()
			m.load_stage(1)
			var leaf: Dictionary = m.shelters[0].duplicate()
			leaf.half_width = half
			m.shelters = [leaf]
			m.walls.clear()
			m.rain_fields.clear()
			m.weather_phase = "rain"
			var x: float = leaf.pos.x+fraction*half
			var u: float = (x-(leaf.pos.x-half-10))/(half*2+20)
			var source_x := int(Sprites.LEAF.position.x+u*Sprites.LEAF.size.x)
			var top := column_y(image,source_x,true)
			var bottom := column_y(image,source_x,false)
			var roof_y: float = leaf.pos.y-161+(top-Sprites.LEAF.position.y)/Sprites.LEAF.size.y*95
			var underside: float = leaf.pos.y-161+(bottom-Sprites.LEAF.position.y)/Sprites.LEAF.size.y*95
			var drawn_rain_stop: float = m.rain_floor_at(x)
			m.p = leaf.pos+Vector2(0,20)
			m.drops = [{"pos":Vector2(x,roof_y+2),"vel":Vector2.ZERO}]
			m.advance_rain(0.0)
			result.append({"half_width":half,"fraction":fraction,"x":x,"opaque_top":roof_y,"opaque_bottom":underside,"rain_floor":drawn_rain_stop,"rain_penetration":drawn_rain_stop-roof_y,"physical_drop_survives_inside_leaf":not m.drops.is_empty()})
	return result
func run() -> void:
	if folder.is_empty():
		push_error("Set SWARM_CANOPY_QA_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var report := {"kind":"developer_baseline","pixel_reference":"original canopy alpha >= 0.6, no image edits","measurements":measurements(),"input_segments":[]}
	if DisplayServer.get_name() != "headless":
		game = Scene.instantiate()
		# Isolate developer setup before _ready can read a user save.
		game.progress_file = folder.path_join("probe-save.json")
		root.add_child(game)
		await process_frame
		game.set_process(false)
		game.world.set_process(false)
		game.sound.set_muted(true)
		key(KEY_ENTER,true)
		key(KEY_ENTER,false)
		game.model.load_stage(1)
		game.model.started = true
		game.model.weather_phase = "rain"
		var leaf: Dictionary = game.model.shelters[0]
		var q: Vector2 = leaf.pos
		var segments := [
			{"name":"left_entry","start":q+Vector2(-250,0),"key":KEY_RIGHT,"frames":48},
			{"name":"right_exit","start":q,"key":KEY_RIGHT,"frames":48},
			{"name":"right_entry","start":q+Vector2(250,0),"key":KEY_LEFT,"frames":48},
			{"name":"left_exit","start":q,"key":KEY_LEFT,"frames":48},
			{"name":"from_above","start":q+Vector2(0,-215),"key":KEY_DOWN,"frames":36},
			{"name":"from_below","start":q+Vector2(0,-25),"key":KEY_UP,"frames":36}]
		for segment in segments:
			position(segment.start)
			held = segment.key
			key(held,true)
			var samples: Array = []
			for frame in segment.frames:
				game.tick(1.0/30)
				game.world._process(1.0/30)
				game.queue_redraw()
				game.world.queue_redraw()
				samples.append({"frame":frame,"p":[game.model.p.x,game.model.p.y],"sheltered":game.model.shelter_index_at(game.model.p)>=0,"stamina":game.model.stamina,"drops":game.model.drops.size()})
				await process_frame
				if frame == segment.frames-1:
					root.get_texture().get_image().save_png(folder.path_join(segment.name+".png"))
			report.input_segments.append({"name":segment.name,"setup_position":[segment.start.x,segment.start.y],"input":"keyboard via root.push_input; 30Hz; production tick","samples":samples})
		position(q)
		game.queue_free()
		await process_frame
	var file := FileAccess.open(folder.path_join("probe.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CANOPY PROBE: ",report.measurements.size()," pixel/rain probes; ",report.input_segments.size()," native keyboard segments")
	quit()
