extends Resource
class_name SnakeBodyComponent3D

## Componente de manejo de cuerpo tipo "Snake" para Godot 4 (GDScript 2.0).
## 
## Diseñado bajo la arquitectura de Resources desacoplados:
## 1. Registra la trayectoria exacta de la cabeza (CharacterBody3D) en un historial de "migas de pan" (Breadcrumbs).
## 2. Contenedor dedicado: Agrupa todos los eslabones en un Node3D específico para mantener limpio el árbol de escenas.
## 3. Despegue en salto y gravedad: Cuando el jugador salta, los cuerpos se despegan del suelo siguiendo
##    la curva del salto, y descienden naturalmente con gravedad artificial sin quedar flotando congelados.
## 4. Mantiene la cola siempre en el último eslabón, intercalando los cuerpos nuevos entre la cabeza y la cola.

# ==============================================================================
# SEÑALES
# ==============================================================================
signal cuerpo_agregado(segmento: Node3D, indice: int)
signal cuerpo_eliminado(indice: int)
signal cola_creada(cola: Node3D)
signal cantidad_segmentos_cambiada(total: int)

# ==============================================================================
# PROPIEDADES EXPORTADAS
# ==============================================================================
@export_category("Contenedor de Nodos")
## Nodo3D opcional donde agrupar los eslabones. Si se deja vacío, el componente crea uno automáticamente en la escena.
var contenedor_personalizado: Node3D = null

@export_category("Escenas de Eslabones")
## Escena asignada en el editor para cada cuerpo intermedio (debe heredar de Node3D).
@export var cuerpo_scene: PackedScene

## Escena asignada en el editor para la cola final (debe heredar de Node3D).
@export var cola_scene: PackedScene

@export_category("Comportamiento Snake")
## Distancia métrica que separa a cada eslabón a lo largo de la trayectoria.
@export_range(0.2, 5.0, 0.1) var distancia_segmento: float = 1.0

## Velocidad de interpolación slerp con la que los cuerpos giran hacia la trayectoria.
@export var velocidad_rotacion: float = 14.0

## Distancia mínima recorrida por la cabeza para registrar un nuevo punto en la ruta.
@export var distancia_muestreo: float = 0.05

## Si es true, la cola se instancia automáticamente cuando el jugador inicia.
@export var crear_cola_al_iniciar: bool = true

@export_category("Gravedad y Despegue del Suelo")
## Activa o desactiva el sistema de gravedad y adaptación vertical sobre los eslabones.
@export var gravedad_activa: bool = true

## Aceleración de gravedad en unidades/s² con la que descienden los eslabones en el aire.
@export_range(0.0, 50.0, 0.5) var fuerza_gravedad: float = 14.0

## Altura del centro del eslabón respecto al suelo (evita que el modelo se entierre).
@export var offset_suelo: float = 0.4

## Velocidad de elevación al despegar por salto o al subir por rampas/terreno.
@export var velocidad_subida_terreno: float = 24.0

## Distancia máxima que el raycast busca suelo hacia abajo.
@export var distancia_maxima_rayo: float = 40.0

## Máscara de colisión física (capas de colisión que representan el terreno o suelo).
@export_flags_3d_physics var mascara_colision_suelo: int = 1

## Factor de flotación aérea (0.0 = gravedad activa con saltos orgánicos; 1.0 = ignora el suelo y flota).
@export_range(0.0, 1.0, 0.05) var flotacion_aerea: float = 0.0

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _cuerpos: Array[Node3D] = []
var _cola: Node3D = null
var _historial_posiciones: Array[Vector3] = []
var _velocidades_y: Dictionary = {}  # Clave: instance_id (int) -> Valor: vel_y acumulada (float)

var _nodo_contenedor: Node3D = null
var _creo_contenedor_propio: bool = false
var _inicializado: bool = false
var _padre_mundo: Node = null

func _init() -> void:
	resource_local_to_scene = true


# ==============================================================================
# CICLO PRINCIPAL (Actor Passing)
# ==============================================================================

