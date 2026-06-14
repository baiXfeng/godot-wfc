class_name WFCStepDemo
extends Node2D

@export var config_path: String = "res://assets/test/modules.json"
@export var grid_width: int = 10
@export var grid_height: int = 10
@export var rng_seed: int = -1
@export var periodic: bool = false
@export var cell_pixels: int = 48

var _module_set: WFCModuleSet
var _solver: WFCStepSolver
var _tile_map: TileMapLayer
var _tile_source_id: int = -1
var _width_spin: SpinBox
var _height_spin: SpinBox
var _reset_button: Button
var _step_button: Button
var _finish_button: Button
var _status_label: Label

var _texture_dir: String = ""
var _atlas_image: Image = null
var _atlas_cols: int = 0
var _atlas_rows: int = 0
var _atlas_regions: Dictionary = {}


func _ready() -> void:
	_tile_map = TileMapLayer.new()
	add_child(_tile_map)
	get_viewport().size_changed.connect(_center_map)
	_build_ui()
	_reset_demo()


func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -76.0
	panel.offset_bottom = -12.0
	panel.offset_left = 24.0
	panel.offset_right = -24.0
	canvas.add_child(panel)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(center)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)

	row.add_child(_make_label("地图宽"))
	_width_spin = _make_spin(grid_width)
	row.add_child(_width_spin)

	row.add_child(_make_label("地图高"))
	_height_spin = _make_spin(grid_height)
	row.add_child(_height_spin)

	_reset_button = _make_button("复位")
	_step_button = _make_button("下一步")
	_finish_button = _make_button("直接完成")
	row.add_child(_reset_button)
	row.add_child(_step_button)
	row.add_child(_finish_button)

	_status_label = _make_label("")
	_status_label.custom_minimum_size = Vector2(180, 0)
	row.add_child(_status_label)

	_reset_button.pressed.connect(_reset_demo)
	_step_button.pressed.connect(_step_once)
	_finish_button.pressed.connect(_finish_generation)


func _make_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_spin(value: int) -> SpinBox:
	var spin = SpinBox.new()
	spin.min_value = 1
	spin.max_value = 128
	spin.step = 1
	spin.rounded = true
	spin.value = value
	spin.custom_minimum_size = Vector2(72, 0)
	return spin


func _make_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	return button


func _reset_demo() -> void:
	grid_width = int(_width_spin.value) if _width_spin else grid_width
	grid_height = int(_height_spin.value) if _height_spin else grid_height
	_module_set = WFCConfigLoader.load_module_set(config_path)
	if _module_set == null or _module_set.modules.is_empty():
		push_error("WFCStepDemo: No module_set available")
		return

	_texture_dir = config_path.get_base_dir() + "/"
	_load_atlas_if_present()
	_build_tile_set()

	_solver = WFCStepSolver.new()
	_solver.init(_module_set, grid_width, grid_height, periodic, rng_seed)
	_refresh_map()
	_update_status("已复位")


func _step_once() -> void:
	if _solver == null:
		_reset_demo()
		return
	var step_result = _solver.step()
	_refresh_map()
	_update_status(step_result.get("action", "step"))


func _finish_generation() -> void:
	if _solver == null:
		_reset_demo()
	if _solver == null:
		return
	_solver.finish()
	_refresh_map()
	_update_status("直接完成")


func _refresh_map() -> void:
	_tile_map.clear()
	if _solver == null:
		return
	for y in range(_solver.get_height()):
		for x in range(_solver.get_width()):
			var module_idx = _solver.get_module_at(x, y)
			if module_idx >= 0:
				_tile_map.set_cell(Vector2i(x, y), _tile_source_id, Vector2i(module_idx, 0))
	_center_map()


func _center_map() -> void:
	var viewport_size = get_viewport_rect().size
	var map_size = Vector2(grid_width * cell_pixels, grid_height * cell_pixels)
	var usable_height = max(1.0, viewport_size.y - 96.0)
	_tile_map.position = Vector2(
		floor((viewport_size.x - map_size.x) * 0.5),
		floor((usable_height - map_size.y) * 0.5)
	)


func _update_status(action: String) -> void:
	if _solver == null:
		_status_label.text = "未初始化"
		return
	var collapsed = _solver.get_collapsed_count()
	var total = _solver.get_width() * _solver.get_height()
	var status = _solver.get_status()
	_status_label.text = "%s  %d/%d  %s" % [action, collapsed, total, status]
	_step_button.disabled = _solver.is_done()
	_finish_button.disabled = _solver.is_done()


