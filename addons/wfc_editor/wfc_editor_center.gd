@tool
class_name WFCEditorCenter
extends CenterContainer

signal slot_checked(dir: String, checked: bool)
signal rotation_toggled(deg: int, enabled: bool)
signal weight_changed(value: float)
signal group_added(group_name: String)
signal group_removed(group_name: String)

const _SLOT_SCENE = preload("res://addons/wfc_editor/wfc_tile_slot.tscn")
const _DIRECTIONS = ["north", "east", "south", "west"]
const DEBUG_LOG := false

var _center_slot: WfcTileSlot
var _slots: Dictionary = {}
var _grid: GridContainer
var _group_flow: FlowContainer
var _group_edit: LineEdit
var _group_add_button: Button


func _ready() -> void:
	_grid = $Inner/CrossGrid
	_group_flow = $Inner/GroupsBox/GroupFlow
	_group_edit = $Inner/GroupsBox/GroupRow/GroupEdit
	_group_add_button = $Inner/GroupsBox/GroupRow/AddGroupButton
	_build_grid()
	_connect_rotation_signals()
	if _group_add_button:
		_group_add_button.pressed.connect(_on_add_group_pressed)
	if _group_edit:
		_group_edit.text_submitted.connect(func(_text): _on_add_group_pressed())
	for dir in _DIRECTIONS:
		var d = dir
		_slots[dir].checked.connect(func(v): slot_checked.emit(d, v))


func _build_grid() -> void:
	var scene = _SLOT_SCENE
	_add_spacer()
	var n = scene.instantiate(); _slots["north"] = n; _grid.add_child(n)
	_add_spacer()
	var w = scene.instantiate(); _slots["west"] = w; _grid.add_child(w)
	_center_slot = scene.instantiate(); _center_slot.is_center = true; _grid.add_child(_center_slot)
	var e = scene.instantiate(); _slots["east"] = e; _grid.add_child(e)
	_add_spacer()
	var s = scene.instantiate(); _slots["south"] = s; _grid.add_child(s)
	_add_spacer()


func _add_spacer() -> void:
	var c = Control.new()
	c.custom_minimum_size = Vector2(180, 180)
	_grid.add_child(c)


func _connect_rotation_signals() -> void:
	$Inner/RotBar/Check90.toggled.connect(func(v): rotation_toggled.emit(90, v))
	$Inner/RotBar/Check180.toggled.connect(func(v): rotation_toggled.emit(180, v))
	$Inner/RotBar/Check270.toggled.connect(func(v): rotation_toggled.emit(270, v))
	$Inner/RotBar/WeightEdit.value_changed.connect(func(v): weight_changed.emit(v))


## Show rotation checkboxes with given states. [rotations] e.g. [1, 3]
func show_rotations(rotations: Array) -> void:
	var int_rots: Array = []
	for r in rotations: int_rots.append(r as int)

	$Inner/RotBar.show()
	$Inner/RotBar/Check90.set_block_signals(true); $Inner/RotBar/Check90.button_pressed = 1 in int_rots; $Inner/RotBar/Check90.set_block_signals(false)
	$Inner/RotBar/Check180.set_block_signals(true); $Inner/RotBar/Check180.button_pressed = 2 in int_rots; $Inner/RotBar/Check180.set_block_signals(false)
	$Inner/RotBar/Check270.set_block_signals(true); $Inner/RotBar/Check270.button_pressed = 3 in int_rots; $Inner/RotBar/Check270.set_block_signals(false)


func hide_rotations() -> void:
	$Inner/RotBar.hide()


func set_weight(value: float) -> void:
	$Inner/RotBar/WeightEdit.set_block_signals(true)
	$Inner/RotBar/WeightEdit.value = value
	$Inner/RotBar/WeightEdit.set_block_signals(false)


func set_groups(groups: Array) -> void:
	for child in _group_flow.get_children():
		child.queue_free()
	var unique_groups: Array = []
	for group_name in groups:
		var name = str(group_name).strip_edges()
		if not name.is_empty() and not unique_groups.has(name):
			unique_groups.append(name)
	unique_groups.sort()
	for group_name in unique_groups:
		_group_flow.add_child(_make_group_chip(group_name))
	if _group_edit:
		_group_edit.text = ""


func clear_groups() -> void:
	set_groups([])


func _make_group_chip(group_name: String) -> Button:
	var chip = Button.new()
	chip.text = group_name + "  x"
	chip.focus_mode = Control.FOCUS_NONE
	chip.pressed.connect(func(): group_removed.emit(group_name))
	return chip


func _on_add_group_pressed() -> void:
	if _group_edit == null:
		return
	var group_name = _group_edit.text.strip_edges()
	if group_name.is_empty():
		return
	group_added.emit(group_name)
	_group_edit.text = ""


func set_main(tile_name: String, texture: Texture2D) -> void:
	_center_slot.set_tile(tile_name, texture)


func set_candidate(tile_name: String, texture: Texture2D, rotation: int = 0) -> void:
	var rot_tex = _rotate_texture(texture, rotation) if rotation > 0 else texture
	if rot_tex == null: rot_tex = texture

	if DEBUG_LOG:
		_ed_log("set_candidate name=%s rot=%d orig=%s final=%s" % [tile_name, rotation,
			"ok" if texture else "NULL", "ok" if rot_tex else "NULL"])

	for dir in _DIRECTIONS:
		_slots[dir].set_tile(tile_name, rot_tex)
		_slots[dir].set_connected(true)  # show full color by default


func clear_candidate() -> void:
	for dir in _DIRECTIONS:
		_slots[dir].set_tile("", null)
		_slots[dir].set_check_visible(false)
		_slots[dir].set_connected(false)


func set_slot_connected(dir: String, connected: bool) -> void:
	var slot = _slots[dir]
	slot.set_check_visible(true)
	slot.set_check_state(connected)
	slot.set_connected(connected)


func reset_slots() -> void:
	for dir in _DIRECTIONS:
		var slot = _slots[dir]
		slot.set_check_visible(false)
		slot.set_check_state(false)
		slot.set_connected(false)


func _rotate_texture(tex: Texture2D, rot: int) -> Texture2D:
	if tex == null or rot == 0: return tex
	var img = tex.get_image()
	if img == null:
		if DEBUG_LOG:
			_ed_log("_rotate_texture get_image=NULL rot=%d" % rot)
		return tex
	img = img.duplicate()
	if DEBUG_LOG:
		_ed_log("_rotate_texture before rot=%d size=%dx%d" % [rot, img.get_width(), img.get_height()])
	for _r in range(rot):
		img.rotate_90(CLOCKWISE)
	var result = ImageTexture.create_from_image(img)
	if DEBUG_LOG:
		_ed_log("_rotate_texture after result=%s size=%dx%d" % ["ok" if result else "NULL", img.get_width(), img.get_height()])
	return result


func _ed_log(msg: String) -> void:
	var f = FileAccess.open("user://wfc_editor.log", FileAccess.WRITE_READ)
	if f:
		f.seek_end()
		f.store_line(msg)
		f.close()
