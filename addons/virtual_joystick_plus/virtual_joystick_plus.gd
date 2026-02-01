@tool
@icon("res://addons/virtual_joystick_plus/icon.svg")

## A virtual on-screen joystick used to provide analog movement input on touch-based devices.
class_name VirtualJoystickPlus
extends Control


## Emitted when the stick is moved.
signal analogic_changed(
	value: Vector2,
	distance: float,
	angle: float,
	angle_clockwise: float,
	angle_not_clockwise: float
)

## Emitted when the stick enters the dead zone.
signal deadzone_enter

## Emitted when the stick leaves the dead zone.
signal deadzone_leave


var _joystick: VirtualJoystickCircle
var _stick: VirtualJoystickCircle

var _joystick_radius: float = 100.0
var _joystick_border_width: float = 10.0

var _stick_radius: float = 45.0
var _stick_border_width: float = -1.0

var _drag_started_inside := false
var _click_in := false
var _delta: Vector2 = Vector2.ZERO
var _in_deadzone: bool = false:
	set(value):
		if value != _in_deadzone:
			_in_deadzone = value
			if not active:
				return
			if _in_deadzone:
				deadzone_enter.emit()
			else:
				deadzone_leave.emit()

var _real_size: Vector2 = size * scale
var _warnings: PackedStringArray = []

var _relative_position: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _dynamic_active: bool = false
var _visible_runtime: bool = true


var _DEFAULT_JOYSTICK_TEXTURE = preload("res://addons/virtual_joystick_plus/resources/textures/joystick_texture_1.png")
var _JOYSTICK_TEXTURE_2 = preload("res://addons/virtual_joystick_plus/resources/textures/joystick_texture_2.png")
var _JOYSTICK_TEXTURE_3 = preload("res://addons/virtual_joystick_plus/resources/textures/joystick_texture_3.png")
var _JOYSTICK_TEXTURE_4 = preload("res://addons/virtual_joystick_plus/resources/textures/joystick_texture_4.png")
var _JOYSTICK_TEXTURE_5 = preload("res://addons/virtual_joystick_plus/resources/textures/joystick_texture_5.png")
var _JOYSTICK_TEXTURE_6 = preload("res://addons/virtual_joystick_plus/resources/textures/joystick_texture_6.png")

var _DEFAULT_STICK_TEXTURE = preload("res://addons/virtual_joystick_plus/resources/textures/stick_texture_1.png")
var _STICK_TEXTURE_2 = preload("res://addons/virtual_joystick_plus/resources/textures/stick_texture_2.png")
var _STICK_TEXTURE_3 = preload("res://addons/virtual_joystick_plus/resources/textures/stick_texture_3.png")
var _STICK_TEXTURE_4 = preload("res://addons/virtual_joystick_plus/resources/textures/stick_texture_4.png")
var _STICK_TEXTURE_5 = preload("res://addons/virtual_joystick_plus/resources/textures/stick_texture_5.png")
var _STICK_TEXTURE_6 = preload("res://addons/virtual_joystick_plus/resources/textures/stick_texture_6.png")

enum Preset {
	## Nothing
	NONE,
	## Default preset texture
	PRESET_DEFAULT,
	## Texture 2
	PRESET_2,
	## Texture 3
	PRESET_3,
	## Texture 4
	PRESET_4,
	## Texture 5
	PRESET_5,
	## Texture 6
	PRESET_6,
}

enum JoystickMode {
	## The joystick has a fixed position and only responds to touches that start inside its base area. [br]
	## This is the classic on-screen joystick behavior.
	NORMAL,
	## The joystick appears at the position where the user touches the screen and remains fixed there until the touch is released.
	DYNAMIC,
	## Similar to DYNAMIC, but when the stick reaches the maximum radius, the joystick base follows the finger movement.[br]
	## The base movement is clamped to the Control size, ensuring it never leaves its bounds.
	FOLLOW
}

enum VisibilityMode {
		## The joystick is always visible, even when not being interacted with.
		VISIBILITY_ALWAYS,
		## The joystick becomes visible only while the screen is being touched and automatically hides when the touch is released.
		VISIBILITY_WHEN_TOUCHED,
	};


## Normalized joystick direction vector (X, Y).
var value: Vector2 = Vector2.ZERO

## Distance of the stick from the joystick center (0.0 to 1.0).
var distance: float = 0.0

## Angle in degrees (universal reference, 0° = right).
var angle_degrees: float = 0.0

## Angle in degrees, measured clockwise.
var angle_degrees_clockwise: float = 0.0