func _build_tile_set() -> void:
	var tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(cell_pixels, cell_pixels)

	var module_count = _module_set.modules.size()
	var atlas_width = module_count * cell_pixels
	var atlas_height = cell_pixels
	var atlas_image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color.TRANSPARENT)

	for i in range(module_count):
		var module_name = _module_set.modules[i].module_name
		var image: Image = null
		if _atlas_image:
			image = _extract_atlas_region(module_name)
			if image:
				image = image.duplicate()
		else:
			image = _load_image(_texture_path_for_module(module_name))
		if image == null:
			continue
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		if image.get_width() != cell_pixels or image.get_height() != cell_pixels:
			image.resize(cell_pixels, cell_pixels, Image.INTERPOLATE_NEAREST)
		if not _atlas_image:
			var module_rotation = _get_module_rotation(module_name)
			for _r in range(module_rotation):
				image.rotate_90(CLOCKWISE)
		atlas_image.blit_rect(image, Rect2i(0, 0, cell_pixels, cell_pixels), Vector2i(i * cell_pixels, 0))

	var atlas_texture = ImageTexture.create_from_image(atlas_image)
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture_region_size = Vector2i(cell_pixels, cell_pixels)
	atlas_source.texture = atlas_texture
	for i in range(module_count):
		atlas_source.create_tile(Vector2i(i, 0))

	_tile_source_id = tile_set.add_source(atlas_source)
	_tile_map.tile_set = tile_set


func _load_atlas_if_present() -> void:
	_atlas_image = null
	_atlas_regions.clear()
	if not FileAccess.file_exists(config_path):
		return
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	var json = JSON.parse_string(file.get_as_text())
	if json == null or not json.has("atlas"):
		return

	var atlas = json["atlas"]
	var atlas_path = _texture_dir + atlas["path"]
	if not FileAccess.file_exists(atlas_path):
		return

	var texture = load(atlas_path) as Texture2D
	if texture == null:
		return
	_atlas_image = texture.get_image()
	if _atlas_image == null:
		return
	_atlas_cols = atlas["columns"] as int
	_atlas_rows = atlas["rows"] as int

	var tile_width = int(float(_atlas_image.get_width()) / float(_atlas_cols))
	var tile_height = int(float(_atlas_image.get_height()) / float(_atlas_rows))
	var name_template = atlas["name_template"]
	for row in range(_atlas_rows):
		for col in range(_atlas_cols):
			var base_name = "%s_%d_%d" % [name_template, row, col]
			var region = _atlas_image.get_region(Rect2i(col * tile_width, row * tile_height, tile_width, tile_height))
			_atlas_regions[base_name] = region
			for rot_idx in range(1, 4):
				var variant_name = "%s_%d" % [base_name, rot_idx]
				var rotated = region.duplicate()
				for _r in range(rot_idx):
					rotated.rotate_90(CLOCKWISE)
				_atlas_regions[variant_name] = rotated


func _extract_atlas_region(module_name: String) -> Image:
	return _atlas_regions.get(module_name)


func _texture_path_for_module(module_name: String) -> String:
	var base = module_name
	var last_underscore = module_name.rfind("_")
	if last_underscore > 0:
		var suffix = module_name.substr(last_underscore + 1)
		if suffix == "0" or suffix == "1" or suffix == "2" or suffix == "3":
			var possible_base = module_name.substr(0, last_underscore)
			var test_path = _texture_dir + possible_base + ".png"
			if FileAccess.file_exists(test_path):
				base = possible_base
	return _texture_dir + base + ".png"


func _get_module_rotation(module_name: String) -> int:
	var last_underscore = module_name.rfind("_")
	if last_underscore > 0:
		var suffix = module_name.substr(last_underscore + 1)
		if suffix == "0" or suffix == "1" or suffix == "2" or suffix == "3":
			var possible_base = module_name.substr(0, last_underscore)
			var test_path = _texture_dir + possible_base + ".png"
			if FileAccess.file_exists(test_path):
				return suffix.to_int()
	return 0


func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		push_warning("WFCStepDemo: Texture not found: ", path)
		return null
	var texture = load(path) as Texture2D
	if texture == null:
		push_warning("WFCStepDemo: Failed to load texture: ", path)
		return null
	var image = texture.get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image
