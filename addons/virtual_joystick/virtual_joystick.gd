@tool
class_name VirtualJoystick extends Control


#region Signals =================================================
## Emitted when the analog value is changed.
signal analogic_changed(value: Vector2, distance: float, angle: float, angle_clockwise: float, angle_not_clockwise: float)
#endregion Signals ==============================================


#region Private Propertys =======================================
var _joystick: VirtualJoystickCircle = null
var _stick: VirtualJoystickCircle = null

var _joystick_radius: float = 100
var _joystick_border_widht = 10
var _joystick_start_position: Vector2 = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)

var _stick_radius: float = 45
var _stick_border_width = -1
var _stick_start_position: Vector2 = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)

var _dragging: bool = false
var _drag_started_inside: bool = false
var _click_in: bool = false

var _delta: Vector2 = Vector2.ZERO
#endregion Private Propertys ====================================


#region Plubic Propertys ========================================
## Gets the joystick value. Returns a Vector2.
var value: Vector2 = Vector2.ZERO

## Gets the distance of the stick from the base of the joystick (length). Returns a float.
var distance: float = 0.0

## Gets the angle in degrees of the joystick in a clockwise direction. Returns a float.
var angle_degrees_clockwise: float = 0.0

## Gets the angle in degrees of the joystick in a counter-clockwise direction. Returns a float.
var angle_degrees_not_clockwise: float = 0.0
#endregion Plubic Propertys =====================================


#region Exports ===================================================
@export_category("Joystick")
## Joystick base color.
@export_color_no_alpha() var joystick_color: Color = Color.WHITE:
	set(value):
		joystick_color = value
		_joystick.color = value
		_joystick.opacity = joystick_opacity
		queue_redraw()
## Opacity of the joystick's base color.
@export_range(0.0, 1.0, 0.001, "suffix:alpha") var joystick_opacity: float = 0.8:
	set(value):
		joystick_opacity = value
		_joystick.opacity = value
		queue_redraw()
## Height of the joystick base edge.
@export_range(1.0, 20.0, 0.01, "suffix:px", "or_greater") var joystick_border: float = 10:
	set(value):
		joystick_border = value
		_joystick.width = value
		_joystick_border_widht = value
		_joystick_start_position = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)
		_joystick.position = _joystick_start_position
		_stick_start_position = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)
		_stick.position = _stick_start_position
		queue_redraw()
##
@export_range(0.0, 0.5, 0.001, "suffix:length") var joystick_deadzone: float = 0.0
## Scale of Joystick
@export_range(0.1, 2.0, 0.001, "suffix:px", "or_greater") var scale_factor: float = 1:
	set(value):
		scale_factor = value
		scale = Vector2(scale_factor, scale_factor)
		queue_redraw()
## Turn the joystick on or off.
@export var active: bool = true

@export_category("Stick")
## Stick color.
@export_color_no_alpha() var stick_color: Color = Color.WHITE:
	set(value):
		stick_color = value
		_stick.color = value
		_stick.opacity = stick_opacity
		queue_redraw()
## Opacity of the Stick's color.
@export_range(0.0, 1.0, 0.001, "suffix:alpha") var stick_opacity: float = 0.8:
	set(value):
		stick_opacity = value
		_stick.opacity = value
		queue_redraw()
#endregion Exports =================================================


#region Engine Methods =============================================
func _ready() -> void:
	set_size(Vector2(_joystick_radius * 2 + _joystick_border_widht * 2, _joystick_radius * 2 + _joystick_border_widht * 2))


func _draw() -> void:
	_joystick.draw(self, false)
	_stick.draw(self, false)
	scale = Vector2(scale_factor, scale_factor)
	set_size(Vector2((_joystick_radius * 2) + (_joystick_border_widht * 2), (_joystick_radius * 2) + (_joystick_border_widht * 2)))
	
	
func _gui_input(event: InputEvent) -> void:
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
				queue_redraw()
				_delta = Vector2.ZERO
				value = Vector2.ZERO
				distance = 0.0
				angle_degrees_clockwise = 0.0
				angle_degrees_not_clockwise = 0.0
				_update_emit_signals()
			_click_in = false
	elif event is InputEventScreenDrag:
		if _drag_started_inside:
			_update_stick(event.position)


