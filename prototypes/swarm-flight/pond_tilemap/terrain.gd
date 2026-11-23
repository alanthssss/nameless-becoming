@tool
extends Node2D
## Saved TileMap cells are the authoring source for both paint and movement.
const CELL := 32
const SAMPLE := 4
const START := Vector2(192, 512)
const FORK := Vector2(960, 512)
const END := Vector2(1536, 448)
const POCKET := Vector2(960, 896)
const NODES := [START, Vector2(576,448), FORK, END, POCKET]
var field_image: Image
var field_origin := Vector2.ZERO
var _corners := {}
var _refresh_queued := false
var _refreshing := false

func _ready() -> void:
	if Engine.is_editor_hint():
		$Ground.changed.connect(_refresh_editor)
		_refresh_editor()

func _refresh_editor() -> void:
	# Coalesce the editor's cell-change notifications before rebuilding the field.
	if not _refreshing and not _refresh_queued and not is_queued_for_deletion():
		_refresh_queued=true
		call_deferred("_rebuild_editor_field")

func _rebuild_editor_field() -> void:
	_refresh_queued=false
	refresh_field()

func mask_at(cell: Vector2i) -> int:
	var data: TileData = $Ground.get_cell_tile_data(cell)
	return int(data.get_custom_data("corners")) if data != null else 0

static func coverage(mask: int, q: Vector2) -> float:
	return lerpf(lerpf(float(mask & 1),float((mask >> 1) & 1),q.x),
		lerpf(float((mask >> 3) & 1),float((mask >> 2) & 1),q.x),q.y)

func land_at(at: Vector2) -> float:
	if field_image == null: return 0.0
	var p := (at-field_origin)/SAMPLE
	var base := Vector2i(floori(p.x),floori(p.y))
	if base.x<0 or base.y<0 or base.x+1>=field_image.get_width() or base.y+1>=field_image.get_height(): return 0.0
	var q := p-Vector2(base)
	return lerpf(lerpf(field_image.get_pixelv(base).r,field_image.get_pixelv(base+Vector2i.RIGHT).r,q.x),
		lerpf(field_image.get_pixelv(base+Vector2i.DOWN).r,field_image.get_pixelv(base+Vector2i.ONE).r,q.x),q.y)

static func spline_weights(t: float) -> Vector4:
	# Positive cubic B-spline weights: continuous first/second derivatives,
	# no ringing or overshoot near a narrow peninsula.
	return Vector4(pow(1.0-t,3.0),3.0*t*t*t-6.0*t*t+4.0,
		-3.0*t*t*t+3.0*t*t+3.0*t+1.0,t*t*t)/6.0

func smooth_land(at: Vector2) -> float:
	# Small world-anchored irregularities; the source paints are never warped.
	var warp := Vector2(10.0*sin(at.y*.012)+4.0*sin(at.y*.033+1.1),
		11.0*sin(at.x*.010+0.7)+4.0*sin(at.x*.031))
	var p := (at+warp)/CELL
	var base := Vector2i(floori(p.x),floori(p.y))
	var wx := spline_weights(p.x-base.x)
	var wy := spline_weights(p.y-base.y)
	var value := 0.0
	for y in 4:
		for x in 4:
			if _corners.has(base+Vector2i(x-1,y-1)): value+=wx[x]*wy[y]
	return value

func refresh_field() -> void:
	_refreshing=true
	# Erasing a cell must not remove the quad beneath a neighbour's shared
	# corner. Restore only empty draw support, never a land corner. Editing land
	# uses the matching-corners terrain brush; deleting a quad is not a hole tool.
	for cell in $Water.get_used_cells():
		if $Ground.get_cell_source_id(cell)<0: $Ground.set_cell(cell,0,Vector2i.ZERO)
	_corners.clear()
	var offsets := [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]
	var used := Rect2i()
	var have_land := false
	for cell in $Ground.get_used_cells():
		var mask := mask_at(cell)
		if mask:
			var rect := Rect2i(cell,Vector2i.ONE)
			used=used.merge(rect) if have_land else rect
			have_land=true
		for i in 4:
			if mask & (1<<i): _corners[cell+offsets[i]]=true
	used=used.grow(2)
	field_origin=Vector2(used.position*CELL)
	var size := used.size*(CELL/SAMPLE)+Vector2i.ONE
	field_image=Image.create_empty(size.x,size.y,false,Image.FORMAT_RF)
	for y in size.y:
		for x in size.x:
			field_image.set_pixel(x,y,Color(smooth_land(field_origin+Vector2(x,y)*SAMPLE),0,0,1))
	var material: ShaderMaterial=$Ground.material
	material.set_shader_parameter("shore_field",ImageTexture.create_from_image(field_image))
	material.set_shader_parameter("field_origin",field_origin)
	material.set_shader_parameter("field_size",Vector2(size))
	_refreshing=false

func build_layout() -> Dictionary:
	# The very same continuous scalar field drives paint and movement.
	# This generated image contains geometry only, never edited source artwork.
	refresh_field()
	var size := field_image.get_size()
	var bitmap := BitMap.new()
	bitmap.create(size)
	for y in size.y:
		for x in size.x:
			if field_image.get_pixel(x,y).r>=0.5: bitmap.set_bit(x,y,true)
	var outlines := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,size),1.0)
	assert(outlines.size()==1,"Preview must be one connected bank without islands")
	var coast := PackedVector2Array()
	for point in outlines[0]: coast.append(point*SAMPLE+field_origin)
	var nodes: Array[Dictionary] = []
	for i in NODES.size(): nodes.append({"id":i,"name":["归途","蓝花岸","分岔","远岸","纤维湾"][i],"p":NODES[i],"radius":110.0})
	return {"region":"pond","coast":coast,"nodes":nodes,
		"bounds":Rect2(0,128,1792,1024),"edges":[Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(2,4)],
		"paths":[PackedVector2Array([START,NODES[1]]),PackedVector2Array([NODES[1],FORK]),PackedVector2Array([FORK,END]),PackedVector2Array([FORK,POCKET])],
		"path_radii":[160.0,160.0,160.0,100.0]}

func set_camera(offset: Vector2) -> void:
	position = -offset
	for layer in [$Water,$Ground]: layer.material.set_shader_parameter("camera_origin",offset)
