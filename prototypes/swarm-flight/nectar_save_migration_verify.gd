extends SceneTree
## Real disk migration/failure fixtures, not player-experience evidence.
const Model = preload("res://nectar_harvest_model.gd")
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
	var m = Model.new()
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
	check(not Model.new().restore_payload(old),"v2 transaction validator refuses raw v1")
	var migrated := Migration.load_progress(path)
	check(migrated.ok and migrated.existed and migrated.migrated and not migrated.blocked,"valid v1 migrates on disk")
	check(FileAccess.get_file_as_bytes(path+".v1.bak") == original,"backup retains original whitespace and every byte")
	check(migrated.payload.version == 2 and migrated.payload.legacy_owned == old.owned,"v2 retains historical ownership explicitly")
	for key in old.keys():
		if key == "version": continue
		check(JSON.stringify(migrated.payload[key],"",true,true) == JSON.stringify(old[key],"",true,true),"migration preserves old field: "+key)
	var live = Model.new()
	check(live.restore_payload(migrated.payload),"migrated model restores")
	check(live.events.is_empty() and live.flowers[0].stock == 5 and live.flowers[0].progress == 0.4 and live.cargo.blue == 7,"migration emits no sale, refill or reward")
	var candidate = Model.new()
	check(candidate.restore_payload(live.to_payload()),"old early unlocks survive pre-sale candidate validation")
	check(candidate.sell() == 8 and candidate.coins == 108,"old pre-sale market keeps its bonus in later sale")
	check(Save.write_payload(candidate.to_payload(),path,Model.new()),"later sale persists with historical authorization")
	var cold := Migration.load_progress(path)
	check(cold.ok and not cold.migrated and cold.payload.legacy_owned == old.owned,"cold v2 load does not remigrate or remove inheritance")
	check(candidate.restore_payload(cold.payload) and candidate.buy("reach"),"migrated ownership supports subsequent new-rule purchase")
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
	for key in ["p","v","face","energy","charge","charging","burst_left","trip_index","flowers"]:
		check(JSON.stringify(field_result.payload[key],"",true,true) == JSON.stringify(field_old[key],"",true,true),"in-flight migration retains "+key)

	var completed = Model.new()
	completed.coins = 500
	completed.owned.assign(Model.UPGRADE_IDS)
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
	check(failed.blocked and not failed.ok and not failed.migrated and failed.payload.is_empty(),"v2 write failure does not publish migrated state")
	check(FileAccess.get_file_as_bytes(write_fail_path) == original and FileAccess.get_file_as_bytes(write_fail_path+".v1.bak") == original,"write failure retains both original and exact backup")
	DirAccess.remove_absolute(write_fail_path+".tmp")
	var retry := Migration.load_progress(write_fail_path)
	check(retry.ok and retry.migrated,"retry reuses identical verified backup safely")

	var state = Model.new()
	state.coins = 1000
	state.buy("bag1")
	state.buy("bag2")
	var good := state.to_payload()
	check(Model.new().restore_payload(good),"new capacity-only sequence is legal in v2")
	for kind in ["unknown","duplicate","not-owned","broken-v1-chain"]:
		var bad := good.duplicate(true)
		if kind == "unknown": bad.legacy_owned = ["invented"]
		elif kind == "duplicate": bad.legacy_owned = ["bag1","bag1"]
		elif kind == "not-owned": bad.legacy_owned = ["gather1"]
		else: bad.legacy_owned = ["bag1","bag2"]
		check(not Model.new().restore_payload(bad),"invalid legacy list rejected: "+kind)
	var missing := good.duplicate(true)
	missing.erase("legacy_owned")
	check(not Model.new().restore_payload(missing),"v2 cannot omit migration metadata")
	var raw_path := directory+"/raw-old.json"
	check(not Save.write_payload(old,raw_path,Model.new()) and not FileAccess.file_exists(raw_path),"generic transaction writer cannot bypass migration backup")

	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+filename)
	for dirname in DirAccess.get_directories_at(directory): DirAccess.remove_absolute(directory+"/"+dirname)
	DirAccess.remove_absolute(directory)
	print("NECTAR MIGRATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
