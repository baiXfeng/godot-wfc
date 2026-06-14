class_name WFCSolver
extends RefCounted

signal generation_started()
signal cell_collapsed(x: int, y: int, module_index: int)
signal propagation_finished(affected_count: int)
signal generation_finished(result: WFCSolverResult)
signal contradiction(x: int, y: int)

var _module_set: WFCModuleSet
var _width: int
var _height: int
var _periodic: bool
var _step_solver: WFCStepSolver
var _last_contradiction: Dictionary = {}


func init(p_module_set: WFCModuleSet, p_width: int, p_height: int, p_periodic: bool = false) -> void:
	_module_set = p_module_set
	_width = max(1, p_width)
	_height = max(1, p_height)
	_periodic = p_periodic


func solve(seed: int = -1) -> WFCSolverResult:
	if _module_set == null or _module_set.modules.is_empty():
		return _make_empty_result(false)

	_step_solver = WFCStepSolver.new()
	_step_solver.generation_started.connect(func(): generation_started.emit())
	_step_solver.cell_collapsed.connect(func(x: int, y: int, module_index: int): cell_collapsed.emit(x, y, module_index))
	_step_solver.propagation_finished.connect(func(affected_count: int): propagation_finished.emit(affected_count))
	_step_solver.contradiction.connect(func(x: int, y: int): contradiction.emit(x, y))
	_step_solver.generation_finished.connect(func(result: WFCSolverResult): generation_finished.emit(result))
	_step_solver.init(_module_set, _width, _height, _periodic, seed)
	var result = _step_solver.finish()
	_last_contradiction = _step_solver.get_last_contradiction()
	return result


func step() -> int:
	assert(false, "step() not supported on WFCSolver wrapper — use WFCStepSolver directly")
	return -1


func _make_empty_result(success: bool) -> WFCSolverResult:
	var result = WFCSolverResult.new()
	result.width = max(1, _width)
	result.height = max(1, _height)
	result.success = success
	result.module_set = _module_set
	result.grid.resize(result.width * result.height)
	result.grid.fill(-1)
	return result


## Try [attempts] deterministic seeds on [module_set] at [width]x[height].
## Returns a Dictionary {attempts: int, successes: int, first_fail: int}
static func verify(module_set: WFCModuleSet, width: int = 10, height: int = 10, attempts: int = 20) -> Dictionary:
	var success := 0
	var first_fail := -1
	var first_diag: Dictionary = {}
	var total_violations := 0
	var violation_samples: Array = []

	for i in range(attempts):
		var solver = WFCSolver.new()
		solver.init(module_set, width, height, false)
		var result = solver.solve(i)
		if result.success:
			success += 1
			var violations = result.validate()
			total_violations += violations.size()
			if violations.size() > 0 and violation_samples.size() < 5:
				for v in violations:
					violation_samples.append(v)
		elif first_fail < 0:
			first_fail = i
			first_diag = solver._last_contradiction.duplicate()
			if first_diag.has("from_cell") and first_diag["from_cell"].x >= 0:
				var mods = first_diag.get("from_modules", [])
				var names = []
				for mid in mods:
					names.append(module_set.modules[mid].module_name)
				first_diag["from_module_names"] = names
			if first_diag.has("from_collapsed") and first_diag["from_collapsed"] >= 0:
				first_diag["from_module_name"] = module_set.modules[first_diag["from_collapsed"]].module_name

	return {
		"attempts": attempts,
		"successes": success,
		"first_fail": first_fail,
		"first_contradiction": first_diag,
		"total_violations": total_violations,
		"violation_samples": violation_samples.slice(0, 10),
	}
