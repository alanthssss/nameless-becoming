extends SceneTree
const Model = preload("res://game_model.gd")
const Save = preload("res://save_data.gd")
var checks := 0
var failures: Array[String] = []
var m

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fly(target: Vector2, limit := 1800) -> bool:
	for i in range(limit):
		if m.p.distance_to(target) < 13 or m.phase != "playing": return true
		m.step((target-m.p).normalized(),false,1.0/60.0)
	return false

func burst(direction: Vector2, settle := 0.62) -> void:
	m.step(direction,false,1.0/60.0)
	for i in range(43): m.step(Vector2.ZERO,true,1.0/60.0)
	m.step(Vector2.ZERO,false,1.0/60.0)
	for i in range(int(settle*60)): m.step(Vector2.ZERO,false,1.0/60.0)

func navigate(target: Vector2, label: String) -> void:
	expect(fly(target),label)

func full_route() -> void:
	m = Model.new()
	navigate(Vector2(590,400),"First pod approach")
	burst(Vector2.RIGHT)
	expect(m.bees == 3,"Burst rescues first pair")
	navigate(Vector2(1040,380),"First stem approach")
	navigate(Vector2(1240,380),"First stem gap")
	navigate(Vector2(1330,235),"Second pod approach")
	burst(Vector2.RIGHT)
	expect(m.bees == 5,"Second pair joins")
	navigate(Vector2(1770,520),"Lower route approach")
	navigate(Vector2(1990,520),"Second stem gap")
	navigate(Vector2(2180,525),"Third pod approach")
	burst(Vector2.RIGHT)
	expect(m.bees == 7 and m.exit_ready,"All six companions rescued")
	navigate(Vector2(2560,420),"Curtain approach")
	burst(Vector2.RIGHT)
	navigate(m.exit_pos,"Meadow exit")
	expect(m.phase == "transition","Stage one has a reachable ending")
	print("ROUTE: meadow completed; seconds=%.1f, recoveries=%d" % [m.time,m.recoveries])
	m.load_stage(1)
	navigate(Vector2(580,460),"Wind bridge approach")
	burst(Vector2.RIGHT,0.8)
	# Re-enter each flower with another chosen launch, not one automated ride.
	for i in range(1,4):
		var target: Vector2 = m.rings[i].pos
		var approach: Vector2 = target - (target-m.p).normalized()*155
		navigate(approach,"Wind flower %d approach" % i)
		burst((target-m.p).normalized(),0.82)
	navigate(Vector2(3470,405),"Final curtain approach")
	burst(Vector2.RIGHT,0.65)
	navigate(m.exit_pos,"Wind bridge exit")
	expect(m.bees == 9 and m.phase == "transition","All nine bees reach the storm chapter")
	expect(m.rings_hit == 4,"Every wind flower can be used by ordinary controls")
	print("ROUTE: flower bridge completed; seconds=%.1f, recoveries=%d" % [m.time,m.recoveries])
	m.load_stage(2)
	# The final route works without relying on the optional wind-ring accelerators.
	navigate(Vector2(670,390),"Storm first approach")
	navigate(Vector2(940,390),"Storm first gap")
	navigate(Vector2(1050,400),"Storm first curtain approach")
	burst(Vector2.RIGHT)
	navigate(Vector2(1640,400),"First shelter")
	expect(m.shelters[0].reached,"First shelter is a checkpoint")
	navigate(Vector2(2000,440),"Middle gap approach")
	navigate(Vector2(2270,440),"Middle gap")
	navigate(Vector2(2380,430),"Middle curtain approach")
	burst(Vector2.RIGHT)
	navigate(Vector2(2970,430),"Second shelter")
	expect(m.shelters[1].reached,"Second shelter is a checkpoint")
	navigate(Vector2(3210,480),"Last gap approach")
	navigate(Vector2(3410,480),"Last gap")
	navigate(Vector2(3810,430),"Last curtain approach")
	burst(Vector2.RIGHT)
	navigate(m.exit_pos,"Reach the hollow")
	expect(m.phase == "ending" and m.bees == 9,"Complete three-stage route ends at home with nine bees")
	print("ROUTE: rainfront completed; seconds=%.1f, recoveries=%d" % [m.time,m.recoveries])

