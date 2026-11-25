extends "res://nectar_harvest_ui.gd"

const SaleFlight = preload("res://region_game/sale_flight.gd")
var reading_book := false
var last_denied_msec := -1000
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
		node.text = node.text.replace("0.27.0","0.32.2" if OS.has_feature("pond_feedback") else "0.29.0").replace("10 个成长节点（共 13 级）","10 个成长节点（共 14 级）")
	for child in node.get_children(): _reword(child)

func _requirements(id: String) -> String:
	if id == "supply": return "先学会轻巧采蜜；第二级需开放紫花地。\n下一趟花源和材料增多，花朵补蜜更快。"
	if id == "reserve": return "已经探索紫花地\n已交售紫蜜  %d / 6 份\n\n学会双簇采蜜" % mini(6,driver.model.rose_sold)
	return super._requirements(id)

func _detail() -> void:
	super._detail()
	if is_instance_valid(board) and board.model!=null and board.selected=="beat":
		detail_effect.text = "厚壳 / 厚树皮 · 2 次 → 1 次" if board.rank_of("beat")==0 else "厚壳与厚树皮只需一次振翅"
		detail_effect.tooltip_text = "近处的薄壳一次可开；岔路和远端较牢。树脂露出后仍需贴近收取。"

	if is_instance_valid(board) and board.model!=null and board.selected=="supply" and board.rank_of("supply")==2:
		detail_effect.text = "36 处花源 · 6 处材料\n补蜜 10 秒"
		detail_effect.tooltip_text = "每朵花都有自己的花期"

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

func _buy_selected() -> void:
	if not buy_button.disabled:
		super._buy_selected()
		return
	if driver.mode != "tree": return
	var id: String = board.next_id(board.selected)
	if id.is_empty() or driver.model.can_buy(id): return
	var now := Time.get_ticks_msec()
	if now - last_denied_msec < 350: return
	last_denied_msec = now
	driver.sound.play_event("denied")
	driver.message(driver.model.locked_reason(id), 3)

func _purchase_button_input(event: InputEvent) -> void:
	super._purchase_button_input(event)
	if buy_button.disabled and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.double_click:
			_buy_selected()

func show_mode(mode: String) -> void:
	if reading_book != (mode == "tree"):
		reading_book = mode == "tree"
		driver.sound.play_event("book_open" if reading_book else "book_close")
	if is_instance_valid(sale_flight) and mode != "shop":
		sale_flight.stop()
	super.show_mode(mode)
