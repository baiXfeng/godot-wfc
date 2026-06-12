class_name WFCSolver
extends RefCounted

signal generation_started()
signal cell_collapsed(x: int, y: int, module_index: int)
signal propagation_finished(affected_count: int)
signal generation_finished(result: WFCSolverResult)
signal contradiction(x: int, y: int)

const DEBUG_LOG := false
const _LOG_PATH := "user://wfc_solver.log"

var _module_set: WFCModuleSet
var _width: int
var _height: int
var _periodic: bool

var _wave: Array            # Array[Array]  — possible module indices per cell
var _observed: PackedInt32Array  # -1 if unobserved, else module index
var _sum_of_weights: PackedFloat64Array
var _entropy: PackedFloat64Array

var _rng: RandomNumberGenerator
var _module_count: int
var _step_count: int = 0
var _last_contradiction: Dictionary = {}

const _DIRECTIONS: Array[String] = ["north", "east", "south", "west"]
const _DX: Dictionary = {"north": 0, "east": 1, "south": 0, "west": -1}
const _DY: Dictionary = {"north": -1, "east": 0, "south": 1, "west": 0}

# ---------- public ----------

func init(p_module_set: WFCModuleSet, p_width: int, p_height: int, p_periodic: bool = false) -> void:
	_module_set = p_module_set
	_width = max(1, p_width)
	_height = max(1, p_height)
	_periodic = p_periodic
	_rng = RandomNumberGenerator.new()
	_module_count = _module_set.modules.size()

func solve(seed: int = -1) -> WFCSolverResult:
	if _module_count == 0:
		return _make_result(false)

	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()

	_slog("=== solve start seed=%d grid=%dx%d modules=%d ===" % [_rng.seed, _width, _height, _module_count])
	generation_started.emit()
	_initialize_wave()
	var result = _run()
	_slog("=== solve end success=%s ===" % result.success)
	generation_finished.emit(result)
	return result

func step() -> int:
	assert(false, "step() not yet implemented — use solve() for batch generation")
	return -1

# ---------- internal ----------

func _initialize_wave() -> void:
	var cell_count = _width * _height

	_wave.clear()
	_wave.resize(cell_count)
	_observed.clear()
	_observed.resize(cell_count)
	_observed.fill(-1)
	_sum_of_weights.clear()
	_sum_of_weights.resize(cell_count)
	_entropy.clear()
	_entropy.resize(cell_count)

	var all_modules: Array = []
	var total_weight := 0.0
	for mod in _module_set.modules:
		all_modules.append(all_modules.size())
		total_weight += mod.weight

	for i in range(cell_count):
		_wave[i] = all_modules.duplicate()
		_sum_of_weights[i] = total_weight
		_entropy[i] = _calc_shannon_entropy(i)

func _calc_shannon_entropy(cell_idx: int) -> float:
	var sum_w = _sum_of_weights[cell_idx]
	if sum_w <= 0.0:
		return INF

	var entropy := 0.0
	for mod_idx in _wave[cell_idx]:
		var w = _module_set.modules[mod_idx].weight
		var p = w / sum_w
		entropy -= p * log(max(p, 1e-12))

	entropy += _rng.randf() * 1e-6
	return entropy

func _run() -> WFCSolverResult:
	_step_count = 0
	while true:
		var cell = _find_lowest_entropy_cell()
		if cell < 0:
			break

		var possible: Array = _wave[cell]
		if possible.is_empty():
			var xy = _idx_to_xy(cell)
			_last_contradiction = {
				"cell": xy,
				"from_cell": Vector2i(-1, -1),
				"direction": "",
				"step": _step_count,
			}
			_slog("contradiction at (%d,%d) step=%d" % [xy.x, xy.y, _step_count])
			contradiction.emit(xy.x, xy.y)
			return _make_result(false)

		_observe(cell)

		if not _propagate(cell):
			return _make_result(false)

	return _make_result(true)

