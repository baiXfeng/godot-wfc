@tool
class_name WFCEditorRight
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
		_add_item(tile_name, textures.get(tile_name))
	_set_enabled(false)


## Insert or update a single item at the correct sorted position.
func set_item(tile_name: String, texture: Texture2D) -> void:
	if _items.has(tile_name):
		_items[tile_name].setup(tile_name, texture)
		return
	_add_item(tile_name, texture)
	_reorder()


## Remove a single item.
func remove_item(tile_name: String) -> void:
	if not _items.has(tile_name): return
	_items[tile_name].queue_free()
	_items.erase(tile_name)


func set_enabled(enabled: bool) -> void:
	_set_enabled(enabled)


func highlight(tile_name: String) -> void:
	_selected = tile_name
	for name in _items:
		_items[name].set_highlight(name == tile_name)


func set_connection_count(tile_name: String, count: int) -> void:
	if not _items.has(tile_name): return
	_items[tile_name].set_count(count)


func _add_item(tile_name: String, tex: Texture2D) -> void:
	var item = _ITEM_SCENE.instantiate()
	item.setup(tile_name, tex)
	item.pressed.connect(func():
		_right_log("right_click name=%s" % tile_name)
		tile_selected.emit(tile_name)
	)
	_items[tile_name] = item
	_grid.add_child(item)


func _right_log(msg: String) -> void:
	var f = FileAccess.open("user://wfc_editor.log", FileAccess.WRITE_READ)
	if f:
		f.seek_end()
		f.store_line(msg)
		f.close()


func _reorder() -> void:
	var names = _items.keys(); names.sort()
	for i in range(names.size()):
		_grid.move_child(_items[names[i]], i)


func _set_enabled(enabled: bool) -> void:
	modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 1)
	for name in _items:
		_items[name].modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 1)


func _clear() -> void:
	for c in _grid.get_children(): c.queue_free()
	_items.clear()
