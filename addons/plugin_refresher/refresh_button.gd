@tool
extends Control

const PROJECT_METADATA_SECTION = "plugin_refresher"
const PROJECT_METADATA_KEY = "selected_plugin" 

const EDITOR_SETTINGS_NAME_PREFIX = "refresher_plugin/"
const EDITOR_SETTINGS_NAME_COMPACT = EDITOR_SETTINGS_NAME_PREFIX + "compact"
const EDITOR_SETTINGS_NAME_SHOW_ENABLE_MENU = EDITOR_SETTINGS_NAME_PREFIX + "show_enable_menu"
const EDITOR_SETTINGS_NAME_SHOW_SWITCH = EDITOR_SETTINGS_NAME_PREFIX + "show_switch"
const EDITOR_SETTINGS_NAME_SHOW_ON_OFF_TOGGLE = EDITOR_SETTINGS_NAME_PREFIX + "show_on_off_toggle"
const EDITOR_SETTINGS_NAME_SHOW_RESTART_BUTTON = EDITOR_SETTINGS_NAME_PREFIX + "show_restart_button"

var switch_icon := preload("plug_switch_icon.svg")
var list_icon := preload("plug_list_icon.svg")

@export var show_enable_menu: bool = true:
	set(value):
		show_enable_menu = value
		_update_children_visibility()
@export var show_switch: bool = true:
	set(value):
		show_switch = value
		_update_children_visibility()
@export var compact: bool = false:
	set(value):
		compact = value
		_update_switch_options_button_look()
@export var show_on_off_toggle: bool = true:
	set(value):
		show_on_off_toggle = value
		_update_children_visibility()
@export var show_restart_button: bool = true:
	set(value):
		show_restart_button = value
		_update_children_visibility()
@export var icon_next_to_plugin_name := true:
	set(value):
		icon_next_to_plugin_name = value
		_update_switch_options_button_look()

@onready var enable_menu := %enable_menu
@onready var switch_options := %switch_options
@onready var btn_toggle := %btn_toggle
@onready var reset_button := %reset_button

var plugin : EditorPlugin

const PLUGIN_FOLDER := "res://addons/"

func _ready():
	plugin.main_screen_changed.connect(update_current_main_screen)
	
	await get_tree().process_frame
	_update_plugins_list()
	var selected_plugin = _get_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, "")
	selected_plugin_index = plugin_ids.find(selected_plugin)
	
	enable_menu.icon = list_icon
	reset_button.icon = get_theme_icon(&"Reload", &"EditorIcons")
	
	compact = _get_editor_setting(EDITOR_SETTINGS_NAME_COMPACT, compact)
	show_enable_menu = _get_editor_setting(EDITOR_SETTINGS_NAME_SHOW_ENABLE_MENU, show_enable_menu)
	show_switch = _get_editor_setting(EDITOR_SETTINGS_NAME_SHOW_SWITCH, show_switch)
	show_on_off_toggle = _get_editor_setting(EDITOR_SETTINGS_NAME_SHOW_ON_OFF_TOGGLE, show_on_off_toggle)
	show_restart_button = _get_editor_setting(EDITOR_SETTINGS_NAME_SHOW_RESTART_BUTTON, show_restart_button)
	if not show_enable_menu and not show_switch:
		show_enable_menu = true
	if not show_on_off_toggle and not show_restart_button:
		show_on_off_toggle = true

	enable_menu.about_to_popup.connect(_on_enable_menu_about_to_popup)
	enable_menu.get_popup().index_pressed.connect(_on_enable_menu_item_selected)
	switch_options.button_down.connect(_on_switch_options_button_down)
	switch_options.item_selected.connect(_on_switch_options_item_selected)
	btn_toggle.toggled.connect(_on_btn_toggle_toggled)
	reset_button.pressed.connect(_on_restart_button_pressed)
	
	_update_switch_options_button_look()
	_update_children_visibility()
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

var show_switch_option_index = -1

var compact_view_option_index = -1
var show_on_off_toggle_option_index = -1
var show_restart_button_option_index = -1
var show_enable_menu_option_index = -1

