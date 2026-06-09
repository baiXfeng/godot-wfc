@tool
class_name WFCEditorLeft
extends VBoxContainer

signal tile_selected(tile_name: String)

const _ITEM_SCENE = preload("res://addons/wfc_editor/wfc_tile_item.tscn")

var _grid: GridContainer
var _items: Dictionary = {}
var _selected: String = ""


func _ready() -> void:
	_grid = $Scroll/Grid


func populate(tiles: Array, textures: Dictionary) -> void:
	_clear()
	_selected = ""
	for tile_name in tiles:
		var item = _ITEM_SCENE.instantiate()
		item.setup(tile_name, textures.get(tile_name))
		item.pressed.connect(func(): tile_selected.emit(tile_name))
		_grid.add_child(item)
		_items[tile_name] = item


func highlight(tile_name: String) -> void:
	_selected = tile_name
	for name in _items:
		_items[name].set_highlight(name == tile_name)


func _clear() -> void:
	for c in _grid.get_children(): c.queue_free()
	_items.clear()
