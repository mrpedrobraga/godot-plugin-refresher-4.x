@tool
extends Control

const PROJECT_METADATA_SECTION = "plugin_refresher"
const PROJECT_METADATA_KEY = "selected_plugin" 

const EDITOR_SETTINGS_NAME_PREFIX = "refresher_plugin/"
const EDITOR_SETTINGS_NAME_COMPACT = EDITOR_SETTINGS_NAME_PREFIX + "compact"

var icon := preload("plug_icon.svg")
@export var compact: bool = false:
	set(value):
		compact = value
		_update_options_button_look()
@export var icon_next_to_plugin_name := true:
	set(value):
		icon_next_to_plugin_name = value
		_update_options_button_look()

@onready var options := %options
@onready var btn_toggle := %btn_toggle

var plugin : EditorPlugin

const PLUGIN_FOLDER := "res://addons/"

func _ready():
	plugin.main_screen_changed.connect(update_current_main_screen)
	
	await get_tree().process_frame
	_update_plugins_list()
	var selected_plugin := plugin.get_editor_interface().get_editor_settings().get_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, "")
	selected_plugin_index = plugin_ids.find(selected_plugin)
	_update_popup()
	
	if plugin.get_editor_interface().get_editor_settings().has_setting(EDITOR_SETTINGS_NAME_COMPACT):
		compact = plugin.get_editor_interface().get_editor_settings().get_setting(EDITOR_SETTINGS_NAME_COMPACT)
	_update_options_button_look()
	_update_btn_toggle_state()

var current_main_screen = null

func update_current_main_screen(s):
	if btn_toggle.button_pressed:
		current_main_screen = s

# No clue yet, how to better identify them, so for future proof id array is added here.
# (If pluins moved around -> folder changes. However Godot identify them by folder name.)
# Used internally by plug-in.
var plugin_ids := PackedStringArray()
var plugin_directories := PackedStringArray()
var plugin_names := PackedStringArray()
var selected_plugin_index = -1
var compact_view_option_index = -1

func _update_plugins_list():
	var selected_prior = null
	if selected_plugin_index >= 0 and selected_plugin_index < plugin_ids.size():
		selected_prior = plugin_ids[selected_plugin_index]
	plugin_ids.clear()
	plugin_directories.clear()
	plugin_names.clear()

	var dir := DirAccess.open(PLUGIN_FOLDER)
	for pdir in dir.get_directories():
		if not pdir == "plugin_refresher":
			_search_dir_for_plugins(PLUGIN_FOLDER, pdir)
	selected_plugin_index = -1
	for i in plugin_ids.size():
		if plugin_ids[i] == selected_prior:
			selected_plugin_index = i
			break

func _search_dir_for_plugins(base : String, dir_name : String):
	var path = base.path_join(dir_name)
	var dir = DirAccess.open(path)
	
	for file in dir.get_files():
		if file == "plugin.cfg":
			var plugincfg = ConfigFile.new()
			plugincfg.load(path.path_join(file))
			
			plugin_ids.push_back(dir_name)
			plugin_directories.push_back(dir_name)
			plugin_names.push_back(plugincfg.get_value("plugin", "name", ""))
			return
	for subdir in dir.get_directories():
		if not subdir == "plugin_refresher":
			_search_dir_for_plugins(path, subdir)

func _update_popup():
	_update_plugins_list()
	
	options.clear()
	btn_toggle.disabled = true
	
	var popup_item_idx = 0
	if plugin_ids.size() > 0:
		btn_toggle.disabled = false
		for i in plugin_ids.size():
			options.add_item(plugin_names[i])
			popup_item_idx += 1
		options.selected = selected_plugin_index
	else:
		options.add_separator("No plugins")
		popup_item_idx += 1
		options.selected = -1
	options.add_separator()
	popup_item_idx += 1
	if !compact:
		options.get_popup().add_item("Set compact view")
	else:
		options.get_popup().add_item("Show plug-in name")
	compact_view_option_index = popup_item_idx
	popup_item_idx += 1 # just for the case further options will be added

func _on_options_button_down():
	_update_popup()
	_update_options_button_look()

func _on_btn_toggle_toggled(button_pressed):
	var current_main_screen_bkp = current_main_screen
	
	if selected_plugin_index >= 0:
		plugin.get_editor_interface().set_plugin_enabled(plugin_directories[selected_plugin_index], button_pressed)
		print("\"", plugin_names[selected_plugin_index], "\" : ", "ON" if button_pressed else "OFF")
	
	if button_pressed:
		if current_main_screen_bkp:
			plugin.get_editor_interface().set_main_screen_editor(current_main_screen_bkp)
	

func _on_options_item_selected(index):
	if index == compact_view_option_index:
		compact = !compact
		plugin.get_editor_interface().get_editor_settings().set_setting(EDITOR_SETTINGS_NAME_COMPACT, compact)
		options.selected = selected_plugin_index
	elif index < plugin_ids.size():
		plugin.get_editor_interface().get_editor_settings().set_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, plugin_directories[options.selected])
		selected_plugin_index = index
		if selected_plugin_index >= plugin_ids.size():
			selected_plugin_index = -1
		_update_btn_toggle_state()
	_update_options_button_look()

func _update_btn_toggle_state():
	if plugin != null and selected_plugin_index >= 0:
		btn_toggle.disabled = false
		var plugin_enabled = plugin.get_editor_interface().is_plugin_enabled(plugin_directories[selected_plugin_index])
		if btn_toggle.button_pressed != plugin_enabled:
			btn_toggle.set_pressed_no_signal(plugin_enabled)
		btn_toggle.tooltip_text = ("Disable" if plugin_enabled else "Enable") \
			+ " " + plugin_names[selected_plugin_index] \
			+ "\n(Select plugin on the left)"
	else:
		btn_toggle.set_pressed_no_signal(false)
		btn_toggle.disabled = true
		btn_toggle.tooltip_text = "No plugin selected" \
			+ "\n(Select plugin on the left)"

func _update_options_button_look():
	if compact:
		options.text = ""
		options.icon = icon
	else:
		if selected_plugin_index >= 0:
			options.text = plugin_names[selected_plugin_index]
			options.icon = icon if icon_next_to_plugin_name else null
		else:
			options.text = "No plugin selected"
			options.icon = null

func _process(delta):
	_update_btn_toggle_state()

func find_visible_child(node : Control):
	for child in node.get_children():
		if child.visible:
			return child
	return null

func get_main_screen()->String:
	var screen:String
	var base:Panel = plugin.get_editor_interface().get_base_control()
	var editor_head:BoxContainer = base.get_child(0).get_child(0)
	if editor_head.get_child_count()<3:
		# may happen when calling from plugin _init()
		return screen
	var main_screen_buttons:Array = editor_head.get_child(2).get_children()
	for button in main_screen_buttons:
		if button.pressed:
			screen = button.text
			break
	return screen
