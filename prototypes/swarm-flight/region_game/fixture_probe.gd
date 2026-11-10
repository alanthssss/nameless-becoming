extends SceneTree
## Explicit developer save fixture for reviewing late growth and completion.
## Not player-earned evidence, never loaded during an ordinary launch.
const Model = preload("res://region_game/model.gd")
const Save = preload("res://save_data.gd")
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty(): quit(2); return
	var m = Model.new()
	m.coins = 1000
	m.materials = {"fiber":100,"resin":100}
	for id in ["gather1","bag1","wings1","gather2","reach","bag2","wings2","meadow"]:
		if not m.buy(id): quit(3); return
	m.visited_meadow = true
	m.rose_sold = 6
	m.sold_total = 6
	m.p = m.HUB_TREE
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var ok := Save.write_payload(m.to_payload(),output,Model.new())
	var label := FileAccess.open(output+".fixture.json",FileAccess.WRITE)
	label.store_string(JSON.stringify({"developer_fixture":true,"human_evidence":false,"purpose":"late growth UI purchases, two-region trips and completion; money/materials granted, prerequisite ranks purchased through validated model","profile":m.to_payload().profile},"\t"))
	print("Developer fixture valid: ",ok)
	quit(0 if ok else 1)
