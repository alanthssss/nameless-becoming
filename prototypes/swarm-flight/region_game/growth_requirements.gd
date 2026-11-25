extends VBoxContainer
## The journal reads purchase conditions from the same rank groups as the map.
const READY_INK := Color("395538")
const MISSING_INK := Color("803d23")
const INK := Color("443822")
const RESOURCE_NAMES := {"coins":"金币","fiber":"纤维","resin":"树脂"}
const RESOURCE_SOURCES := {"coins":"回庭院交售花蜜","fiber":"在池岸振开种穗、飞近接绒","resin":"在紫花地振开树皮、贴近收脂"}
var ui
var links: Array[Button] = []
var open_group := ""
var shown_rank := ""
var shown_rows: Array = []

static func rank_name(board, rank_id: String) -> String:
	var rank: Dictionary = board.ranks_by_id[rank_id]
	var levels: Array = board.entries[rank.cell].ranks
	var name: String = board.model.upgrade(rank_id).name if rank.stage == "demo" else rank.name
	return "%s（第 %d 档）" % [name,levels.find(rank_id)+1] if levels.size()>1 else name

static func rows_for(board, rank_id: String) -> Array:
	var m = board.model
	var rank: Dictionary = board.ranks_by_id[rank_id]
	var result: Array = []
	for group in board.prerequisite_groups(rank_id):
		var ids: Array = group.ranks
		var caption: String
		if ids.size() == 1:
			caption = rank_name(board,ids[0])
		elif int(group.minimum) == 1:
			caption = "任选 1 项 · 已学 %d" % mini(group.owned_count,1)
		else:
			caption = "累计学会 %d 档 · %d / %d" % [group.minimum,mini(group.owned_count,group.minimum),group.minimum]
		result.append({"kind":"skill","met":group.met,"text":caption,"targets":ids})
	var world: Dictionary = rank.get("requires_world",{})
	if world.get("visited_meadow",false):
		result.append({"kind":"world","met":m.visited_meadow,"text":"到过紫花地" if m.visited_meadow else "从庭院出发去一次紫花地","targets":[]})
	var sold: int = world.get("min_lifetime_violet_sold",0)
	if sold>0:
		result.append({"kind":"world","met":m.rose_sold>=sold,"text":"回庭院交售紫蜜 · %d / %d 份" % [mini(m.rose_sold,sold),sold],"targets":[]})
	if world.get("sealed",false):
		result.append({"kind":"world","met":m.completed,"text":"在庭院封罐","targets":[]})
	if world.get("lantern_lit",false):
		result.append({"kind":"world","met":false,"text":"点亮花径灯（后续章节）","targets":[]})
	# Planned ranks use the printed estimate. The first fourteen use the running
	# model, whose prices differ from the planning sheet at several ranks.
	var cost: Dictionary = m.upgrade(rank_id) if rank.stage == "demo" else rank.cost
	for unit in RESOURCE_NAMES:
		var price: int = cost.get("cost" if unit == "coins" and rank.stage == "demo" else unit,0)
		var held: int = m.coins if unit=="coins" else m.materials.get(unit,0)
		if held < price:
			result.append({"kind":"cost","met":false,"text":"还差 %d %s · %s" % [price-held,RESOURCE_NAMES[unit],RESOURCE_SOURCES[unit]],"targets":[]})
	var missing := result.filter(func(item): return not item.met)
	missing.append_array(result.filter(func(item): return item.met))
	return missing

func display(rank: Dictionary) -> void:
	var rows: Array = [] if rank.state=="owned" else rows_for(ui.board,rank.id)
	if rank.id==shown_rank and rows==shown_rows: return
	if rank.id!=shown_rank: open_group = ""
	shown_rows = rows
	shown_rank = rank.id
	_render()

func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	links.clear()
	visible = not shown_rows.is_empty()
	if not visible: return
	var missing: int = shown_rows.filter(func(item): return not item.met).size()
	var previous_section := ""
	for item in shown_rows:
		var section := "met" if item.met else "missing"
		if previous_section != section:
			var count := shown_rows.size()-missing if item.met else missing
			var title := "已满足 %d 项" % count if item.met else "待完成 %d 项" % count
			var heading: Label = ui.text_line(self,title,16,READY_INK if item.met else MISSING_INK)
			heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		previous_section = section
		_add_row(item)

func _add_row(item: Dictionary) -> void:
	var mark := "✓ " if item.met else "◇ "
	var ink := READY_INK if item.met else MISSING_INK
	var ids: Array = item.targets
	if ids.is_empty():
		ui.text_line(self,mark+item.text,16,ink,true)
	elif ids.size()==1:
		_link(mark+("已学 " if item.met else "先学 ")+item.text+"  →",ink,ui.follow_growth_rank.bind(ids[0]),"在树上查看"+rank_name(ui.board,ids[0]))
	else:
		var key := str(ids[0])
		var expanded := open_group==key
		var trigger := _link(mark+item.text+("  ▴" if expanded else "  ▾"),ink,_toggle.bind(key),"展开可计入的成长档位")
		trigger.set_meta("group",key)
		if expanded:
			for id in ids:
				var owned: bool = id in ui.board.model.owned
				_link("    "+("✓ " if owned else "◇ ")+rank_name(ui.board,id)+"  →",READY_INK if owned else INK,ui.follow_growth_rank.bind(id),"在树上查看此档")

func _link(words: String, ink: Color, callback: Callable, hint: String) -> Button:
	var b: Button = ui.action(self,words,callback)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0,27)
	b.add_theme_font_size_override("font_size",16)
	for setting in ["font_color","font_focus_color","font_hover_color","font_pressed_color"]:
		b.add_theme_color_override(setting,ink)
	b.add_theme_stylebox_override("normal",ui.style(Color("f9eac486"),Color("bfa379"),1,4))
	b.tooltip_text = hint
	links.append(b)
	return b

func _toggle(key: String) -> void:
	open_group = "" if open_group==key else key
	_render()
	for link in links:
		if link.get_meta("group","")==key:
			link.grab_focus()
			break

func cycle_link(reverse: bool) -> bool:
	if links.is_empty(): return false
	var owner := get_viewport().gui_get_focus_owner()
	var current := links.find(owner) if owner is Button else -1
	var next := posmod(current+( -1 if reverse else 1),links.size()) if current>=0 else (links.size()-1 if reverse else 0)
	links[next].grab_focus()
	return true

func activate_link() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	if not owner is Button or owner not in links: return false
	owner.pressed.emit()
	return true
