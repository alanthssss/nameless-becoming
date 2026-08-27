extends SceneTree

const OUTPUT_SIZE := Vector2i(1280, 720)
const CAPTURES := [
	{"id": "hive", "file": "01-hive-developer-capture.png", "scene": "hive_threshold"},
	{"id": "spring", "file": "02-spring-developer-capture.png", "scene": "spring_field"},
	{"id": "summer", "file": "03-summer-developer-capture.png", "scene": "summer_field"},
	{"id": "autumn", "file": "04-autumn-developer-capture.png", "scene": "autumn_field"},
	{"id": "winter", "file": "05-winter-developer-capture.png", "scene": "winter_field"},
	{"id": "finale", "file": "06-finale-developer-capture.png", "scene": "finale_handoff"},
]

var directory := ""
var argument_error := ""


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--directory="):
			directory = argument.trim_prefix("--directory=")
		else:
			argument_error = "不支持的验证参数：%s" % argument
	if directory.is_empty() or not directory.is_absolute_path():
		argument_error = "--directory 必须是绝对目录"
	call_deferred("verify")


func verify() -> void:
	if not argument_error.is_empty():
		push_error(argument_error)
		quit(2)
		return
	var manifest_entries: Array[Dictionary] = []
	var seen_hashes := {}
	for capture in CAPTURES:
		var path := directory.path_join(String(capture.file))
		if not FileAccess.file_exists(path):
			_fail("缺少 Journey 截图：%s" % path)
			return
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() < 20_000:
			_fail("Journey 截图文件异常小：%s" % path)
			return
		var image := Image.load_from_file(path)
		if image == null or Vector2i(image.get_width(), image.get_height()) != OUTPUT_SIZE:
			_fail("Journey 截图不是 1280×720：%s" % path)
			return
		if not _has_visible_range(image):
			_fail("Journey 截图近似空白：%s" % path)
			return
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		var digest := hashing.finish().hex_encode()
		if seen_hashes.has(digest):
			_fail("两个 Journey 场景生成了相同画面：%s" % path)
			return
		seen_hashes[digest] = true
		manifest_entries.append({
			"id": String(capture.id),
			"file": String(capture.file),
			"runtime_scene": String(capture.scene),
			"width": image.get_width(),
			"height": image.get_height(),
			"sha256": digest,
			"actual_runtime_ui": true,
			"developer_state_injection": true,
		})
	var manifest := {
		"schema_version": 1,
		"evidence_level": "developer_capture",
		"capture_method": "Godot Journey.tscn runtime framebuffer",
		"post_processing": "none",
		"concept_art_substitution": false,
		"store_ready": false,
		"resolution": [OUTPUT_SIZE.x, OUTPUT_SIZE.y],
		"captures": manifest_entries,
	}
	var manifest_path := directory.path_join("developer-capture-manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("无法写入截图证据清单：%s" % manifest_path)
		return
	manifest_file.store_string(JSON.stringify(manifest, "  ") + "\n")
	manifest_file.close()
	print("JOURNEY MARKETING SCREENSHOTS VERIFIED: %d × 1280x720" % CAPTURES.size())
	quit(0)


func _has_visible_range(image: Image) -> bool:
	var minimum := 1.0
	var maximum := 0.0
	for y in range(0, image.get_height(), 36):
		for x in range(0, image.get_width(), 40):
			var color := image.get_pixel(x, y)
			var luminance := color.get_luminance()
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum >= 0.24


func _fail(message: String) -> void:
	push_error(message)
	quit(2)
