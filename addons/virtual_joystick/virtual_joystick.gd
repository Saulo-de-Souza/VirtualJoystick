@tool
class_name VirtualJoystick
extends Control

#region Signals =================================================
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
#endregion Signals ===============================================


#region Private Properties ======================================
var _joystick: VirtualJoystickCircle
var _stick: VirtualJoystickCircle

var _joystick_radius: float = 100.0
var _joystick_border_width: float = 10.0
var _joystick_start_position: Vector2 = Vector2(_joystick_radius + _joystick_border_width, _joystick_radius + _joystick_border_width)

var _stick_radius: float = 45.0
var _stick_border_width: float = -1.0
var _stick_start_position: Vector2 = _joystick_start_position

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

var _DEFAULT_JOYSTICK_TEXTURE = preload("res://addons/virtual_joystick/resources/textures/joystick_texture_1.png")
var _JOYSTICK_TEXTURE_2 = preload("res://addons/virtual_joystick/resources/textures/joystick_texture_2.png")
var _JOYSTICK_TEXTURE_3 = preload("res://addons/virtual_joystick/resources/textures/joystick_texture_3.png")
var _JOYSTICK_TEXTURE_4 = preload("res://addons/virtual_joystick/resources/textures/joystick_texture_4.png")
var _JOYSTICK_TEXTURE_5 = preload("res://addons/virtual_joystick/resources/textures/joystick_texture_5.png")
var _JOYSTICK_TEXTURE_6 = preload("res://addons/virtual_joystick/resources/textures/joystick_texture_6.png")

var _DEFAULT_STICK_TEXTURE = preload("res://addons/virtual_joystick/resources/textures/stick_texture_1.png")
var _STICK_TEXTURE_2 = preload("res://addons/virtual_joystick/resources/textures/stick_texture_2.png")
var _STICK_TEXTURE_3 = preload("res://addons/virtual_joystick/resources/textures/stick_texture_3.png")
var _STICK_TEXTURE_4 = preload("res://addons/virtual_joystick/resources/textures/stick_texture_4.png")
var _STICK_TEXTURE_5 = preload("res://addons/virtual_joystick/resources/textures/stick_texture_5.png")
var _STICK_TEXTURE_6 = preload("res://addons/virtual_joystick/resources/textures/stick_texture_6.png")

enum _presset_enum {
	## Nothing
	NONE,
	## Default presset texture
	PRESSET_DEFAULT,
	## Texture 2
	PRESSET_2,
	## Texture 3
	PRESSET_3,
	## Texture 4
	PRESSET_4,
	## Texture 5
	PRESSET_5,
	## Texture 6
	PRESSET_6,
	
}
#endregion Private Properties ====================================


#region Public Properties =======================================
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
#endregion Public Properties =====================================


#region Exports ===================================================
@export_category("Virtual Joystick")
## Enables or disables the joystick input.
@export var active: bool = true
## Deadzone threshold (0.0 = off, 1.0 = full range).
@export_range(0.0, 0.9, 0.001, "suffix:length") var deadzone: float = 0.1
## Global scale factor of the joystick.
@export_range(0.1, 2.0, 0.001, "suffix:x", "or_greater") var scale_factor: float = 1.0:
	set(value):
		scale_factor = value
		scale = Vector2(value, value)
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
			
@export_category("Joystick")
## Enable the use of textures for the joystick.
@export var joystick_use_textures: bool = true:
	set(value):
		joystick_use_textures = value
		if value and joystick_texture == null:
			_set_joystick_presset(joystick_presset_texture)
		_verify_can_use_border()
		update_configuration_warnings()
		queue_redraw()
## Select one of the available models. More models will be available soon.
@export var joystick_presset_texture: _presset_enum = _presset_enum.PRESSET_5: set = _set_joystick_presset
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
		_joystick_start_position = Vector2(_joystick_radius + _joystick_border_width, _joystick_radius + _joystick_border_width)
		_joystick.position = _joystick_start_position
		_stick_start_position = Vector2(_joystick_radius + _joystick_border_width, _joystick_radius + _joystick_border_width)
		_stick.position = _stick_start_position
		update_configuration_warnings()
		queue_redraw()


