extends MovementInputProvider
class_name TouchStickInputProvider

## Proveedor de entrada para Stick Virtual en pantalla táctil (Mobile).
## Busca el nodo de joystick en el grupo "virtual_joystick".

@export var grupo_joystick: StringName = &"virtual_joystick"

func get_target_direction(body: CharacterBody3D) -> Vector3:
	var tree := body.get_tree()
	if not tree:
		return Vector3.ZERO
	var stick: Node = tree.get_first_node_in_group(grupo_joystick)
	if stick and stick.has_method("get_output_vector"):
		var vec2: Vector2 = stick.get_output_vector()
		if vec2.length_squared() >= 0.01:
			return Vector3(vec2.x, 0.0, vec2.y).normalized()
	return Vector3.ZERO

func is_active(body: CharacterBody3D) -> bool:
	var tree := body.get_tree()
	if not tree:
		return false
	var stick: Node = tree.get_first_node_in_group(grupo_joystick)
	if stick and stick.has_method("get_output_vector"):
		var vec2: Vector2 = stick.get_output_vector()
		return vec2.length_squared() >= 0.01
	return false
