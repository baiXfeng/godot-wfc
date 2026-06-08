extends Node

func _ready() -> void:
	print("=== WFC Test Started ===")
	_test_basic_solve()
	_test_contradiction()
	_test_preview_image()
	_test_config_loader()
	print("=== WFC Test Complete ===")

func _test_basic_solve() -> void:
	print("--- Test: Basic Solve ---")

	var mod_a = WFCModule.new()
	mod_a.module_name = "Red"
	mod_a.preview_color = Color.RED
	mod_a.connectors = {"north": ["a"], "east": ["a"], "south": ["a"], "west": ["a"]}

	var mod_b = WFCModule.new()
	mod_b.module_name = "Blue"
	mod_b.preview_color = Color.BLUE
	mod_b.connectors = {"north": ["b"], "east": ["b"], "south": ["b"], "west": ["b"]}

	var mod_c = WFCModule.new()
	mod_c.module_name = "Mixed"
	mod_c.preview_color = Color.PURPLE
	mod_c.connectors = {"north": ["a"], "east": ["a", "b"], "south": ["b"], "west": ["a", "b"]}

	var mod_set = WFCModuleSet.new()
	var modules_1: Array[WFCModule] = [mod_a, mod_b, mod_c]
	mod_set.modules = modules_1

	var solver = WFCSolver.new()
	solver.init(mod_set, 8, 8, false)

	var result = solver.solve(42)
	assert(result != null, "Result should not be null")
	assert(result.success, "Solve should succeed with seed=42")
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

	var mod_a = WFCModule.new()
	mod_a.module_name = "A"
	# Self-incompatible in every direction: no two of these can be adjacent
	mod_a.connectors = {"north": ["a"], "east": ["b"], "south": ["c"], "west": ["d"]}

	var mod_set = WFCModuleSet.new()
	var modules_2: Array[WFCModule] = [mod_a]
	mod_set.modules = modules_2

	var solver = WFCSolver.new()
	solver.init(mod_set, 2, 1, false)  # 2x1 forces two self-incompatible modules adjacent

	var result = solver.solve(100)
	print("  Contradiction test: success=%s (expected false)" % result.success)

func _test_preview_image() -> void:
	print("--- Test: Preview Image ---")

	var mod_a = WFCModule.new()
	mod_a.module_name = "R"
	mod_a.preview_color = Color.RED
	mod_a.connectors = {"north": ["*"], "east": ["*"], "south": ["*"], "west": ["*"]}

	var mod_set = WFCModuleSet.new()
	var modules_3: Array[WFCModule] = [mod_a]
	mod_set.modules = modules_3

	var tex = mod_set.generate_preview_image(Vector2i(4, 4), 0)
	assert(tex != null, "Preview texture should not be null")
	print("  Preview texture generated: %dx%d" % [tex.get_width(), tex.get_height()])

func _test_config_loader() -> void:
	print("--- Test: Config Loader (Summer modules.json) ---")

	var mod_set = WFCConfigLoader.load_module_set("res://assets/Summer/modules.json")
	assert(mod_set != null, "Module set should not be null")
	assert(mod_set.modules.size() > 0, "Module set should have modules")

	print("  Loaded %d modules from modules.json" % mod_set.modules.size())
	for i in range(min(5, mod_set.modules.size())):
		var m = mod_set.modules[i]
		print("    [%d] %s  (N:%s E:%s S:%s W:%s)" % [
			i, m.module_name,
			",".join(m.connectors["north"]), ",".join(m.connectors["east"]),
			",".join(m.connectors["south"]), ",".join(m.connectors["west"])
		])
	if mod_set.modules.size() > 5:
		print("    ... and %d more" % (mod_set.modules.size() - 5))

	# Try solving a small grid
	var solver = WFCSolver.new()
	solver.init(mod_set, 6, 6, false)
	var result = solver.solve(42)
	print("  6x6 solve: success=%s" % result.success)

	if result.success:
		# Quick adjacency check on a few cells
		var errors := 0
		for y in range(6):
			for x in range(6):
				var mid = result.get_module_at(x, y)
				if x > 0:
					var left = result.get_module_at(x - 1, y)
					if not mod_set.are_compatible(mid, left, "west"):
						errors += 1
				if y > 0:
					var up = result.get_module_at(x, y - 1)
					if not mod_set.are_compatible(mid, up, "north"):
						errors += 1
		print("  Adjacency errors: %d" % errors)
		assert(errors == 0, "Summer solve should have no adjacency errors")
