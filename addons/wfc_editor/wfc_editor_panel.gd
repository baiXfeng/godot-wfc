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
const _EDITOR_CONFIG_NAME := "modules_editor.json"
const _RUNTIME_CONFIG_NAME := "modules.json"

var _last_dir: String = ""
var _last_atlas_dir: String = ""
var _left_cols: int = 2
var _right_cols: int = 2
var _dirty: bool = false
var _atlas_info: Dictionary = {}  # {path, columns, rows, name_template}

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
	$EditorScreen/TopBar/LeftCols.value = _left_cols
	$EditorScreen/TopBar/RightCols.value = _right_cols
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
	_center.weight_changed.connect(_on_weight_changed)


func _connect_signals() -> void:
	$LoadScreen/LoadBox/DirButton.pressed.connect(_on_directory_load)
	$LoadScreen/LoadBox/AtlasButton.pressed.connect(_on_atlas_load)
	$EditorScreen/TopBar/BackButton.pressed.connect(_on_back_pressed)
	$EditorScreen/TopBar/SaveButton.pressed.connect(_on_save_pressed)
	$EditorScreen/TopBar/LeftCols.value_changed.connect(func(v):
		_left_cols = v as int; _left.set_columns(_left_cols); _save_prefs()
	)
	$EditorScreen/TopBar/RightCols.value_changed.connect(func(v):
		_right_cols = v as int; _right.set_columns(_right_cols); _save_prefs()
	)


# ------- actions -------

func _on_directory_load() -> void:
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


func _on_atlas_load() -> void:
	_show_atlas_params()


