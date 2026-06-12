@tool
class_name WFCGame
extends Node2D

@export var module_set: WFCModuleSet
@export var grid_width: int = 15
@export var grid_height: int = 15
@export var rng_seed: int = -1
@export var periodic: bool = false
@export var cell_pixels: int = 48
@export var config_path: String = "res://assets/test/strict_modules.json"

var _texture_dir: String = ""
var _atlas_image: Image = null
var _atlas_cols: int = 0
var _atlas_rows: int = 0
var _atlas_regions: Dictionary = {}  # module_name -> Image
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

	_texture_dir = config_path.get_base_dir() + "/"
	_load_atlas_if_present()
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
		var mod_name = module_set.modules[i].module_name
		var img: Image = null

		if _atlas_image:
			img = _extract_atlas_region(mod_name)
			if img:
				img = img.duplicate()  # don't mutate cached copy
		else:
			img = _load_image(_texture_path_for_module(mod_name))

		if img == null:
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != cell_pixels or img.get_height() != cell_pixels:
			img.resize(cell_pixels, cell_pixels, Image.INTERPOLATE_NEAREST)

		# Rotation for atlas mode is pre-computed; non-atlas uses on-the-fly rotate
		if not _atlas_image:
			var rot = _get_module_rotation(mod_name)
			for _r in range(rot):
				img.rotate_90(CLOCKWISE)

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

func _load_atlas_if_present() -> void:
	if not FileAccess.file_exists(config_path): return
	var f = FileAccess.open(config_path, FileAccess.READ)
	if f == null: return
	var json = JSON.parse_string(f.get_as_text())
	if json == null or not json.has("atlas"): return

	var a = json["atlas"]
	var atlas_path = _texture_dir + a["path"]
	if not FileAccess.file_exists(atlas_path): return

	var tex = load(atlas_path) as Texture2D
	if tex == null: return
	_atlas_image = tex.get_image()
	if _atlas_image == null: return
	_atlas_cols = a["columns"] as int
	_atlas_rows = a["rows"] as int

	# Pre-compute regions for all modules and their rotation variants
	var tw: int = int(float(_atlas_image.get_width()) / float(_atlas_cols))
	var th: int = int(float(_atlas_image.get_height()) / float(_atlas_rows))
	var name_tmpl = a["name_template"]

	for r in range(_atlas_rows):
		for c in range(_atlas_cols):
			# Base module name: tileset_0_0
			var base_name = "%s_%d_%d" % [name_tmpl, r, c]
			var region = _atlas_image.get_region(Rect2i(c * tw, r * th, tw, th))
			# Rotation 0 (no rotate) — just the base name without suffix
			_atlas_regions[base_name] = region

			# Also pre-compute for rotation variants (rotated by config loader): base_name_X
			# The config loader only adds suffix when rotations are enabled.
			# We compute all 4 in case any rotation is enabled.
			for rot in range(1, 4):
				var vname = "%s_%d" % [base_name, rot]
				var rimg = region.duplicate()
				for _r in range(rot):
					rimg.rotate_90(CLOCKWISE)
				_atlas_regions[vname] = rimg


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
		if not _result.success:
			var f = FileAccess.open("user://wfc_game.log", FileAccess.WRITE)
			if f:
				f.store_string("Generation failed: %dx%d, %d modules\n" % [grid_width, grid_height, module_set.modules.size()])
				for i in range(module_set.modules.size()):
					var m = module_set.modules[i]
					f.store_string("  [%d] %s: N(L%d,R%d) E(L%d,R%d) S(L%d,R%d) W(L%d,R%d)\n" % [
						i, m.module_name,
						m.connect_id_l.get("north", -1), m.connect_id_r.get("north", -1),
						m.connect_id_l.get("east", -1), m.connect_id_r.get("east", -1),
						m.connect_id_l.get("south", -1), m.connect_id_r.get("south", -1),
						m.connect_id_l.get("west", -1), m.connect_id_r.get("west", -1),
					])
				f.close()
		return
	_apply_result()
	_validate_result()

