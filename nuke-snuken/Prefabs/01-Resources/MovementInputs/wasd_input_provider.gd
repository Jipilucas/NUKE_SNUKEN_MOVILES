extends MovementInputProvider
class_name WASDInputProvider

## Proveedor de entrada para Teclado / Mando basado en el InputMap (WASD o Flechas).

@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_forward: StringName = &"move_forward"
@export var action_backward: StringName = &"move_backward"

var _last_target_dir: Vector3 = Vector3.ZERO

func get_target_direction(_body: CharacterBody3D) -> Vector3:
	var input_vec: Vector2 = Input.get_vector(action_left, action_right, action_forward, action_backward)
	if input_vec.length_squared() < 0.01:
		return Vector3.ZERO
	# En Godot: +X = derecha, -X = izquierda, -Z = adelante (forward), +Z = atrás (backward)
	_last_target_dir = Vector3(input_vec.x, 0.0, input_vec.y).normalized()
	return _last_target_dir

func is_active(_body: CharacterBody3D) -> bool:
	return Input.get_vector(action_left, action_right, action_forward, action_backward).length_squared() >= 0.01
