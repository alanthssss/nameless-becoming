@tool
extends Node2D
## Saved TileMap cells are the authoring source for both paint and movement.
const CELL := 64
const SAMPLE := 4
const START := Vector2(192, 512)
const FORK := Vector2(960, 512)
const END := Vector2(1536, 448)
const POCKET := Vector2(960, 896)
const NODES := [START, Vector2(576,448), FORK, END, POCKET]

func mask_at(cell: Vector2i) -> int:
	var data: TileData = $Ground.get_cell_tile_data(cell)
	return int(data.get_custom_data("corners")) if data != null else 0

static func coverage(mask: int, q: Vector2) -> float:
	return lerpf(lerpf(float(mask & 1),float((mask >> 1) & 1),q.x),
		lerpf(float((mask >> 3) & 1),float((mask >> 2) & 1),q.x),q.y)

func land_at(at: Vector2) -> float:
	var cell := Vector2i(floori(at.x/CELL),floori(at.y/CELL))
	return coverage(mask_at(cell),(at-Vector2(cell)*CELL)/CELL)

func build_layout() -> Dictionary:
	# Geometry-only rasterization: no source artwork is modified. Four-pixel
	# sampling gives a <=6px contour tolerance, smaller than the 16px bee margin.
	var used: Rect2i = $Ground.get_used_rect()
	var origin := Vector2(used.position*CELL)
	var size := used.size*(CELL/SAMPLE)
	var bitmap := BitMap.new()
	bitmap.create(size)
	var masks := {}
	for cell in $Ground.get_used_cells(): masks[cell] = mask_at(cell)
	for y in size.y:
		for x in size.x:
			var point := origin+Vector2(x*SAMPLE,y*SAMPLE)
			var cell := Vector2i(floori(point.x/CELL),floori(point.y/CELL))
			var q := (point-Vector2(cell)*CELL)/CELL
			if coverage(int(masks.get(cell,0)),q)>=0.5: bitmap.set_bit(x,y,true)
	var outlines := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,size),1.0)
	assert(outlines.size()==1,"Preview must be one connected bank without islands")
	var coast := PackedVector2Array()
	for point in outlines[0]: coast.append(point*SAMPLE+origin)
	var nodes: Array[Dictionary] = []
	for i in NODES.size(): nodes.append({"id":i,"name":["归途","蓝花岸","分岔","远岸","纤维湾"][i],"p":NODES[i],"radius":110.0})
	return {"region":"pond","coast":coast,"nodes":nodes,
		"bounds":Rect2(0,128,1792,1024),"edges":[Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(2,4)],
		"paths":[PackedVector2Array([START,NODES[1]]),PackedVector2Array([NODES[1],FORK]),PackedVector2Array([FORK,END]),PackedVector2Array([FORK,POCKET])],
		"path_radii":[160.0,160.0,160.0,100.0]}

func set_camera(offset: Vector2) -> void:
	position = -offset
	for layer in [$Water,$Ground]: layer.material.set_shader_parameter("camera_origin",offset)
