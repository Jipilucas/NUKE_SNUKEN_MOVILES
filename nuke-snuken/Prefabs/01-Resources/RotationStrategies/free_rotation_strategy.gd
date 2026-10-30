extends RotationStrategy
class_name FreeRotationStrategy

## Estrategia de rotación libre: Gira suavemente hacia cualquier ángulo sin restricciones.

## Velocidad angular de rotación en radianes por segundo (ej: deg_to_rad(360) = 1 vuelta/seg).
@export var turn_speed: float = 10.0
## Si es true, se orienta instantáneamente hacia la dirección objetivo sin suavizado.
@export var instant: bool = false

func calculate_yaw(current_yaw: float, target_dir: Vector3, delta: float) -> float:
	if target_dir.length_squared() < 0.001:
		return current_yaw
		
	var target_yaw: float = direction_to_yaw(target_dir)
	if instant:
		return target_yaw
		
	# Calcula la diferencia angular por el camino más corto [-PI, PI]
	var diff: float = wrapf(target_yaw - current_yaw, -PI, PI)
	var max_step: float = turn_speed * delta
	
	if abs(diff) <= max_step:
		return target_yaw
	return current_yaw + sign(diff) * max_step