func _apply_result() -> void:
	for y in range(_result.height):
		for x in range(_result.width):
			var mod_idx = _result.get_module_at(x, y)
			_tile_map.set_cell(Vector2i(x, y), _tile_source_id, Vector2i(mod_idx, 0))


func _validate_result() -> void:
	var log_path := "user://wfc_validate.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	if f == null: return

	f.store_string("=== WFC Generation Integrity Report ===\n")
	f.store_string("Grid: %dx%d  Modules: %d\n\n" % [_result.width, _result.height, module_set.modules.size()])

	# ----- 0. Config connections dump (who can connect to whom, on which sides) -----
	f.store_string("--- Config Connections ---\n")
	for i in range(module_set.modules.size()):
		var ma = module_set.modules[i]
		for j in range(i, module_set.modules.size()):
			var mb = module_set.modules[j]
			var pairs: Array = []
			for dir in ["north", "east", "south", "west"]:
				if module_set.are_compatible(i, j, dir):
					pairs.append(dir)
			if not pairs.is_empty():
				f.store_string("  %-30s <-> %-30s : %s\n" % [ma.module_name, mb.module_name, ",".join(pairs)])
	f.store_string("\n")

	# ----- 1. Generated grid -----
	f.store_string("--- Generated Grid ---\n")
	var gen_grid: Array = []
	for y in range(_result.height):
		var row: Array = []
		for x in range(_result.width):
			row.append(_result.get_module_at(x, y))
		gen_grid.append(row)
		f.store_string("  %s\n" % str(row))

	# ----- 2. Rendered grid readback -----
	f.store_string("\n--- Rendered Grid (TileMap) ---\n")
	var ren_mismatches := 0
	for y in range(_result.height):
		var row: Array = []
		for x in range(_result.width):
			var src_id = _tile_map.get_cell_source_id(Vector2i(x, y))
			var atlas = _tile_map.get_cell_atlas_coords(Vector2i(x, y))
			var idx = atlas.x if src_id == _tile_source_id else -1
			row.append(idx)
			if idx != gen_grid[y][x]:
				ren_mismatches += 1
		f.store_string("  %s\n" % str(row))
	f.store_string("  Mismatches: %d\n\n" % ren_mismatches)

	# ----- 3. Edge-by-edge: check every adjacent pair against config -----
	f.store_string("--- Edge-by-Edge Validation ---\n")
	var opp = {"east": "west", "south": "north"}
	var dxy = {"east": Vector2i(1, 0), "south": Vector2i(0, 1)}
	var gen_violations := 0

	for dir in dxy:
		var d = dxy[dir]
		for y in range(_result.height):
			for x in range(_result.width):
				var a_idx = gen_grid[y][x]; if a_idx < 0: continue
				var nx = x + d.x; var ny = y + d.y
				if nx >= _result.width or ny >= _result.height: continue
				var b_idx = gen_grid[ny][nx]; if b_idx < 0: continue

				var ma = module_set.modules[a_idx]; var mb = module_set.modules[b_idx]
				var ok = module_set.are_compatible(a_idx, b_idx, dir)
				var al = ma.connect_id_l.get(dir, -1); var ar = ma.connect_id_r.get(dir, -1)
				var bl = mb.connect_id_l.get(opp[dir], -1); var br = mb.connect_id_r.get(opp[dir], -1)

				f.store_string("  (%d,%d) %s: %s(L%d,R%d) <-> %s(L%d,R%d) %s\n" % [
					x, y, dir, ma.module_name, al, ar, mb.module_name, bl, br,
					"OK" if ok else "FAIL"
				])
				if not ok:
					gen_violations += 1

	f.store_string("\n=== Summary ===\n")
	f.store_string("Gen vs Ren mismatches: %d\n" % ren_mismatches)
	f.store_string("Gen violations: %d\n" % gen_violations)
	var all_ok = ren_mismatches == 0 and gen_violations == 0
	f.store_string("INTEGRITY: %s\n" % ("PASS" if all_ok else "FAIL"))
	f.close()


func generate() -> WFCSolverResult:
	_generate()
	return _result
