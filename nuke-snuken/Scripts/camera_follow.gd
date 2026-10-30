extends Node3D
class_name CameraFollow3D

## Controlador de cámara de seguimiento en tercera persona / vista superior (Top-Down / Twin-Stick).
## Sigue la posición del jugador pero desacopla su rotación para evitar que la cámara gire con él,
## manteniendo su propia orientación en el eje Y (yaw) y ángulo de inclinación (pitch).

@export_category("Objetivo")
## Nodo al que seguirá la cámara. Si no se asigna, intentará seguir automáticamente al nodo padre.
@export var objetivo: Node3D
## Desplazamiento respecto al centro del objetivo (ej: altura del pivote sobre el suelo).
@export var offset_objetivo: Vector3 = Vector3(0.0, 1.0, 0.0)

@export_category("Seguimiento")
## Si es true, la cámara interpola suavemente su posición hacia el objetivo.
@export var seguimiento_suave: bool = true
## Velocidad de interpolación del movimiento de cámara.
@export var velocidad: float = 8.0
## Si el objetivo se aleja más de esta distancia de golpe (ej. al spawnear o teletransportarse),
## la cámara salta inmediatamente a la posición deseada sin lerp.
@export var distancia_teletransporte: float = 8.0

@export_category("Rotación")
## Si es true, la cámara desacopla su rotación del jugador y mantiene su propia orientación fija.
@export var desacoplar_rotacion: bool = true

## Inclinación de la cámara (pitch en eje X) en grados (negativo = mirando hacia abajo al suelo).
@export var inclinacion_x_grados: float = -50.0:
	set(val):
		inclinacion_x_grados = val
		_actualizar_rotacion_fija()

## Orientación de la cámara (yaw en eje Y) en grados (0 = mirando al norte / -Z).
@export var rotacion_y_grados: float = 0.0:
	set(val):
		rotacion_y_grados = val
		_actualizar_rotacion_fija()

## Balanceo / alabeo (roll en eje Z) en grados (normalmente 0).
@export var inclinacion_z_grados: float = 0.0:
	set(val):
		inclinacion_z_grados = val
		_actualizar_rotacion_fija()

@export_category("Distancia de Cámara")
## Si este nodo tiene un hijo Camera3D, ajusta automáticamente su posición Z local a 'distancia'.
@export var ajustar_camara_hija: bool = false
## Distancia de la cámara hacia atrás (zoom) a lo largo del brazo/pivote.
@export var distancia: float = 14.0:
	set(val):
		distancia = val
		if is_inside_tree() and ajustar_camara_hija and is_instance_valid(camara_hija):
			camara_hija.position = Vector3(0.0, 0.0, distancia)

var _rotacion_fija: Vector3
var _iniciado: bool = false
@onready var camara_hija: Camera3D = get_node_or_null("Camera3D") as Camera3D

func _ready() -> void:
	# En multijugador: si este nodo es hijo de un jugador remoto, desactivamos la cámara local
	if get_parent() is CharacterBody3D and not is_multiplayer_authority():
		set_physics_process(false)
		set_process(false)
		if camara_hija:
			camara_hija.current = false
		return

	if not objetivo:
		objetivo = get_parent() as Node3D

	# Configuramos la rotación fija a partir de las propiedades exportadas
	_actualizar_rotacion_fija()

	# Desacoplamos del transform del padre para no rotar con él
	if desacoplar_rotacion:
		set_as_top_level(true)
		global_rotation = _rotacion_fija

	# Ajustar cámara hija si está activado
	if ajustar_camara_hija and camara_hija:
		camara_hija.position = Vector3(0.0, 0.0, distancia)
		camara_hija.rotation = Vector3.ZERO

	# Posicionar inmediatamente en el primer frame para evitar desfases de spawn
	_actualizar_posicion_inmediata()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(objetivo) or not objetivo.is_inside_tree() or not is_inside_tree():
		return

	var posicion_deseada: Vector3 = objetivo.global_position + offset_objetivo

	# Si es el primer frame o si hubo un salto brusco (spawn/teletransporte), posicionar al instante
	if not _iniciado or global_position.distance_to(posicion_deseada) > distancia_teletransporte:
		global_position = posicion_deseada
		_iniciado = true
	elif seguimiento_suave:
		global_position = global_position.lerp(posicion_deseada, velocidad * delta)
	else:
		global_position = posicion_deseada

	if desacoplar_rotacion:
		global_rotation = _rotacion_fija

func _actualizar_rotacion_fija() -> void:
	_rotacion_fija = Vector3(
		deg_to_rad(inclinacion_x_grados),
		deg_to_rad(rotacion_y_grados),
		deg_to_rad(inclinacion_z_grados)
	)
	if is_inside_tree() and desacoplar_rotacion:
		global_rotation = _rotacion_fija

func _actualizar_posicion_inmediata() -> void:
	if is_inside_tree() and is_instance_valid(objetivo) and objetivo.is_inside_tree():
		global_position = objetivo.global_position + offset_objetivo
		_iniciado = true

## Permite cambiar la rotación en el eje Y dinámicamente desde código
func rotar_y(grados: float) -> void:
	rotacion_y_grados = wrapf(rotacion_y_grados + grados, -180.0, 180.0)
