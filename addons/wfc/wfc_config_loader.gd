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
	var rotate_raw = entry.get("rotate", null)
	var color: Color = _parse_color(entry.get("color", ""), name)
	var texture_path: String = entry.get("texture", "")
	if texture_path.is_empty():
		texture_path = name + ".png"

	var cl_data = entry.get("cl")
	var base_cl: Array = _parse_connector_sides(cl_data) if cl_data is Array else []
	var cr_data = entry.get("cr")
	var base_cr: Array = _parse_connector_sides(cr_data) if cr_data is Array else []

	var rotations: Array = []
	if rotate_raw is Array:
		rotations = rotate_raw.duplicate()

	var has_rotations = not rotations.is_empty()
	var out: Array[WFCModule] = []

	# Rotation 0 always exists
	var mod0 = _make_module(name, 0, has_rotations, weight, color, base_cl, base_cr)
	out.append(mod0)
	for r in rotations:
		var mod = _make_module(name, r, true, weight, color, base_cl, base_cr)
		out.append(mod)
	return out


static func _make_module(name: String, rot: int, has_rotations: bool, weight: float, color: Color, base_cl: Array, base_cr: Array) -> WFCModule:
	var mod = WFCModule.new()
	mod.module_name = name + "_" + str(rot) if has_rotations else name
	mod.weight = weight
	mod.preview_color = color

	var cl_dict: Dictionary = {}
	var cr_dict: Dictionary = {}
	for d in range(4):
		var src_idx = posmod(d - rot, 4)
		if base_cl.size() == 4:
			cl_dict[_DIRECTIONS[d]] = (base_cl[src_idx] as Array).duplicate()
		if base_cr.size() == 4:
			cr_dict[_DIRECTIONS[d]] = (base_cr[src_idx] as Array).duplicate()
	mod.connect_id_l = cl_dict
	mod.connect_id_r = cr_dict
	return mod


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

static func _parse_connector_sides(data: Array) -> Array:
	var out: Array = []
	out.resize(data.size())
	for i in range(data.size()):
		out[i] = _parse_connector_ids(data[i])
	return out


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