func _update_plugins_list():
	var selected_prior = null
	if selected_plugin_index >= 0 and selected_plugin_index < plugin_ids.size():
		selected_prior = plugin_ids[selected_plugin_index]
	plugin_ids.clear()
	plugin_directories.clear()
	plugin_names.clear()

	_search_dir_for_plugins(PLUGIN_FOLDER)
	selected_plugin_index = -1
	for i in plugin_ids.size():
		if plugin_ids[i] == selected_prior:
			selected_plugin_index = i
			break

func _search_dir_for_plugins(plugin_folder: String, relative_base_folder: String = ""):
	var path := plugin_folder.path_join(relative_base_folder)
	var dir := DirAccess.open(path)
	
	for subdir_name in dir.get_directories():
		var relative_folder = relative_base_folder.path_join(subdir_name)
		var subdir := DirAccess.open(path.path_join(subdir_name))
		if subdir == null: # Can happen for symlink. They are listed as folder, but if the link is broken, DirAccess returns null
			continue
		for file in subdir.get_files():
			if file == "plugin.cfg":
				if plugin_folder.path_join(relative_folder) == plugin.get_script().resource_path.get_base_dir():
					continue
				var plugincfg = ConfigFile.new()
				plugincfg.load(path.path_join(subdir_name).path_join(file))
				plugin_ids.push_back(relative_folder)
				plugin_directories.push_back(relative_folder)
				plugin_names.push_back(plugincfg.get_value("plugin", "name", ""))
		_search_dir_for_plugins(plugin_folder, relative_folder)

func _is_plugin_enabled(plugin_index: int) -> bool:
	return plugin.get_editor_interface().is_plugin_enabled(plugin_directories[plugin_index])

func _set_plugin_enabled(plugin_index: int, enabled: bool):
	plugin.get_editor_interface().set_plugin_enabled(plugin_directories[plugin_index], enabled)

func _get_editor_setting(name: String, default_value: Variant = null) -> Variant:
	if plugin.get_editor_interface().get_editor_settings().has_setting(name):
		return plugin.get_editor_interface().get_editor_settings().get_setting(name)
	else:
		return default_value

func _set_editor_setting(name: String, value: Variant):
	plugin.get_editor_interface().get_editor_settings().set_setting(name, value)
	
func _set_project_metadata(section: String, key: String, data: Variant):
	plugin.get_editor_interface().set_project_metadata(section, key, data)

func _get_project_metadata(section: String, key: String, default: Variant = null):
	return plugin.get_editor_interface().get_editor_settings().get_project_metadata(section, key, default)

func _update_enable_menu_popup():
	_update_plugins_list()
	
	var popup = enable_menu.get_popup()
	popup.clear()
	
	var popup_item_idx = 0
	if plugin_ids.size() > 0:
		for i in plugin_ids.size():
			popup.add_check_item(plugin_names[i])
			popup.set_item_checked(i, _is_plugin_enabled(i))
			popup_item_idx += 1
	else:
		popup.add_separator("No plugins")
		popup_item_idx += 1
	popup.add_separator()
	popup_item_idx += 1
	if !show_switch:
		popup.add_item("Show quick switch")
	else:
		popup.add_item("Hide quick switch")
	show_switch_option_index = popup_item_idx
	popup_item_idx += 1 # just for the case further options will be added

func _update_switch_button_popup():
	_update_plugins_list()
	
	switch_options.clear()
	btn_toggle.disabled = true
	
	var popup_item_idx = 0
	if plugin_ids.size() > 0:
		btn_toggle.disabled = false
		for i in plugin_ids.size():
			switch_options.add_item(plugin_names[i])
			popup_item_idx += 1
		switch_options.selected = selected_plugin_index
	else:
		switch_options.add_separator("No plugins")
		popup_item_idx += 1
		switch_options.selected = -1
	switch_options.add_separator()
	popup_item_idx += 1
	if !compact:
		switch_options.get_popup().add_item("Set compact view")
	else:
		switch_options.get_popup().add_item("Show plug-in name")
	compact_view_option_index = popup_item_idx
	popup_item_idx += 1
	if !show_on_off_toggle:
		switch_options.get_popup().add_item("Show on/off toggle")
	else:
		switch_options.get_popup().add_item("Hide on/off toggle")
	show_on_off_toggle_option_index = popup_item_idx
	popup_item_idx += 1
	if !show_restart_button:
		switch_options.get_popup().add_item("Show restart button")
	else:
		switch_options.get_popup().add_item("Hide restart button")
	show_restart_button_option_index = popup_item_idx
	popup_item_idx += 1
	switch_options.add_separator()
	popup_item_idx += 1
	if !show_enable_menu:
		switch_options.get_popup().add_item("Show enable menu")
	else:
		switch_options.get_popup().add_item("Hide enable menu")
	show_enable_menu_option_index = popup_item_idx
	popup_item_idx += 1 # just for the case further options will be added

