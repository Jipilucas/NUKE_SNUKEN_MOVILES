extends Resource
class_name MovementInputProvider

## Clase base abstracta para proveedores de entrada de movimiento.
## Traduce las intenciones del jugador en un vector de dirección 3D en el plano horizontal (XZ).

## Retorna la dirección horizontal normalizada deseada. Si no hay entrada activa, retorna Vector3.ZERO.
func get_target_direction(_body: CharacterBody3D) -> Vector3:
	return Vector3.ZERO

## Indica si el jugador está interactuando activamente con este método de entrada.
func is_active(_body: CharacterBody3D) -> bool:
	return false
