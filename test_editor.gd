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
	add_child(panel)

	assert(panel is Control, "Panel should be a Control")
	assert(panel._load_screen != null, "LoadScreen should exist")
	assert(panel._editor_screen != null, "EditorScreen should exist")
	assert(panel._left != null, "Left column should be instantiated")
	assert(panel._center != null, "Center column should be instantiated")
	assert(panel._right != null, "Right column should be instantiated")

	# Verify signals are connected
	assert(panel._left.tile_selected.is_connected(panel._on_main_selected),
		"Left tile_selected should be connected")
	assert(panel._right.tile_selected.is_connected(panel._on_candidate_selected),
		"Right tile_selected should be connected")
	assert(panel._center.slot_checked.is_connected(panel._on_slot_checked),
		"Center slot_checked should be connected")

	remove_child(panel); panel.queue_free()
	print("  OK - panel instantiated, columns loaded, signals connected")


func _test_connection_logic() -> void:
	print("--- Connection Logic ---")
	var panel = _make_panel_with_test_data()

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

	var temp_dir = "user://test_wfc_editor"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	panel._dir_path = temp_dir
	panel._on_save_pressed()

	assert(FileAccess.file_exists(temp_dir + "/modules.json"),
		"modules.json should be saved")

	var panel2 = _make_panel_with_test_data()
	panel2._load_modules_json(temp_dir + "/modules.json")

	assert(panel2._is_connected("grass", "north", "water"),
		"Grass north -> water should survive roundtrip")
	assert(panel2._is_connected("grass", "east", "sand"),
		"Grass east -> sand should survive roundtrip")
	assert(panel2._is_connected("water", "south", "sand"),
		"Water south -> sand should survive roundtrip")
	assert(not panel2._is_connected("grass", "south", "water"),
		"Non-connected direction should remain unconnected")

	DirAccess.remove_absolute(temp_dir + "/modules.json")
	DirAccess.remove_absolute(temp_dir)
	panel.queue_free(); panel2.queue_free()
	print("  OK - save/load roundtrip preserves all connections")


func _test_grid_refresh() -> void:
	print("--- Grid Refresh ---")
	var panel = _make_panel_with_test_data()
	panel._tile_data = {
		"grass": {"texture_path": "", "color": Color.GREEN, "connectors": [[],[],[],[]]},
		"water": {"texture_path": "", "color": Color.BLUE, "connectors": [[],[],[],[]]},
	}
	panel._tile_textures = {}
	add_child(panel)

	var names = panel._tile_data.keys(); names.sort()
	panel._left.populate(names, panel._tile_textures)
	panel._right.populate(names, panel._tile_textures)

	# Simulate selecting a main tile
	panel._on_main_selected("grass")
	assert(panel._selected_main == "grass", "Main tile should be grass")
	assert(panel._selected_candidate == "", "Candidate should be cleared")

	# Simulate selecting a candidate
	panel._on_candidate_selected("water")
	assert(panel._selected_candidate == "water", "Candidate should be water")

	# Toggle a connection via the slot checked handler
	panel._on_slot_checked("north", true)
	assert(panel._is_connected("grass", "north", "water"),
		"Connection should be established")
	panel._on_slot_checked("north", false)
	assert(not panel._is_connected("grass", "north", "water"),
		"Connection should be removed")

	remove_child(panel); panel.queue_free()
	print("  OK - grid/selection/connection flow correct")


# --- helper ---

func _make_panel_with_test_data() -> Control:
	var panel = load("res://addons/wfc_editor/wfc_editor_panel.tscn").instantiate()
	panel._tile_data = {
		"grass": {"texture_path": "", "color": Color.GREEN, "connectors": [[],[],[],[]]},
		"water": {"texture_path": "", "color": Color.BLUE, "connectors": [[],[],[],[]]},
		"sand":  {"texture_path": "", "color": Color.BEIGE, "connectors": [[],[],[],[]]},
	}
	panel._tile_textures = {}
	return panel
