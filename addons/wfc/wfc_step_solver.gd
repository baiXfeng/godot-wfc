class_name WFCStepSolver
extends RefCounted

signal generation_started()
signal cell_collapsed(x: int, y: int, module_index: int)
signal propagation_finished(affected_count: int)
signal generation_finished(result: WFCSolverResult)
signal contradiction(x: int, y: int)

const STATUS_RUNNING := "running"
const STATUS_SUCCESS := "success"
const STATUS_FAILED := "failed"

const _DIRECTIONS: Array[String] = ["north", "east", "south", "west"]
const _DX: Dictionary = {"north": 0, "east": 1, "south": 0, "west": -1}
const _DY: Dictionary = {"north": -1, "east": 0, "south": 1, "west": 0}

var _module_set: WFCModuleSet
var _width: int
var _height: int
var _periodic: bool
var _rng: RandomNumberGenerator
var _module_count: int

var _wave: Array = []
var _observed: PackedInt32Array
var _sum_of_weights: PackedFloat64Array
var _entropy: PackedFloat64Array
var _decisions: Array = []
var _step_count: int = 0
var _done: bool = false
var _success: bool = false
var _last_contradiction: Dictionary = {}
var _last_action: String = ""
var _backtrack_count: int = 0


func init(p_module_set: WFCModuleSet, p_width: int, p_height: int, p_periodic: bool = false, seed: int = -1) -> void:
	_module_set = p_module_set
	_width = max(1, p_width)
	_height = max(1, p_height)
	_periodic = p_periodic
	_rng = RandomNumberGenerator.new()
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	_module_count = _module_set.modules.size() if _module_set else 0
	_done = _module_count == 0
	_success = false
	_last_contradiction = {}
	_last_action = "reset"
	_backtrack_count = 0
	_decisions.clear()
	_step_count = 0
	_initialize_wave()
	generation_started.emit()


func step() -> Dictionary:
	if _done:
		_last_action = "done"
		return _make_step_result("done")

	while true:
		var cell = _find_lowest_entropy_cell()
		if cell < 0:
			_done = true
			_success = true
			_last_action = "completed"
			generation_finished.emit(get_result())
			return _make_step_result("completed")

		var possible: Array = (_wave[cell] as Array).duplicate()
		if possible.is_empty():
			_record_empty_cell_contradiction(cell)
			if not _try_next_branch():
				_done = true
				_success = false
				_last_action = "failed"
				generation_finished.emit(get_result())
				return _make_step_result("failed")
			_backtrack_count += 1
			_last_action = "backtracked"
			return _make_step_result("backtracked")

		_decisions.append({
			"snapshot": _capture_state(),
			"cell": cell,
			"possible_count": possible.size(),
			"remaining": _build_branch_order(possible),
		})

		if _try_next_branch():
			_last_action = "collapsed"
			return _make_step_result("collapsed")

		_done = true
		_success = false
		_last_action = "failed"
		generation_finished.emit(get_result())
		return _make_step_result("failed")

	_last_action = "idle"
	return _make_step_result("idle")


func finish(max_steps: int = 100000) -> WFCSolverResult:
	var guard := 0
	while not _done and guard < max_steps:
		step()
		guard += 1
	if guard >= max_steps and not _done:
		_done = true
		_success = false
		_last_action = "failed"
		generation_finished.emit(get_result())
	return get_result()


func get_result() -> WFCSolverResult:
	var result = WFCSolverResult.new()
	result.width = _width
	result.height = _height
	result.success = _done and _success
	result.module_set = _module_set
	result.grid.resize(_width * _height)
	for i in range(_observed.size()):
		result.grid[i] = _observed[i]
	return result


func get_module_at(x: int, y: int) -> int:
	if x < 0 or x >= _width or y < 0 or y >= _height:
		return -1
	return _observed[y * _width + x]


func get_width() -> int:
	return _width


func get_height() -> int:
	return _height


func get_step_count() -> int:
	return _step_count


func get_collapsed_count() -> int:
	var count := 0
	for idx in _observed:
		if idx >= 0:
			count += 1
	return count


func is_done() -> bool:
	return _done


func is_success() -> bool:
	return _done and _success


func get_status() -> String:
	if not _done:
		return STATUS_RUNNING
	return STATUS_SUCCESS if _success else STATUS_FAILED


func get_last_contradiction() -> Dictionary:
	return _last_contradiction.duplicate(true)


func get_last_action() -> String:
	return _last_action


func get_backtrack_count() -> int:
	return _backtrack_count


func get_progress_ratio() -> float:
	var total = max(1, _width * _height)
	return float(get_collapsed_count()) / float(total)


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
		var weight = _module_set.modules[mod_idx].weight
		var probability = weight / sum_w
		entropy -= probability * log(max(probability, 1e-12))
	return entropy + _rng.randf() * 1e-6


