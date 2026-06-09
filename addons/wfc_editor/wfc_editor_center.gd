@tool
class_name WFCEditorCenter
extends VBoxContainer

signal slot_checked(dir: String, checked: bool)
signal rotation_toggled(deg: int, enabled: bool)

const _SLOT_SCENE = preload("res://addons/wfc_editor/wfc_tile_slot.tscn")
const _DIRECTIONS = ["north", "east", "south", "west"]

var _center_slot: WfcTileSlot
var _slots: Dictionary = {}
var _grid: GridContainer


func _ready() -> void:
	_grid = $CrossGrid
	_build_grid()
	_connect_rotation_signals()
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
	$RotBar/Check90.toggled.connect(func(v): rotation_toggled.emit(90, v))
	$RotBar/Check180.toggled.connect(func(v): rotation_toggled.emit(180, v))
	$RotBar/Check270.toggled.connect(func(v): rotation_toggled.emit(270, v))


## Show rotation checkboxes with given states. [rotations] e.g. [1, 3]
func show_rotations(rotations: Array) -> void:
	# Ensure int comparison
	var int_rots: Array = []
	for r in rotations: int_rots.append(r as int)

	var has_any = not rotations.is_empty()
	$RotBar.visible = has_any
	if not has_any: return

	$RotBar/Check90.set_block_signals(true); $RotBar/Check90.button_pressed = 1 in int_rots; $RotBar/Check90.set_block_signals(false)
	$RotBar/Check180.set_block_signals(true); $RotBar/Check180.button_pressed = 2 in int_rots; $RotBar/Check180.set_block_signals(false)
	$RotBar/Check270.set_block_signals(true); $RotBar/Check270.button_pressed = 3 in int_rots; $RotBar/Check270.set_block_signals(false)


func hide_rotations() -> void:
	$RotBar.hide()


func set_main(tile_name: String, texture: Texture2D) -> void:
	_center_slot.set_tile(tile_name, texture)


func set_candidate(tile_name: String, texture: Texture2D, rotation: int = 0) -> void:
	for dir in _DIRECTIONS:
		_slots[dir].set_tile(tile_name, texture)
		# Apply rotation to the slot display (image rotation handled by caller)
	var rot_tex = _rotate_texture(texture, rotation) if rotation > 0 else texture
	for dir in _DIRECTIONS:
		_slots[dir].set_tile(tile_name, rot_tex if rotation > 0 else texture)


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
	if tex == null: return null
	var img = tex.get_image()
	for _r in range(rot):
		img.rotate_90(CLOCKWISE)
	return ImageTexture.create_from_image(img)
