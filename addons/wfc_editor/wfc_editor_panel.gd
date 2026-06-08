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
const _THUMB_SIZE := 64

# --- column roots ---
var _left_root: Control
var _center_root: Control
var _right_root: Control

# column node refs
var _load_screen: Control
var _editor_screen: Control
var _dir_label: Label
var _left_grid: GridContainer
var _right_grid: GridContainer
var _center_tex: TextureRect
var _center_label: Label
var _slot_tex: Dictionary = {}
var _slot_label: Dictionary = {}
var _slot_check: Dictionary = {}
var _left_items: Dictionary = {}
var _right_items: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(900, 600)
	_store_root_refs()
	_instantiate_columns()
	_store_column_refs()
	_connect_signals()
	_editor_screen.hide()


func _store_root_refs() -> void:
	_load_screen = $LoadScreen
	_editor_screen = $EditorScreen
	_dir_label = $EditorScreen/TopBar/DirLabel


func _instantiate_columns() -> void:
	var split = $EditorScreen/HSplit

	_left_root = load("res://addons/wfc_editor/wfc_editor_left.tscn").instantiate()
	_left_root.custom_minimum_size = Vector2(210, 0)
	split.add_child(_left_root)

	_center_root = load("res://addons/wfc_editor/wfc_editor_center.tscn").instantiate()
	split.add_child(_center_root)

	_right_root = load("res://addons/wfc_editor/wfc_editor_right.tscn").instantiate()
	_right_root.custom_minimum_size = Vector2(210, 0)
	split.add_child(_right_root)


func _store_column_refs() -> void:
	_left_grid = _left_root.get_node("Scroll/Grid")
	_right_grid = _right_root.get_node("Scroll/Grid")
	_center_tex = _center_root.get_node("MidRow/CenterTile/CenterTex")
	_center_label = _center_root.get_node("MidRow/CenterTile/CenterLabel")

	for dir in _DIRECTIONS:
		var cap = dir.capitalize()
		var slot: Node
		if dir == "north":
			slot = _center_root.get_node("SlotNorth")
		elif dir == "south":
			slot = _center_root.get_node("SlotSouth")
		elif dir == "west":
			slot = _center_root.get_node("MidRow/SlotWest")
		else:
			slot = _center_root.get_node("MidRow/SlotEast")

		_slot_tex[dir]   = slot.get_node("Tex" + cap[0])
		_slot_label[dir] = slot.get_node("Label" + cap[0])
		_slot_check[dir] = slot.get_node("Check" + cap[0])


func _connect_signals() -> void:
	$LoadScreen/LoadButton.pressed.connect(_on_load_pressed)
	$EditorScreen/TopBar/BackButton.pressed.connect(_on_back_pressed)
	$EditorScreen/TopBar/SaveButton.pressed.connect(_on_save_pressed)

	for dir in _DIRECTIONS:
		var check: CheckBox = _slot_check[dir]
		var d = dir
		check.toggled.connect(func(v): _on_slot_checked(d, v))


# ------- actions -------

func _on_load_pressed() -> void:
	var fd = EditorFileDialog.new()
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.dir_selected.connect(func(path):
		_load_directory(path)
		fd.queue_free()
	)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


func _load_directory(path: String) -> void:
	_dir_path = path
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
	for c in _left_grid.get_children(): c.queue_free()
	_left_items.clear()
	for c in _right_grid.get_children(): c.queue_free()
	_right_items.clear()

	var names = _tile_data.keys(); names.sort()

	for tile_name in names:
		var item = _make_tile_item(tile_name, false)
		_left_grid.add_child(item)
		_left_items[tile_name] = item

		var ritem = _make_tile_item(tile_name, true)
		ritem.modulate = Color(0.5, 0.5, 0.5, 1)
		_right_grid.add_child(ritem)
		_right_items[tile_name] = ritem

	_selected_main = ""; _selected_candidate = ""
	_update_center()
	_update_right_enabled(false)


