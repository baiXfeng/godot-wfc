extends Node

func _ready() -> void:
	print("=== Validation Test ===")

	# Test strict-mode sample config
	var ms = WFCConfigLoader.load_module_set("res://assets/test/strict_modules.json")
	if ms == null:
		print("Failed to load strict sample modules.json")
		return

	print("Modules: ", ms.modules.size())
	print()

	var r = WFCSolver.verify(ms, 8, 8, 10)

	print("Attempts: ", r.attempts)
	print("Successes: ", r.successes)
	print("Total violations: ", r.total_violations)

	if r.first_fail >= 0:
		print("First fail at attempt: ", r.first_fail)
		var diag = r.first_contradiction
		print("  cell: ", diag.get("cell"))
		print("  direction: ", diag.get("direction"))
		print("  from: ", diag.get("from_module_name"))
		print("  step: ", diag.get("step"))

	if r.violation_samples.size() > 0:
		print("\nViolation samples:")
		for v in r.violation_samples:
			print("  at ", v.pos, " ", v.dir, ": ", v.mod_a, " -> ", v.mod_b)

	assert(r.successes == r.attempts, "Strict sample should succeed for every deterministic seed")
	assert(r.total_violations == 0, "Strict sample should not report adjacency violations")

	# Also dump a sample grid
	if r.successes > 0:
		var result: WFCSolverResult = null
		for attempt_seed in range(r.attempts):
			var solver = WFCSolver.new()
			solver.init(ms, 6, 6, false)
			var attempt = solver.solve(attempt_seed)
			if attempt.success:
				result = attempt
				break
		assert(result != null and result.success, "Sample strict grid should succeed for at least one deterministic seed")
		print("\nSample grid (6x6):")
		print(result.dump_text())
		var violations = result.validate()
		print("Violations in this grid: ", violations.size())
		assert(violations.is_empty(), "Sample strict grid should validate cleanly")

	print("\n=== Done ===")