func _on_enable_menu_about_to_popup():
	_update_enable_menu_popup()

func _on_enable_menu_item_selected(index):
	if index == show_switch_option_index:
		show_switch = !show_switch
		plugin.get_editor_interface().get_editor_settings().set_setting(EDITOR_SETTINGS_NAME_SHOW_SWITCH, show_switch)
	elif index < plugin_ids.size():
		_set_plugin_enabled(index, !_is_plugin_enabled(index))
		
func _on_switch_options_button_down():
	_update_switch_button_popup()
	_update_switch_options_button_look()

func _on_btn_toggle_toggled(button_pressed):
	var current_main_screen_bkp = current_main_screen
	
	if selected_plugin_index >= 0:
		_set_plugin_enabled(selected_plugin_index, button_pressed)
	
	if button_pressed:
		if current_main_screen_bkp:
			plugin.get_editor_interface().set_main_screen_editor(current_main_screen_bkp)
			
func _on_restart_button_pressed():
	if _is_plugin_enabled(selected_plugin_index):
		_set_plugin_enabled(selected_plugin_index, false)
	_set_plugin_enabled(selected_plugin_index, true)

func _on_switch_options_item_selected(index):
	if index == compact_view_option_index:
		compact = !compact
		_set_editor_setting(EDITOR_SETTINGS_NAME_COMPACT, compact)
		switch_options.selected = selected_plugin_index
	elif index == show_on_off_toggle_option_index:
		show_on_off_toggle = !show_on_off_toggle
		_set_editor_setting(EDITOR_SETTINGS_NAME_SHOW_ON_OFF_TOGGLE, show_on_off_toggle)
		if not show_on_off_toggle and not show_restart_button:
			show_restart_button = true
			_set_editor_setting(EDITOR_SETTINGS_NAME_SHOW_RESTART_BUTTON, show_restart_button)
	elif index == show_restart_button_option_index:
		show_restart_button = !show_restart_button
		_set_editor_setting(EDITOR_SETTINGS_NAME_SHOW_RESTART_BUTTON, show_restart_button)
		if not show_restart_button and not show_on_off_toggle:
			show_on_off_toggle = true
			_set_editor_setting(EDITOR_SETTINGS_NAME_SHOW_ON_OFF_TOGGLE, show_on_off_toggle)
	elif index == show_enable_menu_option_index:
		show_enable_menu = !show_enable_menu
		_set_editor_setting(EDITOR_SETTINGS_NAME_SHOW_ENABLE_MENU, show_enable_menu)
	elif index < plugin_ids.size():
		_set_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, plugin_directories[switch_options.selected])
		auto_enable = false
		selected_plugin_index = index
		if selected_plugin_index >= plugin_ids.size():
			selected_plugin_index = -1
		_update_btn_toggle_state()
	_update_switch_options_button_look()

func _update_children_visibility():
	if enable_menu != null:
		enable_menu.visible = show_enable_menu
	if switch_options != null:
		switch_options.visible = show_switch
	if btn_toggle != null:
		btn_toggle.visible = show_switch and show_on_off_toggle
	if reset_button != null:
		reset_button.visible = show_switch and show_restart_button

var auto_enable: bool = false

func _update_btn_toggle_state():
	if plugin != null and selected_plugin_index >= 0:
		btn_toggle.disabled = false
		var plugin_enabled = _is_plugin_enabled(selected_plugin_index)
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

func _update_switch_options_button_look():
	if compact:
		switch_options.text = ""
		switch_options.icon = switch_icon
	else:
		if selected_plugin_index >= 0:
			switch_options.text = plugin_names[selected_plugin_index]
			switch_options.icon = switch_icon if icon_next_to_plugin_name else null
		else:
			switch_options.text = "No plugin selected"
			switch_options.icon = null

func _process(delta):
	_update_btn_toggle_state()
	if auto_enable:
		if not _is_plugin_enabled(selected_plugin_index):
			_set_plugin_enabled(selected_plugin_index, true)

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
