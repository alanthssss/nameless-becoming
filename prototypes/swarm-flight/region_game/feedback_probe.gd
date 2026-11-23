extends SceneTree
## Exercise a new-profile field trip by viewport keyboard input. The later
## boundary cases explicitly seed cargo in an isolated developer fixture.
const Game = preload("res://region_game/main.tscn")
var game
var held := {}
var checks := 0
var output := ""
var broken := false

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		broken = true
		push_error(what)
		quit(1)
	return ok

func key(code: Key, down: bool) -> void:
	if held.get(code,false) == down: return
	held[code] = down
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	root.push_input(e,true)

func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func fly(at: Vector2) -> bool:
	for i in 720:
		var delta: Vector2 = at-game.model.p
		if delta.length() < 18:
			for code in [KEY_W,KEY_A,KEY_S,KEY_D]: key(code,false)
			return true
		key(KEY_D,delta.x>12)
		key(KEY_A,delta.x< -12)
		key(KEY_S,delta.y>12)
		key(KEY_W,delta.y< -12)
		await process_frame
	return check(false,"flight did not reach "+str(at)+" from "+str(game.model.p))

func capture(label: String) -> void:
	if output.is_empty(): return
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="): isolated=true
	if not check(isolated,"isolated profile required"): return
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	game = Game.instantiate()
	root.add_child(game)
	await frames(8)
	await tap(KEY_ENTER)
	await tap(KEY_E)
	if not check(game.mode=="regions","open destinations from new game via E; mode "+game.mode): return
	await tap(KEY_ENTER)
	await tap(KEY_SPACE)
	if not check(game.mode=="play" and game.model.area=="pond","arrive at pond"): return
	var field = game.model.field
	var entry: Vector2 = field.layout.nodes[0].p
	var target: Dictionary = {}
	for flower in field.flowers:
		if flower.enabled and field.available(flower) and entry.distance_to(flower.p)>235:
			target=flower
			break
	if not check(not target.is_empty(),"a reachable ripe flower"): return
	if not await fly(target.p): return
	key(KEY_E,true)
	for i in 240:
		await process_frame
		if i == 45: capture("harvest-contact")
		if game.model.cargo_total()>0: break
	key(KEY_E,false)
	if not check(game.model.cargo_total()==1,"one actual picked nectar"): return
	await frames(10)
	capture("harvest-drop")
	if not check(game.world.nectar_motes.size()==1,"one corresponding droplet"): return
	if not await fly(entry): return
	await tap(KEY_E)
	await tap(KEY_SPACE)
	if not check(game.model.at_home() and game.mode=="play","return with cargo"): return
	if not await fly(game.model.HUB_SHOP): return
	await tap(KEY_E)
	if not check(game.mode=="shop","opened shop"): return
	var value: int = game.model.cargo_value()
	var coins: int = game.model.coins
	var materials: Dictionary = game.model.materials.duplicate()
	await tap(KEY_ENTER)
	var fx=game.ui.sale_flight
	if not check(fx.visible and game.model.cargo_total()==0 and game.model.coins==coins+value,"successful sale credited immediately, animation started"): return
	await frames(5)
	capture("sale-pouring")
	await frames(21)
	capture("sale-coins")
	game.sell_cargo()
	if not check(game.model.coins==coins+value and game.model.materials==materials,"duplicate and materials protected"): return
	await tap(KEY_ESCAPE)
	if not check(not fx.visible and game.mode=="play","closing shop cancels presentation"): return
	await tap(KEY_E)
	if not check(not fx.visible,"reopening does not replay sale"): return
	var saved=game.new_model()
	if not check(saved.restore_payload(game.read_progress(game.saved_path).payload) and saved.coins==coins+value and saved.cargo_total()==0,"persisted settled balance after interruption"): return
	print("KEYBOARD TRIP: harvested 1, returned, sold for ",value,"; reload balance ",saved.coins)
	# Create a valid late-game profile for a mixed delivery.
	game.model.coins=100
	game.model.materials.fiber=10
	for id in ["gather1","bag1","wings1","meadow"]:
		if not check(game.model.buy(id),"fixture prerequisite "+id): return
	game.model.events.clear()
	game.model.visited_meadow=true
	game.model.cargo={"blue":1,"rose":1}
	materials=game.model.materials.duplicate()
	coins=game.model.coins
	game.save_blocked=true
	game.sell_cargo()
	if not check(not fx.visible and game.model.cargo_total()==2 and game.model.coins==coins,"save failure cannot display delivery or spend"): return
	game.save_blocked=false
	game.reduced_motion=true
	game.sell_cargo()
	if not check(fx.visible and fx.reduced and fx.delivery.size()==2 and game.model.coins==coins+4,"mixed sale in reduced motion uses stationary result"): return
	await frames(65)
	if not check(not fx.visible and game.model.materials==materials,"animation retires"): return
	# Verify a bought rank animates its actual board node. This portion uses
	# the same explicitly funded developer profile as the reduced-motion case.
	game.reduced_motion=false
	game.close_shop()
	game.model.p=game.model.HUB_TREE
	game.open_tree()
	game.buy_upgrade("gather2")
	if not check("gather2" in game.model.owned and game.ui.upgrade_buttons.gather2.growth_tween != null,"purchase animated the rank actually bought"): return
	game.close_tree()
	game.model.p=game.model.HUB_DEPART
	game.open_regions()
	game.request_transition("pond")
	await tap(KEY_SPACE)
	field=game.model.field
	# Force two ripe flowers into reach to exercise simultaneous event presentation.
	field.stats.owned.append("twin")
	field.p=field.layout.nodes[1].p
	field.cargo=field.capacity()-2
	game.model.cargo.blue=field.cargo
	for i in [0,3]:
		field.flowers[i].p=field.p+Vector2(-16 if i==0 else 16,2)
		field.flowers[i].phase="ripe"
		field.flowers[i].phase_time=0.0
		field.flowers[i].stock=1
		field.flowers[i].progress=.99
	game.model._sync_field()
	key(KEY_E,true)
	await frames(5)
	key(KEY_E,false)
	if not check(game.model.cargo_total()==game.model.capacity() and game.world.nectar_motes.size()==2,"two simultaneous picks fill two slots and render two drops"): return
	if not check(game.world._full_glow>0,"full bag signals the return direction"): return
	var mat: Dictionary=field.materials[0]
	mat.phase="ripe"
	mat.phase_time=0.0
	field.p=mat.p-Vector2(55,0)
	field.face=Vector2.RIGHT
	game.model._sync_field()
	var fiber_before: int=game.model.materials.fiber
	key(KEY_Q,true)
	await frames(42)
	key(KEY_Q,false)
	if not check(mat.dropped and game.model.materials.fiber==fiber_before,"fiber falls before credit while nectar bag is full"): return
	if not await fly(mat.p): return
	await frames(4)
	if not check(game.model.materials.fiber==fiber_before+1,"fiber pickup still works at full nectar capacity"): return
	var full_count:=0
	for event in game.event_log:
		if event.kind=="full": full_count+=1
	if not check(full_count==1,"full cue fires once while bag stays full"): return
	game.queue_free()
	await frames(3)
	print("Feedback route and transaction checks: ",checks," passed")
	quit(0)
