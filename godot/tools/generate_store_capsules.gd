extends SceneTree

## Developer-only commercial capsule renderer. It combines the separately
## registered key-art concept with exact project-font typography. These outputs
## are brand candidates, never gameplay screenshots or approved store finals.

const TITLE_CN := "一会儿巢里见"
const TITLE_EN := "SEE YOU AT THE HIVE"
const FONT_PATH := "res://fonts/NotoSansCJKsc-ProjectSubset.otf"

const CAPSULES := [
	{
		"filename": "store-header-920x430.png", "size": Vector2i(920, 430), "crop_bias": 0.5,
		"panel": Rect2i(38, 50, 500, 320), "title": Vector2i(72, 126), "title_size": 60,
		"english_y": 220, "english_size": 18,
	},
	{
		"filename": "store-small-462x174.png", "size": Vector2i(462, 174), "crop_bias": 0.5,
		"panel": Rect2i(14, 20, 282, 134), "title": Vector2i(28, 55), "title_size": 31,
		"english_y": 101, "english_size": 10,
	},
	{
		"filename": "store-main-1232x706.png", "size": Vector2i(1232, 706), "crop_bias": 0.5,
		"panel": Rect2i(62, 92, 670, 478), "title": Vector2i(104, 218), "title_size": 82,
		"english_y": 337, "english_size": 25,
	},
	{
		"filename": "store-vertical-748x896.png", "size": Vector2i(748, 896), "crop_bias": 0.72,
		"panel": Rect2i(50, 590, 648, 226), "title": Vector2i(86, 642), "title_size": 60,
		"english_y": 736, "english_size": 18,
	},
	{
		"filename": "library-capsule-600x900.png", "size": Vector2i(600, 900), "crop_bias": 0.72,
		"panel": Rect2i(34, 610, 532, 212), "title": Vector2i(64, 656), "title_size": 49,
		"english_y": 731, "english_size": 14,
	},
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("generate")


func generate() -> void:
	var root_path := ProjectSettings.globalize_path("res://project.godot").get_base_dir().get_base_dir()
	var source_path := root_path.path_join("marketing/key-art/see-you-at-the-hive-key-art-base-v1.png")
	var output_path := root_path.path_join("marketing/store-candidates")
	var make_error := DirAccess.make_dir_recursive_absolute(output_path)
	if make_error != OK:
		push_error("Cannot create commercial store directory: %s" % error_string(make_error))
		quit(1)
		return
	var source := Image.new()
	var load_error := source.load(source_path)
	if load_error != OK:
		push_error("Cannot load commercial key art: %s (%d)" % [source_path, load_error])
		quit(1)
		return
	var font := load(FONT_PATH) as Font
	if font == null:
		push_error("Cannot load commercial title font: %s" % FONT_PATH)
		quit(1)
		return

	for spec in CAPSULES:
		var size: Vector2i = spec.size
		var background := _cover(source, size, float(spec.crop_bias))
		var rendered := await _render_capsule(background, font, spec)
		_save(rendered, output_path.path_join(String(spec.filename)))

	var hero := _cover(source, Vector2i(3840, 1240), 0.5)
	_save(hero, output_path.path_join("library-hero-3840x1240.png"))
	_save(
		await _render_logo(font, Color("f7efd8"), Color("dcb95a"), Color("243d33")),
		output_path.path_join("library-logo-light-1600x520.png")
	)
	_save(
		await _render_logo(font, Color("243d33"), Color("8a681f"), Color("f7efd8")),
		output_path.path_join("library-logo-dark-1600x520.png")
	)
	if failures.is_empty():
		_write_candidate_manifest(source_path, output_path)

	if failures.is_empty():
		print("Generated commercial store candidates in %s" % output_path)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _cover(source: Image, target: Vector2i, horizontal_bias: float) -> Image:
	var ratio := maxf(float(target.x) / float(source.get_width()), float(target.y) / float(source.get_height()))
	var scaled_size := Vector2i(
		ceili(float(source.get_width()) * ratio),
		ceili(float(source.get_height()) * ratio)
	)
	var scaled := source.duplicate()
	scaled.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	var spare_x := maxi(0, scaled_size.x - target.x)
	var spare_y := maxi(0, scaled_size.y - target.y)
	var crop_origin := Vector2i(roundi(float(spare_x) * clampf(horizontal_bias, 0.0, 1.0)), spare_y / 2)
	return scaled.get_region(Rect2i(crop_origin, target))


func _render_capsule(background: Image, font: Font, spec: Dictionary) -> Image:
	var size: Vector2i = spec.size
	var canvas := Control.new()
	canvas.size = Vector2(size)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = ImageTexture.create_from_image(background)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas.add_child(art)
	var panel_rect: Rect2i = spec.panel
	var panel := Panel.new()
	panel.position = Vector2(panel_rect.position)
	panel.size = Vector2(panel_rect.size)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("f7efd8", 0.94)
	panel_style.border_color = Color("6d5b38", 0.96)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(maxi(8, panel_rect.size.y / 18))
	panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(panel)
	var title_position: Vector2i = spec.title
	canvas.add_child(_label(TITLE_CN, font, title_position, int(spec.title_size), Color("243d33")))
	canvas.add_child(_label(
		TITLE_EN,
		font,
		Vector2i(title_position.x, int(spec.english_y)),
		int(spec.english_size),
		Color("435e50")
	))
	return await _capture(canvas, size, false)


func _render_logo(font: Font, title_color: Color, english_color: Color, outline_color: Color) -> Image:
	var size := Vector2i(1600, 520)
	var canvas := Control.new()
	canvas.size = Vector2(size)
	var title := _label(TITLE_CN, font, Vector2i(80, 62), 180, title_color)
	title.add_theme_color_override("font_outline_color", outline_color)
	title.add_theme_constant_override("outline_size", 5)
	canvas.add_child(title)
	var english := _label(TITLE_EN, font, Vector2i(92, 340), 48, english_color)
	english.add_theme_color_override("font_outline_color", outline_color)
	english.add_theme_constant_override("outline_size", 2)
	canvas.add_child(english)
	return await _capture(canvas, size, true)


func _label(text: String, font: Font, position: Vector2i, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(position)
	label.size = Vector2(1450, font_size * 1.7)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _capture(canvas: Control, size: Vector2i, transparent: bool) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = transparent
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	viewport.add_child(canvas)
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var texture := viewport.get_texture()
	var image := texture.get_image() if texture != null else null
	viewport.queue_free()
	await process_frame
	if image == null:
		failures.append("Rendering driver did not provide a capsule framebuffer")
		return Image.new()
	return image


func _save(image: Image, path: String) -> void:
	if image == null or image.is_empty():
		failures.append("Cannot write empty commercial image: %s" % path)
		return
	var error := image.save_png(path)
	if error != OK:
		failures.append("Cannot write %s (%d)" % [path, error])


func _write_candidate_manifest(source_path: String, output_path: String) -> void:
	var expected_sizes := {
		"store-header-920x430.png": Vector2i(920, 430),
		"store-small-462x174.png": Vector2i(462, 174),
		"store-main-1232x706.png": Vector2i(1232, 706),
		"store-vertical-748x896.png": Vector2i(748, 896),
		"library-capsule-600x900.png": Vector2i(600, 900),
		"library-hero-3840x1240.png": Vector2i(3840, 1240),
		"library-logo-light-1600x520.png": Vector2i(1600, 520),
		"library-logo-dark-1600x520.png": Vector2i(1600, 520),
	}
	var filenames := expected_sizes.keys()
	filenames.sort()
	var records: Array[Dictionary] = []
	for filename_variant in filenames:
		var filename := String(filename_variant)
		var path := output_path.path_join(filename)
		var image := Image.new()
		var error := image.load(path)
		if error != OK:
			failures.append("Cannot verify generated store candidate %s (%d)" % [path, error])
			continue
		var actual_size := Vector2i(image.get_width(), image.get_height())
		var expected_size: Vector2i = expected_sizes[filename]
		if actual_size != expected_size:
			failures.append("Store candidate size mismatch for %s: %s" % [filename, actual_size])
			continue
		records.append({
			"file": filename,
			"width": actual_size.x,
			"height": actual_size.y,
			"sha256": FileAccess.get_sha256(path),
		})
	if not failures.is_empty():
		return
	var manifest := {
		"schema_version": 1,
		"identity": "commercial_store_candidate",
		"product": "一会儿巢里见 · See You at the Hive",
		"source": {
			"file": "../key-art/see-you-at-the-hive-key-art-base-v1.png",
			"sha256": FileAccess.get_sha256(source_path),
			"kind": "imagegen_key_art_concept",
		},
		"compositor": "Godot project font renderer",
		"gameplay_screenshot": false,
		"store_ready": false,
		"owner_approved": false,
		"outputs": records,
	}
	var manifest_path := output_path.path_join("candidate-manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write store candidate manifest: %s" % manifest_path)
		return
	file.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	file.close()
