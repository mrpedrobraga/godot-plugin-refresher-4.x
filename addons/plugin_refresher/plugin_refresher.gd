@tool
extends EditorPlugin

const RefreshButton: Script = preload("refresh_button.gd")

var refresh_button: RefreshButton

func _enter_tree() -> void:
	refresh_button = preload("refresh_button.tscn").instantiate() as RefreshButton
	refresh_button.refresh_plugin = self
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, refresh_button)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, refresh_button)
	if refresh_button:
		refresh_button.queue_free()
