extends Control
class_name MobileVirtualJoystick

## Control UI de Joystick Virtual para pantallas táctiles y móviles.
## Dibuja proceduralmente su base y perilla para no requerir texturas externas.

@export var radius: float = 75.0
@export var handle_radius: float = 30.0
@export var deadzone: float = 0.15
@export var color_base: Color = Color(0.2, 0.2, 0.2, 0.4)
@export var color_border: Color = Color(0.8, 0.8, 0.8, 0.5)
@export var color_handle: Color = Color(1.0, 1.0, 1.0, 0.7)

var _output: Vector2 = Vector2.ZERO
var _touch_id: int = -1
var _handle_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

func _ready() -> void:
	add_to_group(&"virtual_joystick")
	custom_minimum_size = Vector2(radius * 2.0 + 20.0, radius * 2.0 + 20.0)
	_reset_handle()

func get_output_vector() -> Vector2:
	return _output

func is_active() -> bool:
	return _output.length_squared() >= deadzone * deadzone

func _reset_handle() -> void:
	_handle_pos = size * 0.5
	_output = Vector2.ZERO
	_touch_id = -1
	_is_dragging = false
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	# Círculo base
	draw_circle(center, radius, color_base)
	draw_arc(center, radius, 0.0, TAU, 32, color_border, 2.0, true)
	# Perilla / Handle
	draw_circle(_handle_pos, handle_radius, color_handle)

func _gui_input(event: InputEvent) -> void:
	var center := size * 0.5
	
	# Soporte Touch (Mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_id == -1 and event.position.distance_to(center) <= radius * 1.5:
				_touch_id = event.index
				_is_dragging = true
				_update_joystick(event.position)
		elif event.index == _touch_id:
			_reset_handle()
			
	elif event is InputEventScreenDrag:
		if event.index == _touch_id:
			_update_joystick(event.position)
			
	# Soporte Mouse (para pruebas en Desktop)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.position.distance_to(center) <= radius * 1.5:
					_is_dragging = true
					_update_joystick(event.position)
			else:
				if _is_dragging:
					_reset_handle()
					
	elif event is InputEventMouseMotion:
		if _is_dragging:
			_update_joystick(event.position)

func _update_joystick(pos: Vector2) -> void:
	var center := size * 0.5
	var diff := pos - center
	var dist := diff.length()
	
	if dist > radius:
		diff = diff.normalized() * radius
		dist = radius
		
	_handle_pos = center + diff
	
	var norm_dist := dist / radius
	if norm_dist < deadzone:
		_output = Vector2.ZERO
	else:
		# Remapea la distancia fuera de la zona muerta
		var factor := (norm_dist - deadzone) / (1.0 - deadzone)
		_output = diff.normalized() * factor
		
	queue_redraw()
