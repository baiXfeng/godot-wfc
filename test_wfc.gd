extends Node

const _DIRECTIONS := ["north", "east", "south", "west"]


func _ready() -> void:
	print("=== WFC Test Started ===")
	_test_module_set_compatibility()
	_test_basic_solve()
	_test_contradiction()
	_test_preview_image()
	_test_config_loader()
	print("=== WFC Test Complete ===")


func _make_module(module_name: String, cl: Array, cr: Array, color: Color = Color.WHITE, weight: float = 1.0) -> WFCModule:
	var mod = WFCModule.new()
	mod.module_name = module_name
	mod.preview_color = color
	mod.weight = weight
	mod.connect_id_l = _to_dir_dict(cl)
	mod.connect_id_r = _to_dir_dict(cr)
	return mod


func _to_dir_dict(values: Array) -> Dictionary:
	var out: Dictionary = {}
	for i in range(min(values.size(), _DIRECTIONS.size())):
		out[_DIRECTIONS[i]] = values[i] as int
	return out


func _test_module_set_compatibility() -> void:
	print("--- Test: Module Compatibility ---")

	var match_a = _make_module("MatchA", [1, 1, 1, 1], [2, 2, 2, 2])
	var match_b = _make_module("MatchB", [2, 2, 2, 2], [1, 1, 1, 1])
	var single_pair_a = _make_module("SinglePairA", [1, -1, -1, -1], [-1, -1, -1, -1])
	var single_pair_b = _make_module("SinglePairB", [-1, -1, -1, -1], [-1, -1, 1, -1])
	var multi_pair_a = _make_module("MultiPairA", [-1, 3, -1, -1], [-1, -1, -1, -1])
	multi_pair_a.connect_id_l["east"] = [3, 4]
	var multi_pair_b = _make_module("MultiPairB", [-1, -1, -1, -1], [-1, -1, -1, -1])
	multi_pair_b.connect_id_r["west"] = [4, 5]
	var mismatch = _make_module("Mismatch", [9, 9, 9, 9], [9, 9, 9, 9])
	var wildcard = _make_module("Wildcard", [-1, -1, -1, -1], [-1, -1, -1, -1])

	var mod_set = WFCModuleSet.new()
	var modules_0: Array[WFCModule] = []
	modules_0.append(match_a)
	modules_0.append(match_b)
	modules_0.append(single_pair_a)
	modules_0.append(single_pair_b)
	modules_0.append(multi_pair_a)
	modules_0.append(multi_pair_b)
	modules_0.append(mismatch)
	modules_0.append(wildcard)
	mod_set.modules = modules_0

	assert(mod_set.are_compatible(0, 1, "east"), "Fully matched cross-checks should be compatible")
	assert(mod_set.are_compatible(2, 3, "north"), "A single matched cross-check should be enough for compatibility")
	assert(mod_set.are_compatible(4, 5, "east"), "Array connector IDs should match on any shared explicit ID")
	assert(not mod_set.are_compatible(0, 6, "east"), "Mismatched cross-checks should be incompatible")
	assert(not mod_set.are_compatible(7, 7, "west"), "Default -1 values should not create implicit compatibility")
	print("  Compatibility cache respects explicit single and multi-ID matches")

