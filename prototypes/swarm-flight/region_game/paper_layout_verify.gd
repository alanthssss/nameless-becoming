extends SceneTree
## Deterministic ink and focus bounds for the regional game's authored UI.
class LayoutGame extends "res://region_game/main.gd":
	var directory: String
	func default_progress_path() -> String:
		return directory.path_join("progress.json")

const Art = preload("res://nectar_ui_art.gd")
# Interior measured in the ORIGINAL 1536×1024 spread. The left leaf is mirrored
# here for the right page. Independent of the layout margins being tested.
const PAPER := Rect2(81,72,672,846)
const TOP_LEAVES := Rect2(0,0,140,138)
const LOWER_LEAVES := Rect2(0,858,151,166)
var game
var ui
var sample := ""
var states := 0
var failures := {}
var printed := {}
var checked_text := 0
var growth_paper: Control

func _initialize() -> void:
	call_deferred("run")

func frames(n := 3) -> void:
	for i in n: await process_frame

func expect(ok: bool, reason: String) -> void:
	if ok: return
	failures[sample+" "+reason] = true
	if not printed.has(reason):
		printed[reason] = true
		printerr("FAIL ",sample," ",reason)

func on_paper(ink: Rect2, panel: Rect2, atlas: Rect2) -> bool:
	var ratio := atlas.size / panel.size
	var mark := Rect2(atlas.position+(ink.position-panel.position)*ratio,ink.size*ratio)
	if mark.get_center().x > 768.0: mark.position.x = 1536.0-mark.end.x
	return PAPER.encloses(mark) and not mark.intersects(TOP_LEAVES) and not mark.intersects(LOWER_LEAVES)

# Fractions measured on the illustrated faces, independently of container padding.
func clear_of_hardware(mark: Rect2, panel: PanelContainer) -> bool:
	var face := panel.get_global_rect()
	var r := Rect2((mark.position-face.position)/face.size,mark.size/face.size)
	match panel.get_meta("material_kind"):
		"book":
			# The top sheets end above the layered fore edge on both pages.
			return Rect2(.096,.075,.363,.655).encloses(r) or Rect2(.520,.075,.371,.655).encloses(r)
		"shop":
			return Rect2(.124,.176,.739,.673).encloses(r) and not r.intersects(Rect2(0,0,.244,.245)) and not r.intersects(Rect2(.71,0,.1,.25))
		"settings":
			return Rect2(.091,.065,.818,.768).encloses(r) and not r.intersects(Rect2(.096,.066,.079,.094)) and not r.intersects(Rect2(.821,.066,.085,.094)) and not r.intersects(Rect2(.09,.707,.076,.10)) and not r.intersects(Rect2(.815,.707,.09,.12))
		"letter":
			return Rect2(.053,.08,.87,.825).encloses(r) and not r.intersects(Rect2(.762,.626,.208,.342))
	return false

func visible_ink(control: Control, box: Rect2) -> Rect2:
	var parent := control.get_parent()
	while parent is Control:
		if parent.clip_contents: box = box.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return box

func inspect_mark(control: Control, ink: Rect2, page: PanelContainer, atlas: Rect2) -> void:
	var visible := visible_ink(control,ink)
	if not visible.has_area(): return
	var label := str(control.text).strip_edges().replace("\n"," ").left(17)
	expect(Rect2(Vector2.ZERO,ui.size).grow(1).encloses(visible),"outside screen: "+label)
	if page and page.has_meta("material_kind"):
		expect(clear_of_hardware(visible,page),"on illustrated frame: "+label)
	elif page:
		expect(on_paper(visible,page.get_global_rect(),atlas),"on painted border: "+label)
	elif ui.tree.is_ancestor_of(control):
		var backing: Control = ui.skill_note if ui.skill_note.is_ancestor_of(control) else growth_paper
		expect(backing.get_global_rect().grow(-2).encloses(visible),"outside the growth parchment: "+label)