func rules_and_recovery() -> void:
	m = Model.new()
	var start: Vector2 = m.p
	for i in range(240): m.step(Vector2.ZERO,false,1.0/60.0)
	expect(m.p == start,"Opening remains safe while reading controls")
	m.step(Vector2(1,1).normalized(),false,0.1)
	expect(m.p.distance_to(start) < 30,"Diagonal movement has the same bounded speed")
	for i in range(5): m.step(Vector2.ZERO,true,1.0/60.0)
	m.step(Vector2.ZERO,false,1.0/60.0)
	expect(m.bursts == 0,"A stray Space tap does not launch")
	m.clear_input()
	expect(m.charge == 0 and not m.charging,"Focus/pause clears charge without releasing a burst")
	# The narrowest obstacle cannot be skipped by a long render-frame burst.
	m.p = Vector2(1090,210)
	m.face = Vector2.RIGHT
	m.burst_left = 0.54
	m.step(Vector2.RIGHT,false,0.1)
	expect(m.p.x < 1120,"Substepped collision prevents tunneling through a stem")
	# Native play revealed a compact-to-spread collision softlock at a wall.
	m.load_stage(1)
	m.p = Vector2(1790,260)
	m.charging = true
	m.charge = 1.0
	m.face = Vector2.RIGHT
	m.step(Vector2.ZERO,false,1.0/60.0)
	for i in range(30): m.step(Vector2.LEFT,false,1.0/60.0)
	expect(m.p.x < 1730,"Unfolding against a wall still permits flying away")
	m.load_stage(0)
	m.p = Vector2(2680,420)
	m.burst_left = 0.54
	m.step(Vector2.RIGHT,false,0.1)
	expect(m.walls[4].broken and m.p.x > 2742,"Burst opens a leaf curtain, with matching collision removal")
	m.load_stage(0)
	navigate(Vector2(590,400),"Recovery rescue approach")
	burst(Vector2.RIGHT)
	var saved_pos: Vector2 = m.checkpoint.p
	m.hp = 1
	m.invulnerable = 0
	m.drops.assign([{"pos":m.p,"vel":Vector2.ZERO},{"pos":m.p,"vel":Vector2.ZERO}])
	m.step(Vector2.ZERO,false,1.0/60.0)
	expect(m.hp == 3 and m.bees == 3 and m.recoveries == 1,"Lethal rain restores the newest rescue without losing bees")
	expect(m.p.distance_to(saved_pos) < 4 and m.drops.is_empty(),"Recovery clears all pending rain safely")
	m.load_stage(2)
	m.p = Vector2(1640,400)
	m.step(Vector2.ZERO,false,0.1)
	var storm_before: float = m.storm_x
	for i in range(600): m.step(Vector2.ZERO,false,1.0/60.0)
	expect(m.storm_x == storm_before and m.hp == 3,"Shelter permits unhurried rest")
	m.p = Vector2(2000,430)
	m.started = true
	m.hp = 1
	m.invulnerable = 0
	m.storm_x = 2050
	m.step(Vector2.ZERO,false,0.1)
	expect(m.hp == 3 and m.p.x < 1700 and m.storm_x < m.p.x-250,"Storm failure resumes at shelter with safe rain margin")

func save_contract() -> void:
	var path := "user://swarm_verify_save.json"
	expect(Save.write_stage(2,path) and Save.read_stage(path) == 2,"Chapter save round-trips")
	expect(not Save.write_stage(9,path) and Save.read_stage(path) == 2,"Invalid chapter cannot overwrite valid save")
	for content in ["broken",'{"version":1,"stage":-1}','{"version":1,"stage":1.5}','{"version":1,"stage":3}','{"version":2,"stage":1}','{"version":1,"stage":"1"}',"[]"]:
		var f := FileAccess.open(path,FileAccess.WRITE)
		f.store_string(content)
		f.close()
		expect(Save.read_stage(path) == -1,"Malformed save rejected: " + content)
	DirAccess.remove_absolute(path)

func run() -> void:
	full_route()
	rules_and_recovery()
	save_contract()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SWARM FLIGHT VERIFIED: %d checks" % checks)
	quit(0 if failures.is_empty() else 1)
