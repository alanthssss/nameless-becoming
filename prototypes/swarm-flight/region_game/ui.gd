extends "res://nectar_harvest_ui.gd"

func _ready() -> void:
	super._ready()
	_reword(self)
	energy_text.tooltip_text = "续航：庭院恢复，飞行、采蜜和振翅消耗"

func _reword(node: Node) -> void:
	if node is Label:
		node.text = node.text.replace("振翅驱离小飞虫，拾取纤维。","振翅松动种穗，飞近拾取纤维。")
		node.text = node.text.replace("从灯球返回","从入口木牌返回")
		node.text = node.text.replace("花蜜在野外 18 秒后恢复","采空的花先收拢再长芽，初始20秒后盛开；花地成长可增加资源并加快再生")
		node.text = node.text.replace("细雨增加消耗，叶棚下可避雨。","花丛不断生长和凋谢；成熟材料可振翅取下。")
		node.text = node.text.replace(" · F 使用近道","")
		node.text = node.text.replace("0.27.0","0.29.0").replace("10 个成长节点（共 13 级）","10 个成长节点（共 14 级）")
	for child in node.get_children(): _reword(child)

func _requirements(id: String) -> String:
	if id == "supply": return "先学会轻巧采蜜；第二级需开放紫花地。\n下一趟两区的花源、材料增多，空位恢复加快。"
	if id == "reserve": return "已经探索紫花地\n已交售紫蜜  %d / 6 份\n\n学会双簇采蜜" % mini(6,driver.model.rose_sold)
	return super._requirements(id)

func refresh() -> void:
	super.refresh()
	if driver == null or not is_instance_valid(board): return
	pond_info.text = "蓝花蜜 · 每份 1 金币\n沿水岸深入，短岔与远端有纤维。"
	meadow_info.text = "紫花蜜 · 每份 3 金币\n"+("循花带深入，短岔与远端有树脂。" if "meadow" in driver.model.owned else "在成长手册中开放这条花路。")
	var field = driver.model.field
	if field != null:
		if field.at_entry(): help_text.text = "E  返回蜂巢庭院"
		elif field.last_action == "材料已松落，靠近拾取": help_text.text = "材料已松落 · 靠近拾取"
		elif driver.model.energy < driver.model.max_energy()*.25: help_text.text = "体力偏低 · 沿花路返回"
		help_text.visible = not help_text.text.is_empty()