func _init() -> void:
	_joystick = VirtualJoystickCircle.new(_joystick_start_position, _joystick_radius, _joystick_border_widht, false, joystick_color, joystick_opacity)
	_stick = VirtualJoystickCircle.new(_stick_start_position, _stick_radius, _stick_border_width, true, stick_color, stick_opacity)

	_joystick.color = joystick_color
	_joystick.opacity = joystick_opacity

	_joystick.width = joystick_border
	_joystick_border_widht = joystick_border
	_joystick_start_position = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)
	_joystick.position = _joystick_start_position
	_stick_start_position = Vector2(_joystick_radius + _joystick_border_widht, _joystick_radius + _joystick_border_widht)
	_stick.position = _stick_start_position

	_stick.color = stick_color
	_stick.opacity = stick_opacity

	scale = Vector2(scale_factor, scale_factor)

	queue_redraw()
#endregion Engine Methods =============================================


#region Private Methods ============================================
func _update_stick(position: Vector2) -> void:
	_delta = position - _stick_start_position
	if _delta.length() > _joystick.radius:
		_delta = _delta.normalized() * _joystick.radius
	_stick.position = _stick_start_position + _delta
	queue_redraw()
	value = _get_value_delta(_delta)
	distance = _get_value_delta(_delta).length()
	angle_degrees_clockwise = _get_angle_delta(_delta, true, true)
	angle_degrees_not_clockwise = _get_angle_delta(_delta, true, false)
	_update_emit_signals()


func _update_emit_signals() -> void:
	analogic_changed.emit(_get_value_delta(_delta), _get_value_delta(_delta).length(), _get_angle_delta(_delta, false, false), _get_angle_delta(_delta, true, true), _get_angle_delta(_delta, true, false))


func _get_angle_delta(delta: Vector2, continuos: bool, clockwise: bool) -> float:
	var _angle_degress = 0
	if continuos and not clockwise:
		_angle_degress = rad_to_deg(atan2(-delta.y, delta.x))
	else:
		_angle_degress = rad_to_deg(atan2(delta.y, delta.x))
	if continuos and _angle_degress < 0:
		_angle_degress += 360
	return _angle_degress
	
	
func _get_value_delta(delta: Vector2) -> Vector2:
	return delta / _joystick.radius
	
#endregion Private Methods ===========================================


#region Public Methods =============================================
## Gets the joystick value. Returns a Vector2.
func get_value() -> Vector2:
	return value


## Gets the angle in degrees of the joystick in a clockwise direction. Returns a float.
func get_angle_degrees_clockwise() -> float:
	return angle_degrees_clockwise


## Gets the angle in degrees of the joystick in a counter-clockwise direction. Returns a float.
func get_angle_degrees_not_clockwise() -> float:
	return angle_degrees_not_clockwise


## Gets the angle in degrees of the joystick. Returns a float.
func get_angle_degress(continuos: bool = true, clockwise: bool = false) -> float:
	return _get_angle_delta(_delta, continuos, clockwise)


## Gets the distance of the stick from the base of the joystick (length). Returns a float.
func get_distance() -> float:
	return distance

#endregion Public Methods ==========================================


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
			position: Vector2,
			radius: float,
			width: float = -1.0,
			filled: bool = true,
			color: Color = Color(255, 255, 255, 1),
			opacity: float = 1,
			antialiased: bool = true
		):
		self.position = position
		self.radius = radius
		self.color = color
		self.width = width
		self.filled = filled
		self.antialiased = antialiased
		self.opacity = opacity
		self.color.a = opacity

	func draw(canvas_item: CanvasItem, offset: bool) -> void:
		if self.filled:
			if offset:
				canvas_item.draw_circle(self.position + Vector2(self.radius, self.radius), self.radius, self.color, self.filled, -1, self.antialiased)
			else:
				canvas_item.draw_circle(self.position, self.radius, self.color, self.filled, -1, self.antialiased)
		else:
			if offset:
				canvas_item.draw_circle(self.position + Vector2(self.radius, self.radius), self.radius, self.color, self.filled, self.width, self.antialiased)
			else:
				canvas_item.draw_circle(self.position, self.radius, self.color, self.filled, self.width, self.antialiased)
#endregion Classes =================================================
