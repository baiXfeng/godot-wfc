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
