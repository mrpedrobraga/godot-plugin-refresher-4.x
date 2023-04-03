@tool
extends Control

@onready var options = %options
@onready var btn_refresh = %btn_refresh

var plugin : EditorPlugin

const PLUGIN_FOLDER := "res://addons/"

func _ready():
	btn_refresh.icon = plugin.get_editor_interface().get_base_control().get_theme_icon("RotateLeft", "EditorIcons")
	plugin.main_screen_changed.connect(update_current_main_screen)
	
	_on_options_button_down()

var current_main_screen := "2D"

func update_current_main_screen(s):
	current_main_screen = s

var plugin_directories := ["resource_bank_editor"]
var plugin_names := ["Resource Bank"]

func _update_plugins_list():
	plugin_directories.clear()
	plugin_names.clear()
	options.clear()
	var dir := DirAccess.open(PLUGIN_FOLDER)
	
	btn_refresh.disabled = true
	
	for pdir in dir.get_directories():
		if not pdir == "plugin_refresher":
			_search_dir_for_plugins(PLUGIN_FOLDER, pdir)
	
	if plugin_directories.size() > 0:
		btn_refresh.disabled = false
		for i in plugin_names:
			options.add_item(i)
		options.select(0)
	else:
		options.add_separator("No Plugins To Refresh.")
		options.selected = -1
		options.add_item("...")

func _search_dir_for_plugins(base : String, dir_name : String):
	var path = base.path_join(dir_name)
	var dir = DirAccess.open(path)
	
	for file in dir.get_files():
		if file == "plugin.cfg":
			var plugincfg = ConfigFile.new()
			plugincfg.load(path.path_join(file))
			
			plugin_directories.push_back(dir_name)
			plugin_names.push_back(plugincfg.get_value("plugin", "name", ""))
			return
	for subdir in dir.get_directories():
		if not subdir == "plugin_refresher":
			_search_dir_for_plugins(path, subdir)
	

func _on_options_button_down():
	_update_plugins_list()

func _on_btn_refresh_pressed():
	var plugin_name = plugin_directories[options.selected]
	
	var current_main_screen_bkp := current_main_screen
	
	if plugin.get_editor_interface().is_plugin_enabled(plugin_name):
		plugin.get_editor_interface().set_plugin_enabled(plugin_name, false)
	plugin.get_editor_interface().set_plugin_enabled(plugin_name, true)
	
	if current_main_screen_bkp:
		plugin.get_editor_interface().set_main_screen_editor(current_main_screen_bkp)
	print("Refreshing plugin \"", plugin_names[options.selected], "\"")

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


