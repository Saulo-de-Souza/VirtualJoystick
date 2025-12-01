@tool
extends EditorPlugin

var icon = preload("res://addons/virtual_joystick/icon.svg")
var script_main = preload("res://addons/virtual_joystick/virtual_joystick.gd")

func _enter_tree():
	add_custom_type("VirtualJoystick", "Control", script_main, icon)

func _exit_tree():
	remove_custom_type("VirtualJoystick")