func _show_atlas_params(file_path: String = "") -> void:
	var dlg = ConfirmationDialog.new()
	dlg.title = "图集参数"
	dlg.ok_button_text = "确认"

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# File path row
	var hrow = HBoxContainer.new()
	hrow.add_child(_make_label("文件路径:"))
	var path_edit = LineEdit.new(); path_edit.text = file_path; path_edit.custom_minimum_size = Vector2(200, 0); path_edit.size_flags_horizontal = 3
	hrow.add_child(path_edit)
	var browse_btn = Button.new(); browse_btn.text = "浏览..."
	browse_btn.pressed.connect(func():
		var fd = EditorFileDialog.new()
		fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		fd.access = EditorFileDialog.ACCESS_RESOURCES
		fd.add_filter("*.png", "PNG Images")
		if not _last_atlas_dir.is_empty():
			fd.current_dir = _last_atlas_dir
		fd.file_selected.connect(func(p): path_edit.text = p; fd.queue_free())
		fd.canceled.connect(func(): fd.queue_free())
		dlg.add_child(fd)
		fd.popup_centered_ratio(0.6)
	)
	hrow.add_child(browse_btn)
	vbox.add_child(hrow)

	# Columns row
	hrow = HBoxContainer.new()
	hrow.add_child(_make_label("列数:"))
	var cols_spin = SpinBox.new(); cols_spin.min_value = 1; cols_spin.max_value = 50; cols_spin.value = 4; cols_spin.rounded = true
	hrow.add_child(cols_spin); vbox.add_child(hrow)

	# Rows row
	hrow = HBoxContainer.new()
	hrow.add_child(_make_label("行数:"))
	var rows_spin = SpinBox.new(); rows_spin.min_value = 1; rows_spin.max_value = 50; rows_spin.value = 4; rows_spin.rounded = true
	hrow.add_child(rows_spin); vbox.add_child(hrow)

	dlg.add_child(vbox)

	dlg.confirmed.connect(func():
		var path = path_edit.text
		var cols = cols_spin.value as int
		var rows = rows_spin.value as int
		if path.is_empty(): return
		var tmpl = path.get_file().get_basename()
		_load_atlas(path, cols, rows, tmpl)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered_ratio(0.5)


func _make_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _load_atlas(file_path: String, columns: int, rows: int, name_template: String) -> void:
	var tex = load(file_path) as Texture2D
	if tex == null: return
	var img = tex.get_image()
	if img == null: return

	var dir = file_path.get_base_dir()
	_dir_path = dir; _last_dir = dir; _last_atlas_dir = dir; _save_prefs()
	_atlas_info = {"path": file_path.get_file(), "columns": columns, "rows": rows, "name_template": name_template}
	_tile_data.clear(); _tile_textures.clear()
	_dirty = false; _update_save_button()

	var tw = img.get_width() / columns
	var th = img.get_height() / rows

	for row in range(rows):
		for col in range(columns):
			var tile_name = "%s_%d_%d" % [name_template, row, col]
			var region = img.get_region(Rect2i(col * tw, row * th, tw, th))
			var region_tex = ImageTexture.create_from_image(region)
			_tile_data[tile_name] = {
				"texture_path": file_path,
				"color": Color.WHITE,
				"connectors": [[], [], [], []]
			}
			_tile_textures[tile_name] = region_tex

	# Load existing editor config if present
	if FileAccess.file_exists(_editor_config_path(dir)):
		_load_editor_json(_editor_config_path(dir))

	_refresh_tile_grids()
	_dir_label.text = dir
	_load_screen.hide(); _editor_screen.show()


func _load_directory(path: String) -> void:
	_dir_path = path; _last_dir = path; _save_prefs()
	_atlas_info = {}
	_tile_data.clear(); _tile_textures.clear()
	_dirty = false
	_update_save_button()

	var dir = DirAccess.open(path)
	if dir == null: return

	var editor_config_path = _editor_config_path(path)
	var editor_atlas = _read_editor_atlas(editor_config_path)
	if not editor_atlas.is_empty():
		var atlas_path = path + "/" + editor_atlas["path"]
		if FileAccess.file_exists(atlas_path):
			_load_atlas(atlas_path, editor_atlas["columns"] as int, editor_atlas["rows"] as int, editor_atlas["name_template"])
			return

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

	if FileAccess.file_exists(editor_config_path):
		_load_editor_json(editor_config_path)

	_refresh_tile_grids()
	_dir_label.text = path
	_load_screen.hide(); _editor_screen.show()


func _load_editor_json(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return
	var json = JSON.parse_string(file.get_as_text())
	if not json is Dictionary or not json.has("tiles"): return

	if json.has("atlas") and json["atlas"] is Dictionary:
		_atlas_info = (json["atlas"] as Dictionary).duplicate(true)

	var tiles: Dictionary = json["tiles"]
	for name in tiles:
		if not _tile_data.has(name):
			continue
		var tile_entry = tiles[name]
		if not tile_entry is Dictionary:
			continue
		var data: Dictionary = tile_entry
		if data.has("connectors"):
			var parsed = _parse_editor_connectors(data["connectors"])
			if parsed.size() == 4:
				_tile_data[name]["connectors"] = parsed
		if data.has("weight"):
			_tile_data[name]["weight"] = data["weight"]
		if data.has("rotate") and data["rotate"] is Array:
			_tile_data[name]["rotate"] = (data["rotate"] as Array).duplicate()
		else:
			_tile_data[name].erase("rotate")


func _refresh_tile_grids() -> void:
	var names = _tile_data.keys(); names.sort()
	_left.populate(names, _tile_textures)
	_right.populate(names, _tile_textures)
	_selected_main = ""; _selected_candidate = ""
	_center.set_main("", null)
	_center.clear_candidate()
	_center.reset_slots()
	_center.hide_rotations()


# ------- event handling -------

func _on_main_selected(tile_name: String) -> void:
	_selected_main = tile_name
	_left.highlight(tile_name)
	_center.set_main(tile_name, _tile_textures.get(tile_name))
	_right.set_enabled(true)

	var rot_data = _get_rotations(tile_name)
	_center.show_rotations(rot_data)
	var w = _tile_data.get(tile_name, {}).get("weight", 1.0)
	_center.set_weight(w as float)
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
	_center.set_slot_connected(dir, checked)
	_refresh_right_colors()
	_mark_dirty()


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
	_mark_dirty()


func _on_weight_changed(value: float) -> void:
	if _selected_main.is_empty(): return
	_tile_data[_selected_main]["weight"] = value
	_mark_dirty()


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
	_save_editor_json()
	_save_runtime_modules_json()
	_dirty = false
	_update_save_button()


func _editor_config_path(base_dir: String = _dir_path) -> String:
	return base_dir + "/" + _EDITOR_CONFIG_NAME


func _runtime_config_path(base_dir: String = _dir_path) -> String:
	return base_dir + "/" + _RUNTIME_CONFIG_NAME


func _read_editor_atlas(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.parse_string(file.get_as_text())
	if not json is Dictionary:
		return {}
	if json.has("atlas") and json["atlas"] is Dictionary:
		return (json["atlas"] as Dictionary).duplicate(true)
	return {}


func _save_editor_json() -> void:
	var tiles := {}
	var names = _tile_data.keys()
	names.sort()
	for tile_name in names:
		var data: Dictionary = _tile_data[tile_name]
		var entry: Dictionary = {
			"connectors": _duplicate_tags_per_side(data.get("connectors", [[], [], [], []])),
			"weight": data.get("weight", 1.0),
		}
		if data.has("rotate"):
			entry["rotate"] = (data["rotate"] as Array).duplicate()
		tiles[tile_name] = entry

	var out: Dictionary = {
		"version": 1,
		"tiles": tiles,
	}
	if not _atlas_info.is_empty():
		out["atlas"] = _atlas_info.duplicate(true)
	var file = FileAccess.open(_editor_config_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()


func _save_runtime_modules_json() -> void:
	var out: Dictionary = {
		"version": 1,
		"modules": _build_runtime_modules(),
	}
	if not _atlas_info.is_empty():
		out["atlas"] = _atlas_info.duplicate(true)
	var file = FileAccess.open(_runtime_config_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()


func _build_runtime_modules() -> Array:
	var modules: Array = []
	var names = _tile_data.keys()
	names.sort()
	for tile_name in names:
		var data: Dictionary = _tile_data[tile_name]
		var rotations: Array = [0]
		for rot in _get_rotations(tile_name):
			rotations.append(rot)
		var has_variants = rotations.size() > 1
		for rot in rotations:
			modules.append(_build_runtime_module_entry(tile_name, data, rot, has_variants))
	return modules


func _build_runtime_module_entry(tile_name: String, data: Dictionary, rotation: int, has_variants: bool) -> Dictionary:
	var entry: Dictionary = {
		"name": _runtime_module_name(tile_name, rotation, has_variants),
		"weight": data.get("weight", 1.0),
		"edges": _build_runtime_edges(data.get("connectors", [[], [], [], []]), rotation),
	}
	return entry


func _runtime_module_name(tile_name: String, rotation: int, has_variants: bool) -> String:
	return tile_name + "_" + str(rotation) if has_variants else tile_name


func _build_runtime_edges(tags_per_side: Array, rotation: int) -> Dictionary:
	var edges: Dictionary = {}
	for dir_idx in range(_DIRECTIONS.size()):
		var src_idx = posmod(dir_idx - rotation, 4)
		var tags: Array = tags_per_side[src_idx] if src_idx < tags_per_side.size() else []
		var left_ids: Array = []
		var right_ids: Array = []
		for tag in tags:
			var tag_text = tag as String
			if tag_text.begins_with("L"):
				var id = tag_text.substr(1).to_int()
				if id >= 0 and not left_ids.has(id):
					left_ids.append(id)
			elif tag_text.begins_with("R"):
				var id = tag_text.substr(1).to_int()
				if id >= 0 and not right_ids.has(id):
					right_ids.append(id)
		edges[_DIRECTIONS[dir_idx]] = {
			"left": left_ids,
			"right": right_ids,
		}
	return edges


func _duplicate_tags_per_side(tags_per_side: Array) -> Array:
	var out: Array = []
	out.resize(4)
	for i in range(4):
		var side: Array = []
		if i < tags_per_side.size() and tags_per_side[i] is Array:
			for tag in tags_per_side[i]:
				var tag_text = tag as String
				if not tag_text.is_empty() and not side.has(tag_text):
					side.append(tag_text)
		out[i] = side
	return out


func _parse_editor_connectors(value) -> Array:
	var out: Array = []
	out.resize(4)
	for i in range(4):
		var side: Array = []
		if value is Array and i < value.size() and value[i] is Array:
			for tag in value[i]:
				var tag_text = tag as String
				if (tag_text.begins_with("L") or tag_text.begins_with("R")) and not side.has(tag_text):
					side.append(tag_text)
		out[i] = side
	return out


func _load_prefs() -> void:
	if not FileAccess.file_exists(_PREFS_PATH): return
	var f = FileAccess.open(_PREFS_PATH, FileAccess.READ)
	if f == null: return
	var json = JSON.parse_string(f.get_as_text())
	if json is Dictionary:
		_last_dir = json.get("last_dir", "")
		if json.has("left_cols"): _left_cols = json["left_cols"] as int
		if json.has("right_cols"): _right_cols = json["right_cols"] as int
		if json.has("last_atlas_dir"): _last_atlas_dir = json["last_atlas_dir"]


func _save_prefs() -> void:
	var f = FileAccess.open(_PREFS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"last_dir": _last_dir, "left_cols": _left_cols, "right_cols": _right_cols, "last_atlas_dir": _last_atlas_dir}))


func _on_back_pressed() -> void:
	if _dirty:
		_show_save_dialog()
	else:
		_do_back()


func _do_back() -> void:
	_editor_screen.hide(); _load_screen.show()


func _show_save_dialog() -> void:
	var dlg = ConfirmationDialog.new()
	dlg.title = "未保存的更改"
	dlg.dialog_text = "你有未保存的更改，是否保存后再返回？"
	dlg.ok_button_text = "保存并退出"
	dlg.cancel_button_text = "忽略并退出"
	dlg.add_button("关闭", false, "close")
	dlg.confirmed.connect(func():
		_on_save_pressed()
		_do_back()
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		_do_back()
		dlg.queue_free()
	)
	dlg.custom_action.connect(func(action):
		dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_update_save_button()


func _update_save_button() -> void:
	var btn: Button = $EditorScreen/TopBar/SaveButton
	if _dirty:
		btn.text = "保存配置(*)"
		btn.add_theme_color_override("font_color", Color.RED)
	else:
		btn.text = "保存配置"
		btn.add_theme_color_override("font_color", Color.WHITE)


func _log(msg: String) -> void:
	var f = FileAccess.open("user://wfc_editor.log", FileAccess.WRITE_READ)
	if f:
		f.seek_end()
		f.store_line(msg)
		f.close()
