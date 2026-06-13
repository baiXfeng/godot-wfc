@tool
class_name WFCConfigLoader
extends RefCounted

const _DIRECTIONS: Array[String] = ["north", "east", "south", "west"]

static func load_module_set(json_path: String) -> WFCModuleSet:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("WFCConfigLoader: Cannot open file: ", json_path)
		return null

	var text = file.get_as_text()
	var json = JSON.parse_string(text)
	if json == null:
		push_error("WFCConfigLoader: Invalid JSON in: ", json_path)
		return null

	var modules_data: Array = json.get("modules", [])
	if modules_data.is_empty():
		push_error("WFCConfigLoader: No modules found in: ", json_path)
		return null

	var module_set = WFCModuleSet.new()
	var all_modules: Array[WFCModule] = []

	for entry in modules_data:
		if not entry is Dictionary:
			continue
		var module = _parse_module_entry(entry)
		if module:
			all_modules.append(module)

	module_set.modules = all_modules
	return module_set

static func _parse_module_entry(entry: Dictionary) -> WFCModule:
	var name: String = entry.get("name", "")
	if name.is_empty():
		return null
	var weight: float = entry.get("weight", 1.0)
	var color: Color = _parse_color(entry.get("color", ""), name)
	var edges_data = entry.get("edges", {})
	if not edges_data is Dictionary:
		push_error("WFCConfigLoader: Missing edges for module: ", name)
		return null
	return _make_module(name, weight, color, edges_data)


static func _make_module(name: String, weight: float, color: Color, edges_data: Dictionary) -> WFCModule:
	var mod = WFCModule.new()
	mod.module_name = name
	mod.weight = weight
	mod.preview_color = color

	var cl_dict: Dictionary = {}
	var cr_dict: Dictionary = {}
	for dir in _DIRECTIONS:
		var edge = edges_data.get(dir, {})
		if not edge is Dictionary:
			edge = {}
		cl_dict[dir] = _parse_connector_ids((edge as Dictionary).get("left", []))
		cr_dict[dir] = _parse_connector_ids((edge as Dictionary).get("right", []))
	mod.connect_id_l = cl_dict
	mod.connect_id_r = cr_dict
	return mod


static func _parse_connector_ids(value) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			var parsed = _connector_id_from_value(item)
			if parsed >= 0 and not out.has(parsed):
				out.append(parsed)
	else:
		var parsed = _connector_id_from_value(value)
		if parsed >= 0:
			out.append(parsed)
	return out


static func _connector_id_from_value(value) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and not (value as String).is_empty():
		return (value as String).to_int()
	return -1

static func _parse_color(hex: String, name: String) -> Color:
	if not hex.is_empty() and hex.begins_with("#"):
		var h = hex.substr(1)
		if h.length() >= 6:
			var r = h.substr(0, 2).hex_to_int() / 255.0
			var g = h.substr(2, 2).hex_to_int() / 255.0
			var b = h.substr(4, 2).hex_to_int() / 255.0
			var a = 1.0
			if h.length() >= 8:
				a = h.substr(6, 2).hex_to_int() / 255.0
			return Color(r, g, b, a)

	var h = hash(name) % 360
	return Color.from_hsv(float(h) / 360.0, 0.6, 0.85)