## Método principal llamado en el _physics_process del CharacterBody3D.
func actualizar(body: CharacterBody3D, delta: float) -> void:
	if not is_instance_valid(body):
		return
	
	if not _inicializado:
		_inicializar(body)
	
	var pos_cabeza: Vector3 = body.global_position
	
	# 1. Registrar punto en el historial si la cabeza se ha desplazado
	if _historial_posiciones.is_empty():
		_historial_posiciones.push_front(pos_cabeza)
	else:
		if pos_cabeza.distance_to(_historial_posiciones[0]) >= distancia_muestreo:
			_historial_posiciones.push_front(pos_cabeza)
	
	# 2. Obtener la cadena ordenada de eslabones: [Cuerpo0, Cuerpo1, ..., CuerpoN, Cola]
	var segmentos_activos: Array[Node3D] = _obtener_segmentos_ordenados()
	if segmentos_activos.is_empty():
		return
	
	# 3. Posicionar y rotar cada eslabón a su distancia correspondiente en la ruta
	var total_distancia_requerida: float = float(segmentos_activos.size() + 1) * distancia_segmento
	
	for i in range(segmentos_activos.size()):
		var seg: Node3D = segmentos_activos[i]
		if not is_instance_valid(seg):
			continue
		
		# Cada eslabón i debe estar a (i + 1) * distancia_segmento de la cabeza a lo largo de la ruta
		var distancia_objetivo: float = float(i + 1) * distancia_segmento
		var muestra: Dictionary = _obtener_posicion_en_historial(pos_cabeza, distancia_objetivo)
		
		# --- TRASLACIÓN CON DESPEGUE DE SALTO Y GRAVEDAD ---
		var pos_final: Vector3 = muestra["posicion"]
		
		if gravedad_activa and fuerza_gravedad > 0.0 and flotacion_aerea < 1.0:
			pos_final.y = _calcular_y_con_gravedad_y_salto(body, seg, pos_final, delta)
		
		seg.global_position = pos_final
		
		# --- ROTACIÓN SUAVE HACIA LA TRAYECTORIA ---
		var dir_adelante: Vector3 = muestra["direccion"]
		if dir_adelante.length_squared() > 0.001:
			var target_pos: Vector3 = seg.global_position + dir_adelante
			if not dir_adelante.is_equal_approx(Vector3.UP) and not dir_adelante.is_equal_approx(Vector3.DOWN):
				var target_transform: Transform3D = seg.global_transform.looking_at(target_pos, Vector3.UP)
				seg.global_basis = seg.global_basis.slerp(target_transform.basis, velocidad_rotacion * delta)
	
	# 4. Purgar puntos obsoletos del historial para mantener óptimo el uso de memoria
	_recortar_historial(pos_cabeza, total_distancia_requerida + 3.0)


# ==============================================================================
# SISTEMA DE GRAVEDAD ARTIFICIAL Y DESPEGUE EN SALTO
# ==============================================================================

## Calcula la altura Y del eslabón:
## - Si el camino tiene elevación por salto (el player saltó), permite que el eslabón se despegue del suelo.
## - En el aire o caída libre, aplica gravedad acelerada hacia el suelo.
## - Si el player se detiene en el suelo, asienta suavemente los cuerpos para evitar que queden flotando en el aire.
func _calcular_y_con_gravedad_y_salto(body: CharacterBody3D, seg: Node3D, pos_camino: Vector3, delta: float) -> float:
	var espacio: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	if not espacio:
		return pos_camino.y
	
	# Raycast vertical hacia abajo desde una altura superior al punto más alto conocido
	var origen_y: float = maxf(pos_camino.y, seg.global_position.y) + 1.5
	var origen_rayo: Vector3 = Vector3(pos_camino.x, origen_y, pos_camino.z)
	var destino_rayo: Vector3 = origen_rayo - Vector3(0.0, distancia_maxima_rayo, 0.0)
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origen_rayo, destino_rayo, mascara_colision_suelo)
	query.exclude = [body.get_rid()]
	
	var colision: Dictionary = espacio.intersect_ray(query)
	
	# Si no hay suelo debajo (abismo o caída infinita), conserva la altura del camino histórico
	if colision.is_empty():
		return pos_camino.y
	
	var altura_suelo: float = colision.position.y + offset_suelo
	
	# 1. DESPEGUE DEL SUELO CUANDO SALTA EL PLAYER:
	# Calculamos cuánto se elevó la cabeza por encima del suelo en este punto histórico
	var elevacion_salto: float = maxf(0.0, pos_camino.y - altura_suelo)
	
	# Si el jugador ya aterrizó en el suelo y se detuvo, reducimos la elevación para que la cola baje al piso
	var jugador_en_suelo_quieto: bool = body.is_on_floor() and body.velocity.length_squared() < 0.05
	if jugador_en_suelo_quieto:
		elevacion_salto = 0.0
	
	# Altura deseada combinando suelo y salto
	var altura_objetivo: float = altura_suelo + elevacion_salto
	
	# Mezcla con flotación aérea en caso de estar configurada
	if flotacion_aerea > 0.0:
		altura_objetivo = lerpf(altura_objetivo, pos_camino.y, clampf(flotacion_aerea, 0.0, 1.0))
	
	var seg_id: int = seg.get_instance_id()
	var vel_y: float = _velocidades_y.get(seg_id, 0.0)
	var y_actual: float = seg.global_position.y
	
	# CASO A: El eslabón debe subir (despegue de salto o terreno que asciende)
	if y_actual < altura_objetivo:
		vel_y = 0.0
		_velocidades_y[seg_id] = vel_y
		return move_toward(y_actual, altura_objetivo, velocidad_subida_terreno * delta)
	
	# CASO B: El eslabón está en el aire por encima del objetivo y desciende por gravedad
	elif y_actual > altura_objetivo:
		vel_y -= fuerza_gravedad * delta
		var nueva_y: float = y_actual + vel_y * delta
		
		# Aterrizaje sobre la superficie objetivo
		if nueva_y <= altura_objetivo:
			nueva_y = altura_objetivo
			vel_y = 0.0
		
		_velocidades_y[seg_id] = vel_y
		return nueva_y
	
	# CASO C: En contacto con la altura objetivo
	else:
		_velocidades_y[seg_id] = 0.0
		return altura_objetivo


