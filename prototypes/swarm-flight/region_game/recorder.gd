extends Node
## Opt-in native evidence capture. Observes the viewport and input; never drives
## the player or changes simulation time. Disabled in an ordinary launch.
var driver
var directory := ""
var elapsed := 0.0
var next_capture := 0.0
var index := 0
var busy := false
var manifest: FileAccess
var inputs: FileAccess
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(directory.path_join("frames"))
	manifest = FileAccess.open(directory.path_join("frames.jsonl"),FileAccess.WRITE)
	inputs = FileAccess.open(directory.path_join("inputs.jsonl"),FileAccess.WRITE)
func _input(event: InputEvent) -> void:
	if inputs != null and (event is InputEventKey or event is InputEventMouseButton):
		inputs.store_line(JSON.stringify({"time":elapsed,"event":event.as_text(),"pressed":event.is_pressed(),"mode":driver.mode,"area":driver.model.area}))
		inputs.flush()
func _process(dt: float) -> void:
	elapsed += dt
	if elapsed < next_capture or busy or manifest == null: return
	busy = true
	next_capture = elapsed+.2
	await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	var path := "frames/%06d.jpg" % index
	get_viewport().get_texture().get_image().save_jpg(directory.path_join(path),.82)
	var m = driver.model
	manifest.store_line(JSON.stringify({"frame":index,"path":path,"time":elapsed,"play_time":driver.played_seconds,"mode":driver.mode,"area":m.area,"p":[m.p.x,m.p.y],"energy":m.energy,"cargo":m.cargo,"materials":m.materials,"owned":m.owned}))
	manifest.flush()
	index += 1
	busy = false
func _exit_tree() -> void:
	if manifest != null: manifest.close()
	if inputs != null: inputs.close()