## Angle in degrees, measured counter-clockwise.
var angle_degrees_not_clockwise: float = 0.0


@export_category("Virtual Joystick")
## Enables or disables the joystick input.
@export var active: bool = true

## Defines how the joystick behaves in relation to touch input.[br]
##[br] 
## [b][color=yellow]IMPORTANT:[/color][/b][br]
## The size of this Control defines the touch interaction area for the joystick.[br]
## For [b]DYNAMIC[/b] and [b]FOLLOW[/b] modes to work as expected, you should resize this Control
## to cover the desired screen region (for example, the left half of the screen
## for a left movement stick).[br]
##[br]
## - [b]NORMAL:[/b] Reacts only to touches starting inside the joystick base.[br]
## - [b]DYNAMIC:[/b] The joystick appears at the touch position within this Control area.[br]
## - [b]FOLLOW:[/b] Similar to DYNAMIC, but the base follows the finger when reaching its limit.
@export var joystick_mode: JoystickMode = JoystickMode.NORMAL

## Controls when the joystick is visually displayed on the screen.[br]
##[br]
## [b][color=yellow]Note:[/color][/b][br]
## Visibility is independent from touch detection. Touch events are still limited
## to the size of this Control, which should be resized to match the intended
## interaction area, especially when using dynamic joystick modes.
@export var visibility_mode: VisibilityMode = VisibilityMode.VISIBILITY_ALWAYS:
	set(value):
		visibility_mode = value
		if not Engine.is_editor_hint():
			if visibility_mode == VisibilityMode.VISIBILITY_WHEN_TOUCHED:
				_visible_runtime = false
			else:
				_visible_runtime = true
			queue_redraw()
		
## Deadzone threshold (0.0 = off, 1.0 = full range).
@export_range(0.0, 0.9, 0.001, "suffix:length") var deadzone: float = 0.1
## Global scale factor of the joystick.
@export_range(0.1, 2.0, 0.001, "suffix:x", "or_greater") var scale_factor: float = 1.0:
	set(value):
		scale_factor = value
		_joystick.scale = scale_factor
		_stick.scale = scale_factor
		_update_real_size()
		queue_redraw()
## If true, the Joystick will only be displayed on the screen on mobile devices.
@export var only_mobile: bool = false:
	set(value):
		only_mobile = value
		if only_mobile == true and OS.get_name().to_lower() not in ["android", "ios"]:
			visible = false
		else:
			visible = true
			
## Sets the base position of the joystick using normalized coordinates (0.0 to 1.0).[br]
##[br]
## This position is relative to the size of this Control and represents the initial
## center of the joystick base.[br]
##[br]
## - (0, 0) places the joystick at the top-left corner.[br]
## - (0.5, 0.5) places it at the center.[br]
## - (1, 1) places it at the bottom-right corner.[br]
##[br]
## [b][color=yellow]IMPORTANT:[/color][/b][br]
## For [b]DYNAMIC[/b] and [b]FOLLOW[/b] modes, this value is used only as the initial position.
## The joystick will then respond to touch events occurring anywhere inside this
## [b]Control's area[/b].[br]
##[br]
## The final position is clamped to ensure the joystick remains fully visible.
@export var relative_position: Vector2 = Vector2(0.5, 0.5):
	set(value):
		relative_position = value.clamp(Vector2.ZERO, Vector2.ONE)
		_update_base_from_relative()


@export_category("Joystick")
## Enable the use of textures for the joystick.
@export var joystick_use_textures: bool = true:
	set(value):
		joystick_use_textures = value
		if value and joystick_texture == null:
			_set_joystick_preset(joystick_preset_texture)
		_verify_can_use_border()
		update_configuration_warnings()
		queue_redraw()
## Select one of the available models. More models will be available soon.
@export var joystick_preset_texture: Preset = Preset.PRESET_5: set = _set_joystick_preset
## Select a texture for the joystick figure.
@export var joystick_texture: Texture2D = _JOYSTICK_TEXTURE_5:
	set(value):
		joystick_texture = value
		update_configuration_warnings()
		_verify_can_use_border()
		queue_redraw()
## Base color of the joystick background.
@export_color_no_alpha() var joystick_color: Color = Color.WHITE:
	set(value):
		joystick_color = value
		if _joystick:
			_joystick.color = value
			_joystick.opacity = joystick_opacity
		queue_redraw()
## Opacity of the joystick base.
@export_range(0.0, 1.0, 0.001, "suffix:alpha") var joystick_opacity: float = 0.8:
	set(value):
		joystick_opacity = value
		if _joystick:
			_joystick.opacity = value
		queue_redraw()
