@tool
class_name WFCGenerator
extends Node2D

@export var module_set: WFCModuleSet:
	set(v):
		if module_set and module_set.changed.is_connected(_on_module_set_changed):
			module_set.changed.disconnect(_on_module_set_changed)
		module_set = v
		if module_set:
			module_set.changed.connect(_on_module_set_changed)
		_update_preview()

@export var grid_width: int = 10:
	set(v):
		grid_width = max(1, v)
		_update_preview()

@export var grid_height: int = 10:
	set(v):
		grid_height = max(1, v)
		_update_preview()

@export var seed: int = -1:
	set(v):
		seed = v
		_update_preview()

@export var periodic: bool = false:
	set(v):
		periodic = v
		_update_preview()

@export var cell_size: int = 16:
	set(v):
		cell_size = max(1, v)
		queue_redraw()

var _preview_result: WFCSolverResult

func _ready() -> void:
	if module_set and not module_set.changed.is_connected(_on_module_set_changed):
		module_set.changed.connect(_on_module_set_changed)
	if Engine.is_editor_hint():
		_update_preview()

func _on_module_set_changed() -> void:
	_update_preview()

func _update_preview() -> void:
	if not is_inside_tree():
		return

	if module_set == null or module_set.modules.is_empty():
		_preview_result = null
		queue_redraw()
		return

	var solver = WFCSolver.new()
	solver.init(module_set, grid_width, grid_height, periodic)
	_preview_result = solver.solve(seed)
	queue_redraw()

func _draw() -> void:
	if _preview_result == null or not _preview_result.success:
		return
	if module_set == null:
		return

	for y in range(_preview_result.height):
		for x in range(_preview_result.width):
			var mod_idx = _preview_result.get_module_at(x, y)
			if mod_idx >= 0 and mod_idx < module_set.modules.size():
				var color = module_set.modules[mod_idx].preview_color
				var rect = Rect2(Vector2(x, y) * cell_size, Vector2(cell_size, cell_size))
				draw_rect(rect, color)
				draw_rect(rect, Color.BLACK, false, 1.0)

func generate() -> WFCSolverResult:
	if module_set == null or module_set.modules.is_empty():
		return null
	var solver = WFCSolver.new()
	solver.init(module_set, grid_width, grid_height, periodic)
	return solver.solve(seed)
