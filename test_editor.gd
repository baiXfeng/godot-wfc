extends Node

func _ready() -> void:
	print("=== Editor Smoke Test ===")
	_test_panel_instantiation()
	_test_connection_logic()
	_test_save_load_roundtrip()
	_test_grid_refresh()
	print("=== Smoke Test Passed ===")

func _test_panel_instantiation() -> void:
	print("--- Panel Instantiation ---")
	var panel_scene = load("res://addons/wfc_editor/wfc_editor_panel.tscn")
	assert(panel_scene != null, "Failed to load panel scene")
	var panel = panel_scene.instantiate()
	assert(panel != null, "Failed to instantiate panel")
	add_child(panel)  # trigger _ready()

	assert(panel is Control, "Panel should be a Control")
	assert(panel._load_screen != null, "LoadScreen should exist")
	assert(panel._editor_screen != null, "EditorScreen should exist")
	assert(panel._left_root != null, "Left column should be instantiated")
	assert(panel._center_root != null, "Center column should be instantiated")
	assert(panel._right_root != null, "Right column should be instantiated")
	assert(panel._left_grid != null, "Left grid should exist")
	assert(panel._right_grid != null, "Right grid should exist")
	assert(panel._center_tex != null, "Center texture should exist")
	assert(panel._center_label != null, "Center label should exist")

	for dir in ["north", "east", "south", "west"]:
		assert(panel._slot_tex.has(dir), "Slot tex missing: " + dir)
		assert(panel._slot_label.has(dir), "Slot label missing: " + dir)
		assert(panel._slot_check.has(dir), "Slot check missing: " + dir)

	remove_child(panel)
	panel.queue_free()
	print("  OK - panel instantiated, columns loaded, all nodes accessible")


func _test_connection_logic() -> void:
	print("--- Connection Logic ---")

	var panel = _make_panel_with_test_data()

	# Verify initial state: no connections
	assert(not panel._is_connected("grass", "north", "water"),
		"Should not be connected initially")
	assert(not panel._is_connected("grass", "east", "water"),
		"Should not be connected initially")

	# Add connection
	panel._add_connection("grass", "north", "water")
	assert(panel._is_connected("grass", "north", "water"),
		"Should be connected after add")
	assert(panel._is_connected("water", "south", "grass"),
		"Bidirectional: water south should connect to grass")
	assert(not panel._is_connected("grass", "east", "water"),
		"Only north should be connected, not east")

	# Add another connection on same side
	panel._add_connection("grass", "north", "sand")
	assert(panel._is_connected("grass", "north", "sand"),
		"Should connect to sand too")
	assert(panel._is_connected("grass", "north", "water"),
		"Water connection should remain")

	# Remove connection
	panel._remove_connection("grass", "north", "water")
	assert(not panel._is_connected("grass", "north", "water"),
		"Should be disconnected after remove")
	assert(panel._is_connected("grass", "north", "sand"),
		"Sand connection should remain")
	assert(not panel._is_connected("water", "south", "grass"),
		"Bidirectional: water south should also disconnect")

	# Tag format verification
	var grass_tags = panel._get_tags("grass", "north")
	assert(grass_tags.size() > 0, "Grass north should have at least one tag")
	for tag in grass_tags:
		assert(tag.begins_with("L") or tag.begins_with("R"),
			"Tags should be L/R format: " + tag)

	panel.queue_free()
	print("  OK - connections added/removed correctly, bidirectional working")


func _test_save_load_roundtrip() -> void:
	print("--- Save/Load Roundtrip ---")

	var panel = _make_panel_with_test_data()
	panel._add_connection("grass", "north", "water")
	panel._add_connection("grass", "east", "sand")
	panel._add_connection("water", "south", "sand")

	# Save to temp path
	var temp_dir = "user://test_wfc_editor"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	panel._dir_path = temp_dir
	panel._on_save_pressed()

	# Verify file was created
	assert(FileAccess.file_exists(temp_dir + "/modules.json"),
		"modules.json should be saved")

	# Load into a fresh panel
	var panel2 = _make_panel_with_test_data()
	panel2._load_modules_json(temp_dir + "/modules.json")

	# Verify connections survived roundtrip
	assert(panel2._is_connected("grass", "north", "water"),
		"Grass north -> water should survive roundtrip")
	assert(panel2._is_connected("grass", "east", "sand"),
		"Grass east -> sand should survive roundtrip")
	assert(panel2._is_connected("water", "south", "sand"),
		"Water south -> sand should survive roundtrip")
	assert(not panel2._is_connected("grass", "south", "water"),
		"Non-connected direction should remain unconnected")

	# Cleanup
	DirAccess.remove_absolute(temp_dir + "/modules.json")
	DirAccess.remove_absolute(temp_dir)
	panel.queue_free()
	panel2.queue_free()
	print("  OK - save/load roundtrip preserves all connections")


func _test_grid_refresh() -> void:
	print("--- Grid Refresh ---")

	var panel = _make_panel_with_test_data()
	panel._tile_data = {
		"grass": {"texture_path": "", "color": Color.GREEN, "connectors": [[],[],[],[]]},
		"water": {"texture_path": "", "color": Color.BLUE, "connectors": [[],[],[],[]]},
	}
	panel._tile_textures = {}
	add_child(panel)  # trigger _ready() to build UI
	panel._refresh_tile_grids()

	# Verify grid items were created
	assert(panel._left_items.size() == 2, "Left items: expected 2, got " + str(panel._left_items.size()))
	assert(panel._right_items.size() == 2, "Right items: expected 2, got " + str(panel._right_items.size()))
	assert(panel._left_items.has("grass"), "Left items should contain grass")
	assert(panel._right_items.has("water"), "Right items should contain water")

	# Verify selection state
	assert(panel._selected_main == "", "No tile selected initially")
	assert(panel._selected_candidate == "", "No candidate selected initially")

	remove_child(panel)
	panel.queue_free()

	# Verify right items are grayed out initially

	panel.queue_free()
	print("  OK - grids populated, selection state correct")


# --- helpers ---

func _make_panel_with_test_data() -> Control:
	var panel = load("res://addons/wfc_editor/wfc_editor_panel.tscn").instantiate()

	# Set up test data (bypassing the file dialog)
	panel._tile_data = {
		"grass": {"texture_path": "", "color": Color.GREEN, "connectors": [[],[],[],[]]},
		"water": {"texture_path": "", "color": Color.BLUE, "connectors": [[],[],[],[]]},
		"sand":  {"texture_path": "", "color": Color.BEIGE, "connectors": [[],[],[],[]]},
	}
	panel._tile_textures = {}
	return panel
