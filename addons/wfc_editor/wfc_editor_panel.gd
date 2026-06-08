@tool
class_name WFCEditorPanel
extends Control

var plugin: EditorPlugin

# --- state ---
var _dir_path: String = ""
var _tile_data: Dictionary = {}  # name -> {texture_path, color, connectors: [[tags],...]}
var _tile_textures: Dictionary = {}  # name -> Texture2D
var _selected_main: String = ""
var _selected_candidate: String = ""

# --- UI roots ---
var _load_screen: Control
var _editor_screen: Control

# left grid
var _left_scroll: ScrollContainer
var _left_grid: GridContainer
var _left_items: Dictionary = {}  # name -> Control

# center
var _center_main_rect: TextureRect
var _center_main_label: Label
var _slot_north: Control
var _slot_east: Control
var _slot_south: Control
var _slot_west: Control
var _check_north: CheckBox
var _check_east: CheckBox
var _check_south: CheckBox
var _check_west: CheckBox
var _slot_rects: Dictionary = {}  # "north" -> TextureRect, etc
var _slot_labels: Dictionary = {}
var _checks: Dictionary = {}  # "north" -> CheckBox, etc

# right grid
var _right_scroll: ScrollContainer
var _right_grid: GridContainer
var _right_items: Dictionary = {}  # name -> Control

const _DIRECTIONS = ["north", "east", "south", "west"]
const _THUMB_SIZE := 64


func _ready() -> void:
	custom_minimum_size = Vector2(900, 600)
	_build_load_screen()
	_build_editor_screen()

func _build_load_screen() -> void:
	_load_screen = Control.new()
	_load_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_load_screen)

	var btn = Button.new()
	btn.text = "加载图块配置"
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.custom_minimum_size = Vector2(200, 60)
	btn.pressed.connect(_on_load_pressed)
	_load_screen.add_child(btn)


func _build_editor_screen() -> void:
	_editor_screen = Control.new()
	_editor_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_screen.hide()
	add_child(_editor_screen)

	# Top bar
	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.add_theme_constant_override("separation", 8)

	var back_btn = Button.new()
	back_btn.text = "< 返回"
	back_btn.pressed.connect(_on_back_pressed)
	top_bar.add_child(back_btn)

	var dir_label = Label.new()
	dir_label.name = "DirLabel"
	dir_label.text = "未选择目录"
	dir_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(dir_label)

	var save_btn = Button.new()
	save_btn.text = "保存配置"
	save_btn.pressed.connect(_on_save_pressed)
	top_bar.add_child(save_btn)

	_editor_screen.add_child(top_bar)

	# Split container
	var split = HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	split.position = Vector2(0, 36)
	split.size = Vector2(900, 564)
	_editor_screen.add_child(split)

	# --- Left column ---
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(200, 400)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND
	left_vbox.add_theme_constant_override("separation", 4)
	split.add_child(left_vbox)

	var left_label = Label.new()
	left_label.text = "图块列表 (点选主图块)"
	left_vbox.add_child(left_label)

	_left_scroll = ScrollContainer.new()
	_left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_scroll.size_flags_vertical = Control.SIZE_EXPAND
	left_vbox.add_child(_left_scroll)

	_left_grid = GridContainer.new()
	_left_grid.columns = 2
	_left_grid.add_theme_constant_override("h_separation", 4)
	_left_grid.add_theme_constant_override("v_separation", 4)
	_left_scroll.add_child(_left_grid)

	# --- Center column ---
	var center = VBoxContainer.new()
	center.custom_minimum_size = Vector2(300, 400)
	center.size_flags_horizontal = Control.SIZE_EXPAND
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 4)
	split.add_child(center)

	# North slot
	_slot_north = _make_direction_slot("north")
	_check_north = _slot_north.get_node("Check")
	_checks["north"] = _check_north
	_slot_rects["north"] = _slot_north.get_node("TextureRect")
	_slot_labels["north"] = _slot_north.get_node("Label")
	center.add_child(_slot_north)

	# Middle row: west | center | east
	var mid_row = HBoxContainer.new()
	mid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_row.add_theme_constant_override("separation", 8)
	center.add_child(mid_row)

	_slot_west = _make_direction_slot("west")
	_check_west = _slot_west.get_node("Check")
	_checks["west"] = _check_west
	_slot_rects["west"] = _slot_west.get_node("TextureRect")
	_slot_labels["west"] = _slot_west.get_node("Label")
	mid_row.add_child(_slot_west)

	# Center tile
	var center_tile = Control.new()
	center_tile.custom_minimum_size = Vector2(_THUMB_SIZE * 2 + 8, _THUMB_SIZE * 2 + 8)
	mid_row.add_child(center_tile)

	_center_main_rect = TextureRect.new()
	_center_main_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_center_main_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_center_main_rect.custom_minimum_size = Vector2(_THUMB_SIZE * 2, _THUMB_SIZE * 2)
	_center_main_rect.modulate = Color(0.5, 0.5, 0.5, 1)
	center_tile.add_child(_center_main_rect)

	_center_main_label = Label.new()
	_center_main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_main_label.position = Vector2(0, _THUMB_SIZE * 2)
	_center_main_label.custom_minimum_size = Vector2(_THUMB_SIZE * 2, 20)
	center_tile.add_child(_center_main_label)

	_slot_east = _make_direction_slot("east")
	_check_east = _slot_east.get_node("Check")
	_checks["east"] = _check_east
	_slot_rects["east"] = _slot_east.get_node("TextureRect")
	_slot_labels["east"] = _slot_east.get_node("Label")
	mid_row.add_child(_slot_east)

	# South slot
	_slot_south = _make_direction_slot("south")
	_check_south = _slot_south.get_node("Check")
	_checks["south"] = _check_south
	_slot_rects["south"] = _slot_south.get_node("TextureRect")
	_slot_labels["south"] = _slot_south.get_node("Label")
	center.add_child(_slot_south)

	# --- Right column ---
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(200, 400)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND
	right_vbox.add_theme_constant_override("separation", 4)
	split.add_child(right_vbox)

	var right_label = Label.new()
	right_label.text = "候选图块 (点选后配置连接)"
	right_vbox.add_child(right_label)

	_right_scroll = ScrollContainer.new()
	_right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_scroll.size_flags_vertical = Control.SIZE_EXPAND
	right_vbox.add_child(_right_scroll)

	_right_grid = GridContainer.new()
	_right_grid.columns = 2
	_right_grid.add_theme_constant_override("h_separation", 4)
	_right_grid.add_theme_constant_override("v_separation", 4)
	_right_scroll.add_child(_right_grid)


