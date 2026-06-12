class_name WFCSolverResult
extends RefCounted

var width: int
var height: int
var grid: PackedInt32Array
var success: bool
var module_set: WFCModuleSet

func get_module_at(x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return -1
	return grid[y * width + x]

func get_module_resource_at(x: int, y: int) -> WFCModule:
	var idx = get_module_at(x, y)
	if idx < 0 or module_set == null or module_set.modules.is_empty():
		return null
	return module_set.modules[idx]


## Return a compact text grid. Each module gets a short label.
func dump_text(labels: Dictionary = {}) -> String:
	# Auto-generate labels if not provided: use first 4 chars of module name
	if labels.is_empty() and module_set:
		var used = {}
		var auto_labels: Dictionary = {}
		var label_counts: Dictionary = {}
		for y in range(height):
			for x in range(width):
				var idx = get_module_at(x, y)
				if idx >= 0:
					used[idx] = true
		for idx in used:
			var short_label = module_set.modules[idx].module_name.left(4)
			auto_labels[idx] = short_label
			label_counts[short_label] = label_counts.get(short_label, 0) + 1
		for idx in used:
			var short_label = auto_labels[idx]
			labels[idx] = short_label if label_counts[short_label] == 1 else str(idx)
	var out := ""
	for y in range(height):
		for x in range(width):
			var idx = get_module_at(x, y)
			if idx >= 0:
				out += labels.get(idx, str(idx)).lpad(5)
			else:
				out += "  ?? "
		out += "\n"
	return out


## Validate all adjacent pairs. Returns an Array of violation dicts.
## Each violation: {pos: Vector2i, dir: String, mod_a: String, mod_b: String, reason: String}
func validate() -> Array:
	var violations: Array = []
	if not success or module_set == null:
		return violations

	var dirs = ["east", "south"]  # check each pair once
	var dx  = [1, 0]
	var dy  = [0, 1]

	for y in range(height):
		for x in range(width):
			var a = get_module_at(x, y)
			if a < 0: continue
			for di in range(2):
				var nx = x + dx[di]; var ny = y + dy[di]
				var b = get_module_at(nx, ny)
				if b < 0: continue
				if not module_set.are_compatible(a, b, dirs[di]):
					violations.append({
						"pos": Vector2i(x, y),
						"dir": dirs[di],
						"mod_a": module_set.modules[a].module_name,
						"mod_b": module_set.modules[b].module_name,
					})
	return violations
