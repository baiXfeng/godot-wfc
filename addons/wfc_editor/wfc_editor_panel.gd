@tool
class_name WFCEditorPanel
extends Control

var plugin: EditorPlugin

# --- state ---
var _dir_path: String = ""
var _tile_data: Dictionary = {}
var _tile_textures: Dictionary = {}
var _selected_main: String = ""
var _selected_candidate: String = ""

const _DIRECTIONS = ["north", "east", "south", "west"]
const _PREFS_PATH := "user://wfc_editor_prefs.json"
const DEBUG_LOG := false

var _last_dir: String = ""

var _load_screen: Control
var _editor_screen: Control
var _dir_label: Label
var _left: WFCEditorLeft
var _center: WFCEditorCenter
var _right: WFCEditorRight


func _ready() -> void:
	custom_minimum_size = Vector2(900, 600)
	_load_screen = $LoadScreen
	_editor_screen = $EditorScreen
	_dir_label = $EditorScreen/TopBar/DirLabel
	_instantiate_columns()
	_connect_signals()
	_load_prefs()
	_editor_screen.hide()


func _instantiate_columns() -> void:
	var split = $EditorScreen/HSplit

	_left = load("res://addons/wfc_editor/wfc_editor_left.tscn").instantiate()
	_left.custom_minimum_size = Vector2(210, 0)
	split.add_child(_left)

	_center = load("res://addons/wfc_editor/wfc_editor_center.tscn").instantiate()
	split.add_child(_center)

	_right = load("res://addons/wfc_editor/wfc_editor_right.tscn").instantiate()
	_right.custom_minimum_size = Vector2(210, 0)
	split.add_child(_right)

	_left.tile_selected.connect(_on_main_selected)
	_right.tile_selected.connect(_on_candidate_selected)
	_center.slot_checked.connect(_on_slot_checked)
	_center.rotation_toggled.connect(_on_rotation_toggled)


func _connect_signals() -> void:
	$LoadScreen/LoadButton.pressed.connect(_on_load_pressed)
	$EditorScreen/TopBar/BackButton.pressed.connect(_on_back_pressed)
	$EditorScreen/TopBar/SaveButton.pressed.connect(_on_save_pressed)


# ------- actions -------

func _on_load_pressed() -> void:
	var fd = EditorFileDialog.new()
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	if not _last_dir.is_empty():
		fd.current_dir = _last_dir
	fd.dir_selected.connect(func(path):
		_load_directory(path)
		fd.queue_free()
	)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


func _load_directory(path: String) -> void:
	_dir_path = path; _last_dir = path; _save_prefs()
	_tile_data.clear(); _tile_textures.clear()

	var dir = DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var base = file_name.trim_suffix(".png")
			_tile_data[base] = {
				"texture_path": path + "/" + file_name,
				"color": Color.WHITE,
				"connectors": [[], [], [], []]
			}
			var tex = load(path + "/" + file_name) as Texture2D
			if tex: _tile_textures[base] = tex
		file_name = dir.get_next()

	if FileAccess.file_exists(path + "/modules.json"):
		_load_modules_json(path + "/modules.json")

	_refresh_tile_grids()
	_dir_label.text = path
	_load_screen.hide(); _editor_screen.show()


