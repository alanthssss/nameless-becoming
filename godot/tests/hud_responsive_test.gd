extends SceneTree

const ProductionHUDScript := preload("res://scripts/ui/production_hud.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func rect_encloses(outer: Rect2, inner: Rect2, tolerance := 0.01) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)

func rect_is_equal(actual: Rect2, expected: Rect2, tolerance := 0.01) -> bool:
	return actual.position.distance_to(expected.position) <= tolerance and actual.size.distance_to(expected.size) <= tolerance

func route_mouse_click(control: Control) -> Dictionary:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	root.push_input(press, true)
	var press_handled := root.is_input_handled()
	await process_frame
	var button_was_down := bool((control as Button).button_pressed)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.global_position = point
	release.pressed = false
	root.push_input(release, true)
	var release_handled := root.is_input_handled()
	await process_frame
	return {
		"press_handled": press_handled,
		"release_handled": release_handled,
		"hovered": "<none>" if hovered == null else String(hovered.get_path()),
		"button_was_down": button_was_down,
	}

func route_touch_tap(control: Control, touch_index := 0) -> Dictionary:
	var point := control.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index = touch_index
	press.position = point
	press.pressed = true
	root.push_input(press, true)
	var press_handled := root.is_input_handled()
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = touch_index
	release.position = point
	release.pressed = false
	root.push_input(release, true)
	var release_handled := root.is_input_handled()
	await process_frame
	return {"press_handled": press_handled, "release_handled": release_handled}

func route_touch_drag_out(control: Control, touch_index := 0) -> Dictionary:
	var point := control.get_global_rect().get_center()
	var outside := control.get_global_rect().position - Vector2(12, 0)
	var press := InputEventScreenTouch.new()
	press.index = touch_index
	press.position = point
	press.pressed = true
	root.push_input(press, true)
	var press_handled := root.is_input_handled()
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = touch_index
	drag.position = outside
	drag.relative = outside - point
	root.push_input(drag, true)
	var drag_handled := root.is_input_handled()
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = touch_index
	release.position = outside
	release.pressed = false
	root.push_input(release, true)
	var release_handled := root.is_input_handled()
	await process_frame
	return {"press_handled": press_handled, "drag_handled": drag_handled, "release_handled": release_handled}

func route_ui_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func route_key(keycode: int) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func check_output_layout(label: String, output_size: Vector2) -> void:
	var layout: Dictionary = ProductionHUDScript.layout_for_output(output_size)
	expect(not layout.is_empty(), "%s 没有生成 HUD 安全布局" % label)
	if layout.is_empty():
		return
	var output_rect := Rect2(Vector2.ZERO, output_size)
	var safe_frame: Rect2 = layout.safe_frame
	expect(rect_encloses(output_rect, safe_frame), "%s 的等比安全框跑出窗口" % label)
	for key in ["top_tray", "stat_shelf", "world", "status_card", "action_card", "history_card", "tutorial", "sense_button", "return_button", "drink_button"]:
		expect(rect_encloses(safe_frame, layout[key]), "%s 的 %s 跑出 HUD 安全框" % [label, key])

	var top_tray: Rect2 = layout.top_tray
	var stat_shelf: Rect2 = layout.stat_shelf
	var world: Rect2 = layout.world
	var status_card: Rect2 = layout.status_card
	var action_card: Rect2 = layout.action_card
	var history_card: Rect2 = layout.history_card
	var tutorial: Rect2 = layout.tutorial
	var sense_button: Rect2 = layout.sense_button
	var return_button: Rect2 = layout.return_button
	var drink_button: Rect2 = layout.drink_button
	expect(rect_encloses(top_tray, stat_shelf), "%s 的资源架跑出顶栏" % label)
	expect(top_tray.end.y <= world.position.y, "%s 的顶栏遮住世界区" % label)
	expect(world.end.x <= status_card.position.x, "%s 的局面卡遮住世界区" % label)
	expect(status_card.end.y <= action_card.position.y, "%s 的局面卡与动作卡重叠" % label)
	expect(action_card.end.y <= history_card.position.y, "%s 的动作卡与历史卡重叠" % label)
	expect(not tutorial.intersects(status_card) and not tutorial.intersects(action_card) and not tutorial.intersects(history_card), "%s 的教学条遮住侧栏关键状态" % label)
	for button_spec in [["情境动作", sense_button], ["归巢", return_button], ["饮蜜", drink_button]]:
		var button_name := String(button_spec[0])
		var button_rect: Rect2 = button_spec[1]
		expect(rect_encloses(action_card, button_rect), "%s 的%s按钮悬在动作卡外" % [label, button_name])
		expect(minf(button_rect.size.x, button_rect.size.y) >= 44.0, "%s 的%s触控目标小于 44px" % [label, button_name])
	expect(not sense_button.intersects(return_button), "%s 的情境动作与归巢按钮重叠" % label)
	expect(not sense_button.intersects(drink_button) and not return_button.intersects(drink_button), "%s 的饮蜜按钮与其他动作重叠" % label)

func run_test() -> void:
	# Assets and global classes are prepared by scripts/test_godot.sh before this
	# test is launched. These settings assertions catch direct invocation using a
	# different canvas instead of silently validating the wrong geometry.
	expect(String(ProjectSettings.get_setting("display/window/stretch/mode", "")) == "canvas_items", "HUD 必须使用 canvas_items 逻辑画布")
	expect(String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "keep", "HUD 必须等比 keep，不能在 16:10 或窄屏上拉伸变形")
	for output in [
		["基准 1280×720", Vector2(1280, 720)],
		["高清 1920×1080", Vector2(1920, 1080)],
		["16:10 1440×900", Vector2(1440, 900)],
		["窄屏安全 1024×768", Vector2(1024, 768)],
	]:
		check_output_layout(String(output[0]), output[1])

	var wide_layout: Dictionary = ProductionHUDScript.layout_for_output(Vector2(1920, 1080))
	expect(is_equal_approx(float(wide_layout.scale), 1.5) and rect_is_equal(wide_layout.safe_frame, Rect2(0, 0, 1920, 1080)), "1920×1080 应完整等比放大，不应产生无谓黑边")
	var ten_layout: Dictionary = ProductionHUDScript.layout_for_output(Vector2(1440, 900))
	expect(rect_is_equal(ten_layout.safe_frame, Rect2(0, 45, 1440, 810)), "1440×900 应保留上下各 45px 安全边，不能纵向拉伸 HUD")
	var narrow_layout: Dictionary = ProductionHUDScript.layout_for_output(Vector2(1024, 768))
	expect(rect_is_equal(narrow_layout.safe_frame, Rect2(0, 96, 1024, 576)), "1024×768 应保留上下各 96px 安全边")

	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		failures.append("无法加载主场景；请先通过 scripts/test_godot.sh 完成资源导入")
		finish_test()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.persistence_enabled = false
	var ui := game.get_node("Interface") as CanvasLayer
	expect(game.production_hud.size == ProductionHUDScript.REFERENCE_SIZE, "运行时 HUD 没有使用 1280×720 参考画布")
	expect(game.WORLD == ProductionHUDScript.WORLD_RECT, "运行时世界区与 HUD 安全布局的世界区不一致")
	expect(rect_is_equal((ui.get_node("ForagePanel") as Control).get_global_rect(), Rect2(46, 70, 300, 52)), "运行时采集资源组与参考布局不一致")
	expect(rect_is_equal((ui.get_node("ContextRail") as Control).get_global_rect(), Rect2(1018, 146, 232, 538)), "运行时情境栏与参考布局不一致")
	expect(rect_is_equal(game.sense_button.get_global_rect(), ProductionHUDScript.SENSE_BUTTON_RECT), "运行时情境动作按钮没有使用集中布局")
	expect(rect_is_equal(game.return_button.get_global_rect(), ProductionHUDScript.RETURN_BUTTON_RECT), "运行时归巢按钮没有使用集中布局")
	expect(rect_is_equal(game.drink_button.get_global_rect(), ProductionHUDScript.DRINK_BUTTON_RECT), "运行时饮蜜按钮没有使用集中布局")
	expect(game.drink_button.mouse_filter == Control.MOUSE_FILTER_STOP and game.drink_button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "饮蜜按钮没有消费指针事件，或不是松手确认，可能误触世界移动")
	expect(not game.drink_button.visible, "尚未出巢时提前展示饮蜜按钮")

	game.start_game()
	game.tutorial_complete = true
	game.tutorial_step = 6
	game.mentor_tutorial.profile_id = ""
	game.mentor_tutorial.phase = "inactive"
	game.carried = 2
	game.crop_fuel_used = 0
	game.bee.energy = 50.0
	game.bee.has_target = false
	game.update_interface()
	# Freeze only world simulation so the two input frames do not drain energy;
	# GUI routing remains active and the expected refill stays exact.
	game.set_process(false)
	var refill := minf(game.balance_value("player", "crop_fuel_refill", 22.0), game.effective_energy_cap() - game.bee.energy)
	expect(game.can_drink_honey() and game.drink_button.visible and not game.drink_button.disabled, "携蜜且体力未满时没有提供指针/触控饮蜜入口")
	expect(game.drink_button.text.contains("+%d" % ceili(refill)) and game.drink_button.text.contains("余2"), "饮蜜按钮没有说明恢复量与剩余次数")
	var energy_before: float = game.bee.energy
	var mouse_route: Dictionary = await route_mouse_click(game.drink_button)
	expect(bool(mouse_route.press_handled) and bool(mouse_route.release_handled), "真实鼠标按下/松开没有被饮蜜按钮消费")
	expect(game.carried == 1 and game.crop_fuel_used == 1 and is_equal_approx(game.bee.energy, energy_before + refill), "真实鼠标点击结果错误：携带=%d，续力=%d，体力=%.2f" % [game.carried, game.crop_fuel_used, game.bee.energy])
	expect(bool(mouse_route.button_was_down), "真实鼠标没有压下饮蜜按钮；悬停控件=%s" % String(mouse_route.hovered))
	expect(not game.bee.has_target and not Input.is_action_pressed("drink_honey"), "鼠标点击饮蜜泄漏成世界移动或残留全局 E 输入")

	game.carried = 2
	game.crop_fuel_used = 0
	game.bee.energy = 50.0
	game.bee.has_target = false
	game.update_interface()
	energy_before = game.bee.energy
	var touch_route: Dictionary = await route_touch_tap(game.drink_button)
	expect(bool(touch_route.press_handled) and bool(touch_route.release_handled), "关闭触摸转鼠标后，真实触摸按下/松开没有被饮蜜按钮消费")
	expect(game.carried == 1 and game.crop_fuel_used == 1 and is_equal_approx(game.bee.energy, energy_before + refill), "真实触摸结果错误：携带=%d，续力=%d，体力=%.2f" % [game.carried, game.crop_fuel_used, game.bee.energy])
	expect(not game.bee.has_target and not Input.is_action_pressed("drink_honey"), "触摸饮蜜泄漏成世界移动或残留全局 E 输入")

	game.carried = 2
	game.crop_fuel_used = 0
	game.bee.energy = 50.0
	game.bee.has_target = false
	game.update_interface()
	var canceled_touch: Dictionary = await route_touch_drag_out(game.drink_button)
	expect(bool(canceled_touch.press_handled) and bool(canceled_touch.drag_handled) and bool(canceled_touch.release_handled), "饮蜜触摸拖出时有事件泄漏到世界")
	expect(game.carried == 2 and game.crop_fuel_used == 0 and is_equal_approx(game.bee.energy, 50.0), "触摸拖出按钮后仍错误饮蜜")
	expect(game.drink_touch_index == -1 and not game.drink_touch_armed and not game.drink_button.button_pressed and not game.bee.has_target, "触摸拖出取消后仍残留按压或世界移动状态")

	# Full energy, used-up allowance, mentor demonstration, and boss all suppress
	# the pointer action. Boss is intentionally aligned with the existing keyboard
	# path: update_boss() has no E/drink handler, so this does not add boss fuel.
	game.carried = 2
	game.crop_fuel_used = 0
	game.bee.energy = game.effective_energy_cap()
	game.update_interface()
	game.on_drink_honey_pressed()
	expect(not game.drink_button.visible and game.carried == 2, "体力已满时饮蜜入口仍可见或仍会浪费蜜")
	game.bee.energy = 40.0
	game.crop_fuel_used = int(game.balance_value("player", "crop_fuel_limit", 2))
	game.update_interface()
	game.on_drink_honey_pressed()
	expect(not game.drink_button.visible and game.carried == 2, "续力次数用尽后饮蜜入口仍可见或仍会耗蜜")
	game.crop_fuel_used = 0
	game.mentor_tutorial.phase = "demo"
	game.update_progressive_guidance()
	game.on_drink_honey_pressed()
	expect(not game.drink_button.visible and game.carried == 2, "老师傅演示锁定期间饮蜜入口仍可操作")
	game.mentor_tutorial.phase = "inactive"
	game.phase = "boss"
	game.update_progressive_guidance()
	game.on_drink_honey_pressed()
	expect(not game.drink_button.visible and game.carried == 2, "Boss 阶段意外新增了指针饮蜜，和现有键盘路径不一致")

	game.queue_free()
	await process_frame

	# Overlay keyboard regression uses GUI-routed ui actions and a physical Tab
	# event. Directly invoking callbacks would miss focus gaps and Enter events
	# that accidentally activate both the old and newly revealed controls.
	var focus_game = packed.instantiate()
	root.add_child(focus_game)
	await process_frame
	focus_game.persistence_enabled = false
	focus_game.set_process(false)
	expect(root.gui_get_focus_owner() == focus_game.overlay_button, "标题弹层没有把焦点交给出巢按钮")
	await route_ui_action("ui_accept")
	expect(focus_game.phase == "playing" and focus_game.stage_index == 0, "标题页一次 ui_accept 没有恰好进入第一节点")

	# The first visible enabled growth card owns initial focus. Disabled cards are
	# skipped, and a real right action moves through the authored card row.
	focus_game.upgrade_counts = {"long_wing": focus_game.UPGRADE_CAP, "forager": 0, "guard": 0}
	focus_game.delivered = int(focus_game.stages[0].goal)
	focus_game.show_between()
	await process_frame
	expect(root.gui_get_focus_owner() == focus_game.upgrade_buttons[1], "成长弹层没有聚焦第一个可用项，或聚焦了已满成长")
	focus_game.upgrade_buttons[1].release_focus()
	await process_frame
	await process_frame
	expect(root.gui_get_focus_owner() == focus_game.upgrade_buttons[1], "成长弹层失焦后没有恢复原来的有效成长项")
	await route_ui_action("ui_right")
	expect(root.gui_get_focus_owner() == focus_game.upgrade_buttons[2], "成长卡向右没有跳到下一个可用项")
	await route_ui_action("ui_accept")
	expect(focus_game.phase == "playing" and focus_game.stage_index == 1, "一次成长确认没有恰好推进一个节点")
	expect(focus_game.chosen_upgrades.size() == 1 and focus_game.chosen_upgrades[0] == "guard", "方向选择后的成长确认没有应用当前焦点项，或一次输入应用了多次")

	# Once every growth is full, the explicit continue button becomes the primary
	# target. Application focus restoration must resolve the current overlay state
	# instead of assuming the hidden growth cards or allocation controls.
	focus_game.upgrade_counts = {"long_wing": focus_game.UPGRADE_CAP, "forager": focus_game.UPGRADE_CAP, "guard": focus_game.UPGRADE_CAP}
	focus_game.delivered = int(focus_game.stages[1].goal)
	focus_game.show_between()
	await process_frame
	expect(root.gui_get_focus_owner() == focus_game.overlay_button and focus_game.overlay_button.text == "再次出巢", "成长全满时没有聚焦“再次出巢”")
	focus_game.overlay_button.release_focus()
	focus_game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(root.gui_get_focus_owner() == focus_game.overlay_button, "应用恢复时没有恢复成长全满弹层的主焦点")
	await route_ui_action("ui_accept")
	expect(focus_game.phase == "playing" and focus_game.stage_index == 2, "成长全满页一次 ui_accept 没有恰好推进一个节点")

	# White Dew ends the reserve segment. The slider starts focused, arrows adjust
	# its step, physical Tab reaches confirmation, and that confirmation must stop
	# on the newly revealed all-mature continue button until a second Enter.
	focus_game.spawn_stage(17)
	focus_game.upgrade_counts = {"long_wing": focus_game.UPGRADE_CAP, "forager": focus_game.UPGRADE_CAP, "guard": focus_game.UPGRADE_CAP}
	focus_game.delivered = int(focus_game.stages[17].goal)
	focus_game.show_between()
	await process_frame
	expect(focus_game.allocation_pending and root.gui_get_focus_owner() == focus_game.allocation_slider, "收成分配没有以滑杆作为初始焦点")
	var allocation_before: float = focus_game.allocation_slider.value
	await route_ui_action("ui_right")
	expect(is_equal_approx(focus_game.allocation_slider.value, allocation_before + focus_game.allocation_slider.step), "收成滑杆方向键没有按一个步长调整")
	await route_key(KEY_TAB)
	expect(root.gui_get_focus_owner() == focus_game.allocation_confirm, "收成分配 Tab 没有到达确认按钮")
	focus_game.allocation_confirm.release_focus()
	focus_game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(root.gui_get_focus_owner() == focus_game.allocation_confirm, "应用恢复时没有保留分配页当前的有效焦点")
	await route_ui_action("ui_accept")
	expect(not focus_game.allocation_pending and focus_game.phase == "between" and focus_game.stage_index == 17, "一次分配确认穿透到新按钮并推进了第二次")
	expect(focus_game.overlay_button.visible and root.gui_get_focus_owner() == focus_game.overlay_button, "分配确认后没有把焦点交给成长全满继续按钮")
	await route_ui_action("ui_accept")
	expect(focus_game.phase == "boss" and focus_game.stage_index == 18, "分配后的第二次独立 ui_accept 没有恰好进入秋分失律者")

	focus_game.queue_free()
	await process_frame
	finish_test()

func finish_test() -> void:
	if failures.is_empty():
		print("HUD RESPONSIVE TEST PASSED")
		print("TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
