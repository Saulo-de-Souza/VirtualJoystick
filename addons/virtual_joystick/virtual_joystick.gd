@tool
class_name VirtualJoystick
extends Control

#region Signals =================================================
## Emitted whenever the joystick value or angle changes.
signal analogic_changed(
	value: Vector2,
	distance: float,
	angle: float,
	angle_clockwise: float,
	angle_not_clockwise: float
)
#endregion Signals ===============================================


#region Private Properties ======================================
var _joystick: VirtualJoystickCircle = null
var _stick: VirtualJoystickCircle = null

var _joystick_radius: float = 100
var _joystick_border_widht = 10
var _joystick_start_position: Vector2 = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)

var _stick_radius: float = 45
var _stick_border_width = -1
var _stick_start_position: Vector2 = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)

var _drag_started_inside: bool = false
var _click_in: bool = false

var _delta: Vector2 = Vector2.ZERO
#endregion Private Properties ====================================


#region Public Properties =======================================
## Normalized joystick direction vector (X, Y).
var value: Vector2 = Vector2.ZERO

## Distance of the stick from the joystick center (0.0 to 1.0).
var distance: float = 0.0

## Angle in degrees, measured clockwise.
var angle_degrees_clockwise: float = 0.0

## Angle in degrees, measured counter-clockwise.
var angle_degrees_not_clockwise: float = 0.0
#endregion Public Properties =====================================


#region Exports ===================================================
@export_category("Joystick")
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
@export_range(1.0, 20.0, 0.01, "suffix:px", "or_greater") var joystick_border: float = 10:
	set(value):
		joystick_border = value
		if _joystick:
			_joystick.width = value
		_joystick_border_widht = value
		_joystick_start_position = Vector2(_joystick_radius + value, _joystick_radius + value)
		_stick_start_position = _joystick_start_position
		queue_redraw()

## Deadzone threshold. Values below this range are ignored.
@export_range(0.0, 0.5, 0.001, "suffix:length") var joystick_deadzone: float = 0.0

## Global scale factor of the joystick.
@export_range(0.1, 2.0, 0.001, "suffix:x", "or_greater") var scale_factor: float = 1:
	set(value):
		scale_factor = value
		scale = Vector2(value, value)
		queue_redraw()

## Enables or disables the joystick input.
@export var active: bool = true


@export_category("Stick")
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
	_joystick = VirtualJoystickCircle.new(_joystick_start_position, _joystick_radius, _joystick_border_widht, false, joystick_color, joystick_opacity)
	_stick = VirtualJoystickCircle.new(_stick_start_position, _stick_radius, _stick_border_width, true, stick_color, stick_opacity)
	queue_redraw()


func _ready() -> void:
	set_size(Vector2(_joystick_radius * 2 + _joystick_border_widht * 2, _joystick_radius * 2 + _joystick_border_widht * 2))


func _draw() -> void:
	_joystick.draw(self, false)
	_stick.draw(self, false)
	scale = Vector2(scale_factor, scale_factor)
	set_size(Vector2((_joystick_radius * 2) + (_joystick_border_widht * 2), (_joystick_radius * 2) + (_joystick_border_widht * 2)))


func _gui_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			distance = event.position.distance_to(_joystick.position)
			_drag_started_inside = distance <= _joystick.radius + _joystick.width / 2
			if _drag_started_inside:
				_click_in = true
				_update_stick(event.position)
		else:
			_stick.position = _stick_start_position
			if _click_in:
				_reset_values()
				_update_emit_signals()
			_click_in = false

	elif event is InputEventScreenDrag and _drag_started_inside:
		_update_stick(event.position)
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
	angle_degrees_clockwise = processed.angle_clockwise
	angle_degrees_not_clockwise = processed.angle_not_clockwise

	_update_emit_signals()


func _reset_values() -> void:
	_delta = Vector2.ZERO
	value = Vector2.ZERO
	distance = 0.0
	angle_degrees_clockwise = 0.0
	angle_degrees_not_clockwise = 0.0
	_stick.position = _stick_start_position
	queue_redraw()


## Applies linear deadzone adjustment and calculates resulting angles.
func _apply_deadzone(input_value: Vector2) -> Dictionary:
	var length = input_value.length()
	var result = Vector2.ZERO
	var deadzone = clamp(joystick_deadzone, 0.0, 0.99)

	if length <= deadzone:
		result = Vector2.ZERO
		length = 0.0
	else:
		# Re-scale linearly between deadzone and full range
		var adjusted = (length - deadzone) / (1.0 - deadzone)
		result = input_value.normalized() * adjusted
		length = adjusted

	var angle_cw = _get_angle_delta(result * _joystick.radius, true, true)
	var angle_ccw = _get_angle_delta(result * _joystick.radius, true, false)

	return {
		"value": result,
		"distance": length,
		"angle_clockwise": angle_cw,
		"angle_not_clockwise": angle_ccw
	}


func _update_emit_signals() -> void:
	analogic_changed.emit(
		value,
		distance,
		_get_angle_delta(_delta, false, false),
		angle_degrees_clockwise,
		angle_degrees_not_clockwise
	)


## Calculates the angle of a vector in degrees.
func _get_angle_delta(delta: Vector2, continuous: bool, clockwise: bool) -> float:
	var _angle_degrees = 0.0
	if continuous and not clockwise:
		_angle_degrees = rad_to_deg(atan2(-delta.y, delta.x))
	else:
		_angle_degrees = rad_to_deg(atan2(delta.y, delta.x))
	if continuous and _angle_degrees < 0:
		_angle_degrees += 360.0
	return _angle_degrees
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

	func _init(
		_position: Vector2,
		_radius: float,
		_width: float = -1.0,
		_filled: bool = true,
		_color: Color = Color(255, 255, 255, 1),
		_opacity: float = 1.0,
		_antialiased: bool = true
	):
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
