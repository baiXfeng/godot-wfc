@tool
class_name WFCEditorCenter
extends VBoxContainer

## Emitted when a direction-slot checkbox is toggled.
signal slot_checked(dir: String, checked: bool)

const _DIRECTIONS = ["north", "east", "south", "west"]

# 3x3 grid positions:   (0,0)=NW, (1,0)=N, (2,0)=NE
#                        (0,1)=W,  (1,1)=Center, (2,1)=E
#                        (0,2)=SW, (1,2)=S,  (2,2)=SE
const _GRID_POS = {
	"north": Vector2i(1, 0),
	"east":  Vector2i(2, 1),
	"south": Vector2i(1, 2),
	"west":  Vector2i(0, 1),
}

var _center_slot: WfcTileSlot
var _slots: Dictionary = {}  # dir -> WfcTileSlot
var _grid: GridContainer


func _ready() -> void:
	_grid = $CrossGrid
	_build_grid()
	# Connect checkbox signals after all slots exist
	for dir in _DIRECTIONS:
		var d = dir
		_slots[dir].checked.connect(func(v): slot_checked.emit(d, v))


func _build_grid() -> void:
	# Row 0: spacer | north | spacer
	_add_spacer()
	var north = _make_dir_slot(); _slots["north"] = north; _grid.add_child(north)
	_add_spacer()

	# Row 1: west | center | east
	var west = _make_dir_slot(); _slots["west"] = west; _grid.add_child(west)

	_center_slot = WfcTileSlot.new()
	_center_slot.is_center = true
	_grid.add_child(_center_slot)

	var east = _make_dir_slot(); _slots["east"] = east; _grid.add_child(east)

	# Row 2: spacer | south | spacer
	_add_spacer()
	var south = _make_dir_slot(); _slots["south"] = south; _grid.add_child(south)
	_add_spacer()


func _make_dir_slot() -> WfcTileSlot:
	var slot = WfcTileSlot.new()
	slot.is_center = false
	return slot


func _add_spacer() -> void:
	var c = Control.new()
	c.custom_minimum_size = Vector2(72, 84)
	_grid.add_child(c)


## Display [tile_name] with [texture] as the center tile.
func set_main(tile_name: String, texture: Texture2D) -> void:
	_center_slot.set_tile(tile_name, texture)


## Fill all 4 direction slots with [tile_name] and [texture].
func set_candidate(tile_name: String, texture: Texture2D) -> void:
	for dir in _DIRECTIONS:
		_slots[dir].set_tile(tile_name, texture)


## Remove the candidate from all direction slots.
func clear_candidate() -> void:
	for dir in _DIRECTIONS:
		_slots[dir].set_tile("", null)
		_slots[dir].set_check_visible(false)
		_slots[dir].set_connected(false)


## Set a direction slot's connection state: checked + full color, or unchecked + grayscale.
func set_slot_connected(dir: String, connected: bool) -> void:
	var slot = _slots[dir]
	slot.set_check_visible(true)
	slot.set_check_state(connected)
	slot.set_connected(connected)


## Hide all checkboxes and dim all direction slots.
func reset_slots() -> void:
	for dir in _DIRECTIONS:
		var slot = _slots[dir]
		slot.set_check_visible(false)
		slot.set_check_state(false)
		slot.set_connected(false)