func inspect(node: Node, page: PanelContainer = null, atlas := Rect2()) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is PanelContainer:
		var bg: StyleBox = node.get_theme_stylebox("panel")
		if node.has_meta("material_kind"):
			page = node
			expect(Rect2(Vector2.ZERO,ui.size).grow(1).encloses(page.get_global_rect()),"whole illustrated panel outside screen")
		elif bg is StyleBoxTexture and bg.texture is AtlasTexture and bg.texture.atlas == Art.JOURNAL:
			page = node
			atlas = bg.texture.region
			expect(Rect2(Vector2.ZERO,ui.size).grow(1).encloses(page.get_global_rect()),"whole paper outside screen")
	if node is Label and not node.text.is_empty():
		checked_text += 1
		for i in node.text.length():
			if node.text[i].strip_edges().is_empty(): continue
			var ink: Rect2 = node.get_character_bounds(i)
			if ink.has_area(): inspect_mark(node,node.get_global_transform()*ink,page,atlas)
	elif node is VScrollBar:
		if page and page.has_meta("material_kind"):
			expect(clear_of_hardware(node.get_global_rect(),page),"scroll track on illustrated frame")
		elif ui.skill_note.is_ancestor_of(node):
			expect(ui.skill_note.get_global_rect().encloses(node.get_global_rect()),"track outside growth note")
	elif node is Button and not node.text.is_empty():
		checked_text += 1
		var font: Font = node.get_theme_font("font")
		var px: int = node.get_theme_font_size("font_size")
		var bg: StyleBox = node.get_theme_stylebox("normal")
		var inner_width: float = node.size.x - bg.get_minimum_size().x
		var longest := 0.0
		for line in node.text.split("\n"):
			longest = maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x)
		if node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			expect(longest <= inner_width+1,"button text wider than writing area: "+node.text.left(17))
		else:
			var wrapped := font.get_multiline_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,inner_width,px)
			expect(wrapped.y <= node.size.y+1,"wrapped caption too tall: "+node.text.left(17))
		# Buttons' navigation outlines can touch the wood even when the caption fits.
		inspect_mark(node,node.get_global_rect(),page,atlas)
	for child in node.get_children(): inspect(child,page,atlas)

func scan(tag: String, screen: Control) -> void:
	sample = str(root.size)+" "+tag
	states += 1
	expect(screen.is_visible_in_tree(),"screen not open")
	inspect(screen)

func mode(tag: String) -> void:
	game.mode = tag
	ui.show_mode(tag)
	await frames()

func check_menus() -> void:
	for tag in ["title","pause","complete"]:
		await mode(tag)
		scan(tag,ui.pause_folio if tag == "pause" else ui.menu)
	game.save_blocked = true
	await mode("title")
	scan("blocked save",ui.menu)
	ui.ask_restart()
	await frames()
	scan("restart",ui.restart_dialog)
	ui.close_restart()
	game.open_slots()
	await frames()
	scan("slots",ui.slots)
	game.close_slots()
	game.save_blocked = false
	game.has_save = true
	game.save_warning = true
	await mode("title")
	scan("saved game / write warning",ui.menu)
	game.save_warning = false
	await mode("settings")
	scan("settings top",ui.settings)
	expect(ui.settings_scroll.scroll_vertical==0,"first setting scrolled away")
	var back: Rect2 = ui.settings_back.get_global_rect()
	game.reduced_motion = true
	ui.refresh_settings()
	scan("alternate setting captions",ui.settings)
	ui.settings_about.pressed.emit()
	await frames()
	scan("settings credits",ui.settings)
	game.reduced_motion = false
	ui.settings_scroll.scroll_vertical = int(ui.settings_scroll.get_v_scroll_bar().max_value)
	await frames()
	scan("settings end",ui.settings)
	expect(ui.settings_back.get_global_rect()==back,"settings return moves with text")
	ui._open_controls()
	var controls = ui.controls_page
	for device in ["kbm","pad"]:
		controls.open(device)
		controls.scroll.scroll_vertical = 0
		await frames()
		scan("bindings "+device,controls)
		controls._listen("interact","key" if device=="kbm" else "pad")
		await frames()
		scan("waiting for binding "+device,controls)
		controls.scroll.scroll_vertical = int(controls.scroll.get_v_scroll_bar().max_value)
		await frames()
		scan("bindings end "+device,controls)
		controls._finish_capture()
		for section in ["菜单","成长树","花湾"]:
			controls.sections[section].pressed.emit()
			await frames()
			scan("fixed controls "+device+" "+section,controls)
	ui.close_controls()
	game.model.visited_meadow = false
	await mode("journal")
	scan("unvisited journal",ui.journal)
	game.model.visited_meadow = true
	game.model.rose_sold = 35
	await mode("journal")
	scan("visited journal",ui.journal)
	ui.journal_regions[1].pressed.emit()
	await frames()
	scan("meadow journal",ui.journal)
	ui.journal_return_notes.show()
	await frames()
	scan("field return rules open",ui.journal)