# ==============================================================================
# GESTIÓN DEL CONTENEDOR ESPECÍFICO DE NODOS
# ==============================================================================

## Obtiene o crea el Node3D dedicado donde residen todos los eslabones
func _obtener_contenedor(body: CharacterBody3D) -> Node3D:
	if is_instance_valid(contenedor_personalizado):
		return contenedor_personalizado
	
	if is_instance_valid(_nodo_contenedor):
		return _nodo_contenedor
	
	# Crear contenedor dedicado en el mundo automáticamente
	_nodo_contenedor = Node3D.new()
	_nodo_contenedor.name = body.name + "_SnakeBody"
	_creo_contenedor_propio = true
	_padre_mundo.add_child(_nodo_contenedor)
	return _nodo_contenedor


# ==============================================================================
# GESTIÓN DINÁMICA DE CUERPOS Y COLA
# ==============================================================================

## Agrega un nuevo cuerpo intermedio. Siempre se inserta entre la cabeza y la cola.
func agregar_cuerpo(body: CharacterBody3D) -> Node3D:
	if not is_instance_valid(body):
		return null
	if not _inicializado:
		_inicializar(body)
	
	if not cuerpo_scene:
		push_warning("SnakeBodyComponent3D: No se ha asignado 'cuerpo_scene' en el Inspector.")
		return null
	
	var nuevo_cuerpo: Node3D = cuerpo_scene.instantiate() as Node3D
	if not nuevo_cuerpo:
		push_warning("SnakeBodyComponent3D: La escena 'cuerpo_scene' debe heredar de Node3D.")
		return null
	
	# Colocación inicial en la posición del eslabón anterior para evitar parpadeos en (0,0,0)
	if not _cuerpos.is_empty() and is_instance_valid(_cuerpos.back()):
		nuevo_cuerpo.global_position = _cuerpos.back().global_position
	elif _cola and is_instance_valid(_cola):
		nuevo_cuerpo.global_position = _cola.global_position
	else:
		nuevo_cuerpo.global_position = body.global_position
	
	# Al agregarlo a _cuerpos, queda ubicado inmediatamente antes de _cola en la cadena
	_cuerpos.append(nuevo_cuerpo)
	
	# Se añade al contenedor específico (no suelto en el mundo)
	var contenedor: Node3D = _obtener_contenedor(body)
	contenedor.add_child(nuevo_cuerpo)
	
	var nuevo_indice: int = _cuerpos.size() - 1
	cuerpo_agregado.emit(nuevo_cuerpo, nuevo_indice)
	cantidad_segmentos_cambiada.emit(obtener_cantidad_segmentos())
	
	return nuevo_cuerpo


## Elimina el último cuerpo intermedio antes de la cola (si existe).
func quitar_cuerpo() -> bool:
	if _cuerpos.is_empty():
		return false
	
	var ultimo: Node3D = _cuerpos.pop_back() as Node3D
	if is_instance_valid(ultimo):
		_velocidades_y.erase(ultimo.get_instance_id())
		ultimo.queue_free()
	
	cuerpo_eliminado.emit(_cuerpos.size())
	cantidad_segmentos_cambiada.emit(obtener_cantidad_segmentos())
	return true


## Retorna la cantidad total de eslabones actuales (cuerpos + cola).
func obtener_cantidad_segmentos() -> int:
	var total: int = _cuerpos.size()
	if _cola and is_instance_valid(_cola):
		total += 1
	return total


## Devuelve la lista de cuerpos intermedios actuales.
func obtener_cuerpos() -> Array[Node3D]:
	return _cuerpos.duplicate()


## Devuelve el nodo de la cola actual (o null si no hay).
func obtener_cola() -> Node3D:
	return _cola