func _make_tile_item(tile_name: String, is_right: bool) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(_THUMB_SIZE + 12, _THUMB_SIZE + 26)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.15, 0.15, 1)
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2;  s.border_width_bottom = 2
	s.border_color = Color(0.15, 0.15, 0.15, 1)
	panel.add_theme_stylebox_override("panel", s)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var rect = TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(_THUMB_SIZE, _THUMB_SIZE)
	var tex = _tile_textures.get(tile_name)
	if tex: rect.texture = tex
	vbox.add_child(rect)

	var label = Label.new()
	label.text = tile_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.clip_text = true
	label.custom_minimum_size = Vector2(_THUMB_SIZE, 16)
	vbox.add_child(label)

	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_tile_clicked(tile_name, is_right)
	)
	return panel


func _on_tile_clicked(tile_name: String, is_right: bool) -> void:
	if is_right:
		if _selected_main.is_empty(): return
		_selected_candidate = tile_name
		_update_right_highlight()
		_update_center()
	else:
		_selected_main = tile_name
		_selected_candidate = ""
		_update_left_highlight()
		_update_center()
		_update_right_enabled(true)
		_refresh_right_colors()


func _update_left_highlight() -> void:
	for name in _left_items:
		var p = _left_items[name]
		var st = p.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		st.border_color = Color(0.3, 0.7, 1.0, 1) if name == _selected_main else Color(0.15, 0.15, 0.15, 1)
		p.add_theme_stylebox_override("panel", st)


func _update_right_highlight() -> void:
	for name in _right_items:
		var p = _right_items[name]
		var st = p.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		st.border_color = Color(0.3, 0.7, 1.0, 1) if name == _selected_candidate else Color(0.15, 0.15, 0.15, 1)
		p.add_theme_stylebox_override("panel", st)


func _update_center() -> void:
	if _selected_main.is_empty():
		_center_tex.texture = null
		_center_tex.modulate = Color(0.5, 0.5, 0.5, 1)
		_center_label.text = ""
	else:
		_center_tex.texture = _tile_textures.get(_selected_main)
		_center_tex.modulate = Color.WHITE
		_center_label.text = _selected_main

	var cand_tex = _tile_textures.get(_selected_candidate) if not _selected_candidate.is_empty() else null
	for dir in _DIRECTIONS:
		var tex: TextureRect = _slot_tex[dir]
		var label: Label = _slot_label[dir]
		if cand_tex:
			tex.texture = cand_tex; label.text = _selected_candidate
		else:
			tex.texture = null; label.text = ""
		_update_slot_appearance(dir)


func _update_slot_appearance(dir: String) -> void:
	var tex: TextureRect = _slot_tex[dir]
	var check: CheckBox = _slot_check[dir]
	if _selected_main.is_empty() or _selected_candidate.is_empty():
		check.button_pressed = false
		tex.modulate = Color(0.3, 0.3, 0.3, 1)
		check.visible = false
		return

	check.visible = true
	var connected = _is_connected(_selected_main, dir, _selected_candidate)
	check.set_block_signals(true)
	check.button_pressed = connected
	check.set_block_signals(false)
	tex.modulate = Color.WHITE if connected else Color(0.35, 0.35, 0.35, 1)


func _on_slot_checked(dir: String, checked: bool) -> void:
	if _selected_main.is_empty() or _selected_candidate.is_empty(): return
	if checked:
		_add_connection(_selected_main, dir, _selected_candidate)
	else:
		_remove_connection(_selected_main, dir, _selected_candidate)
	_update_slot_appearance(dir)
	_refresh_right_colors()


func _update_right_enabled(enabled: bool) -> void:
	for name in _right_items:
		_right_items[name].modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 1)


func _refresh_right_colors() -> void:
	if _selected_main.is_empty(): return
	for name in _right_items:
		var has = false
		for dir in _DIRECTIONS:
			if _is_connected(_selected_main, dir, name): has = true; break
		_right_items[name].modulate = Color.WHITE if has else Color(0.5, 0.5, 0.5, 1)


# ------- connection data -------

func _get_tags(tile: String, dir: String) -> Array:
	var idx = _DIRECTIONS.find(dir)
	if idx < 0: return []
	var c: Array = _tile_data.get(tile, {}).get("connectors", [[],[],[],[]])
	return c[idx].duplicate() if c.size() == 4 else []


func _opposite_dir(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
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


func _on_back_pressed() -> void:
	_editor_screen.hide(); _load_screen.show()
