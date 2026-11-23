extends SceneTree
## Rebuild only the prototype's saved TileSet and TileMap scene.
const Terrain = preload("res://pond_tilemap/terrain.gd")
const GROUND = preload("res://art/region-ground.png")
const WATER = preload("res://art/region-water.png")
const SHORE = preload("res://pond_tilemap/shore.gdshader")

func _initialize() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(Terrain.CELL,Terrain.CELL)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0,"corners")
	tiles.set_custom_data_layer_type(0,TYPE_INT)
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tiles.add_terrain(0)
	tiles.set_terrain_name(0,0,"手绘草岸")
	tiles.set_terrain_color(0,0,Color("a5b96a"))
	var source := TileSetAtlasSource.new()
	source.texture = GROUND
	source.texture_region_size = tiles.tile_size
	source.use_texture_padding = false
	tiles.add_source(source,0)
	var corners := [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER]
	for mask in 16:
		var coord := Vector2i(mask%4,mask/4)
		source.create_tile(coord)
		var data := source.get_tile_data(coord,0)
		data.set_custom_data("corners",mask)
		data.terrain_set = 0
		data.terrain = 0 if mask else -1
		for i in 4: data.set_terrain_peering_bit(corners[i],0 if mask & (1<<i) else -1)
	assert(ResourceSaver.save(tiles,"res://pond_tilemap/shore_tiles.tres")==OK)
	tiles.take_over_path("res://pond_tilemap/shore_tiles.tres")
	var scene := Node2D.new()
	scene.name = "PondTerrain"
	scene.set_script(Terrain)
	var water := make_layer("Water",tiles,true)
	var ground := make_layer("Ground",tiles,false)
	for layer in [water,ground]:
		scene.add_child(layer)
		layer.owner = scene
	for y in range(-10,48):
		for x in range(-16,74):
			var cell := Vector2i(x,y)
			water.set_cell(cell,0,Vector2i.ZERO)
			var mask := 0
			var points := [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
			for i in 4:
				if inside(Vector2((cell+points[i])*Terrain.CELL)): mask |= 1<<i
			# Zero-mask cells provide draw coverage for the smoothed neighbouring rim.
			ground.set_cell(cell,0,Vector2i(mask%4,mask/4))
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://pond_tilemap/terrain.tscn")==OK)
	print("Pond TileMap authored: water=",water.get_used_cells().size()," ground=",ground.get_used_cells().size())
	scene.free()
	quit()

func inside(at: Vector2) -> bool:
	# Gentle meander and independently changing shoulders, not straight capsules.
	for x in range(192,1537,24):
		var y := 492.0-34.0*sin((x-160)*.004)+18.0*sin((x-160)*.009)
		var radius := 161.0+19.0*sin(x*.007+0.5)+10.0*sin(x*.016)
		var delta := at-Vector2(x,y)
		delta.y*=1.0 if delta.y<0 else 1.08+0.08*sin(x*.006)
		if delta.length()<radius: return true
	for y in range(520,905,16):
		var t := (y-520.0)/384.0
		var x := 960.0+28.0*sin(t*PI)-12.0*t
		var width := 113.0+17.0*sin(t*PI*.9)
		if at.distance_to(Vector2(x,y))<width: return true
	# Offset bay bulge avoids a rectangular, symmetrical dead end.
	if ((at-Vector2(969,907))/Vector2(145,112)).length()<1.0: return true
	return false

func make_layer(title: String,tiles: TileSet,water: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = title
	layer.tile_set = tiles
	layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.collision_enabled = false # Movement reads the same authored corner masks.
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = SHORE
	material.set_shader_parameter("ground_paint",GROUND)
	material.set_shader_parameter("water_paint",WATER)
	material.set_shader_parameter("water_only",water)
	layer.material = material
	return layer