func _load_modules_json(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return
	var json = JSON.parse_string(file.get_as_text())
	if json == null or not json.has("modules"): return

	for entry in json["modules"]:
		var name = entry.get("name", "")
		if not _tile_data.has(name): continue
		var connectors = entry.get("connectors", [])
		if connectors is Array and connectors.size() == 4:
			var parsed = []
			for s in connectors:
				if s is String and not s.is_empty():
					parsed.append(s.split(",", false))
				else:
					parsed.append([])
			_tile_data[name]["connectors"] = parsed
		if entry.has("weight"): _tile_data[name]["weight"] = entry["weight"]
		if entry.has("rotate"): _tile_data[name]["rotate"] = entry["rotate"]


func _refresh_tile_grids() -> void:
	var names = _tile_data.keys(); names.sort()
	_left.populate(names, _tile_textures)
	_right.populate(names, _tile_textures)
	_selected_main = ""; _selected_candidate = ""
	_center.set_main("", null)
	_center.hide_rotations()


# ------- event handling -------

func _on_main_selected(tile_name: String) -> void:
	_selected_main = tile_name
	_left.highlight(tile_name)
	_center.set_main(tile_name, _tile_textures.get(tile_name))
	_right.set_enabled(true)

	var rot_data = _get_rotations(tile_name)
	_center.show_rotations(rot_data)
	_populate_right_with_rotations()

	if _get_base_name(_selected_candidate) == _selected_candidate:
		# candidate is a base name, re-apply
		if not _selected_candidate.is_empty():
			_on_candidate_selected(_selected_candidate)
		else:
			_center.clear_candidate(); _center.reset_slots()
	else:
		_center.clear_candidate(); _center.reset_slots()

	_refresh_right_colors()


func _on_candidate_selected(tile_name: String) -> void:
	if _selected_main.is_empty(): return
	_selected_candidate = tile_name
	_right.highlight(tile_name)

	var info = _resolve_variant(tile_name)
	var base = info["base"]; var rot = info["rotation"]
	var tex = _tile_textures.get(base)

	if DEBUG_LOG:
		_log("candidate=%s base=%s rot=%d tex=%s" % [tile_name, base, rot, "ok" if tex else "NULL"])

	_center.set_candidate(tile_name, tex, rot)

	for dir in _DIRECTIONS:
		var connected = _is_connected_variant(_selected_main, dir, tile_name)
		_center.set_slot_connected(dir, connected)


func _on_slot_checked(dir: String, checked: bool) -> void:
	if _selected_main.is_empty() or _selected_candidate.is_empty(): return
	if checked:
		_add_connection_variant(_selected_main, dir, _selected_candidate)
	else:
		_remove_connection_variant(_selected_main, dir, _selected_candidate)
	_refresh_right_colors()


func _on_rotation_toggled(deg: int, enabled: bool) -> void:
	if _selected_main.is_empty(): return
	var data = _tile_data[_selected_main]
	var rots: Array = data.get("rotate", [])
	if enabled:
		var r = deg / 90
		if not rots.has(r): rots.append(r); rots.sort()
	else:
		var r = deg / 90; rots.erase(r)
	if rots.is_empty():
		data.erase("rotate")
	else:
		data["rotate"] = rots

	_populate_right_with_rotations()
	if not _selected_candidate.is_empty():
		if _get_base_name(_selected_candidate) == _selected_candidate:
			_on_candidate_selected(_selected_candidate)
		else:
			# Candidate was a rotated variant that may have been removed
			if not _right._items.has(_selected_candidate):
				_selected_candidate = ""
				_center.clear_candidate(); _center.reset_slots()
	_refresh_right_colors()


func _refresh_right_colors() -> void:
	if _selected_main.is_empty(): return
	for name in _right._items:
		var count := 0
		for dir in _DIRECTIONS:
			if _is_connected_variant(_selected_main, dir, name):
				count += 1
		_right.set_connection_count(name, count)


# ------- right column variant management -------

func _populate_right_with_rotations() -> void:
	# Start with base names
	var bases = _tile_data.keys(); bases.sort()
	# Clear and rebuild (simpler than diff-based updates)
	_right._clear()
	for base in bases:
		_right._add_item(base, _tile_textures.get(base))
		var rots: Array = _tile_data[base].get("rotate", [])
		for r_raw in rots:
			var r: int = r_raw as int
			var vname = base + "_" + str(r)
			var rtex = _rotate_texture(_tile_textures.get(base), r)
			_right._add_item(vname, rtex)
			if DEBUG_LOG:
				_log("populate_right add %s rot=%d tex=%s" % [vname, r, "ok" if rtex else "NULL"])
	_right._reorder()
	_right._set_enabled(true)


func _rotate_texture(tex: Texture2D, rot: int) -> Texture2D:
	if tex == null or rot == 0: return tex
	var img = tex.get_image().duplicate()
	for _r in range(rot):
		img.rotate_90(CLOCKWISE)
	return ImageTexture.create_from_image(img)


# ------- variant helpers -------

func _get_base_name(tile_name: String) -> String:
	var info = _resolve_variant(tile_name)
	return info["base"]


func _resolve_variant(tile_name: String) -> Dictionary:
	var last = tile_name.rfind("_")
	if last > 0:
		var suffix = tile_name.substr(last + 1)
		if suffix == "0" or suffix == "1" or suffix == "2" or suffix == "3":
			var base = tile_name.substr(0, last)
			if _tile_data.has(base):
				return {"base": base, "rotation": suffix.to_int(), "variant": true}
	return {"base": tile_name, "rotation": 0, "variant": false}


func _get_rotations(tile_name: String) -> Array:
	var raw = _tile_data.get(tile_name, {}).get("rotate", [])
	var out: Array = []
	for r in raw: out.append(r as int)
	return out


# ------- data logic (supports rotated variants) -------

func _get_tags(tile: String, dir: String) -> Array:
	var info = _resolve_variant(tile)
	var base = info["base"]; var rot = info["rotation"]
	var base_dir_idx = posmod(_DIRECTIONS.find(dir) - rot, 4)
	var c: Array = _tile_data.get(base, {}).get("connectors", [[],[],[],[]])
	return c[base_dir_idx].duplicate() if c.size() == 4 else []


func _opposite_dir(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
	return ""


func _is_connected_variant(main: String, dir: String, cand: String) -> bool:
	var mt = _get_tags(main, dir); var ct = _get_tags(cand, _opposite_dir(dir))
	if mt.is_empty() or ct.is_empty(): return false
	for tag in mt:
		if _match_tag(tag, ct): return true
	return false


func _match_tag(tag: String, other: Array) -> bool:
	if tag.begins_with("L"): return ("R" + tag.substr(1)) in other
	if tag.begins_with("R"): return ("L" + tag.substr(1)) in other
	return tag in other


func _next_tag_id() -> int:
	var max_id = 0
	for name in _tile_data:
		for tags in _tile_data[name].get("connectors", []):
			for tag in tags:
				var v = (tag as String).trim_prefix("L").trim_prefix("R").to_int()
				if v > max_id: max_id = v
	return max_id + 1


func _add_connection_variant(main: String, dir: String, cand: String) -> void:
	var m_info = _resolve_variant(main); var c_info = _resolve_variant(cand)
	var m_base = m_info["base"]; var m_rot = m_info["rotation"]
	var c_base = c_info["base"]; var c_rot = c_info["rotation"]

	# Reverse-rotate to base coordinates
	var m_dir_idx = posmod(_DIRECTIONS.find(dir) - m_rot, 4)
	var c_dir_idx = posmod(_DIRECTIONS.find(_opposite_dir(dir)) - c_rot, 4)

	# Check existing
	var mt = _tile_data[m_base]["connectors"][m_dir_idx]
	var ct = _tile_data[c_base]["connectors"][c_dir_idx]
	for tag in mt:
		if tag.begins_with("L") and ("R" + tag.substr(1)) in ct: return
		if tag.begins_with("R") and ("L" + tag.substr(1)) in ct: return

	var tag_id = _next_tag_id()
	_tile_data[m_base]["connectors"][m_dir_idx].append("L%d" % tag_id)
	_tile_data[c_base]["connectors"][c_dir_idx].append("R%d" % tag_id)


func _remove_connection_variant(main: String, dir: String, cand: String) -> void:
	var m_info = _resolve_variant(main); var c_info = _resolve_variant(cand)
	var m_base = m_info["base"]; var m_rot = m_info["rotation"]
	var c_base = c_info["base"]; var c_rot = c_info["rotation"]

	var m_dir_idx = posmod(_DIRECTIONS.find(dir) - m_rot, 4)
	var c_dir_idx = posmod(_DIRECTIONS.find(_opposite_dir(dir)) - c_rot, 4)

	var mc: Array = _tile_data[m_base]["connectors"]
	var cc: Array = _tile_data[c_base]["connectors"]
	var rm = ""; var rc = ""
	for tag in mc[m_dir_idx]:
		if tag.begins_with("L") and ("R" + tag.substr(1)) in cc[c_dir_idx]: rm = tag; rc = "R" + tag.substr(1); break
		if tag.begins_with("R") and ("L" + tag.substr(1)) in cc[c_dir_idx]: rm = tag; rc = "L" + tag.substr(1); break
	if not rm.is_empty(): mc[m_dir_idx].erase(rm); cc[c_dir_idx].erase(rc)


# ------- save / back -------

func _on_save_pressed() -> void:
	if _dir_path.is_empty(): return
	var modules = []
	for tile_name in _tile_data:
		var data = _tile_data[tile_name]
		var conns = data.get("connectors", [[],[],[],[]])
		var strs = []
		for tags in conns:
			if tags.is_empty(): strs.append("")
			else:
				var dedup = {}; for t in tags: dedup[t] = true
				var keys = dedup.keys(); keys.sort(); strs.append(",".join(keys))
		var entry = {"name": tile_name, "connectors": strs}
		if data.has("weight"): entry["weight"] = data["weight"]
		if data.has("rotate"): entry["rotate"] = data["rotate"]
		modules.append(entry)

	var out = {"connector_colors": {}, "modules": modules}
	var file = FileAccess.open(_dir_path + "/modules.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(out, "\t")); file.close()


func _load_prefs() -> void:
	if not FileAccess.file_exists(_PREFS_PATH): return
	var f = FileAccess.open(_PREFS_PATH, FileAccess.READ)
	if f == null: return
	var json = JSON.parse_string(f.get_as_text())
	if json is Dictionary: _last_dir = json.get("last_dir", "")


func _save_prefs() -> void:
	var f = FileAccess.open(_PREFS_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"last_dir": _last_dir}))


func _on_back_pressed() -> void:
	_editor_screen.hide(); _load_screen.show()


func _log(msg: String) -> void:
	var f = FileAccess.open("user://wfc_editor.log", FileAccess.WRITE_READ)
	if f:
		f.seek_end()
		f.store_line(msg)
		f.close()
