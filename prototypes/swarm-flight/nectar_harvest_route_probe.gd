extends SceneTree
## Known-route developer input recording. No teleport, granted currency or upgrades.
const Scene = preload("res://nectar_harvest.tscn")
const Model = preload("res://nectar_harvest_model.gd")
var game
var output := ""
var pressed := {}
var trace: Array[Dictionary] = []
var frame_samples: Array = []
var failures: Array[String] = []
var checks := 0
var frame_count := 0
var resume_check := false
const SHORTCUT_PLAN := ["gather1","bag1","wings1","meadow","shortcut","reserve"]
const TWIN_PLAN := ["gather1","reach","gather2","meadow","twin","reserve"]
var purchase_plan: Array = SHORTCUT_PLAN.duplicate()
var growth_route := "shortcut"
var planned: Array[String] = []
var purchased: Array[String] = []
var last_buy_input_msec := -1000
var earned_total := 0
var spent_total := 0
var purple_recorded := false
var twin_recorded := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool,words: String) -> void:
	checks += 1
	if not ok:
		failures.append(words)
		push_error(words)

func frames(count: int) -> void:
	for i in count:
		await process_frame
		frame_count += 1
		if is_instance_valid(game):
			var m = game.model
			frame_samples.append([frame_count,game.mode,m.p.x,m.p.y,m.energy,m.cargo.blue,m.cargo.rose,m.coins,m.owned.size(),m.area])

func key(code: int,value: bool) -> void:
	if bool(pressed.get(code,false)) == value: return
	pressed[code] = value
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = value
	root.push_input(event,true)
	trace.append({"frame":frame_count,"event":"key","key":code,"pressed":value,"pos":[game.model.p.x,game.model.p.y],"cargo":game.model.cargo_total(),"coins":game.model.coins,"materials":game.model.materials.duplicate()})

func release() -> void:
	for code in pressed.keys(): key(code,false)

func tap(code: int) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func click(b: Button) -> bool:
	if not is_instance_valid(b) or not b.is_visible_in_tree() or b.disabled:
		check(false,"requested mouse target is a visible enabled button")
		return false
	var at := b.get_global_rect().get_center()
	var label := b.text
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion,true)
	await frames(2)
	for value in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = value
		root.push_input(event,true)
		await frames(3)
	trace.append({"frame":frame_count,"event":"button","text_before":label,"text_after":b.text,"at":[at.x,at.y],"mode":game.mode,"coins":game.model.coins,"owned":game.model.owned.duplicate()})
	return true

func purchase(id: String) -> bool:
	var before: int = game.model.coins
	var owned_before: Array = game.model.owned.duplicate()
	var cost: int = game.model.upgrade(id).cost
	if not await click(game.ui.upgrade_buttons[id]): return false
	var selection_ok: bool = game.mode == "tree" and game.ui.board.next_id(game.ui.board.selected) == id
	check(selection_ok,"node selection displays the next rank "+id)
	check(game.model.coins == before and game.model.owned == owned_before,"selecting a growth node never spends money or grants "+id)
	if not selection_ok or game.model.coins != before or game.model.owned != owned_before: return false
	# The production confirmation button debounces wall-clock input. Keep every
	# rendered frame while waiting, including when movie capture runs faster.
	while Time.get_ticks_msec()-last_buy_input_msec < 400: await frames(1)
	if not await click(game.ui.buy_button): return false
	last_buy_input_msec = Time.get_ticks_msec()
	var bought: bool = id in game.model.owned and game.model.owned.size() == owned_before.size()+1 and game.model.coins == before-cost
	check(bought,"separate confirmation spends exactly one price and grants "+id)
	if bought:
		purchased.append(id)
		spent_total += cost
		trace.append({"frame":frame_count,"event":"confirmed_purchase","id":id,"cost":cost,"coins_before":before,"coins_after":game.model.coins,"owned":game.model.owned.duplicate()})
	return bought

func fly_to(target: Vector2) -> bool:
	# Known-route choice: use the visible low shelter when crossing the shower.
	if game.model.area == "meadow" and minf(target.x,game.model.p.x)<2920 and maxf(target.x,game.model.p.x)>2600 and minf(target.y,game.model.p.y)<640:
		if not await fly_direct(Vector2(game.model.p.x,645)): return false
		if not await fly_direct(Vector2(target.x,645)): return false
	return await fly_direct(target)

