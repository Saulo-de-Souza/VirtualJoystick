@tool
extends EditorPlugin

var icon = preload("res://addons/virtual_joystick_plus/icon.svg")
var script_main = preload("res://addons/virtual_joystick_plus/virtual_joystick_plus.gd")

func _enter_tree():
	add_custom_type("VirtualJoystickPlus", "Control", script_main, icon)

func _exit_tree():
	remove_custom_type("VirtualJoystickPlus")