func _find_lowest_entropy_cell() -> int:
	var best_cell := -1
	var best_entropy := INF
	for i in range(_wave.size()):
		if _observed[i] >= 0:
			continue
		if (_wave[i] as Array).is_empty():
			return i
		if _entropy[i] < best_entropy:
			best_entropy = _entropy[i]
			best_cell = i
	return best_cell


func _try_next_branch() -> bool:
	while not _decisions.is_empty():
		var frame: Dictionary = _decisions[_decisions.size() - 1]
		var remaining: Array = frame["remaining"]
		while not remaining.is_empty():
			_restore_state(frame["snapshot"])
			var chosen = remaining.pop_front() as int
			frame["remaining"] = remaining
			_decisions[_decisions.size() - 1] = frame
			var cell = frame["cell"] as int
			_collapse_to(cell, chosen, frame["possible_count"] as int)
			if _propagate(cell):
				return true
		_decisions.pop_back()
		_restore_state(frame["snapshot"])
	return false


func _collapse_to(cell_idx: int, chosen: int, possible_count: int) -> void:
	_wave[cell_idx] = [chosen]
	_observed[cell_idx] = chosen
	_sum_of_weights[cell_idx] = _module_set.modules[chosen].weight
	_entropy[cell_idx] = 0.0
	_step_count += 1
	var xy = _idx_to_xy(cell_idx)
	cell_collapsed.emit(xy.x, xy.y, chosen)


func _pick_weighted_candidate(possible: Array) -> int:
	var weight_sum := 0.0
	for mod_idx in possible:
		weight_sum += _module_set.modules[mod_idx].weight

	var target = _rng.randf() * weight_sum
	var cumulative := 0.0
	var chosen: int = possible[0]
	for i in range(possible.size()):
		cumulative += _module_set.modules[possible[i]].weight
		if target <= cumulative:
			chosen = possible[i]
			break
	return chosen


func _build_branch_order(possible: Array) -> Array:
	var remaining = possible.duplicate()
	var ordered: Array = []
	while not remaining.is_empty():
		var chosen = _pick_weighted_candidate(remaining)
		ordered.append(chosen)
		remaining.erase(chosen)
	return ordered


func _capture_state() -> Dictionary:
	var wave_copy: Array = []
	wave_copy.resize(_wave.size())
	for i in range(_wave.size()):
		wave_copy[i] = (_wave[i] as Array).duplicate()
	return {
		"wave": wave_copy,
		"observed": _observed.duplicate(),
		"sum_of_weights": _sum_of_weights.duplicate(),
		"entropy": _entropy.duplicate(),
		"step_count": _step_count,
	}


func _restore_state(snapshot: Dictionary) -> void:
	_wave = snapshot["wave"]
	_observed = snapshot["observed"]
	_sum_of_weights = snapshot["sum_of_weights"]
	_entropy = snapshot["entropy"]
	_step_count = snapshot["step_count"]


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

			var neighbor_idx = _xy_to_idx(nx, ny)
			if _observed[neighbor_idx] >= 0:
				continue

			var old_count = (_wave[neighbor_idx] as Array).size()
			var new_wave: Array = []
			for neighbor_module in (_wave[neighbor_idx] as Array):
				var found := false
				for current_module in (_wave[cell] as Array):
					if _module_set.are_compatible(current_module as int, neighbor_module as int, dir):
						found = true
						break
				if found:
					new_wave.append(neighbor_module)

			if new_wave.size() < old_count:
				affected += 1
				_wave[neighbor_idx] = new_wave
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
				_sum_of_weights[neighbor_idx] = sum_w
				_entropy[neighbor_idx] = _calc_shannon_entropy(neighbor_idx)
				stack.append(neighbor_idx)
	propagation_finished.emit(affected)
	return true


func _record_empty_cell_contradiction(cell_idx: int) -> void:
	_last_contradiction = {
		"cell": _idx_to_xy(cell_idx),
		"from_cell": Vector2i(-1, -1),
		"direction": "",
		"step": _step_count,
	}
	var xy = _idx_to_xy(cell_idx)
	contradiction.emit(xy.x, xy.y)


func _make_step_result(action: String) -> Dictionary:
	return {
		"status": get_status(),
		"action": action,
		"step_count": _step_count,
		"collapsed": get_collapsed_count(),
		"total": _width * _height,
	}


func _idx_to_xy(idx: int) -> Vector2i:
	return Vector2i(idx % _width, idx / _width)


func _xy_to_idx(x: int, y: int) -> int:
	return y * _width + x