func _test_basic_solve() -> void:
	print("--- Test: Basic Solve ---")

	var mod_a = _make_module("Red", [1, 1, 1, 1], [1, 1, 1, 1], Color.RED, 1.0)
	var mod_b = _make_module("Blue", [1, 1, 1, 1], [1, 1, 1, 1], Color.BLUE, 1.0)
	var mod_c = _make_module("Mixed", [1, 1, 1, 1], [1, 1, 1, 1], Color.PURPLE, 2.0)

	var mod_set = WFCModuleSet.new()
	var modules_1: Array[WFCModule] = []
	modules_1.append(mod_a)
	modules_1.append(mod_b)
	modules_1.append(mod_c)
	mod_set.modules = modules_1

	var solver = WFCSolver.new()
	solver.init(mod_set, 8, 8, false)

	var result = solver.solve(42)
	assert(result != null, "Result should not be null")
	assert(result.success, "Solve should succeed with seed=42")
	assert(result.validate().is_empty(), "Generated grid should satisfy all adjacency constraints")
	print("  Grid 8x8 generated successfully: success=%s" % result.success)

	var counts = {}
	for y in range(8):
		for x in range(8):
			var idx = result.get_module_at(x, y)
			var mname = mod_set.modules[idx].module_name
			counts[mname] = counts.get(mname, 0) + 1
	print("  Module distribution: ", counts)

	# Verify adjacency
	for y in range(8):
		for x in range(8):
			var mid = result.get_module_at(x, y)
			if x > 0:
				var left = result.get_module_at(x - 1, y)
				assert(mod_set.are_compatible(mid, left, "west"),
					"Incompatible at (%d,%d) west" % [x, y])
			if y > 0:
				var up = result.get_module_at(x, y - 1)
				assert(mod_set.are_compatible(mid, up, "north"),
					"Incompatible at (%d,%d) north" % [x, y])
	print("  All adjacency constraints verified.")

func _test_contradiction() -> void:
	print("--- Test: Contradiction Detection ---")

	var mod_a = _make_module("A", [-1, 1, -1, 2], [-1, 1, -1, 2])

	var mod_set = WFCModuleSet.new()
	var modules_2: Array[WFCModule] = []
	modules_2.append(mod_a)
	mod_set.modules = modules_2

	var solver = WFCSolver.new()
	solver.init(mod_set, 2, 1, false)

	var result = solver.solve(100)
	assert(not result.success, "2x1 solve should fail when the only module cannot connect to itself horizontally")
	print("  Contradiction test: success=%s (expected false)" % result.success)

func _test_preview_image() -> void:
	print("--- Test: Preview Image ---")

	var mod_a = _make_module("R", [1, 1, 1, 1], [1, 1, 1, 1], Color.RED)

	var mod_set = WFCModuleSet.new()
	var modules_3: Array[WFCModule] = []
	modules_3.append(mod_a)
	mod_set.modules = modules_3

	var tex = mod_set.generate_preview_image(Vector2i(4, 4), 0)
	assert(tex != null, "Preview texture should not be null")
	print("  Preview texture generated: %dx%d" % [tex.get_width(), tex.get_height()])

func _test_config_loader() -> void:
	print("--- Test: Config Loader (strict sample) ---")

	var mod_set = WFCConfigLoader.load_module_set("res://assets/test/strict_modules.json")
	assert(mod_set != null, "Module set should not be null")
	assert(mod_set.modules.size() > 0, "Module set should have modules")
	assert(mod_set.modules.size() == 4, "Rotation variants should be expanded")
	assert(mod_set.modules.any(func(m): return m.module_name == "1_1"), "Rotation variants should be expanded")

	print("  Loaded %d modules from modules.json" % mod_set.modules.size())
	for i in range(min(5, mod_set.modules.size())):
		var m = mod_set.modules[i]
		print("    [%d] %s  (N:L%s/R%s E:L%s/R%s S:L%s/R%s W:L%s/R%s)" % [
			i, m.module_name,
			str(m.connect_id_l.get("north", [])), str(m.connect_id_r.get("north", [])),
			str(m.connect_id_l.get("east", [])), str(m.connect_id_r.get("east", [])),
			str(m.connect_id_l.get("south", [])), str(m.connect_id_r.get("south", [])),
			str(m.connect_id_l.get("west", [])), str(m.connect_id_r.get("west", []))
		])
	if mod_set.modules.size() > 5:
		print("    ... and %d more" % (mod_set.modules.size() - 5))

	# Try solving a small grid
	var solver = WFCSolver.new()
	solver.init(mod_set, 6, 6, false)
	var result = solver.solve(42)
	print("  6x6 solve: success=%s" % result.success)
	assert(result.success, "Strict sample 6x6 solve should succeed")

	var errors := result.validate().size()
	print("  Adjacency errors: %d" % errors)
	assert(errors == 0, "Strict sample solve should have no adjacency errors")
