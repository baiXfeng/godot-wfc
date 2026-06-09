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
	_dir_path = path
	_last_dir = path
	_save_prefs()
	_tile_data.clear()
	_tile_textures.clear()

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

	var config_path = path + "/modules.json"
	if FileAccess.file_exists(config_path):
		_load_modules_json(config_path)

	_refresh_tile_grids()
	_dir_label.text = path
	_load_screen.hide()
	_editor_screen.show()


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


# ------- event handling -------

func _on_main_selected(tile_name: String) -> void:
	_selected_main = tile_name
	_left.highlight(tile_name)
	_center.set_main(tile_name, _tile_textures.get(tile_name))
	_right.set_enabled(true)

	if _selected_candidate.is_empty():
		_center.clear_candidate()
		_center.reset_slots()
	else:
		_on_candidate_selected(_selected_candidate)

	_refresh_right_colors()


func _on_candidate_selected(tile_name: String) -> void:
	if _selected_main.is_empty(): return
	_selected_candidate = tile_name
	_right.highlight(tile_name)
	_center.set_candidate(tile_name, _tile_textures.get(tile_name))

	for dir in _DIRECTIONS:
		var connected = _is_connected(_selected_main, dir, _selected_candidate)
		_center.set_slot_connected(dir, connected)


func _on_slot_checked(dir: String, checked: bool) -> void:
	if _selected_main.is_empty() or _selected_candidate.is_empty(): return
	if checked:
		_add_connection(_selected_main, dir, _selected_candidate)
	else:
		_remove_connection(_selected_main, dir, _selected_candidate)
	_refresh_right_colors()


func _refresh_right_colors() -> void:
	if _selected_main.is_empty(): return
	var names = _tile_data.keys()
	for name in names:
		var count := 0
		for dir in _DIRECTIONS:
			if _is_connected(_selected_main, dir, name):
				count += 1
		_right.set_connection_count(name, count)


# ------- data logic -------

func _get_tags(tile: String, dir: String) -> Array:
	var idx = _DIRECTIONS.find(dir)
	if idx < 0: return []
	var c: Array = _tile_data.get(tile, {}).get("connectors", [[],[],[],[]])
	return c[idx].duplicate() if c.size() == 4 else []


func _opposite_dir(dir: String) -> String:
	match dir:
		"north":
			return "south"
		"south":
			return "north"
		"east":
			return "west"
		"west":
			return "east"
	return ""


func _is_connected(main: String, dir: String, cand: String) -> bool:
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


func _add_connection(main: String, dir: String, cand: String) -> void:
	if _is_connected(main, dir, cand): return
	var tag_id = _next_tag_id()
	_tile_data[main]["connectors"][_DIRECTIONS.find(dir)].append("L%d" % tag_id)
	_tile_data[cand]["connectors"][_DIRECTIONS.find(_opposite_dir(dir))].append("R%d" % tag_id)


func _remove_connection(main: String, dir: String, cand: String) -> void:
	var mi = _DIRECTIONS.find(dir); var ci = _DIRECTIONS.find(_opposite_dir(dir))
	var mc: Array = _tile_data[main]["connectors"]; var cc: Array = _tile_data[cand]["connectors"]
	if mc.size() != 4 or cc.size() != 4: return
	var rm = ""; var rc = ""
	for tag in mc[mi]:
		if tag.begins_with("L") and ("R" + tag.substr(1)) in cc[ci]: rm = tag; rc = "R" + tag.substr(1); break
		if tag.begins_with("R") and ("L" + tag.substr(1)) in cc[ci]: rm = tag; rc = "L" + tag.substr(1); break
	if not rm.is_empty(): mc[mi].erase(rm); cc[ci].erase(rc)


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
	if json is Dictionary:
		_last_dir = json.get("last_dir", "")


func _save_prefs() -> void:
	var f = FileAccess.open(_PREFS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"last_dir": _last_dir}))


func _on_back_pressed() -> void:
	_editor_screen.hide(); _load_screen.show()
