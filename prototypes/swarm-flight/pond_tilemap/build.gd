extends SceneTree
## Rebuild only the prototype's saved TileSet and TileMap scene.
const Terrain = preload("res://pond_tilemap/terrain.gd")
const Layout = preload("res://region_greybox/layout.gd")
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
		data.modulate = Color(float(mask)/15.0,1,1,1)
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
	for y in range(-5,24):
		for x in range(-8,37):
			var cell := Vector2i(x,y)
			water.set_cell(cell,0,Vector2i.ZERO)
			var mask := 0
			var points := [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
			for i in 4:
				if inside(Vector2((cell+points[i])*Terrain.CELL)): mask |= 1<<i
			if mask: ground.set_cell(cell,0,Vector2i(mask%4,mask/4))
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://pond_tilemap/terrain.tscn")==OK)
	print("Pond TileMap authored: water=",water.get_used_cells().size()," ground=",ground.get_used_cells().size())
	scene.free()
	quit()

func inside(at: Vector2) -> bool:
	var points := Terrain.NODES
	for edge in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(2,4)]:
		var width := 128.0 if edge.y==4 else 175.0+22.0*sin(at.x*.007)+12.0*sin(at.x*.014)
		if Layout.segment_distance(at,points[edge.x],points[edge.y])<width: return true
	return false

func make_layer(title: String,tiles: TileSet,water: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = title
	layer.tile_set = tiles
	layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.collision_enabled = false # Movement reads the same authored corner masks.
	var material := ShaderMaterial.new()
	material.shader = SHORE
	material.set_shader_parameter("ground_paint",GROUND)
	material.set_shader_parameter("water_paint",WATER)
	material.set_shader_parameter("water_only",water)
	layer.material = material
	return layer
