extends RotationStrategy
class_name SnappedRotationStrategy

## Estrategia de rotación en ángulos discretos / fijos (ej: 90° o 45°).
## Encastra la dirección a múltiplos exactos de los grados configurados.

enum ModoAngulo {
	GRADOS_90 = 90, # 4 direcciones cardinales (Snake clásico)
	GRADOS_45 = 45  # 8 direcciones (Cardinales + Diagonales)
}

@export var modo_angulo: ModoAngulo = ModoAngulo.GRADOS_90
## Si es true, el giro es instantáneo hacia el nuevo ángulo.
@export var instantaneo: bool = false
## Velocidad angular de transición hacia el ángulo encastrado si no es instantáneo (grados/seg).
@export var velocidad_transicion_grados: float = 540.0
## Si es true, impide realizar un giro exacto de 180° hacia atrás (muy útil en 90° para Snake).
@export var ignorar_reversa_directa: bool = true

func calculate_yaw(current_yaw: float, target_dir: Vector3, delta: float) -> float:
	if target_dir.length_squared() < 0.001:
		return current_yaw
		
	var raw_yaw: float = direction_to_yaw(target_dir)
	var step_rad: float = deg_to_rad(float(modo_angulo))
	
	# Encastra el ángulo al múltiplo más cercano del paso
	var snapped_yaw: float = snappedf(raw_yaw, step_rad)
	
	# Comprobar si es un giro de 180° respecto al actual
	var diff: float = wrapf(snapped_yaw - current_yaw, -PI, PI)
	if ignorar_reversa_directa and abs(abs(diff) - PI) < deg_to_rad(15.0):
		# Intento de ir 180° hacia atrás: se ignora para no suicidarse
		return current_yaw
		
	if instantaneo:
		return snapped_yaw
		
	var max_step: float = deg_to_rad(velocidad_transicion_grados) * delta
	if abs(diff) <= max_step:
		return snapped_yaw
		
	return current_yaw + sign(diff) * max_step
