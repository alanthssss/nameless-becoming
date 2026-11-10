extends SceneTree
const Field = preload("res://region_game/field.gd")
const Layout = preload("res://region_greybox/layout.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func _initialize() -> void:
	for region in ["pond","violet"]:
		for seed_value in range(1,9):
			for rank in 3:
				var field = Field.new()
				field.configure(region,1,seed_value)
				field.set_supply_rank(rank)
				check(field.flowers.filter(func(f): return f.enabled).size() == [16,24,36][rank],"flower abundance "+region)
				check(field.materials.filter(func(m): return m.enabled).size() == [3,4,6][rank],"material abundance "+region)
				for i in field.flowers.size():
					var flower: Dictionary = field.flowers[i]
					check(Layout.walkable(field.layout,flower.p,55),"flower stays on visible ground")
					for j in i: check(flower.p.distance_to(field.flowers[j].p) >= 80,"flower breathing room")
				for item in field.materials: check(Layout.walkable(field.layout,item.p,35),"material reachable from ground")
				var copy = Field.new()
				check(copy.restore(field.snapshot()),"population cold restore")
				check(copy.supply_rank == rank and copy.flowers == field.flowers,"no hidden population reset")
				var bad: Dictionary = field.snapshot()
				bad.flowers[2].enabled = not bad.flowers[2].enabled
				check(not copy.restore(bad),"reject illegal enabled slot")
	for rank in 3:
		var f = Field.new()
		f.configure("pond",1,4)
		f.set_supply_rank(rank)
		f._enter_phase(f.flowers[0],"empty",false)
		var seconds: float = [20,14,10][rank]
		for i in int((seconds-.1)/.05): f._supply(.05)
		check(f.flowers[0].phase == "bud","flower still grows before deadline")
		for i in 4: f._supply(.05)
		check(f.flowers[0].phase == "ripe","upgraded flower regenerates on time")
		f._enter_phase(f.materials[0],"empty",true)
		seconds = [44,30.8,22][rank]
		for i in int((seconds-.1)/.05): f._supply(.05)
		check(f.materials[0].phase == "bud","material still grows before deadline")
		for i in 4: f._supply(.05)
		check(f.materials[0].phase == "ripe","upgraded material regenerates on time")
	print("Regional field: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
