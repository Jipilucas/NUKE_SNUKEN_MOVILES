extends RotationStrategy
class_name LimitedAngleRotationStrategy

## Estrategia de rotación con límite de ángulo:
## 1. Limita la velocidad máxima de giro (tasa de giro / turn-rate).
## 2. Restringe el ángulo máximo de deflexión respecto al rumbo actual para evitar
##    giros bruscos en reversa (180°) que provocarían colisión directa contra el cuerpo.

## Velocidad máxima de giro en grados por segundo (ej: 180°/s).
@export_range(30.0, 720.0, 5.0) var velocidad_giro_grados: float = 200.0

## Si es true, impide que el jugador intente girar directamente en reversa hacia su propio cuerpo.
@export var limitar_cono_deflexion: bool = true

## Ángulo máximo permitido de giro instantáneo respecto al rumbo actual en grados (ej: 120°).
## Si la entrada apunta fuera de este cono (como un giro de 180° en reversa), se clampa al borde del cono.
@export_range(45.0, 175.0, 5.0) var angulo_maximo_deflexion_grados: float = 135.0

func calculate_yaw(current_yaw: float, target_dir: Vector3, delta: float) -> float:
	if target_dir.length_squared() < 0.001:
		return current_yaw
		
	var target_yaw: float = direction_to_yaw(target_dir)
	var diff: float = wrapf(target_yaw - current_yaw, -PI, PI)
	
	# Restricción de cono (evitar giro en reversa directo de 180°)
	if limitar_cono_deflexion:
		var max_deflection_rad: float = deg_to_rad(angulo_maximo_deflexion_grados)
		if abs(diff) > max_deflection_rad:
			# Se clampa al ángulo más cercano permitido dentro del cono
			diff = sign(diff) * max_deflection_rad
			target_yaw = current_yaw + diff
			
	# Avance angular con tasa de giro limitada
	var max_step: float = deg_to_rad(velocidad_giro_grados) * delta
	if abs(diff) <= max_step:
		return target_yaw
		
	return current_yaw + sign(diff) * max_step