## Width of the joystick base border.
@export_range(1.0, 20.0, 0.01, "suffix:px", "or_greater") var joystick_border: float = 1.0:
	set(value):
		joystick_border = value
		_joystick.width = value
		_joystick_border_width = value
		_joystick.position = _joystick.relative_position
		_stick.position = _stick.relative_position
		update_configuration_warnings()
		queue_redraw()


@export_category("Stick")
## Enable the use of textures for the stick.
@export var stick_use_textures: bool = true:
	set(value):
		stick_use_textures = value
		if value and stick_texture == null:
			_set_stick_preset(stick_preset_texture)
		update_configuration_warnings()
		queue_redraw()
## Select one of the available models. More models will be available soon.
@export var stick_preset_texture: Preset = Preset.PRESET_5: set = _set_stick_preset
## Select a texture for the stick figure.
@export var stick_texture: Texture2D = _STICK_TEXTURE_5:
	set(value):
		stick_texture = value
		update_configuration_warnings()
		queue_redraw()
## Stick (thumb) color.
@export_color_no_alpha() var stick_color: Color = Color.WHITE:
	set(value):
		stick_color = value
		if _stick:
			_stick.color = value
			_stick.opacity = stick_opacity
		queue_redraw()
## Opacity of the stick.
@export_range(0.0, 1.0, 0.001, "suffix:alpha") var stick_opacity: float = 0.8:
	set(value):
		stick_opacity = value
		if _stick:
			_stick.opacity = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(300, 300)
	_joystick = VirtualJoystickCircle.new(_relative_position, _relative_position, scale_factor, _joystick_radius, _joystick_border_width, false, joystick_color, joystick_opacity)
	_stick = VirtualJoystickCircle.new(_relative_position, _relative_position, scale_factor, _stick_radius, _stick_border_width, true, stick_color, stick_opacity)
	queue_redraw()


func _ready() -> void:
	_update_real_size()

	if not Engine.is_editor_hint():
		if visibility_mode == VisibilityMode.VISIBILITY_WHEN_TOUCHED:
			_visible_runtime = false
		else:
			_visible_runtime = true
		queue_redraw()
	_update_base_from_relative()


func _draw() -> void:
	if not _visible_runtime:
		return

	if joystick_use_textures and joystick_texture:
		var base_size = joystick_texture.get_size()
		var base_scale = ((_joystick_radius * 2) / base_size.x) * scale_factor
		draw_set_transform(_joystick.position, 0, Vector2(base_scale, base_scale))
		draw_texture(joystick_texture, -base_size / 2, Color(joystick_color.r, joystick_color.g, joystick_color.b, joystick_opacity))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_joystick.draw(self )

	if stick_use_textures and stick_texture:
		var stick_size = stick_texture.get_size()
		var stick_scale = ((_stick_radius * 2) / stick_size.x) * scale_factor
		draw_set_transform(_stick.position, 0, Vector2(stick_scale, stick_scale))
		draw_texture(stick_texture, -stick_size / 2, Color(stick_color.r, stick_color.g, stick_color.b, stick_opacity))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_stick.draw(self )


func _gui_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_index = event.index

			if visibility_mode == VisibilityMode.VISIBILITY_WHEN_TOUCHED:
				_visible_runtime = true
				queue_redraw()

			match joystick_mode:
				JoystickMode.NORMAL:
					distance = event.position.distance_to(_joystick.position)
					_drag_started_inside = distance <= _joystick.radius * _joystick.scale + _joystick.width / 2
					if _drag_started_inside:
						_click_in = true
						_update_stick(event.position)
					else:
						_click_in = false

				JoystickMode.DYNAMIC, JoystickMode.FOLLOW:
					_dynamic_active = true
					_click_in = true
					_drag_started_inside = true

					var local_pos = event.position
					_set_base_position(local_pos)
					_update_stick(local_pos)

		else:
			if event.index != _touch_index:
				return

			_reset_values()
			_update_emit_signals()

			_click_in = false
			_drag_started_inside = false
			_dynamic_active = false
			_touch_index = -1

			_stick.position = _stick.relative_position

			if visibility_mode == VisibilityMode.VISIBILITY_WHEN_TOUCHED:
				_visible_runtime = false

			queue_redraw()

	elif event is InputEventScreenDrag:
		if event.index != _touch_index:
			return
		if _drag_started_inside:
			_update_stick(event.position)


