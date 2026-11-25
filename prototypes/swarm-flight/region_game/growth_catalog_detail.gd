extends RefCounted
## Add rank browsing to the existing fixed-price page. The original detail
## renderer remains the source of truth for the next real purchase.
const INK := Color("503e29")
const MOSS := Color("637854")

static func add_rank_controls(ui) -> void:
	var column = ui.detail_title.get_parent().get_parent()
	var bar: HBoxContainer = ui.row(column,8)
	bar.name = "CatalogRankPicker"
	column.move_child(bar,1)
	var prev: Button = ui.action(bar,"上一档",func(): ui.board.shift_rank(-1))
	prev.name = "Previous"
	var text: Label = ui.text_line(bar,"",15,MOSS)
	text.name = "Rank"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next: Button = ui.action(bar,"下一档",func(): ui.board.shift_rank(1))
	next.name = "Next"
	for button in [prev,next]:
		button.custom_minimum_size = Vector2(78,29)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size",16)
	prev.tooltip_text = "查看上一档"
	next.tooltip_text = "查看下一档"

static func sync_rank_controls(ui) -> void:
	if not is_instance_valid(ui.detail_title) or ui.board.model == null: return
	var bar: HBoxContainer = ui.detail_title.get_parent().get_parent().get_node_or_null("CatalogRankPicker")
	if bar == null: return
	var data: Dictionary = ui.board.inspect_data()
	var multi: bool = data.rank_count > 1
	bar.get_node("Previous").visible = multi
	bar.get_node("Next").visible = multi
	bar.get_node("Previous").disabled = data.rank_index<=0
	bar.get_node("Next").disabled = data.rank_index+1>=data.rank_count
	bar.get_node("Rank").text = "%s · 第 %d / %d 档" % [data.stage_name,data.rank_index+1,data.rank_count]

static func add_cost_stock(ui) -> void:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation",12)
	flow.add_theme_constant_override("v_separation",0)
	ui.detail_cost_row.add_child(flow)
	for unit in ui.detail_costs:
		var amount: Label = ui.detail_costs[unit]
		var price: HBoxContainer = amount.get_parent()
		price.reparent(flow,false)
		price.get_child(0).custom_minimum_size = Vector2(25,25)
		amount.add_theme_font_size_override("font_size",17)
		ui.cost_stock[unit] = ui.text_line(price,"",16,INK)

static func update_cost_stock(ui, rank: Dictionary) -> void:
	for unit in ui.cost_stock:
		var label: Label = ui.cost_stock[unit]
		var key: String = "coins" if unit=="coin" else unit
		var name: String = {"coins":"金币","fiber":"纤维","resin":"树脂"}[key]
		var held: int = ui.driver.model.coins if key=="coins" else ui.driver.model.materials.get(key,0)
		label.text = "%s · 持有 %d" % [name,held] if rank.state!="owned" else "%s · 已付" % name
		label.add_theme_color_override("font_color",Color("803d23") if rank.state!="owned" and held<int(rank.cost.get(key,0)) else INK)

static func update(ui,id: String) -> bool:
	if not is_instance_valid(ui.board) or ui.board.model == null: return false
	if not ui.board.has_method("inspect_data") or ui.board.selected != id: return false
	var data: Dictionary = ui.board.inspect_data()
	sync_rank_controls(ui)
	if data.state == "next":
		ui.detail_effect.add_theme_font_size_override("font_size",24)
		return false
	ui.detail_effect.add_theme_font_size_override("font_size",18)
	ui.detail_title.text = data.name
	ui.detail_level.text = "%d / %d" % [ui.board.rank_of(id),data.rank_count]
	ui.detail_preview.hide()
	ui.detail_effect.text = data.effect_text
	ui.detail_effect.tooltip_text = data.feedback
	ui.detail_cost_row.show()
	for key in ui.detail_costs:
		var unit: String = "coins" if key == "coin" else key
		var amount: int = data.cost.get(unit,0)
		var label: Label = ui.detail_costs[key]
		label.get_parent().visible = amount>0
		label.text = str(amount)
		label.add_theme_color_override("font_color",INK)
	ui.detail_requirements.text = data.requirements
	ui.detail_requirements.visible = not str(data.requirements).is_empty()
	ui.detail_hint.show()
	ui.buy_button.disabled = true
	match str(data.state):
		"owned":
			ui.buy_button.text = "已成长"
			ui.detail_hint.text = "已获得这一档。"
		"preview":
			ui.buy_button.text = "先学前一档"
			ui.detail_hint.text = "可在上一档查看目前可购买的成长。"
		_:
			ui.buy_button.text = "后续开放"
			ui.detail_hint.text = "后续章节预览 · 标价与效果为设计中的方案。"
	ui.detail_card.tooltip_text = data.requirements
	ui.buy_button.tooltip_text = ui.detail_hint.text
	ui._place_detail.call_deferred()
	return true
