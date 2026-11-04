extends SceneTree
## Real disk migration/failure fixtures, not player-experience evidence.
const Model = preload("res://nectar_harvest_model.gd")
const LegacyV4 = preload("res://nectar_legacy_model_v4.gd")
const LegacyV3 = preload("res://nectar_legacy_model_v3.gd")
const Legacy = preload("res://nectar_legacy_model_v2.gd")
const Save = preload("res://save_data.gd")
const Migration = preload("res://nectar_save_migration.gd")
var checks := 0
var failures := 0
var directory := "user://nectar-migration-%d" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func write_bytes(path: String,bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func v1_fixture() -> Dictionary:
	var m = Legacy.new()
	m.coins = 100
	m.owned.assign(["gather1","meadow","shortcut","market"])
	m.cargo = {"blue":7,"rose":0}
	m.flowers[0].stock = 5
	m.flowers[0].progress = 0.4
	var data: Dictionary = m.to_payload()
	data.version = 1
	data.erase("legacy_owned")
	return data

func fixture_bytes(data: Dictionary) -> PackedByteArray:
	# Deliberate whitespace must survive in the rollback file exactly.
	return ("\n"+JSON.stringify(data,"  ",false,true)+"\n").to_utf8_buffer()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory+"/progress.json"
	var absent := Migration.load_progress(path)
	check(not absent.ok and not absent.existed and not absent.blocked and absent.payload.is_empty(),"missing file is a normal new game")
	var old := v1_fixture()
	var original := fixture_bytes(old)
	write_bytes(path,original)
	var v1 = Model.new()
	check(v1.restore_v1_payload(old),"frozen v1 allows early region and pre-sale market")
	check(not Model.new().restore_payload(old),"v4 transaction validator refuses raw v1")
	var migrated := Migration.load_progress(path)
	check(migrated.ok and migrated.existed and migrated.migrated and not migrated.blocked,"valid v1 migrates on disk")
	check(FileAccess.get_file_as_bytes(path+".v1.bak") == original,"backup retains original whitespace and every byte")
	check(migrated.payload.version == 5 and migrated.payload.legacy_owned == old.owned,"v4 retains historical ownership explicitly")
	for key in old.keys():
		if key in ["version","energy","p","v","charge","charging","burst_left","coins","cargo","flowers","sold_total","rose_sold"]: continue
		check(JSON.stringify(migrated.payload[key],"",true,true) == JSON.stringify(old[key],"",true,true),"migration preserves old field: "+key)
	var live = Model.new()
	check(live.restore_payload(migrated.payload),"migrated model restores")
	check(live.events.is_empty() and live.flowers[0].stock == 1 and is_equal_approx(live.flowers[0].progress,0.4/3.0) and live.cargo.blue == 3 and live.coins == 34,"migration emits no sale, refill or reward")
	var candidate = Model.new()
	check(candidate.restore_payload(live.to_payload()),"old early unlocks survive pre-sale candidate validation")
	check(candidate.sell() == 3 and candidate.coins == 37,"old pre-sale market keeps its bonus in later sale")
	check(Save.write_payload(candidate.to_payload(),path,Model.new()),"later sale persists with historical authorization")
	var cold := Migration.load_progress(path)
	check(cold.ok and not cold.migrated and cold.payload.legacy_owned == old.owned,"cold v4 load does not remigrate or remove inheritance")
	check(candidate.restore_payload(cold.payload),"migrated state reloads before new material purchase")
	candidate.materials.fiber = 3 # Isolated post-migration transaction fixture.
	check(candidate.buy("reach"),"migrated ownership supports subsequent new-rule purchase")
	check(Save.write_payload(candidate.to_payload(),path,Model.new()),"subsequent purchase writes successfully")
	var last := Migration.load_progress(path)
	check(last.ok and "reach" in last.payload.owned and "reach" not in last.payload.legacy_owned,"new purchase never enters historical exceptions")
	check(FileAccess.get_file_as_bytes(path+".v1.bak") == original,"later trades and cold reads never alter rollback backup")
	var field_old := old.duplicate(true)
	field_old.phase = "field"
	field_old.p = [620.0,520.0]
	field_old.v = [10.0,-20.0]
	field_old.energy = 77.0
	field_old.charge = 0.2
	field_old.charging = true
	field_old.trip_index = 2
	var field_path := directory+"/field.json"
	write_bytes(field_path,fixture_bytes(field_old))
	var field_result := Migration.load_progress(field_path)
	check(field_result.ok and field_result.payload.phase == "field","in-flight v1 migrates without returning the player home")
	for key in ["p","v","face","charge","charging","burst_left","trip_index"]:
		check(JSON.stringify(field_result.payload[key],"",true,true) == JSON.stringify(field_old[key],"",true,true),"in-flight migration retains "+key)

	var completed = Legacy.new()
	completed.coins = 500
	completed.owned.assign(Legacy.UPGRADE_IDS)
	completed.energy = completed.max_energy()
	completed.visited_meadow = true
	completed.sold_total = 22
	completed.rose_sold = 18
	completed.completed = true
	var done_old := completed.to_payload()
	done_old.version = 1
	done_old.erase("legacy_owned")
	var done_path := directory+"/completed.json"
	write_bytes(done_path,fixture_bytes(done_old))
	var done := Migration.load_progress(done_path)
	check(done.ok and done.payload.completed and done.payload.owned.size() == 12,"completed v1 remains completed with all effects")
	var done_model = Model.new()
	check(done_model.restore_payload(done.payload) and done_model.events.is_empty(),"completed migration does not replay completion events")

	# A genuine 0.20 v2 save has independent bag ranks and its original schema.
	var old_v2 = Legacy.new()
	old_v2.coins = 1000
	for id in ["gather1","bag1","bag2","meadow"]: old_v2.buy(id)
	old_v2.phase = "field"
	old_v2.p = Vector2(1790,400)
	old_v2.trip_index = 4
	old_v2.visited_meadow = true
	old_v2.energy = 60.0
	old_v2.flowers[0].stock = 2
	old_v2.cargo = {"blue":8,"rose":4}
	var old_v2_data: Dictionary = old_v2.to_payload()
	check(Legacy.new().restore_payload(old_v2_data),"v2 fixture passes its frozen schema before migration")
	var old_v2_bytes := fixture_bytes(old_v2_data)
	var v2_path := directory+"/v2.json"
	write_bytes(v2_path,old_v2_bytes)
	var v2_result := Migration.load_progress(v2_path)
	check(v2_result.ok and v2_result.migrated and v2_result.payload.version == 5,"valid v2 migrates to v4 on disk")
	check(FileAccess.get_file_as_bytes(v2_path+".v2.bak") == old_v2_bytes and not FileAccess.file_exists(v2_path+".v1.bak"),"v2 backup records actual original version and exact bytes")
	check(v2_result.payload.area == "meadow" and v2_result.payload.p == [1840.0,400.0],"old inter-region gap maps into meadow's valid entrance bounds")
	for key in ["owned","legacy_owned","trip_index"]:
		check(v2_result.payload[key] == old_v2_data[key],"v2 migration retains economic/expedition field: "+key)
	check(v2_result.payload.creatures.all(func(c): return c.state == "gone"),"migration never spawns enemies onto an existing expedition")
	var v2_live = Model.new()
	check(v2_live.restore_payload(v2_result.payload),"v2 conversion is a legal strict-v4 state")
	v2_live.p = Model.MEADOW_ENTRY
	check(v2_live.transition_to("hub") and v2_live.p == Model.HOME,"migrated field can return to new life scene")
	v2_live.p = Model.HUB_DEPART
	check(v2_live.transition_to("pond") and v2_live.creatures[0].state == "patrol" and v2_live.trip_index == 5,"only the next expedition starts new enemy population")
	var v2_conflict_path := directory+"/v2-conflict.json"
	write_bytes(v2_conflict_path,old_v2_bytes)
	write_bytes(v2_conflict_path+".v2.bak","keep v2 backup".to_utf8_buffer())
	check(Migration.load_progress(v2_conflict_path).blocked and FileAccess.get_file_as_bytes(v2_conflict_path) == old_v2_bytes,"v2 backup conflict preserves original")
	var v2_write_path := directory+"/v2-write-fail.json"
	write_bytes(v2_write_path,old_v2_bytes)
	DirAccess.make_dir_absolute(v2_write_path+".tmp")
	check(Migration.load_progress(v2_write_path).blocked and FileAccess.get_file_as_bytes(v2_write_path) == old_v2_bytes and FileAccess.get_file_as_bytes(v2_write_path+".v2.bak") == old_v2_bytes,"v2 write failure retains source and verified rollback")
	DirAccess.remove_absolute(v2_write_path+".tmp")
	var v2_bad := old_v2_data.duplicate(true)
	v2_bad.owned = ["gather1","meadow"]
	var v2_bad_path := directory+"/v2-invalid.json"
	write_bytes(v2_bad_path,fixture_bytes(v2_bad))
	check(Migration.load_progress(v2_bad_path).blocked and not FileAccess.file_exists(v2_bad_path+".v2.bak"),"v2 invalid early region cannot be laundered by migration")

	var malformed := v1_fixture()
	malformed.owned = ["bag1","bag2"]
	var invalid_path := directory+"/invalid-old.json"
	var invalid_bytes := fixture_bytes(malformed)
	write_bytes(invalid_path,invalid_bytes)
	var invalid := Migration.load_progress(invalid_path)
	check(invalid.blocked and not invalid.ok and not invalid.migrated,"new-legal but v1-illegal alternating chain is not laundered through migration")
	check(FileAccess.get_file_as_bytes(invalid_path) == invalid_bytes and not FileAccess.file_exists(invalid_path+".v1.bak"),"invalid old bytes remain untouched without a misleading backup")
	var corrupt_path := directory+"/corrupt.json"
	write_bytes(corrupt_path,"{ broken".to_utf8_buffer())
	var corrupt := Migration.load_progress(corrupt_path)
	check(corrupt.blocked and corrupt.payload.is_empty() and FileAccess.get_file_as_string(corrupt_path) == "{ broken","corrupt file is never overwritten")
	var oversized_path := directory+"/oversized.json"
	write_bytes(oversized_path,"x".repeat(Save.MAX_BYTES+1).to_utf8_buffer())
	check(Migration.load_progress(oversized_path).blocked,"oversized old input is bounded")

	var conflict_path := directory+"/conflict.json"
	write_bytes(conflict_path,original)
	write_bytes(conflict_path+".v1.bak","keep earlier backup".to_utf8_buffer())
	check(Migration.load_progress(conflict_path).blocked,"conflicting backup blocks migration")
	check(FileAccess.get_file_as_bytes(conflict_path) == original and FileAccess.get_file_as_string(conflict_path+".v1.bak") == "keep earlier backup","both source and conflicting backup preserved")
	var backup_fail_path := directory+"/backup-fail.json"
	write_bytes(backup_fail_path,original)
	DirAccess.make_dir_absolute(backup_fail_path+".v1.bak.tmp")
	check(Migration.load_progress(backup_fail_path).blocked,"unwritable backup destination blocks migration")
	check(FileAccess.get_file_as_bytes(backup_fail_path) == original,"backup failure retains source bytes")
	var write_fail_path := directory+"/write-fail.json"
	write_bytes(write_fail_path,original)
	DirAccess.make_dir_absolute(write_fail_path+".tmp")
	var failed := Migration.load_progress(write_fail_path)
	check(failed.blocked and not failed.ok and not failed.migrated and failed.payload.is_empty(),"v4 write failure does not publish migrated state")
	check(FileAccess.get_file_as_bytes(write_fail_path) == original and FileAccess.get_file_as_bytes(write_fail_path+".v1.bak") == original,"write failure retains both original and exact backup")
	DirAccess.remove_absolute(write_fail_path+".tmp")
	var retry := Migration.load_progress(write_fail_path)
	check(retry.ok and retry.migrated,"retry reuses identical verified backup safely")

	var state = Model.new()
	state.coins = 1000
	state.materials.fiber = 3
	state.buy("bag1")
	state.buy("bag2")
	var good := state.to_payload()
	check(Model.new().restore_payload(good),"new capacity-only sequence is legal in v4")
	for kind in ["unknown","duplicate","not-owned","broken-v1-chain"]:
		var bad := good.duplicate(true)
		if kind == "unknown": bad.legacy_owned = ["invented"]
		elif kind == "duplicate": bad.legacy_owned = ["bag1","bag1"]
		elif kind == "not-owned": bad.legacy_owned = ["gather1"]
		else: bad.legacy_owned = ["bag1","bag2"]
		check(not Model.new().restore_payload(bad),"invalid legacy list rejected: "+kind)
	var missing := good.duplicate(true)
	missing.erase("legacy_owned")
	check(not Model.new().restore_payload(missing),"v4 cannot omit migration metadata")
	var raw_path := directory+"/raw-old.json"
	check(not Save.write_payload(old,raw_path,Model.new()) and not FileAccess.file_exists(raw_path),"generic transaction writer cannot bypass migration backup")

	v4_migration_matrix()
	v3_migration_matrix()
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	for dirname in DirAccess.get_directories_at(directory): DirAccess.remove_absolute(directory+"/"+dirname)
	DirAccess.remove_absolute(directory)
	print("NECTAR MIGRATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func v3_migration_matrix() -> void:
	# All legal mixed cargo quantities for every capacity and market state.
	# Value is conserved after per-type ceil(/3); the rounding uplift is explicit.
	for tier in 3:
		for market in [false,true]:
			var old = LegacyV3.new()
			old.owned.assign(["gather1","gather2","reach","meadow"])
			if tier > 0: old.owned.append("bag1")
			if tier > 1: old.owned.append("bag2")
			if market: old.owned.append("market")
			old.visited_meadow = true
			old.sold_total = 19
			old.rose_sold = 1
			old.coins = 100
			old.p = Vector2(1800,600) # Legal v3 courtyard outside the new courtyard.
			for blue in old.capacity()+1:
				for rose in old.capacity()-blue+1:
					old.cargo = {"blue":blue,"rose":rose}
					var data: Dictionary = old.to_payload()
					var live = Model.new()
					var ok: bool = live.restore_legacy_payload(data,3)
					check(ok,"v3 mixed cargo migrates tier=%d market=%s blue=%d rose=%d" % [tier,market,blue,rose])
					if not ok: continue
					var rounded := {"blue":ceili(blue/3.0),"rose":ceili(rose/3.0)}
					var base: int = rounded.blue+3*rounded.rose
					var expected := base+int(floor(base*.25)) if market else base
					check(live.cargo_total() <= live.capacity() and (blue == 0 or live.cargo.blue > 0) and (rose == 0 or live.cargo.rose > 0),"mixed cargo keeps both original types within new capacity")
					check(live.cargo_value()+live.coins == expected+34,"mixed cargo sale value plus migration change is conserved")
					check(live.p == Model.HUB_DEPART and live.camera_x == 0 and live.sold_total == 7 and live.rose_sold == 1 and live.events.is_empty(),"migration relocates old hub without false sales or rewards")
	var old = LegacyV3.new()
	old.p = LegacyV3.HUB_DEPART
	old.transition_to("pond")
	old.p = old.creatures[0].anchor
	old.creatures[0].state = "chase"
	old.creatures[0].timer = 1.0
	old.hurt_left = 1.1
	old.flowers[0].stock = 0
	old.flowers[1].progress = 1.4
	old.cargo.blue = 17
	var bytes := fixture_bytes(old.to_payload())
	var path := directory+"/v3.json"
	write_bytes(path,bytes)
	var migrated := Migration.load_progress(path)
	check(migrated.ok and migrated.migrated and FileAccess.get_file_as_bytes(path+".v3.bak") == bytes,"v3 disk migration keeps exact original bytes")
	var live = Model.new()
	check(live.restore_payload(migrated.payload) and live.creatures[0].state == "patrol" and live.hurt_left == 0,"old chase and invulnerability normalize to harmless patrol")
	check(live.flowers[0].stock == 0 and live.flowers[1].stock == 1 and is_equal_approx(live.flowers[1].progress,1.4/3.0),"old empty flower remains empty and partial work scales without a reward")
	var energy: float = live.energy
	live.step(0.1,Vector2.ZERO,false,false)
	check(is_equal_approx(live.energy,energy-0.06) and live.hurt_left == 0,"migrated hostile contact only pays ordinary endurance drain")
	check(Migration.load_progress(path).ok and not Migration.load_progress(path).migrated,"cold v4 read never rescales again")
	var bad: Dictionary = old.to_payload()
	bad.creatures[0].timer = 999
	var bad_path := directory+"/bad-v3.json"
	var bad_bytes := fixture_bytes(bad)
	write_bytes(bad_path,bad_bytes)
	check(Migration.load_progress(bad_path).blocked and FileAccess.get_file_as_bytes(bad_path) == bad_bytes and not FileAccess.file_exists(bad_path+".v3.bak"),"invalid frozen v3 cannot be normalized into a valid v4")

func v4_migration_matrix() -> void:
	for area in ["hub","pond","meadow"]:
		for rank in [0,1,2]:
			var old = LegacyV4.new()
			old.coins = 800
			for id in ["gather1","bag1","gather2","meadow"]: old.buy(id)
			if rank >= 1: old.buy("wings1")
			if rank == 2: old.buy("wings2")
			if area != "hub":
				old.transition_to(area)
				old.energy = old.max_energy()*.4
				old.flowers[0].stock = 0
			old.cargo.blue = 2
			var bytes := fixture_bytes(old.to_payload())
			var path := directory+"/v4-%s-%d.json" % [area,rank]
			write_bytes(path,bytes)
			var result := Migration.load_progress(path)
			check(result.ok and result.migrated and result.payload.version == 5,"v4 disk migration: %s %d" % [area,rank])
			check(FileAccess.get_file_as_bytes(path+".v4.bak") == bytes,"v4 exact original retained")
			var live = Model.new()
			check(live.restore_payload(result.payload) and live.cargo == old.cargo and live.coins == old.coins and live.owned == old.owned,"v4 economy and ownership retained")
			check(is_equal_approx(live.energy/live.max_energy(),old.energy/old.max_energy()),"v4 remaining endurance ratio retained")
			check(live.materials == {"fiber":0,"resin":0} and live.drops.is_empty(),"migration cannot invent materials")
			check(not Migration.load_progress(path).migrated,"cold v5 does not repeat migration")
