@tool
class_name WFCEditorLeft
extends VBoxContainer

## Emitted when user clicks a tile in this column.
signal tile_selected(tile_name: String)

const _THUMB_SIZE := 64

var _grid: GridContainer
var _items: Dictionary = {}  # tile_name -> PanelContainer
var _selected: String = ""


func _ready() -> void:
	_grid = $Scroll/Grid


## Replace all tiles with a new list.
## [tiles] is an ordered Array[String] of tile names.
## [textures] is a Dictionary[String, Texture2D].
func populate(tiles: Array, textures: Dictionary) -> void:
	_clear()
	_selected = ""
	for tile_name in tiles:
		var panel = _make_tile_item(tile_name, textures.get(tile_name))
		_grid.add_child(panel)
		_items[tile_name] = panel


## Highlight [tile_name] with a blue border; clear previous highlight.
func highlight(tile_name: String) -> void:
	_selected = tile_name
	for name in _items:
		var st = _items[name].get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		st.border_color = Color(0.3, 0.7, 1.0, 1) if name == tile_name else Color(0.15, 0.15, 0.15, 1)
		_items[name].add_theme_stylebox_override("panel", st)


func _clear() -> void:
	for c in _grid.get_children(): c.queue_free()
	_items.clear()


func _make_tile_item(tile_name: String, tex: Texture2D) -> Control:
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
			tile_selected.emit(tile_name)
	)
	return panel