func fly_direct(target: Vector2) -> bool:
	for i in 1600:
		var delta: Vector2 = target-game.model.p
		if delta.length() < 16:
			release()
			await frames(6)
			return true
		key(KEY_D,delta.x > 8)
		key(KEY_A,delta.x < -8)
		key(KEY_S,delta.y > 8)
		key(KEY_W,delta.y < -8)
		await frames(1)
		if game.mode != "play": break
	release()
	return false

func capture(name: String) -> void:
	if output.is_empty(): return
	await frames(3)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func save_json(name: String,data) -> void:
	var file := FileAccess.open(output.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t",true,true))

func transition_settled() -> void:
	for i in 90:
		await frames(1)
		if game.mode != "transition": break
	check(game.mode != "transition","dance transition settles within three seconds")

func run() -> void:
	var progress_argument := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
		if arg == "--resume-check": resume_check=true
		if arg == "--growth-route=twin": growth_route="twin"
		if arg.begins_with("--progress-file="): progress_argument=arg.trim_prefix("--progress-file=")
	purchase_plan = TWIN_PLAN.duplicate() if growth_route == "twin" else SHORTCUT_PLAN.duplicate()
	planned.assign(purchase_plan)
	if output.is_empty(): quit(2); return
	if progress_argument.is_empty() or "journey" in progress_argument.get_file():
		push_error("Route recording requires an explicit isolated --progress-file path")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game=Scene.instantiate()
	root.add_child(game)
	await frames(12)
	if resume_check:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("save-before.json")))
		var expected_model = Model.new()
		var expected_valid: bool = expected_model.restore_payload(expected)
		check(game.has_save and expected_valid and game.model.to_payload() == expected_model.to_payload(),"cold process restores exact persisted state before continuation")
		save_json("cold-loaded.json",game.model.to_payload())
		await capture("11-cold-title")
		await tap(KEY_ENTER)
		check(game.mode == "play","actual continue input resumes exported-independent scene")
		var before: Vector2=game.model.p
		key(KEY_D,true)
		await frames(15)
		key(KEY_D,false)
		await tap(KEY_ESCAPE)
		check(game.model.p.x>before.x,"ordinary movement works after cold resume")
		save_json("save-after.json",game.model.to_payload())
		await capture("12-cold-continued")
		await finish("cold-result.json")
		return
	check(not game.has_save and game.model.coins == 0 and game.model.owned.is_empty(),"whole route begins from real new progress")
	if not failures.is_empty():
		await finish("route-result.json")
		return
	check(game.ui.upgrade_buttons.gather1 == game.ui.upgrade_buttons.gather2 and game.ui.upgrade_buttons.bag1 == game.ui.upgrade_buttons.bag2 and game.ui.upgrade_buttons.wings1 == game.ui.upgrade_buttons.wings2,"each two-rank ability shares one selectable node")
	await capture("01-new-title")
	await tap(KEY_ENTER)
	await capture("02-hive-departure")
	for expedition in 50:
		if planned.is_empty(): break
		var m = game.model
		var materials_before: Dictionary = m.materials.duplicate()
		var need_fiber := 0
		var need_resin := 0
		for id in planned:
			need_fiber += int(m.upgrade(id).get("fiber",0))
			need_resin += int(m.upgrade(id).get("resin",0))
		var destination := "meadow" if "meadow" in m.owned and m.materials.fiber >= need_fiber else "pond"
		check(await fly_to(Model.HUB_DEPART),"ordinary flight to departure %d" % expedition)
		await tap(KEY_E)
		check(game.mode == "regions","E opens actual departure lamp")
		await click(game.ui.meadow_button if destination == "meadow" else game.ui.pond_button)
		if expedition == 0:
			await frames(16); await capture("02a-dance")
			await frames(22); await capture("02b-iris")
			await frames(6); await capture("02c-silhouette")
		await transition_settled()
		check(m.area == destination and game.world.area_key == destination,"departure loads selected scene once")
		if not failures.is_empty(): break
		var region := 0 if destination == "pond" else 1
		var home: Vector2 = Model.POND_ENTRY if region == 0 else Model.MEADOW_ENTRY
		for creature in m.creatures:
			if creature.region != region: continue
			if region == 0 and m.materials.fiber >= need_fiber: continue
			if region == 1 and m.materials.resin >= need_resin: continue
			var cost: float = m.p.distance_to(creature.pos)/180+creature.pos.distance_to(home)/180+(3 if creature.kind == "guard" else 2)*2.6+4
			if m.energy < cost: break
			check(await fly_to(creature.pos+Vector2(95 if creature.pos.x>2800 else -95,0)),"ordinary flight approaches material carrier")
			for hit in 3:
				if creature.state == "gone": break
				await tap(KEY_Q)
				if expedition == 0 and hit == 0: await capture("03a-wing-pulse")
				await frames(17)
			check(creature.state == "gone" and not m.drops.is_empty(),"distinct pulse input sheds physical material")
			if not m.drops.is_empty():
				if expedition == 0: await capture("03b-material-drop")
				check(await fly_to(m.drops[-1].pos),"ordinary movement retrieves material")
				await frames(12)
			if not failures.is_empty(): break
		var picked: Array = []
		for attempt in 20:
			if m.cargo_total() >= m.capacity(): break
			var target: Dictionary = {}
			for flower in m.flowers:
				if flower.stock <= 0 or flower.region != region or flower.id in picked: continue
				if target.is_empty() or m.p.distance_to(flower.pos) < m.p.distance_to(target.pos): target = flower
			if target.is_empty(): break
			var required: float = m.p.distance_to(target.pos)/180+target.pos.distance_to(home)/180+1.9/m.harvest_rate()+4.0
			if m.energy <= required: break
			var approach: Vector2 = target.pos
			var paired: Dictionary = {}
			var stock_before := int(target.stock)
			var paired_before := 0
			if "twin" in m.owned and not twin_recorded:
				for flower in m.flowers:
					if flower.id != target.id and flower.region == target.region and flower.stock > 0 and target.pos.distance_to(flower.pos) < 2*m.harvest_radius()-30:
						paired = flower; paired_before = int(flower.stock)
						approach = (target.pos+flower.pos)*.5
						break
			check(await fly_to(approach),"source reached through ordinary controls")
			if region == 1 and not purple_recorded:
				purple_recorded = true
				await capture("07b-first-purple-visit")
			key(KEY_E,true)
			for tick in 150:
				await frames(1)
				if expedition == 0 and attempt == 0 and tick == 20: await capture("03c-active-harvest-progress")
				if not paired.is_empty() and not twin_recorded and m.harvesting_ids.size()==2 and int(target.stock)<stock_before and int(paired.stock)<paired_before:
					twin_recorded = true
					trace.append({"frame":frame_count,"event":"two_sources_harvested","ids":[target.id,paired.id],"before":[stock_before,paired_before],"after":[target.stock,paired.stock]})
					await capture("08b-two-source-harvest")
				if m.cargo_total()>=m.capacity() or target.stock<=0: break
			key(KEY_E,false)
			await frames(3)
			picked.append(target.id)
			if m.at_home(): check(false,"planned route unexpectedly exhausted energy"); break
		check(m.cargo_total()>0 or m.materials.fiber>materials_before.fiber or m.materials.resin>materials_before.resin,"trip returns with actual nectar or material rewards and an energy reserve")
		if not failures.is_empty(): break
		if expedition == 0: await capture("04-first-return-reserve")
		check(await fly_to(home),"ordinary flight returns before exhaustion")
		await tap(KEY_E)
		if region == 1: await click(game.ui.home_button)
		await transition_settled()
		check(m.area == "hub" and m.p.distance_to(Model.HUB_DEPART)<5,"return arrives at actual courtyard lamp")
		check(await fly_to(Model.HUB_SHOP),"ordinary flight to the separate sale NPC")
		if not failures.is_empty(): break
		await tap(KEY_E)
		check(game.mode == "shop","E opens hive transaction screen")
		if expedition==0: await capture("05-first-sale-offer")
		var gain: int=game.model.cargo_value()
		var coins_before: int=game.model.coins
		if gain > 0: await click(game.ui.sell_button)
		else: check(game.ui.sell_button.disabled,"material expedition does not invent nectar sale proceeds")
		check(game.model.cargo_total()==0 and game.model.coins==coins_before+gain,"sale commits real collected cargo")
		if not failures.is_empty(): break
		earned_total += gain
		await click(game.ui.leave_button)
		check(await fly_to(Model.HUB_TREE),"ordinary flight to separate growth station")
		await tap(KEY_E)
		check(game.mode == "tree" and game.ui.tree.visible and not game.ui.shop.visible,"growth station opens its own page after the sale")
		if not failures.is_empty(): break
		while not planned.is_empty() and game.model.can_buy(planned[0]):
			var id: String=planned[0]
			if id == "meadow": check(game.model.growth_count() == 3,"three actual base-rank purchases open meadow, including gather rank two")
			if not await purchase(id): break
			planned.pop_front()
			if id == "gather1": await capture("06-first-upgrade")
			if id == "gather2": await capture("06b-second-rank-same-node")
			if id == "meadow": await capture("07-meadow-unlocked")
			if id == "shortcut": await capture("08-shortcut-unlocked")
		if not failures.is_empty(): break
		if game.mode == "complete": break
		await tap(KEY_ESCAPE)
		check(game.mode == "play","Esc from growth returns to the courtyard station")
		if not failures.is_empty(): break
	check(game.model.completed and planned.is_empty() and purchased == purchase_plan,"chosen route completes reserve through six actual confirmed purchases")
	check(purple_recorded and game.model.rose_sold >= 6,"completion uses actual purple exploration and at least 6 sold purple nectar")
	check("market" not in game.model.owned and ("twin" not in game.model.owned if growth_route == "shortcut" else "shortcut" not in game.model.owned) and game.model.owned.size() < Model.UPGRADE_IDS.size(),"stage completes without market, the alternative OR branch, or a full tree")
	if growth_route == "twin": check(twin_recorded,"ordinary-input twin route depletes two flower stocks simultaneously")
	check(game.model.coins == earned_total-spent_total,"all upgrade costs come from recorded real harvest sales")
	if not failures.is_empty():
		await finish("route-result.json")
		return
	await capture("09-reserve-complete")
	await tap(KEY_ENTER)
	check(game.mode == "play","completion allows continued free play")
	await fly_to(Model.HUB_DEPART)
	await tap(KEY_E)
	await click(game.ui.pond_button)
	await transition_settled()
	if growth_route == "shortcut":
		check(await fly_to(Model.SHORTCUTS[0]),"reach shortcut after upgrade")
		await tap(KEY_F); await transition_settled()
		check(game.model.area == "meadow","outward shortcut works through ordinary F")
		await tap(KEY_F); await transition_settled()
		check(game.model.area == "pond","return shortcut preserves same trip")
	await fly_to(game.model.flowers[0].pos)
	key(KEY_E,true)
	await frames(40)
	key(KEY_E,false)
	await tap(KEY_ESCAPE)
	save_json("save-before.json",game.model.to_payload())
	await capture("10-saved-in-field")
	await finish("route-result.json")

func finish(name: String) -> void:
	release()
	save_json(name,{"checks":checks,"failures":failures,"frames":frame_count,"game_seconds":game.played_seconds,"classification":"known-route developer native input; not uncoached or human play","run_kind":"cold_resume" if resume_check else "new_route","progress_path":game.saved_path,"purchase_plan":purchase_plan,"growth_route":growth_route,"twin_recorded":twin_recorded,"purchased":purchased,"earned_total":earned_total,"spent_total":spent_total,"frame_sample_columns":["frame","mode","x","y","energy","blue_cargo","rose_cargo","coins","owned_count","area"],"frame_samples":frame_samples,"trace":trace,"events":game.event_log,"final":game.model.to_payload()})
	print("NECTAR NATIVE ROUTE: %d checks, %d failures, %.1f game seconds" % [checks,failures.size(),game.played_seconds])
	game.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