func _make_direction_slot(dir_name: String) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(_THUMB_SIZE, _THUMB_SIZE + 20)

	var rect = TextureRect.new()
	rect.name = "TextureRect"
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(_THUMB_SIZE, _THUMB_SIZE)
	rect.modulate = Color(0.3, 0.3, 0.3, 1)
	c.add_child(rect)

	var label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, _THUMB_SIZE)
	label.custom_minimum_size = Vector2(_THUMB_SIZE, 16)
	label.add_theme_font_size_override("font_size", 10)
	c.add_child(label)

	var check = CheckBox.new()
	check.name = "Check"
	check.position = Vector2(_THUMB_SIZE - 16, 2)
	check.size = Vector2(16, 16)
	check.focus_mode = Control.FOCUS_NONE
	var dir = dir_name
	check.toggled.connect(func(v): _on_slot_checked(dir, v))
	c.add_child(check)

	return c


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

	# Scan for PNG files
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var base = file_name.trim_suffix(".png")
			# Check for existing config
			_tile_data[base] = {
				"texture_path": path + "/" + file_name,
				"color": Color.WHITE,
				"connectors": [[], [], [], []]  # N, E, S, W
			}
			# Load texture
			var tex = load(path + "/" + file_name) as Texture2D
			if tex:
				_tile_textures[base] = tex
		file_name = dir.get_next()

	# Try loading existing modules.json
	var config_path = path + "/modules.json"
	if FileAccess.file_exists(config_path):
		_load_modules_json(config_path)

	# Refresh UI
	_refresh_tile_grids()
	_editor_screen.get_node("DirLabel").text = path
	_load_screen.hide()
	_editor_screen.show()