func _find_lowest_entropy_cell() -> int:
	var best_cell := -1
	var best_entropy := INF

	for i in range(_wave.size()):
		if _observed[i] >= 0:
			continue
		if _wave[i].is_empty():
			return i
		if _entropy[i] < best_entropy:
			best_entropy = _entropy[i]
			best_cell = i

	return best_cell

func _observe(cell_idx: int) -> void:
	var possible: Array = _wave[cell_idx]
	var weight_sum := 0.0
	for mod_idx in possible:
		weight_sum += _module_set.modules[mod_idx].weight

	var r = _rng.randf() * weight_sum
	var cumulative := 0.0
	var chosen: int = possible[0]
	for i in range(possible.size()):
		cumulative += _module_set.modules[possible[i]].weight
		if r <= cumulative:
			chosen = possible[i]
			break

	_wave[cell_idx] = [chosen]
	_observed[cell_idx] = chosen
	_sum_of_weights[cell_idx] = _module_set.modules[chosen].weight
	_entropy[cell_idx] = 0.0

	var xy = _idx_to_xy(cell_idx)
	_step_count += 1
	_slog("step=%d observe (%d,%d) module=%d (%d possible)" % [_step_count, xy.x, xy.y, chosen, possible.size()])
	cell_collapsed.emit(xy.x, xy.y, chosen)

func _propagate(start_cell: int) -> bool:
	var stack: Array = [start_cell]
	var affected := 0

	while not stack.is_empty():
		var cell = stack.pop_back()
		var xy = _idx_to_xy(cell)

		for dir in _DIRECTIONS:
			var nx = xy.x + (_DX[dir] as int)
			var ny = xy.y + (_DY[dir] as int)

			if not _periodic:
				if nx < 0 or nx >= _width or ny < 0 or ny >= _height:
					continue
			else:
				nx = posmod(nx, _width)
				ny = posmod(ny, _height)

			var ni = _xy_to_idx(nx, ny)
			if _observed[ni] >= 0:
				continue

			var old_count = (_wave[ni] as Array).size()
			var new_wave: Array = []
			for mod_n in (_wave[ni] as Array):
				var found := false
				for mod_c in (_wave[cell] as Array):
					if _module_set.are_compatible(mod_c as int, mod_n as int, dir):
						found = true
						break
				if found:
					new_wave.append(mod_n)

			if new_wave.size() < old_count:
				affected += 1
				_wave[ni] = new_wave

				if new_wave.is_empty():
					_last_contradiction = {
						"cell": Vector2i(nx, ny),
						"from_cell": xy,
						"direction": dir,
						"from_modules": _wave[cell].duplicate(),
						"from_collapsed": _observed[cell],
						"step": _step_count,
					}
					contradiction.emit(nx, ny)
					return false

				var sum_w := 0.0
				for mod_idx in new_wave:
					sum_w += _module_set.modules[mod_idx].weight
				_sum_of_weights[ni] = sum_w
				_entropy[ni] = _calc_shannon_entropy(ni)

				stack.append(ni)

	propagation_finished.emit(affected)
	return true

func _make_result(success: bool) -> WFCSolverResult:
	var result = WFCSolverResult.new()
	result.width = _width
	result.height = _height
	result.success = success
	result.module_set = _module_set
	result.grid.resize(_width * _height)
	for i in range(_observed.size()):
		result.grid[i] = _observed[i]
	return result

func _idx_to_xy(idx: int) -> Vector2i:
	return Vector2i(idx % _width, idx / _width)

func _xy_to_idx(x: int, y: int) -> int:
	return y * _width + x


# ------- static verification -------

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
				var fc = first_diag["from_cell"] as Vector2i
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


func _slog(msg: String) -> void:
	if not DEBUG_LOG: return
	var f = FileAccess.open(_LOG_PATH, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line(msg)
		f.close()
