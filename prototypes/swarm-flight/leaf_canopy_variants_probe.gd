extends "res://leaf_canopy_probe.gd"
## Controlled asset fixtures in the production scene, not player or save evidence.
class NativeFixture extends "res://spring_journey_main.gd":
	# G2 tests asset motion, not pause controls. Never allow OS focus changes
	# to turn a scripted movement trace into a paused screenshot sequence.
	func pause_game() -> void: pass

func lamp_join_visible(leaf: Dictionary) -> bool:
	if DisplayServer.get_name()=="headless": return true
	# Independent original alpha edge + actual rendered string pixels.
	# This catches a renderer that still bypasses the geometry helper.
	var source:=Image.load_from_file("res://art/revision-atlas.png")
	var width: float=leaf.half_width*2+20
	var source_x:=19+int((width/2-7)/width*592)
	var bottom:=column_y(source,source_x,false)
	var edge_y: float=leaf.pos.y-161+float(bottom-822)/251*95
	var frame:=root.get_texture().get_image()
	var x:=int(round(leaf.pos.x-7-game.model.camera_x))
	var ink:=Color("58452c")
	for y in range(int(ceil(edge_y))+1,int(ceil(edge_y))+4):
		var connected:=false
		for dx in range(-2,3):
			var color:=frame.get_pixel(x+dx,y)
			if absf(color.r-ink.r)+absf(color.g-ink.g)+absf(color.b-ink.b)<0.2: connected=true
		if not connected: return false
	return true

func snapshot(name: String) -> void:
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(folder.path_join(name))

func run() -> void:
	if folder.is_empty():
		push_error("Set SWARM_CANOPY_QA_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	game=NativeFixture.new()
	game.test_mode=true # Existing QA flag: custom asset fixtures must never write saves.
	game.progress_file=folder.path_join("unused-isolated-save.json")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)
	game.begin_stage(0)
	var color_lamps: bool="--color-lamps" in OS.get_cmdline_user_args()
	var report: Dictionary={"kind":"controlled_native_asset_variants","baseline_revision":"0518a9c","exact_source":"see receipt source hashes","widths":[118,180],"input":"root.push_input,30Hz,production main/model/view with QA-only pause suppression; saves disabled before ready","conditions":"width,height and terrain-free surroundings are explicit fixtures; each weather phase uses its actual chapter; requested phase reset before each tick and actual state is logged; no authored data changes","color_lamps":color_lamps,"cases":[]}
	for half in [118.0,180.0]:
		var matrix: Array=[{"height":465.0,"weather":"dry","reached":false},{"height":500.0,"weather":"warning","reached":false},{"height":520.0,"weather":"rain","reached":true},{"height":600.0,"weather":"after","reached":true}]
		if color_lamps: matrix=[matrix[0],matrix[-1]]
		for row in matrix:
			game.model.load_stage(0 if row.weather=="dry" else 2 if row.weather=="after" else 1)
			if game.model.stage==0: game.model.walls.clear()
			game.model.started=true
			var leaf: Dictionary=game.model.shelters[0]
			leaf.half_width=half
			leaf.pos=Vector2(620,row.height)
			game.model.sections[0].rest=leaf.pos
			if color_lamps:
				game.model.shelters.clear()
				game.model.shelters.append(leaf)
			var q: Vector2=leaf.pos
			var record: Dictionary={"half_width":half,"anchor":[q.x,q.y],"weather":row.weather,"stage":game.model.stage,"reached":row.reached,"segments":[]}
			var stem_joint:=q+Vector2(half+4,-80)
			record.support_joint=[stem_joint.x,stem_joint.y]
			for segment in [{"name":"entry","start":q+Vector2(-half-50,0),"key":KEY_RIGHT,"frames":40},{"name":"above","start":q+Vector2(0,-210),"key":KEY_DOWN,"frames":30},{"name":"below","start":q+Vector2(0,-20),"key":KEY_UP,"frames":30}]:
				position(segment.start)
				game.model.weather_phase=row.weather
				game.model.warning_elapsed=0 if row.weather!="rain" else game.model.WARNING_SECONDS
				leaf.reached=row.reached
				if segment.name=="entry":
					game.refresh_hud()
					game.queue_redraw()
					game.world.queue_redraw()
					await process_frame
					await process_frame
					if not color_lamps and not lamp_join_visible(leaf):
						push_error("Actual rendered lamp string is disconnected: "+str([half,row.height]))
						quit(1)
						return
					record["rendered_lamp_join_checked"]=not color_lamps and DisplayServer.get_name()!="headless"
					snapshot("w%d-y%d-%s-before.png"%[int(half),int(row.height),row.weather])
				held=segment.key
				key(held,true)
				var trace: Array=[]
				for frame in segment.frames:
					game.model.weather_phase=row.weather
					game.model.warning_elapsed=0 if row.weather!="rain" else game.model.WARNING_SECONDS
					leaf.reached=row.reached
					if game.mode!="play":
						push_error("Fixture unexpectedly paused: "+str(row))
						quit(1)
						return
					game.tick(1.0/30)
					game.world._process(1.0/30)
					game.queue_redraw()
					game.world.queue_redraw()
					trace.append({"p":[game.model.p.x,game.model.p.y],"reached":leaf.reached,"weather":game.model.weather_phase,"stamina":game.model.stamina,"sheltered":game.model.shelter_index_at(game.model.p)>=0})
					await process_frame
				if game.model.p.distance_to(segment.start)<20:
					push_error("No meaningful native motion: "+segment.name)
					quit(1)
					return
				if segment.name=="entry" and not trace.any(func(t):return t.sheltered):
					push_error("Native entry did not reach shelter")
					quit(1)
					return
				if not trace.all(func(t):return t.weather==row.weather):
					push_error("Fixture weather differs from claimed state")
					quit(1)
					return
				var name: String="w%d-y%d-%s-%s"%[int(half),int(row.height),row.weather,segment.name]
				snapshot(name+".png")
				record.segments.append({"name":segment.name,"screenshot":name+".png","trace":trace})
			report.cases.append(record)
	position(Vector2(620,520))
	game.queue_free()
	await process_frame
	FileAccess.open(folder.path_join("variants.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CANOPY VARIANTS: ",report.cases.size()," native matrix rows; three keyboard segments per row; saves disabled")
	quit()