func _load_modules_json(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json = JSON.parse_string(file.get_as_text())
	if json == null or not json.has("modules"):
		return

	for entry in json["modules"]:
		var name = entry.get("name", "")
		if not _tile_data.has(name):
			continue
		var connectors = entry.get("connectors", [])
		if connectors is Array and connectors.size() == 4:
			var parsed = []
			for s in connectors:
				if s is String and not s.is_empty():
					parsed.append(s.split(",", false))
				else:
					parsed.append([])
			_tile_data[name]["connectors"] = parsed
		if entry.has("color"):
			_tile_data[name]["color"] = _parse_hex(entry.get("color", ""))
		if entry.has("weight"):
			_tile_data[name]["weight"] = entry["weight"]
		if entry.has("rotate"):
			_tile_data[name]["rotate"] = entry["rotate"]


func _refresh_tile_grids() -> void:
	# Clear
	for c in _left_grid.get_children():
		c.queue_free()
	_left_items.clear()
	for c in _right_grid.get_children():
		c.queue_free()
	_right_items.clear()

	var names = _tile_data.keys()
	names.sort()

	for tile_name in names:
		var item = _make_tile_item(tile_name, false)
		_left_grid.add_child(item)
		_left_items[tile_name] = item

		var ritem = _make_tile_item(tile_name, true)
		ritem.modulate = Color(0.5, 0.5, 0.5, 1)
		_right_grid.add_child(ritem)
		_right_items[tile_name] = ritem

	# Clear selection
	_selected_main = ""
	_selected_candidate = ""
	_update_center()
	_update_right_enabled(false)


func _make_tile_item(tile_name: String, is_right: bool) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(_THUMB_SIZE + 12, _THUMB_SIZE + 26)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.15, 0.15, 0.15, 1)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var rect = TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(_THUMB_SIZE, _THUMB_SIZE)
	var tex = _tile_textures.get(tile_name)
	if tex:
		rect.texture = tex
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
		if _selected_main.is_empty():
			return
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
		var panel = _left_items[name]
		var style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if name == _selected_main:
			style.border_color = Color(0.3, 0.7, 1.0, 1)
		else:
			style.border_color = Color(0.15, 0.15, 0.15, 1)
		panel.add_theme_stylebox_override("panel", style)


func _update_right_highlight() -> void:
	for name in _right_items:
		var panel = _right_items[name]
		var style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if name == _selected_candidate:
			style.border_color = Color(0.3, 0.7, 1.0, 1)
		else:
			style.border_color = Color(0.15, 0.15, 0.15, 1)
		panel.add_theme_stylebox_override("panel", style)


func _update_center() -> void:
	# Center tile
	if _selected_main.is_empty():
		_center_main_rect.texture = null
		_center_main_rect.modulate = Color(0.5, 0.5, 0.5, 1)
		_center_main_label.text = ""
	else:
		_center_main_rect.texture = _tile_textures.get(_selected_main)
		_center_main_rect.modulate = Color.WHITE
		_center_main_label.text = _selected_main

	# Direction slots - fill with candidate
	var candidate_tex = _tile_textures.get(_selected_candidate) if not _selected_candidate.is_empty() else null

	for dir in _DIRECTIONS:
		var rect: TextureRect = _slot_rects[dir]
		var label: Label = _slot_labels[dir]
		var check = _checks[dir]
		if candidate_tex:
			rect.texture = candidate_tex
			label.text = _selected_candidate
		else:
			rect.texture = null
			label.text = ""

		# Update check state based on existing connection data
		_update_slot_appearance(dir)


func _update_slot_appearance(dir: String) -> void:
	var rect: TextureRect = _slot_rects[dir]
	var check: CheckBox = _checks[dir]

	if _selected_main.is_empty() or _selected_candidate.is_empty():
		check.button_pressed = false
		rect.modulate = Color(0.3, 0.3, 0.3, 1)
		check.visible = false
		return

	check.visible = true
	var connected = _is_connected(_selected_main, dir, _selected_candidate)
	check.set_block_signals(true)
	check.button_pressed = connected
	check.set_block_signals(false)

	if connected:
		rect.modulate = Color.WHITE
	else:
		rect.modulate = Color(0.35, 0.35, 0.35, 1)


func _on_slot_checked(dir: String, checked: bool) -> void:
	if _selected_main.is_empty() or _selected_candidate.is_empty():
		return

	if checked:
		_add_connection(_selected_main, dir, _selected_candidate)
	else:
		_remove_connection(_selected_main, dir, _selected_candidate)

	_update_slot_appearance(dir)
	_refresh_right_colors()


func _update_right_enabled(enabled: bool) -> void:
	for name in _right_items:
		_right_items[name].modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 1)


# ------- connection data logic -------

func _get_tags(tile_name: String, dir: String) -> Array:
	var idx = _DIRECTIONS.find(dir)
	if idx < 0:
		return []
	var conns: Array = _tile_data.get(tile_name, {}).get("connectors", [[], [], [], []])
	if conns.size() != 4:
		return []
	return conns[idx].duplicate()