func check_courtyard() -> void:
	game.model.coins = 1000000000
	game.model.materials = {"fiber":1000000000,"resin":1000000000}
	for at in [game.model.HUB_SHOP,game.model.HUB_TREE,game.model.HUB_DEPART]:
		game.model.p = at
		await mode("play")
		scan("courtyard "+ui.hub_action.text,ui.hud)
		var pad: Rect2 = ui.hud_status.get_global_rect().grow_individual(-14,-10,-14,-12)
		for label in [ui.coins_text,ui.fiber_text,ui.resin_text,ui.energy_text,ui.bag_text]:
			expect(pad.encloses(label.get_global_rect()),"HUD value leaves its backing")
	await mode("regions")
	scan("destinations locked",ui.regions)
	game.model.owned.assign(["gather1","bag1","wings1","meadow"])
	ui.refresh()
	await frames()
	scan("destinations open",ui.regions)
	game.model.area = "pond"
	await mode("regions")
	scan("destinations return",ui.regions)
	game.model.area = "hub"
	game.model.coins = 1000000000
	game.model.materials = {"fiber":1000000000,"resin":1000000000}
	game.model.sold_total = 35
	for cargo in [{"blue":0,"rose":0},{"blue":3,"rose":2}]:
		game.model.cargo = cargo
		await mode("shop")
		scan("shop "+str(cargo),ui.shop)
	game.home_return_summary = "救援带回 · 蓝花蜜 3 · 紫花蜜 2\n损失 · 蓝花蜜 2 · 紫花蜜 2\n材料保留 · 纤维 15 · 树脂 8"
	game.home_sale_summary = "已交付 · 蓝花蜜 3 · 紫花蜜 2\n获得 9 金币"
	game.model.cargo = {"blue":0,"rose":0}
	await mode("shop")
	scan("shop rescue and sale receipt",ui.shop)
	ui.shop_receipt.button_pressed = true
	ui._toggle_shop_receipt()
	await frames()
	scan("receipt expanded",ui.shop)
	ui.shop_scroll.scroll_vertical = int(ui.shop_scroll.get_v_scroll_bar().max_value)
	await frames()
	scan("shop end of receipt",ui.shop)
	ui.show_toast("已交付 · 蓝花蜜 3 · 紫花蜜 2",2)
	await frames()
	scan("shop receipt feedback",ui.toast_panel)
	await mode("transition")
	scan("transition guidance",ui.transition_hint)

func check_book() -> void:
	await mode("tree")
	for rank in ui.board.ranks_by_id:
		ui.board.select_rank(rank)
		ui._reveal_note()
		await frames(2)
		scan("growth "+rank,ui.tree)
		var scroll: ScrollContainer = ui.detail_scroll
		expect(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,"growth detail wider than its scroll area")
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await frames(1)
		scan("growth end "+rank,ui.detail_card)
	ui.board.select_rank("meadow")
	for trigger in ui.conditions.links:
		if trigger.has_meta("group"):
			trigger.pressed.emit()
			break
	await frames()
	scan("expanded prerequisites",ui.tree)
	ui.growth_map.zoom_selected(ui.growth_map.MAX_ZOOM)
	await frames()
	scan("map at maximum zoom",ui.tree)
	ui.board.select_rank("gather1")
	ui.follow_growth_rank("bag1")
	await frames()
	scan("return to tracked prerequisite",ui.tree)
	ui.show_toast("金币不足",2)
	await frames()
	scan("growth feedback",ui.toast_panel)
	expect(not ui.tree_footer.visible,"feedback overlaps growth controls")
	ui.board.select_node("cascade")
	ui._open_bay()
	await frames()
	for stage in ui.bay_preview.STAGES.size():
		ui.bay_preview._stage_changed(stage)
		await frames()
		scan("flower bay "+str(stage),ui.bay_preview)
	ui._close_bay()

func check_size(pixels: Vector2i) -> void:
	root.size = pixels
	var directory := DirAccess.create_temp("honey-page-layout")
	if directory == null:
		expect(false,"create isolated progress directory")
		return
	game = LayoutGame.new()
	game.directory = directory.get_current_dir()
	root.add_child(game)
	ui = game.ui
	growth_paper = null
	for node in ui.tree.get_children():
		if node.get_script() == preload("res://region_game/growth_parchment.gd") and not node.small_note:
			growth_paper = node
	expect(is_instance_valid(growth_paper),"growth parchment present")
	var known := [ui.hud,ui.shop,ui.tree,ui.regions,ui.menu,ui.pause_folio,ui.settings,ui.slots,ui.journal,
		ui.controls_page,ui.restart_dialog,ui.transition_layer,ui.transition_hint,ui.toast_panel]
	for node in ui.get_children():
		if node is Control: expect(node in known,"uncovered UI root "+str(node.get_class())+" "+str(node.name))
	await frames()
	var occupied = game.new_model()
	occupied.coins = 1000000000
	occupied.trip_index = 1000000000
	expect(game.Save.write_payload(occupied.to_payload(),game.slot_path(2),game.new_model()),"write occupied slot fixture")
	var corrupt := FileAccess.open(game.slot_path(3),FileAccess.WRITE)
	corrupt.store_string("unreadable")
	corrupt.close()
	game.home_return_summary = ""
	game.home_sale_summary = ""
	await check_menus()
	await check_courtyard()
	await check_book()
	game.queue_free()
	await frames()

func run() -> void:
	# Include the supported minimum and letterboxing on wider and taller displays.
	for pixels in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1280,720),Vector2i(1024,768)]:
		await check_size(pixels)
	# The mixer uses real time even when the CI driver advances at fixed FPS.
	var drain_until := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain_until:
		OS.delay_msec(8)
		await process_frame
	print("HONEY PAGE LAYOUT: %d states, %d text controls, %d failures" % [states,checked_text,failures.size()])
	quit(1 if failures.size() else 0)
