extends Node

const MAIN_SCENE := preload("res://main.tscn")
const TicketValidatorScript := preload("res://scripts/playtest/playtest_ticket_validator.gd")
const TICKET_ARGUMENT_NAME := "--playtest-ticket"
const TICKET_ARGUMENT_PREFIX := "--playtest-ticket="
const READY_RECEIPT_FILENAME := "playtest-ready-receipt.json"

var _test_arguments: Variant = null
var _test_raw_arguments: Variant = null
var _test_validator: Variant = null
var launched_scene: Node
var last_error_code := ""

func configure_test_fixture(arguments: PackedStringArray, validator: RefCounted, raw_arguments: PackedStringArray) -> Error:
	if is_inside_tree() or _test_arguments != null or _test_raw_arguments != null:
		return ERR_ALREADY_IN_USE
	if not OS.has_feature("editor"):
		return ERR_UNAVAILABLE
	_test_arguments = arguments.duplicate()
	_test_raw_arguments = raw_arguments.duplicate()
	_test_validator = validator
	return OK

func _ready() -> void:
	var arguments: PackedStringArray = _test_arguments if _test_arguments != null else OS.get_cmdline_user_args()
	var raw_arguments: PackedStringArray = _test_raw_arguments if _test_raw_arguments != null else OS.get_cmdline_args()
	if _contains_misplaced_ticket_argument(raw_arguments):
		_show_failure("PT-ARG-SEPARATOR", "A playtest ticket was supplied before Godot's user-argument separator. Relaunch with -- before the ticket argument.")
		return
	if arguments.is_empty():
		_activate_scene(MAIN_SCENE.instantiate())
		return
	if arguments.size() != 1:
		_show_failure("PT-ARG-COUNT", "Bootstrap accepts either no user arguments or exactly one playtest ticket argument; received %d." % arguments.size())
		return
	var argument := String(arguments[0])
	if not argument.begins_with(TICKET_ARGUMENT_PREFIX):
		_show_failure("PT-ARG-FORMAT", "Unsupported bootstrap user argument: %s" % argument)
		return
	var ticket_path := argument.trim_prefix(TICKET_ARGUMENT_PREFIX)
	if not _is_external_filesystem_path(ticket_path):
		_show_failure("PT-ARG-PATH", "Playtest ticket argument must contain an absolute filesystem path.")
		return
	var validator: Variant = _test_validator if _test_validator != null else TicketValidatorScript.new()
	var result: Dictionary = validator.validate_ticket(ticket_path)
	if not bool(result.get("ok", false)):
		_show_failure(String(result.get("code", "PT-VALIDATION")), String(result.get("detail", "Ticket validation failed without detail.")))
		return
	var packed_scene = result.get("scene")
	if not packed_scene is PackedScene:
		_show_failure("PT-SCENE", "Validated registry result did not provide a PackedScene.")
		return
	var instance := (packed_scene as PackedScene).instantiate()
	if not instance.has_method("configure_playtest_session"):
		instance.free()
		_show_failure("PT-SCENE-CONTRACT", "Compiled playtest scene does not implement the session configuration contract.")
		return
	var configure_error: Error = instance.configure_playtest_session(result.context)
	if configure_error != OK:
		instance.free()
		_show_failure("PT-SCENE-CONFIG", "Compiled playtest scene rejected validated context with error %d." % configure_error)
		return
	_activate_scene(instance, ticket_path, result.context)

func _contains_misplaced_ticket_argument(arguments: PackedStringArray) -> bool:
	for raw_argument in arguments:
		var argument := String(raw_argument)
		if argument == TICKET_ARGUMENT_NAME or argument.begins_with(TICKET_ARGUMENT_PREFIX):
			return true
	return false

func _is_external_filesystem_path(path: String) -> bool:
	# Godot considers res:// and user:// absolute, but a playtest ticket must be
	# an external OS path distributed beside its artifact manifest. Use a syntax
	# whitelist because single-slash URI forms such as file:/ are also reported as
	# absolute. Preserve POSIX, drive-letter and UNC paths.
	if path.is_empty() or not path.is_absolute_path():
		return false
	if path.begins_with("/") or path.begins_with("\\\\"):
		return true
	var drive_path := RegEx.new()
	return drive_path.compile("^[A-Za-z]:[\\\\/]") == OK and drive_path.search(path) != null

func _activate_scene(instance: Node, ticket_path := "", context: Dictionary = {}) -> void:
	var tree := get_tree()
	var scene_root := tree.root
	if get_parent() == scene_root:
		call_deferred("_replace_root_scene", instance, ticket_path, context)
	else:
		add_child(instance)
		if not ticket_path.is_empty() and _write_ready_receipt(ticket_path, context) != OK:
			remove_child(instance)
			instance.free()
			_show_failure("PT-RECEIPT-WRITE", "The validated playtest scene became ready, but its launch receipt could not be written beside the ticket.")
			return
		launched_scene = instance

func _replace_root_scene(instance: Node, ticket_path := "", context: Dictionary = {}) -> void:
	if not is_instance_valid(instance):
		_show_failure("PT-SCENE", "Prepared scene became invalid before activation.")
		return
	var tree := get_tree()
	tree.root.add_child(instance)
	if not ticket_path.is_empty() and _write_ready_receipt(ticket_path, context) != OK:
		tree.root.remove_child(instance)
		instance.free()
		_show_failure("PT-RECEIPT-WRITE", "The validated playtest scene became ready, but its launch receipt could not be written beside the ticket.")
		return
	launched_scene = instance
	tree.current_scene = instance
	queue_free()

func _write_ready_receipt(ticket_path: String, context: Dictionary) -> Error:
	var receipt_path := ticket_path.get_base_dir().path_join(READY_RECEIPT_FILENAME)
	var receipt := {
		"schema_version": 1,
		"status": "ready",
		"session_id": String(context.get("session_id", "")),
		"slice_code": String((context.get("task", {}) as Dictionary).get("slice_code", "")),
		"product_commit": String((context.get("product", {}) as Dictionary).get("commit", "")),
		"ticket_sha256": String(context.get("ticket_sha256", "")),
	}
	var file := FileAccess.open(receipt_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error

func _show_failure(code: String, detail: String) -> void:
	last_error_code = code
	printerr("Playtest bootstrap failure [%s]: %s" % [code, detail])
	var layer := CanvasLayer.new()
	layer.name = "PlaytestFailure"
	add_child(layer)
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("17191f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var label := Label.new()
	label.name = "ErrorCode"
	label.text = "无法启动此试玩。\n错误码：%s" % code
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 80)
	background.add_child(label)