func _opposite_dir(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
	return ""


func _is_connected(main: String, dir: String, candidate: String) -> bool:
	var main_tags = _get_tags(main, dir)
	var cand_tags = _get_tags(candidate, _opposite_dir(dir))
	if main_tags.is_empty() or cand_tags.is_empty():
		return false
	for tag in main_tags:
		if _match_tag(tag, cand_tags):
			return true
	return false


func _match_tag(tag: String, other_tags: Array) -> bool:
	if tag.begins_with("L"):
		var val = tag.substr(1)
		return ("R" + val) in other_tags
	if tag.begins_with("R"):
		var val = tag.substr(1)
		return ("L" + val) in other_tags
	return tag in other_tags


func _next_tag_id() -> int:
	var max_id = 0
	for tile_name in _tile_data:
		var conns: Array = _tile_data[tile_name].get("connectors", [])
		for tags in conns:
			for tag in tags:
				var s = tag as String
				var v = s.trim_prefix("L").trim_prefix("R").to_int()
				if v > max_id:
					max_id = v
	return max_id + 1


func _add_connection(main: String, dir: String, candidate: String) -> void:
	if _is_connected(main, dir, candidate):
		return

	# Generate a new tag pair
	var tag_id = _next_tag_id()

	# Main tile side gets L{id}
	var main_idx = _DIRECTIONS.find(dir)
	var main_conns: Array = _tile_data[main]["connectors"]
	main_conns[main_idx].append("L%d" % tag_id)

	# Candidate opposite side gets R{id}
	var opp = _opposite_dir(dir)
	var cand_idx = _DIRECTIONS.find(opp)
	var cand_conns: Array = _tile_data[candidate]["connectors"]
	cand_conns[cand_idx].append("R%d" % tag_id)


func _remove_connection(main: String, dir: String, candidate: String) -> void:
	var main_conns: Array = _tile_data[main]["connectors"]
	var main_idx = _DIRECTIONS.find(dir)
	var cand_conns: Array = _tile_data[candidate]["connectors"]
	var cand_idx = _DIRECTIONS.find(_opposite_dir(dir))

	if main_conns.size() != 4 or cand_conns.size() != 4:
		return

	# Find and remove matching tag pair
	var to_remove_main = ""
	var to_remove_cand = ""

	for tag in main_conns[main_idx]:
		if tag.begins_with("L"):
			var val = tag.substr(1)
			var check = "R" + val
			if check in cand_conns[cand_idx]:
				to_remove_main = tag
				to_remove_cand = check
				break
		if tag.begins_with("R"):
			var val = tag.substr(1)
			var check = "L" + val
			if check in cand_conns[cand_idx]:
				to_remove_main = tag
				to_remove_cand = check
				break

	if not to_remove_main.is_empty():
		main_conns[main_idx].erase(to_remove_main)
		cand_conns[cand_idx].erase(to_remove_cand)


func _refresh_right_colors() -> void:
	if _selected_main.is_empty():
		return
	for name in _right_items:
		var has_any_connection := false
		for dir in _DIRECTIONS:
			if _is_connected(_selected_main, dir, name):
				has_any_connection = true
				break
		_right_items[name].modulate = Color.WHITE if has_any_connection else Color(0.5, 0.5, 0.5, 1)


func _on_save_pressed() -> void:
	if _dir_path.is_empty():
		return

	var modules = []
	for tile_name in _tile_data:
		var data = _tile_data[tile_name]
		var conns = data.get("connectors", [[], [], [], []])
		var conn_strs = []
		for tags in conns:
			if tags.is_empty():
				conn_strs.append("")
			else:
				var dedup = {}
				for t in tags:
					dedup[t] = true
				var sorted_tags = dedup.keys()
				sorted_tags.sort()
				conn_strs.append(",".join(sorted_tags))

		var entry = {
			"name": tile_name,
			"connectors": conn_strs,
		}
		var col = data.get("color", Color.WHITE)
		if col != Color.WHITE:
			entry["color"] = "#%02x%02x%02x" % [int(col.r * 255), int(col.g * 255), int(col.b * 255)]
		if data.has("weight"):
			entry["weight"] = data["weight"]
		if data.has("rotate"):
			entry["rotate"] = data["rotate"]
		modules.append(entry)

	var out = {
		"connector_colors": {},
		"modules": modules
	}

	var path = _dir_path + "/modules.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()
		print("WFC Editor: Saved to ", path)


func _on_back_pressed() -> void:
	_editor_screen.hide()
	_load_screen.show()


func _parse_hex(hex: String) -> Color:
	if hex.begins_with("#") and hex.length() >= 7:
		var r = hex.substr(1, 2).hex_to_int() / 255.0
		var g = hex.substr(3, 2).hex_to_int() / 255.0
		var b = hex.substr(5, 2).hex_to_int() / 255.0
		return Color(r, g, b, 1)
	return Color.WHITE
