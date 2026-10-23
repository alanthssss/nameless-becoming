extends SceneTree
## Isolated serialization fixtures, not player paths. Never opens a real save path.
const Model = preload("res://game_model.gd")
const Save = preload("res://save_data.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fixture(stage_index: int, saved_checkpoint := -1) -> Dictionary:
	var m = Model.new()
	m.load_stage(stage_index)
	m.checkpoint_index = saved_checkpoint
	for pod in m.pods:
		pod.open = pod.section <= saved_checkpoint
		if pod.open: m.bees += int(pod.count)
	for wall in m.walls: wall.broken = wall.kind == "curtain"
	for i in m.rings.size(): m.rings[i].active = i%2 == 0
	for i in m.shields.size(): m.shields[i].collected = i%2 == 0
	for sprayer in m.sprayers:
		sprayer.rewarded = true
		sprayer.stun_left = 2.0
		sprayer.timer = 1.25
	if stage_index == 4 and saved_checkpoint >= 0: m.sample_approach = "bottom"
	m.p = m.shelters[saved_checkpoint].pos if saved_checkpoint >= 0 else Vector2(180,420)
	m.save_checkpoint()
	return m.save_payload()

func award_sum(data: Dictionary) -> int:
	var total := 0
	for count in data.garden_awards: total += int(count)
	return total+int(data.get("legacy_dew_awards",0))

func previous(data: Dictionary) -> Dictionary:
	var old: Dictionary = data.duplicate(true)
	old.content_revision = 8
	old.erase("legacy_dew_awards")
	return old

func reject_without_mutation(data: Dictionary, message: String) -> void:
	var m = Model.new()
	m.load_stage(7)
	var before: Dictionary = m.save_payload()
	expect(not m.restore_payload(data),message)
	expect(m.save_payload() == before,message+" leaves the active run unchanged")

func current_chapter_migration() -> void:
	var layout: Dictionary = Model.Data.build(4)
	for saved_checkpoint in range(-1,layout.sections.size()):
		for retired in [false,true]:
			for surviving in [false,true]:
				var old := previous(fixture(4,saved_checkpoint))
				old.dew = [retired,surviving]
				old.garden_awards[4] = int(retired)+int(surviving)
				var original: Dictionary = old.duplicate(true)
				var m = Model.new()
				expect(m.restore_payload(old),"Revision 8 current 05 accepts both exact pickup flags")
				expect(old == original,"Migration does not mutate the caller's old payload")
				expect(m.dew.size() == 1 and m.dew[0].collected == surviving,"Old second dew remains the only live pickup with its original state")
				expect(m.legacy_dew_awards == int(retired) and m.garden_awards[4] == int(surviving),"Only old first dew becomes historical reward")
				expect(m.garden_total() == award_sum(old),"Current-chapter migration preserves total earned rewards")
				var saved: Dictionary = m.save_payload()
				expect(saved.content_revision == 9 and saved.checkpoint_index == saved_checkpoint and saved.stage == 4,"Write advances revision while preserving chapter/checkpoint")
				for field in ["pods","walls","rings","shields","sprayers","bees","sample_approach"]:
					expect(saved[field] == old[field],"Unchanged current 05 state survives: "+field)
				m.restore_checkpoint()
				expect(m.garden_total() == award_sum(old) and m.dew[0].collected == surviving,"Checkpoint return cannot erase or duplicate historical dew")
				var again = Model.new()
				expect(again.restore_payload(saved) and again.save_payload() == saved,"Revision 9 round trip is stable")
				expect(again.restore_payload(saved) and again.garden_total() == award_sum(old),"Repeated restore never accumulates retired rewards")
				again.load_stage(5)
				expect(again.garden_total() == award_sum(old),"Advancing to 06 keeps historical and prior live awards")
				again.reset_journey()
				expect(again.garden_total() == 0 and again.legacy_dew_awards == 0,"A new journey clears historical awards")

func past_chapter_migration() -> void:
	for stage_index in [5,12,15]:
		var layout: Dictionary = Model.Data.build(stage_index)
		for old_count in [0,1,2]:
			var old := previous(fixture(stage_index,layout.sections.size()-1))
			old.garden_awards[4] = old_count
			old.arrived = true
			old.completed = stage_index == Model.STAGE_COUNT-1
			var m = Model.new()
			expect(m.restore_payload(old),"Past-05 revision 8 total remains readable")
			expect(m.legacy_dew_awards == old_count and m.garden_awards[4] == 0,"Unknown historical pickup identity is not guessed")
			expect(m.garden_total() == old_count and m.stage_dew_total() == Model.Data.dew_count(stage_index),"Historical rewards do not create new pickups")
			var saved: Dictionary = m.save_payload()
			expect(saved.arrived and saved.completed == old.completed and saved.stage == stage_index,"Arrival and completed journey survive old-total migration")
			for field in ["pods","walls","rings","dew","shields","sprayers","bees"]:
				expect(saved[field] == old[field],"Later chapter retains state: "+field)
			var again = Model.new()
			expect(again.restore_payload(saved) and again.save_payload() == saved,"Past-chapter migration is idempotent after write")
	for stage_index in [0,3]:
		var old := previous(fixture(stage_index))
		var m = Model.new()
		expect(m.restore_payload(old) and m.legacy_dew_awards == 0,"Before 05 old saves gain no historical rewards")

func invalid_history() -> void:
	for amount in [-1,0.5,3,"1",true,NAN,INF]:
		var bad := fixture(5)
		bad.legacy_dew_awards = amount
		reject_without_mutation(bad,"Invalid historical reward is rejected: "+str(amount))
	var early := fixture(3)
	early.legacy_dew_awards = 1
	reject_without_mutation(early,"Cannot grant retired 05 dew before reaching 05")
	var current := fixture(4)
	current.legacy_dew_awards = 2
	reject_without_mutation(current,"Current 05 can retire only one exact pickup")
	var duplicate := fixture(5)
	duplicate.legacy_dew_awards = 2
	duplicate.garden_awards[4] = 1
	reject_without_mutation(duplicate,"Historical and live 05 rewards cannot exceed the old two-pickup maximum")
	var injected := previous(fixture(5))
	injected.legacy_dew_awards = 1
	reject_without_mutation(injected,"Revision 8 cannot inject a separate historical bonus")
	var bad_total := previous(fixture(5))
	bad_total.garden_awards[4] = 3
	reject_without_mutation(bad_total,"Old past-05 total above two is rejected")
	var bad_flags := previous(fixture(4))
	reject_without_mutation(bad_flags,"Revision 8 current 05 requires both original flags")
	bad_flags.dew = [true,false]
	bad_flags.garden_awards[4] = 0
	reject_without_mutation(bad_flags,"Old count must match both old flags before conversion")
	var new_flags := fixture(4)
	new_flags.dew = [false,false]
	reject_without_mutation(new_flags,"Revision 9 rejects the retired pickup slot")
	var future := fixture(0)
	future.content_revision = 10
	reject_without_mutation(future,"Unknown future content revision is rejected")

func isolated_file_round_trip() -> void:
	var old := previous(fixture(4,0))
	old.dew = [true,false]
	old.garden_awards[4] = 1
	var path := "/tmp/swarm-flight-save-supply-%d-%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	if FileAccess.file_exists(path):
		expect(false,"Unique isolated save fixture path already exists")
		return
	expect(Save.write_payload(old,path),"Old revision fixture writes only to an isolated explicit path")
	var read := Save.read_payload(path)
	var m = Model.new()
	expect(not read.is_empty() and m.restore_payload(read),"Save reader accepts old revision without touching the real save")
	expect(Save.write_payload(m.save_payload(),path),"Migrated fixture writes revision 9")
	var again = Model.new()
	expect(again.restore_payload(Save.read_payload(path)) and again.garden_total() == 1 and again.dew.size() == 1,"File reread retains one historical reward and one uncollected live pickup")
	DirAccess.remove_absolute(path)

func supplied_legacy_copy() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--legacy-save-copy="): continue
		var path: String = argument.trim_prefix("--legacy-save-copy=")
		# The optional real-world evidence must be an already-copied review file.
		# This verifier never opens the player's application-data save directly.
		if not path.contains("/outputs/swarm-flight/") or not path.contains("/review/"):
			expect(false,"Legacy fixture argument must point to an isolated review copy")
			continue
		var before := FileAccess.get_sha256(path)
		var old: Dictionary = Save.read_payload(path)
		expect(not before.is_empty() and not old.is_empty(),"Real legacy review copy can be read without writing")
		if old.is_empty(): continue
		expect(old.content_revision == 8,"Real review copy retains its original revision 8 identity")
		var m = Model.new()
		expect(m.restore_payload(old),"Real copied progress restores under revision 9")
		expect(m.stage == int(old.stage) and m.checkpoint_index == int(old.checkpoint_index) and m.completed == old.completed,"Real chapter, safe checkpoint and ending are preserved")
		expect(m.garden_total() == award_sum(old),"Real historical reward total is preserved exactly")
		var saved: Dictionary = m.save_payload()
		for field in ["pods","walls","rings","shields","sprayers","bees","arrived"]:
			expect(saved[field] == old.get(field,old.completed if field == "arrived" else null),"Real copied state is retained: "+field)
		var again = Model.new()
		expect(again.restore_payload(saved) and again.save_payload() == saved,"Real copied progress is stable after migration and reread")
		expect(FileAccess.get_sha256(path) == before,"Real review copy remains byte-for-byte untouched")

func run() -> void:
	expect(Model.Data.dew_count(4) == 1 and Model.new().journey_dew_total() == 14,"Fixtures target revision 9's fourteen live dew and one in 05")
	current_chapter_migration()
	past_chapter_migration()
	invalid_history()
	isolated_file_round_trip()
	supplied_legacy_copy()
	for failure in failures: push_error(failure)
	print("SAVE SUPPLY VERIFY: %d checks, failures %d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
