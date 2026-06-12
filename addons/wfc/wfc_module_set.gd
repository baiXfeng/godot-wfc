@tool
class_name WFCModuleSet
extends Resource

@export var modules: Array[WFCModule] = []

var _compatible_cache: Dictionary = {}
var _cache_valid: bool = false

const _DIRECTIONS: Array[String] = ["north", "east", "south", "west"]
const _OPPOSITE: Dictionary = {
	"north": "south",
	"south": "north",
	"east":  "west",
	"west":  "east",
}

func _init() -> void:
	changed.connect(_on_modules_changed)

func _on_modules_changed() -> void:
	_cache_valid = false

func build_compatibility_cache() -> void:
	_compatible_cache.clear()
	for dir in _DIRECTIONS:
		_compatible_cache[dir] = {}
		for i in range(modules.size()):
			var compat: Array = []
			for j in range(modules.size()):
				if _modules_compatible(i, j, dir):
					compat.append(j)
			_compatible_cache[dir][i] = compat
	_cache_valid = true

func _modules_compatible(a_idx: int, b_idx: int, direction: String) -> bool:
	var mod_a = modules[a_idx]
	var mod_b = modules[b_idx]
	var opp = _OPPOSITE.get(direction, "")

	var a_l: int = mod_a.connect_id_l.get(direction, -1)
	var a_r: int = mod_a.connect_id_r.get(direction, -1)
	var b_l: int = mod_b.connect_id_l.get(opp, -1)
	var b_r: int = mod_b.connect_id_r.get(opp, -1)

	return _cross_check(a_l, b_r) or _cross_check(a_r, b_l)


func _cross_check(a_value: int, b_value: int) -> bool:
	return a_value >= 0 and b_value >= 0 and a_value == b_value


func are_compatible(a_idx: int, b_idx: int, direction: String) -> bool:
	if not _cache_valid:
		build_compatibility_cache()
	var dir_cache = _compatible_cache.get(direction, {})
	var compat_list: Array = dir_cache.get(a_idx, [])
	return b_idx in compat_list

func get_compatible_modules(module_idx: int, direction: String) -> Array:
	if not _cache_valid:
		build_compatibility_cache()
	var dir_cache = _compatible_cache.get(direction, {})
	var compat_list: Array = dir_cache.get(module_idx, [])
	return compat_list.duplicate()

func generate_preview_image(size: Vector2i = Vector2i(32, 32), seed: int = 0) -> ImageTexture:
	if modules.is_empty():
		return null

	var solver = WFCSolver.new()
	solver.init(self, size.x, size.y, false)
	var result = solver.solve(seed)

	if result == null or not result.success:
		return null

	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(size.y):
		for x in range(size.x):
			var mod_idx = result.get_module_at(x, y)
			var color = modules[mod_idx].preview_color
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)