func _get_configuration_warnings() -> PackedStringArray:
	_warnings = []
	if joystick_use_textures and (joystick_texture == null):
		_warnings.append("The joystick_texture properties must be set when using joystick_use_textures = true.")
	if stick_use_textures and (stick_texture == null):
		_warnings.append("The stick_texture properties must be set when using stick_use_textures = true.")
	if joystick_use_textures and joystick_texture != null and joystick_preset_texture != Preset.NONE and joystick_border > 1.0:
		_warnings.append("When using a texture preset, the ideal border height would be 1.0.")
	return _warnings


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_base_from_relative()
		_update_real_size()


func _update_base_from_relative() -> void:
	if not is_inside_tree():
		return

	var half = Vector2(
		_joystick.radius * scale_factor + _joystick_border_width,
		_joystick.radius * scale_factor + _joystick_border_width
	)

	# Área útil (onde o centro pode ficar)
	var usable_size = size - half * 2.0
	usable_size.x = max(0.0, usable_size.x)
	usable_size.y = max(0.0, usable_size.y)

	# Normalizado → espaço local
	var pos = half + usable_size * relative_position

	_relative_position = pos

	if is_instance_valid(_joystick):
		_joystick.relative_position = pos
		_joystick.position = pos

	if is_instance_valid(_stick):
		_stick.relative_position = pos
		_stick.position = pos

	queue_redraw()


func _update_stick(_position: Vector2) -> void:
	_delta = _position - _stick.relative_position
	var max_radius = _joystick.radius * _joystick.scale

	if _delta.length() > max_radius:
		if joystick_mode == JoystickMode.FOLLOW:
			var excess = _delta.normalized() * (_delta.length() - max_radius)
			_set_base_position(_joystick.relative_position + excess)
			_delta = _position - _stick.relative_position

		_delta = _delta.normalized() * max_radius

	_stick.position = _stick.relative_position + _delta
	queue_redraw()

	var processed = _apply_deadzone(_delta / max_radius)
	value = processed.value
	distance = processed.distance
	angle_degrees = processed.angle_degrees
	angle_degrees_clockwise = processed.angle_clockwise
	angle_degrees_not_clockwise = processed.angle_not_clockwise

	_update_emit_signals()


func _reset_values() -> void:
	_delta = Vector2.ZERO
	value = Vector2.ZERO
	distance = 0.0
	angle_degrees = 0.0
	angle_degrees_clockwise = 0.0
	angle_degrees_not_clockwise = 0.0
	_stick.position = _stick.relative_position

	var length = (_delta / (_joystick.radius * _joystick.scale)).length()
	var dz = clamp(deadzone, 0.0, 0.99)
	if length <= dz:
		_in_deadzone = true

	queue_redraw()


func _apply_deadzone(input_value: Vector2) -> Dictionary:
	var length = input_value.length()
	var result = Vector2.ZERO
	var dz = clamp(deadzone, 0.0, 0.99)

	if length <= dz:
		_in_deadzone = true
		result = Vector2.ZERO
		length = 0.0
	else:
		_in_deadzone = false
		var adjusted = (length - dz) / (1.0 - dz)
		result = input_value.normalized() * adjusted
		length = adjusted

	var angle_cw = _get_angle_delta(result * _joystick.radius * _joystick.scale, true, true)
	var angle_ccw = _get_angle_delta(result * _joystick.radius * _joystick.scale, true, false)
	var angle = _get_angle_delta(result * _joystick.radius * _joystick.scale, false, false)

	if active:
		return {
			"value": result,
			"distance": length,
			"angle_clockwise": angle_cw,
			"angle_not_clockwise": angle_ccw,
			"angle_degrees": angle
		}
	else:
		return {
			"value": Vector2.ZERO,
			"distance": 0.0,
			"angle_clockwise": 0.0,
			"angle_not_clockwise": 0.0,
			"angle_degrees": 0.0
		}


func _update_emit_signals() -> void:
	if not active:
		return
	if _in_deadzone:
		analogic_changed.emit(
			Vector2.ZERO,
			0.0,
			0.0,
			0.0,
			0.0
			)
	else:
		analogic_changed.emit(
		value,
		distance,
		angle_degrees,
		angle_degrees_clockwise,
		angle_degrees_not_clockwise
	)


func _update_real_size() -> void:
	_real_size = size * scale
	pivot_offset = size / 2


