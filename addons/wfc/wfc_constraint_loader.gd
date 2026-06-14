class_name WFCConstraintLoader
extends RefCounted

static func load_constraints(json_path: String) -> WFCConstraints:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("WFCConstraintLoader: Cannot open file: ", json_path)
		return null

	var json = JSON.parse_string(file.get_as_text())
	if not json is Dictionary:
		push_error("WFCConstraintLoader: Invalid JSON in: ", json_path)
		return null

	var constraints = WFCConstraints.new()
	constraints.width = _as_int((json as Dictionary).get("width", 0))
	constraints.height = _as_int((json as Dictionary).get("height", 0))
	constraints.fixed_tiles = _parse_entries((json as Dictionary).get("fixed_tiles", []), true)
	constraints.allowed_groups = _parse_entries((json as Dictionary).get("allowed_groups", []), false)
	constraints.blocked_groups = _parse_entries((json as Dictionary).get("blocked_groups", []), false)
	return constraints


static func _parse_entries(raw_entries, expect_tile: bool) -> Array:
	var entries: Array = []
	if not raw_entries is Array:
		return entries
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var parsed := {
			"x": _as_int(entry.get("x", -1)),
			"y": _as_int(entry.get("y", -1)),
		}
		if expect_tile:
			parsed["tile"] = str(entry.get("tile", ""))
		else:
			parsed["groups"] = _parse_groups(entry.get("groups", []))
		entries.append(parsed)
	return entries


static func _parse_groups(raw_groups) -> PackedStringArray:
	var groups := PackedStringArray()
	if raw_groups is Array:
		for group_name in raw_groups:
			var name = str(group_name)
			if not name.is_empty() and not groups.has(name):
				groups.append(name)
	return groups


static func _as_int(value) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and not (value as String).is_empty():
		return (value as String).to_int()
	return 0