@export_category("Stick")
## Enable the use of textures for the stick.
@export var stick_use_textures: bool = true:
	set(value):
		stick_use_textures = value
		if value and stick_texture == null:
			_set_stick_presset(stick_presset_texture)
		update_configuration_warnings()
		queue_redraw()
## Select one of the available models. More models will be available soon.
@export var stick_presset_texture: _presset_enum = _presset_enum.PRESSET_5: set = _set_stick_presset
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
#endregion Exports =================================================


#region Engine Methods =============================================
func _init() -> void:
	_joystick = VirtualJoystickCircle.new(_joystick_start_position, _joystick_radius, _joystick_border_width, false, joystick_color, joystick_opacity)
	_stick = VirtualJoystickCircle.new(_stick_start_position, _stick_radius, _stick_border_width, true, stick_color, stick_opacity)
	queue_redraw()
	

func _ready() -> void:
	set_size(Vector2(_joystick_radius * 2 + _joystick_border_width * 2, _joystick_radius * 2 + _joystick_border_width * 2))
	_update_real_size()


func _draw() -> void:
	if joystick_use_textures and joystick_texture:
		var base_size = joystick_texture.get_size()
		var base_scale = (_joystick_radius * 2) / base_size.x
		draw_set_transform(_joystick.position, 0, Vector2(base_scale, base_scale))
		draw_texture(joystick_texture, -base_size / 2, Color(joystick_color.r, joystick_color.g, joystick_color.b, joystick_opacity))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_joystick.draw(self, false)
			
	if stick_use_textures and stick_texture:
		var stick_size = stick_texture.get_size()
		var stick_scale = (_stick_radius * 2) / stick_size.x
		draw_set_transform(_stick.position, 0, Vector2(stick_scale, stick_scale))
		draw_texture(stick_texture, -stick_size / 2, Color(stick_color.r, stick_color.g, stick_color.b, stick_opacity))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_stick.draw(self, false)

	scale = Vector2(scale_factor, scale_factor)
	set_size(Vector2((_joystick_radius * 2) + (_joystick_border_width * 2), (_joystick_radius * 2) + (_joystick_border_width * 2)))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			distance = event.position.distance_to(_joystick.position)
			_drag_started_inside = distance <= _joystick.radius + _joystick.width / 2
			if _drag_started_inside:
				_click_in = true
				_update_stick(event.position)
			else:
				_click_in = false
		else:
			if _click_in:
				_reset_values()
				_update_emit_signals()
			_click_in = false
			_drag_started_inside = false
			_stick.position = _stick_start_position
			queue_redraw()

	elif event is InputEventScreenDrag:
		if _drag_started_inside:
			_update_stick(event.position)


func _get_configuration_warnings() -> PackedStringArray:
	_warnings = []
	if joystick_use_textures and (joystick_texture == null):
		_warnings.append("The joystick_texture properties must be set when using joystick_use_textures = true.")
	if stick_use_textures and (stick_texture == null):
		_warnings.append("The stick_texture properties must be set when using stick_use_textures = true.")
	if joystick_use_textures and joystick_texture != null and joystick_presset_texture != _presset_enum.NONE and joystick_border > 1.0:
		_warnings.append("When using a texture preset, the ideal border height would be 1.0.")
	return _warnings
	
#endregion Engine Methods =============================================


#region Private Methods ============================================
func _update_stick(_position: Vector2) -> void:
	_delta = _position - _stick_start_position
	if _delta.length() > _joystick.radius:
		_delta = _delta.normalized() * _joystick.radius
	_stick.position = _stick_start_position + _delta
	queue_redraw()

	var processed = _apply_deadzone(_delta / _joystick.radius)
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
	_stick.position = _stick_start_position
	
	var length = (_delta / _joystick.radius).length()
	var dz = clamp(deadzone, 0.0, 0.99)
	if length <= dz:
		_in_deadzone = true
		
	queue_redraw()


