extends "res://nectar_harvest_ui.gd"

const SaleFlight = preload("res://region_game/sale_flight.gd")
var sale_flight

func _ready() -> void:
	super._ready()
	sale_flight = SaleFlight.new()
	shop.add_child(sale_flight)
	sale_flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reword(self)
	energy_text.tooltip_text = "续航：庭院恢复，飞行、采蜜和振翅消耗"

func _reword(node: Node) -> void:
	if node is Label:
		node.text = node.text.replace("每花 1 份 · 生物不会攻击。","花心带蜜光时，每朵可采一份。").replace("每花 1 份 · 可收集树脂。","留意木头裂口里的金色树脂。")
		node.text = node.text.replace("振翅驱离小飞虫，拾取纤维。","朝种穗振翅（Q / 右键），飞近飘绒收纤维。")
		node.text = node.text.replace("从灯球返回","从入口木牌返回")
		node.text = node.text.replace("花蜜在野外 18 秒后恢复","花蜜采走后会慢慢补回，花朵继续自己的花期")
		node.text = node.text.replace("细雨增加消耗，叶棚下可避雨。","朝裂口振翅掀皮，贴近按住 E / 左键收树脂。")
		node.text = node.text.replace(" · F 使用近道","")
		node.text = node.text.replace("0.27.0","0.32.1" if OS.has_feature("pond_feedback") else "0.29.0").replace("10 个成长节点（共 13 级）","10 个成长节点（共 14 级）")
	for child in node.get_children(): _reword(child)

func _requirements(id: String) -> String:
	var m = driver.model
	var next: String = board.next_id(id)
	if next.is_empty(): return ""
	var lines: Array[String] = []
	var needed: Array = m.upgrade(next).requires.duplicate()
	if next == "reserve": needed.append("twin")
	for prerequisite in needed:
		var name: String = m.upgrade(prerequisite).name
		lines.append(("✓ " if prerequisite in m.owned else "需 ") + name)
	match next:
		"wings1": lines.append("轻巧采蜜、舒展蜜囊任选一项")
		"meadow": lines.append("采蜜、蜜囊、双翼、触角、双簇合计 %d / 3 次；同格两级计两次。" % mini(3,m.growth_count()))
		"market","reserve":
			var goal := 6 if next == "reserve" else 1
			lines.append(("✓ " if m.visited_meadow else "需 ") + "探索紫花地")
			lines.append("已交售紫蜜 %d / %d 份" % [mini(m.rose_sold,goal),goal])
	return "\n".join(lines)

func _detail() -> void:
	super._detail()
	if is_instance_valid(board) and board.model!=null and board.selected=="beat":
		detail_effect.text = "厚壳 / 厚树皮 · 2 次 → 1 次" if board.rank_of("beat")==0 else "厚壳与厚树皮只需一次振翅"
		detail_effect.tooltip_text = "近处的薄壳一次可开；岔路和远端较牢。树脂露出后仍需贴近收取。"

	if is_instance_valid(board) and board.model!=null and board.selected=="supply" and board.rank_of("supply")==2:
		detail_effect.text = "36 处花源 · 6 处材料\n补蜜 10 秒"
		detail_effect.tooltip_text = "每朵花都有自己的花期"

	if not is_instance_valid(board) or board.model == null: return
	var rank_id: String = board.next_id(board.selected)
	if rank_id.is_empty():
		detail_hint.hide()
		return
	var entry: Dictionary = driver.model.upgrade(rank_id)
	var lines: Array[String] = []
	detail_title.text = entry.name
	var condition := _requirements(board.selected)
	if not detail_requirements.text.begins_with("还需"): detail_requirements.hide()
	if not condition.is_empty():
		lines.append(condition)
	if entry.get("fiber",0)>driver.model.materials.fiber:
		lines.append("纤维 · 池岸振开种穗，飞近接绒")
	if entry.get("resin",0)>driver.model.materials.resin:
		lines.append("树脂 · 紫花地振开树皮，贴近收取")
	detail_hint.text = "\n".join(lines)
	detail_hint.visible = not lines.is_empty()

func refresh() -> void:
	super.refresh()
	if driver == null or not is_instance_valid(board): return
	pond_info.text = "蓝花蜜 · 每份 1 金币\n振松种穗，飞近收纤维 · 可织轻盈双翼。"
	meadow_info.text = "紫花蜜 · 每份 3 金币\n"+("振开树皮，贴近收树脂 · 可修远行双翼。" if "meadow" in driver.model.owned else "在成长手册中开放这条花路。")
	var field = driver.model.field
	if field != null:
		# Action prompts belong to the nearby flower, seed head, seam or sign.
		# Reserve the lower HUD for a whole-trip constraint.
		help_text.text = ""
		if driver.model.energy < driver.model.max_energy()*.25: help_text.text = "体力偏低 · 沿花路返回"
		elif driver.model.cargo_total()>=driver.model.capacity(): help_text.text = "蜜囊已满 · 仍可取材"
		help_text.visible = not help_text.text.is_empty()

func show_mode(mode: String) -> void:
	if is_instance_valid(sale_flight) and mode != "shop":
		sale_flight.stop()
	super.show_mode(mode)

func create_growth_board():
	return preload("res://region_game/growth_board.gd").new()

func _build_tree() -> void:
	super._build_tree()
	anchored(board,Rect2(0,0,.50,1),Rect2(76,165,-103,-291))
	tree_footer.text = "实线 · 必需     虚线 · 任选或累计\n方向键 / 十字键 选格     Enter / A 成长     Esc / B 返回"
	tree_footer.tooltip_text = "点选蜂房查看详情 · Tab 逐格翻阅"
	anchored(tree_footer,Rect2(0,1,.5,0),Rect2(63,-117,-83,48))

func _place_detail() -> void:
	if not is_instance_valid(detail_card) or not tree.visible: return
	var left := size.x*.54
	detail_card.position = Vector2(left,183)
	detail_card.size = Vector2(size.x*.915-left,detail_card.get_combined_minimum_size().y)

func _input(event: InputEvent) -> void:
	if driver == null or driver.mode != "tree" or not event is InputEventJoypadButton: return
	var directions := {JOY_BUTTON_DPAD_UP:KEY_UP,JOY_BUTTON_DPAD_DOWN:KEY_DOWN,JOY_BUTTON_DPAD_LEFT:KEY_LEFT,JOY_BUTTON_DPAD_RIGHT:KEY_RIGHT}
	if event.button_index not in directions and event.button_index not in [JOY_BUTTON_A,JOY_BUTTON_B]: return
	get_viewport().set_input_as_handled()
	if not event.pressed: return
	if event.button_index in directions:
		board.navigate(directions[event.button_index])
	elif event.button_index == JOY_BUTTON_A:
		_buy_selected()
	else:
		driver.close_tree()