# ==============================================================================
# ALGORITMO DE TRAYECTORIA (Breadcrumbs Polyline Sampling)
# ==============================================================================

## Recorre el historial de puntos acumulando distancia e interpola suavemente
## entre los dos puntos que contienen la distancia objetivo.
func _obtener_posicion_en_historial(pos_cabeza: Vector3, distancia_objetivo: float) -> Dictionary:
	if _historial_posiciones.is_empty():
		return {"posicion": pos_cabeza, "direccion": Vector3.FORWARD}
	
	var anterior: Vector3 = pos_cabeza
	var dist_acumulada: float = 0.0
	
	for i in range(_historial_posiciones.size()):
		var actual: Vector3 = _historial_posiciones[i]
		var seg_dist: float = anterior.distance_to(actual)
		
		if seg_dist <= 0.0001:
			continue
		
		if dist_acumulada + seg_dist >= distancia_objetivo:
			var restante: float = distancia_objetivo - dist_acumulada
			var t: float = restante / seg_dist
			var pos_interpolada: Vector3 = anterior.lerp(actual, t)
			# Vector apuntando hacia la cabeza por el camino
			var direccion: Vector3 = (anterior - actual).normalized()
			return {"posicion": pos_interpolada, "direccion": direccion}
		
		dist_acumulada += seg_dist
		anterior = actual
	
	# Si la cabeza aún no ha avanzado suficiente distancia total,
	# el segmento permanece en el extremo final registrado
	var ultimo_punto: Vector3 = _historial_posiciones.back()
	var dir_final: Vector3 = (anterior - ultimo_punto).normalized() if anterior != ultimo_punto else Vector3.FORWARD
	return {"posicion": ultimo_punto, "direccion": dir_final}


## Elimina los puntos históricos cuya distancia exceda el largo total de la serpiente.
func _recortar_historial(pos_cabeza: Vector3, max_distancia: float) -> void:
	if _historial_posiciones.size() < 3:
		return
	
	var anterior: Vector3 = pos_cabeza
	var dist_acumulada: float = 0.0
	var corte_idx: int = -1
	
	for i in range(_historial_posiciones.size()):
		var actual: Vector3 = _historial_posiciones[i]
		dist_acumulada += anterior.distance_to(actual)
		if dist_acumulada > max_distancia:
			corte_idx = i + 1
			break
		anterior = actual
	
	if corte_idx != -1 and corte_idx < _historial_posiciones.size():
		_historial_posiciones.resize(corte_idx)


# ==============================================================================
# INICIALIZACIÓN Y LIMPIEZA
# ==============================================================================

func _inicializar(body: CharacterBody3D) -> void:
	_inicializado = true
	_padre_mundo = body.get_parent()
	if not _padre_mundo:
		_padre_mundo = body.get_tree().current_scene
	
	# Conexión para limpiar segmentos en caso de que el CharacterBody3D sea eliminado
	if not body.tree_exited.is_connected(limpiar):
		body.tree_exited.connect(limpiar)
	
	_historial_posiciones.clear()
	_historial_posiciones.push_front(body.global_position)
	
	if crear_cola_al_iniciar and cola_scene and not _cola:
		_crear_cola(body)


func _crear_cola(body: CharacterBody3D) -> void:
	if not cola_scene:
		return
	var instancia: Node3D = cola_scene.instantiate() as Node3D
	if not instancia:
		push_warning("SnakeBodyComponent3D: La escena 'cola_scene' debe heredar de Node3D.")
		return
	
	_cola = instancia
	_cola.global_position = body.global_position
	
	# Se añade al contenedor dedicado
	var contenedor: Node3D = _obtener_contenedor(body)
	contenedor.add_child(_cola)
	
	cola_creada.emit(_cola)
	cantidad_segmentos_cambiada.emit(obtener_cantidad_segmentos())


## Devuelve todos los eslabones en el orden correcto de cabeza a cola:
## [Cuerpos..., Cola]
func _obtener_segmentos_ordenados() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for c in _cuerpos:
		if is_instance_valid(c):
			lista.append(c)
	if _cola and is_instance_valid(_cola):
		lista.append(_cola)
	return lista


## Limpia y destruye todos los segmentos y su contenedor dedicado si fue creado dinámicamente.
func limpiar() -> void:
	for c in _cuerpos:
		if is_instance_valid(c):
			c.queue_free()
	_cuerpos.clear()
	
	if _cola and is_instance_valid(_cola):
		_cola.queue_free()
		_cola = null
	
	if _creo_contenedor_propio and is_instance_valid(_nodo_contenedor):
		_nodo_contenedor.queue_free()
		_nodo_contenedor = null
	
	_historial_posiciones.clear()
	_velocidades_y.clear()
	_inicializado = false
