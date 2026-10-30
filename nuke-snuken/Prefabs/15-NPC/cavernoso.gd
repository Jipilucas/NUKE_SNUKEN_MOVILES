class_name Cavernoso
extends Node3D

## Actor Receptor (Receiver) en el Patrón de Comandos.
## Contiene las capacidades físicas y visuales del sapo (moverse, esperar, atacar, esconderse).

signal emergio
signal ataco
signal escondio
@export var modelo3D : Node3D
@export_group("Puntos de Posición (Marker3D)")
## Marcador 3D que indica la posición de la cueva (escondite)
@export var punto_cueva: Marker3D
## Marcador 3D que indica la posición afuera de la cueva
@export var punto_salida: Marker3D

@export_group("Parámetros de Salto")
@export var duracion_salto: float = 0.8
@export var altura_salto: float = 1.2
@export var particulas_ataque: GPUParticles3D #Agregué particulas cuando aparece el escuerzo
@export_group("Combate y Ataque")
## Area3D que inflige daño (ej. Zona_Danio_Sphere o cualquier Area3D con zona_danio.gd)
@export var hitbox_ataque: Area3D
@export var tiempo_aviso_ataque: float = 0.4
@export var tiempo_activo_ataque: float = 0.4
@export var sfx_salto: AudioStreamPlayer3D
@export var sfx_ataque: AudioStreamPlayer3D

@export_group("Comandos")
@export var intervalo :float = 2
@onready var controladorcom = $ControladorComandos
@export var rutina: Array[Command] = []

var posicion_cueva: Vector3
var posicion_afuera: Vector3
var _escala_original: Vector3 = Vector3.ONE

func _ready() -> void:
	print("DEBUG CAVERNOSO | [Cavernoso] Inicializado | Peer: ",multiplayer.get_unique_id()," | Servidor: ",multiplayer.is_server()," | Nodo: ",get_path())
	controladorcom.intervalo_rutina = intervalo
	if rutina.size() > 0:
		controladorcom.rutina = rutina

	
	_escala_original = scale
	
	# Fijar coordenadas en vectores inmutables
	if punto_cueva != null:
		posicion_cueva = punto_cueva.global_position
		modelo3D.global_position = posicion_cueva
		print("DEBUG POSICION CAVERNOSO | [Cavernoso] Modelo: ",modelo3D.name," | Posición global: ",modelo3D.global_position)
	else:
		posicion_cueva = global_position
	
	if punto_salida != null:
		posicion_afuera = punto_salida.global_position
	else:
		posicion_afuera = posicion_cueva + transform.basis * Vector3(0, 0, 4.0)
	
	# Inicializar hitbox apagado
	if hitbox_ataque != null:
		hitbox_ataque.monitoring = false
		hitbox_ataque.visible = false

## 1. Acción: Emerger (Salto parabólico de la cueva hacia afuera)
func emerger() -> void:
	if not is_inside_tree():
		return
	await _animar_salto(modelo3D.global_position, posicion_afuera, duracion_salto)
	emergio.emit()

## 2. Acción: Esperar un tiempo determinado
func esperar(segundos: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(segundos).timeout

## 3. Acción: Atacar en área (Squash/stretch preparatorio + activación de hitbox)
func atacar_area() -> void:
	if not is_inside_tree():
		return
		
	if sfx_ataque != null: #SFX
		sfx_ataque.play()
		
	# A. Anticipación (se comprime preparando el golpe)
	#var tween_prep := create_tween()
	#tween_prep.tween_property(self, "scale", _escala_original * Vector3(1.3, 0.6, 1.3), tiempo_aviso_ataque)
	#await tween_prep.finished
	if not is_inside_tree():
		return
	
	# B. Impacto y activación del Area3D de daño
	#var tween_impacto := create_tween()
	#tween_impacto.tween_property(self, "scale", _escala_original * Vector3(0.85, 1.35, 0.85), 0.1)
	
	if hitbox_ataque != null:
		hitbox_ataque.monitoring = true
		hitbox_ataque.visible = true
		if particulas_ataque != null:
			particulas_ataque.restart()
		
		# Si ya hay jugadores u objetivos solapados en el instante de encendido:
		for body in hitbox_ataque.get_overlapping_bodies():
			if hitbox_ataque.has_method("_on_body_entered"):
				hitbox_ataque._on_body_entered(body)
	
	await get_tree().create_timer(tiempo_activo_ataque).timeout
	if not is_inside_tree():
		return
	
	# Desactivar hitbox
	if hitbox_ataque != null:
		hitbox_ataque.monitoring = false
		hitbox_ataque.visible = false
	
	# C. Retorno a la escala normal
	#var tween_recup := create_tween()
	#tween_recup.tween_property(self, "scale", _escala_original, 0.2)
	#await tween_recup.finished
	
	ataco.emit()
	if sfx_ataque != null:
		sfx_ataque.stop()

## 4. Acción: Esconderse (Salto parabólico de regreso a la cueva)
func esconderse() -> void:
	if not is_inside_tree():
		return
	await _animar_salto(modelo3D.global_position, posicion_cueva, duracion_salto)
	escondio.emit()

## Animación procedural de salto con arco parabólico en Y
func _animar_salto(origen: Vector3, destino: Vector3, duracion: float) -> void:
	if sfx_salto !=null:
		sfx_salto.play()
	if not is_inside_tree():
		return
		
	var dir := destino - origen
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		look_at(modelo3D.global_position + dir.normalized(), Vector3.UP)
	
	var mitad := duracion * 0.5
	var pico_y := maxf(origen.y, destino.y) + altura_salto
	
	# Squash antes del salto
	#var tween_squash := create_tween()
	#tween_squash.tween_property(self, "scale", _escala_original * Vector3(1.2, 0.7, 1.2), 0.1)
	#await tween_squash.finished
	if not is_inside_tree():
		return
	
	# Desplazamiento horizontal + estiramiento en el aire
	var tween_mov := create_tween().set_parallel(true)
	tween_mov.tween_property(modelo3D, "global_position:x", destino.x, duracion)
	tween_mov.tween_property(modelo3D, "global_position:z", destino.z, duracion)
	#tween_mov.tween_property(self, "scale", _escala_original * Vector3(0.9, 1.2, 0.9), mitad)
	
	# Arco parabólico en Y
	var tween_y := create_tween()
	tween_y.tween_property(modelo3D, "global_position:y", pico_y, mitad).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(modelo3D, "global_position:y", destino.y, mitad).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween_mov.finished
	if not is_inside_tree():
		return
	
	# Squash al aterrizar
	#var tween_land := create_tween()
	#tween_land.tween_property(self, "scale", _escala_original * Vector3(1.25, 0.75, 1.25), 0.1)
	#tween_land.tween_property(self, "scale", _escala_original, 0.15)
	#await tween_land.finished
	
	if sfx_salto != null:
		sfx_salto.stop()
	
