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
		var modules = _parse_module_entry(entry)
		for m in modules:
			all_modules.append(m)

	module_set.modules = all_modules
	return module_set

static func _parse_module_entry(entry: Dictionary) -> Array[WFCModule]:
	var name: String = entry.get("name", "")
	var weight: float = entry.get("weight", 1.0)
	var rotate: bool = entry.get("rotate", false)
	var color: Color = _parse_color(entry.get("color", ""), name)
	var texture_path: String = entry.get("texture", "")
	if texture_path.is_empty():
		texture_path = name + ".png"

	var connectors_data = entry.get("connectors")
	var base_connectors := _parse_connectors(connectors_data)

	var out: Array[WFCModule] = []

	var rotation_count = 4 if rotate else 1
	for r in range(rotation_count):
		var mod = WFCModule.new()
		if rotate:
			mod.module_name = name + "_" + str(r)
		else:
			mod.module_name = name
		mod.weight = weight
		mod.preview_color = color

		var conn_dict: Dictionary = {}
		for d in range(4):
			var src_idx = posmod(d - r, 4)
			var tags: Array = base_connectors[src_idx]
			conn_dict[_DIRECTIONS[d]] = tags.duplicate()
		mod.connectors = conn_dict

		out.append(mod)

	return out

static func _parse_connectors(data) -> Array:
	var result: Array = []
	result.resize(4)
	for i in range(4):
		result[i] = []

	if data is String:
		var tags = _split_tags(data)
		for i in range(4):
			result[i] = tags.duplicate()
		return result

	if not data is Array:
		return result

	if data.size() == 4:
		var all_arrays := true
		var all_strings := true
		for item in data:
			if not item is Array:
				all_arrays = false
			if not item is String:
				all_strings = false

		if all_arrays:
			for i in range(4):
				result[i] = (data[i] as Array).duplicate()
			return result

		for i in range(4):
			var item = data[i]
			if item is String:
				result[i] = _split_tags(item)
			elif item is Array:
				result[i] = (item as Array).duplicate()
		return result

	return result

static func _split_tags(s: String) -> Array:
	var parts = s.split(",", false)
	var out: Array = []
	for p in parts:
		var trimmed = p.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out

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