func _get_angle_delta(delta: Vector2, continuous: bool, clockwise: bool) -> float:
	var angle_deg = 0.0
	if continuous and not clockwise:
		angle_deg = rad_to_deg(atan2(-delta.y, delta.x))
	else:
		angle_deg = rad_to_deg(atan2(delta.y, delta.x))
	if continuous and angle_deg < 0.0:
		angle_deg += 360.0
	return angle_deg


func _set_joystick_preset(_value: Preset) -> void:
	joystick_preset_texture = _value
	match (_value):
		Preset.PRESET_DEFAULT:
			joystick_texture = _DEFAULT_JOYSTICK_TEXTURE
		Preset.PRESET_2:
			joystick_texture = _JOYSTICK_TEXTURE_2
		Preset.PRESET_3:
			joystick_texture = _JOYSTICK_TEXTURE_3
		Preset.PRESET_4:
			joystick_texture = _JOYSTICK_TEXTURE_4
		Preset.PRESET_5:
			joystick_texture = _JOYSTICK_TEXTURE_5
		Preset.PRESET_6:
			joystick_texture = _JOYSTICK_TEXTURE_6
		Preset.NONE:
			if joystick_texture in [_DEFAULT_JOYSTICK_TEXTURE, _JOYSTICK_TEXTURE_2, _JOYSTICK_TEXTURE_3, _JOYSTICK_TEXTURE_4, _JOYSTICK_TEXTURE_5, _JOYSTICK_TEXTURE_6]:
				joystick_texture = null
	_verify_can_use_border()
	update_configuration_warnings()


func _set_stick_preset(_value: Preset) -> void:
	stick_preset_texture = _value
	match (_value):
		Preset.PRESET_DEFAULT:
			stick_texture = _DEFAULT_STICK_TEXTURE
		Preset.PRESET_2:
			stick_texture = _STICK_TEXTURE_2
		Preset.PRESET_3:
			stick_texture = _STICK_TEXTURE_3
		Preset.PRESET_4:
			stick_texture = _STICK_TEXTURE_4
		Preset.PRESET_5:
			stick_texture = _STICK_TEXTURE_5
		Preset.PRESET_6:
			stick_texture = _STICK_TEXTURE_6
		Preset.NONE:
			if stick_texture in [_DEFAULT_STICK_TEXTURE, _STICK_TEXTURE_2, _STICK_TEXTURE_3, _STICK_TEXTURE_4, _STICK_TEXTURE_5, _STICK_TEXTURE_6]:
				stick_texture = null


func _verify_can_use_border() -> bool:
	if joystick_use_textures and not joystick_texture == null:
		joystick_border = 1.0
		return false
	return true


func _set_base_position(pos: Vector2) -> void:
	var half = Vector2(
		_joystick.radius * scale_factor + _joystick_border_width,
		_joystick.radius * scale_factor + _joystick_border_width
	)

	var clamped = pos.clamp(half, size - half)

	_relative_position = clamped
	_joystick.relative_position = clamped
	_joystick.position = clamped
	_stick.relative_position = clamped
	_stick.position = clamped


## Returns the current joystick vector value.
func get_value() -> Vector2:
	return value


## Returns the joystick distance (0 to 1).
func get_distance() -> float:
	return distance


## Returns the current joystick angle (clockwise).
func get_angle_degrees_clockwise() -> float:
	return angle_degrees_clockwise


## Returns the current joystick angle (counter-clockwise).
func get_angle_degrees_not_clockwise() -> float:
	return angle_degrees_not_clockwise


## Returns a specific angle configuration.
func get_angle_degrees(continuous: bool = true, clockwise: bool = false) -> float:
	return _get_angle_delta(_delta, continuous, clockwise)


class VirtualJoystickCircle extends RefCounted:
	var position: Vector2:
		get():
			return position
	var radius: float
	var color: Color
	var width: float
	var filled: bool
	var antialiased: bool
	var opacity: float:
		set(value):
			opacity = value
			self.color.a = opacity
	var relative_position: Vector2
	var scale: float = 1.0

	func _init(_position: Vector2, _relative_position: Vector2, _scale: float, _radius: float, _width: float = -1.0, _filled: bool = true, _color: Color = Color.WHITE, _opacity: float = 1.0, _antialiased: bool = true):
		self.position = _position
		self.radius = _radius
		self.color = _color
		self.width = _width
		self.filled = _filled
		self.antialiased = _antialiased
		self.opacity = _opacity
		self.color.a = _opacity
		self.relative_position = _relative_position
		self.scale = _scale

	func draw(canvas_item: CanvasItem) -> void:
		canvas_item.draw_circle(self.position, self.radius * self.scale, self.color, self.filled, self.width, self.antialiased)
