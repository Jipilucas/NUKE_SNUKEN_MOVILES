extends Resource
class_name RotationStrategy

## Clase base abstracta para estrategias de rotación del "Norte" del personaje.

## Calcula el nuevo ángulo de rotación Y (en radianes) a partir del ángulo actual y la dirección deseada.
func calculate_yaw(current_yaw: float, _target_dir: Vector3, _delta: float) -> float:
	return current_yaw

## Convierte un vector de dirección XZ normalizado a su ángulo yaw correspondiente en Godot (-Z es adelante).
static func direction_to_yaw(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

## Convierte un ángulo yaw de Godot al vector frontal horizontal resultante.
static func yaw_to_forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
