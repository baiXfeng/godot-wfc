@tool
class_name WFCGame
extends Node2D

@export var module_set: WFCModuleSet
@export var grid_width: int = 10
@export var grid_height: int = 10
@export var rng_seed: int = -1
@export var periodic: bool = false
@export var cell_pixels: int = 48
@export var config_path: String = "res://assets/Summer/modules.json"
@export var texture_dir: String = "res://assets/Summer/"

var _tile_map: TileMapLayer
var _result: WFCSolverResult
var _tile_source_id: int = -1

func _ready() -> void:
	_tile_map = TileMapLayer.new()
	add_child(_tile_map)

	if Engine.is_editor_hint():
		return

	if module_set == null and not config_path.is_empty():
		module_set = WFCConfigLoader.load_module_set(config_path)

	if module_set == null or module_set.modules.is_empty():
		push_error("WFCGame: No module_set available")
		return

	_build_tile_set()
	_generate()

func _build_tile_set() -> void:
	var tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(cell_pixels, cell_pixels)

	var module_count = module_set.modules.size()
	var atlas_width = module_count * cell_pixels
	var atlas_height = cell_pixels

	var atlas_image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color.TRANSPARENT)

	for i in range(module_count):
		var tex_path = _texture_path_for_module(module_set.modules[i].module_name)
		var img = _load_image(tex_path)
		if img == null:
			continue
		if img.get_width() != cell_pixels or img.get_height() != cell_pixels:
			img.resize(cell_pixels, cell_pixels, Image.INTERPOLATE_NEAREST)
		atlas_image.blit_rect(img, Rect2i(0, 0, cell_pixels, cell_pixels), Vector2i(i * cell_pixels, 0))

	var atlas_texture = ImageTexture.create_from_image(atlas_image)

	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture_region_size = Vector2i(cell_pixels, cell_pixels)
	atlas_source.texture = atlas_texture

	for i in range(module_count):
		atlas_source.create_tile(Vector2i(i, 0))

	var source_id = tile_set.add_source(atlas_source)
	_tile_source_id = source_id

	_tile_map.tile_set = tile_set

func _texture_path_for_module(module_name: String) -> String:
	var base = module_name
	var last_underscore = module_name.rfind("_")
	if last_underscore > 0:
		var suffix = module_name.substr(last_underscore + 1)
		if suffix == "0" or suffix == "1" or suffix == "2" or suffix == "3":
			var possible_base = module_name.substr(0, last_underscore)
			var test_path = texture_dir + possible_base + ".png"
			if FileAccess.file_exists(test_path):
				base = possible_base
	return texture_dir + base + ".png"

func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		push_warning("WFCGame: Texture not found: ", path)
		return null
	var texture = load(path) as Texture2D
	if texture == null:
		push_warning("WFCGame: Failed to load texture: ", path)
		return null
	var img = texture.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

func _generate() -> void:
	var solver = WFCSolver.new()
	solver.init(module_set, grid_width, grid_height, periodic)
	_result = solver.solve(rng_seed)
	if not _result.success:
		push_warning("WFCGame: Generation failed")
		return
	_apply_result()

func _apply_result() -> void:
	for y in range(_result.height):
		for x in range(_result.width):
			var mod_idx = _result.get_module_at(x, y)
			_tile_map.set_cell(Vector2i(x, y), _tile_source_id, Vector2i(mod_idx, 0))

func generate() -> WFCSolverResult:
	_generate()
	return _result
