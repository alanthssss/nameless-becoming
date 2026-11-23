extends SceneTree
const Scene = preload("res://pond_tilemap/main.tscn")
const Layout = preload("res://region_greybox/layout.gd")
const Terrain = preload("res://pond_tilemap/terrain.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL "+message)

func walk(target: Vector2) -> void:
	for i in 900:
		if game.model.p.distance_to(target)<9: break
		game.advance(1.0/60.0,(target-game.model.p).normalized())
	check(game.model.p.distance_to(target)<12,"ordinary free flight reaches "+str(target))
	check(Layout.walkable(game.layout,game.model.p),"route ends inside visible shore")

func run() -> void:
	game=Scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	check(game.terrain.get_node("Ground") is TileMapLayer,"real ground TileMapLayer")
	check(game.terrain.get_node("Water") is TileMapLayer,"real water TileMapLayer")
	check(game.terrain.get_node("Ground").get_used_cells().size()>40,"authored reusable cells")
	check(game.terrain.get_node("Ground").tile_set.get_source(0).get_tiles_count()==16,"shared sixteen-pattern TileSet")
	for flower in game.model.field.flowers:
		check(Layout.walkable(game.layout,flower.p,40),"flower safely rooted/reachable "+str(flower.id))
	for item in game.model.field.materials:
		check(Layout.walkable(game.layout,item.anchor,45),"material safely rooted/reachable")
	for target in [Vector2(360,470),Vector2(576,448),Terrain.FORK,Terrain.POCKET,Terrain.FORK,Terrain.END,Terrain.FORK,Vector2(576,448),Terrain.START]: walk(target)
	check(game.saw_branch and game.saw_end,"both branches visited by ordinary flight")
	game.advance(1.0/60.0,Vector2.ZERO,true)
	check(game.finished,"real return condition")
	game.restart()
	# Hold toward the northern bank, then test fast displacement on the same rim.
	for i in 200: game.advance(1.0/60.0,Vector2.UP)
	check(Layout.walkable(game.layout,game.model.p),"held input cannot cross bank")
	var rim: Vector2=game.model.p
	var after: Vector2=Layout.move(game.layout,rim,Vector2(0,-500))
	check(after.distance_to(rim)<8,"large dash cannot tunnel through water boundary")
	check(game.terrain.land_at(after)>=0.5,"collision agrees with shader land")
	# Samples use the shader's independently evaluated public coverage at native
	# world points, with a tolerance for the documented 4px collision raster.
	var disagreement := 0
	for y in range(192,1152,17):
		for x in range(0,1792,17):
			var at:=Vector2(x,y)
			var coverage: float=game.terrain.land_at(at)
			if absf(coverage-.5)<.10: continue
			if (coverage>.5)!=Layout.walkable(game.layout,at,0): disagreement+=1
	check(disagreement==0,"ground and movement share cells across the whole slice")
	game.restart()
	for i in 9: game.advance(.05,Vector2.ZERO,false,true)
	check(game.model.field.charge>=.32,"pause regression starts with releasable charge")
	game.set_paused(true)
	game.set_paused(false)
	game.advance(.05,Vector2.ZERO)
	check(game.model.field.burst_left==0 and not game.model.field.charging,"pause cancels held charge without a surprise dash")
	game.restart()
	game.model.field.energy=.001
	game.advance(.05,Vector2.RIGHT)
	check(game.finished and game.outcome.begins_with("体力用完"),"exhaustion has a visible outcome instead of silent reset")
	game.restart()
	check(not game.finished and game.model.p==Terrain.START and game.model.cargo_total()==0,"restart clears only the isolated preview")
	await process_frame
	print("POND TILEMAP VERIFIED: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