## Applies linear deadzone adjustment and calculates resulting angles.
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
		# Re-scale linearly between deadzone and full range
		var adjusted = (length - dz) / (1.0 - dz)
		result = input_value.normalized() * adjusted
		length = adjusted

	var angle_cw = _get_angle_delta(result * _joystick.radius, true, true)
	var angle_ccw = _get_angle_delta(result * _joystick.radius, true, false)
	var angle = _get_angle_delta(result * _joystick.radius, false, false)
	
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
	
	
## Calculates the angle of a vector in degrees.
func _get_angle_delta(delta: Vector2, continuous: bool, clockwise: bool) -> float:
	var angle_deg = 0.0
	if continuous and not clockwise:
		angle_deg = rad_to_deg(atan2(-delta.y, delta.x))
	else:
		angle_deg = rad_to_deg(atan2(delta.y, delta.x))
	if continuous and angle_deg < 0.0:
		angle_deg += 360.0
	return angle_deg


func _set_joystick_presset(_value: _presset_enum) -> void:
	joystick_presset_texture = _value
	match (_value):
		_presset_enum.PRESSET_DEFAULT:
			joystick_texture = _DEFAULT_JOYSTICK_TEXTURE
		_presset_enum.PRESSET_2:
			joystick_texture = _JOYSTICK_TEXTURE_2
		_presset_enum.PRESSET_3:
			joystick_texture = _JOYSTICK_TEXTURE_3
		_presset_enum.PRESSET_4:
			joystick_texture = _JOYSTICK_TEXTURE_4
		_presset_enum.PRESSET_5:
			joystick_texture = _JOYSTICK_TEXTURE_5
		_presset_enum.PRESSET_6:
			joystick_texture = _JOYSTICK_TEXTURE_6
		_presset_enum.NONE:
			if joystick_texture in [_DEFAULT_JOYSTICK_TEXTURE, _JOYSTICK_TEXTURE_2, _JOYSTICK_TEXTURE_3, _JOYSTICK_TEXTURE_4, _JOYSTICK_TEXTURE_5, _JOYSTICK_TEXTURE_6]:
				joystick_texture = null
	_verify_can_use_border()
	update_configuration_warnings()
				
func _set_stick_presset(_value: _presset_enum) -> void:
	stick_presset_texture = _value
	match (_value):
		_presset_enum.PRESSET_DEFAULT:
			stick_texture = _DEFAULT_STICK_TEXTURE
		_presset_enum.PRESSET_2:
			stick_texture = _STICK_TEXTURE_2
		_presset_enum.PRESSET_3:
			stick_texture = _STICK_TEXTURE_3
		_presset_enum.PRESSET_4:
			stick_texture = _STICK_TEXTURE_4
		_presset_enum.PRESSET_5:
			stick_texture = _STICK_TEXTURE_5
		_presset_enum.PRESSET_6:
			stick_texture = _STICK_TEXTURE_6
		_presset_enum.NONE:
			if stick_texture in [_DEFAULT_STICK_TEXTURE, _STICK_TEXTURE_2, _STICK_TEXTURE_3, _STICK_TEXTURE_4, _STICK_TEXTURE_5, _STICK_TEXTURE_6]:
				stick_texture = null


func _verify_can_use_border() -> bool:
	if joystick_use_textures and not joystick_texture == null:
		joystick_border = 1.0
		return false
	return true
#endregion Private Methods ===========================================


#region Public Methods =============================================
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
#endregion Public Methods ============================================


#region Classes ====================================================
class VirtualJoystickCircle extends RefCounted:
	var position: Vector2
	var radius: float
	var color: Color
	var width: float
	var filled: bool
	var antialiased: bool
	var opacity: float:
		set(value):
			opacity = value
			self.color.a = opacity

	func _init(_position: Vector2, _radius: float, _width: float = -1.0, _filled: bool = true, _color: Color = Color.WHITE, _opacity: float = 1.0, _antialiased: bool = true):
		self.position = _position
		self.radius = _radius
		self.color = _color
		self.width = _width
		self.filled = _filled
		self.antialiased = _antialiased
		self.opacity = _opacity
		self.color.a = _opacity

	func draw(canvas_item: CanvasItem, offset: bool) -> void:
		var pos = self.position + (Vector2(self.radius, self.radius) if offset else Vector2.ZERO)
		canvas_item.draw_circle(pos, self.radius, self.color, self.filled, self.width, self.antialiased)
#endregion Classes ===================================================
