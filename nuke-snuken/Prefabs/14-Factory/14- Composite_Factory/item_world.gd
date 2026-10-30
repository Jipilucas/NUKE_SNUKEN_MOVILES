# res://Prefabs/00-Prefabs-Scripts/item_world.gd
class_name ItemWorld
extends Area3D

## Ruta del recurso que se sincroniza por red en el spawn
@export var data_path: String = "":
	set(valor):
		data_path = valor
		if not data_path.is_empty():
			# Carga el recurso automáticamente al recibir la ruta por red
			data = load(data_path)
			
@export var data: ItemData:
	set(nuevo_data):
		data = nuevo_data
		if data and data_path.is_empty() and not data.resource_path.is_empty():
			data_path = data.resource_path
		if is_node_ready():
			_actualizar_visuales()

@export var mesh_instance: MeshInstance3D #= $MeshInstance3D
var _instancia_escena: Node3D = null

@export var collision_shape : CollisionShape3D

func _ready() -> void:
	if not mesh_instance and has_node("MeshInstance3D"):
		mesh_instance = $MeshInstance3D
	if not collision_shape and has_node("CollisionShape3D"): 
		collision_shape = $CollisionShape3D
	body_entered.connect(_on_body_entered)
	_actualizar_visuales()

func _actualizar_visuales() -> void:
	if not data:
		return
		
	# Limpiar instancia de escena previa si existiera
	if _instancia_escena and is_instance_valid(_instancia_escena):
		_instancia_escena.queue_free()
		_instancia_escena = null
		
	# Opción A: Es un modelo en formato escena (.glb, .gltf, .tscn)
	if data.modelo_escena:
		if mesh_instance:
			mesh_instance.visible = false
		_instancia_escena = data.modelo_escena.instantiate() as Node3D
		if _instancia_escena:
			add_child(_instancia_escena)
			_instancia_escena.scale = data.escala_visual
			
	# Opción B: Es una malla individual (.obj, Mesh primitiva)
	elif data.modelo_mesh and mesh_instance:
		mesh_instance.visible = true
		mesh_instance.mesh = data.modelo_mesh
		mesh_instance.scale = data.escala_visual
		if data.material_override:
			mesh_instance.material_override = data.material_override

func _on_body_entered(body: Node3D) -> void:
		# REGLA OBLIGATORIA: Solo el servidor procesa el consumo y destruye el item en red
	if not multiplayer.is_server():
		return
		
	if not body.is_in_group("Jugador"):
		return
		
	if data:
		data.aplicar_efecto(body)
		
	despawn()

func despawn() -> void:
	# 1. Desactivar colisiones inmediatamente en el servidor
	# para evitar que otro jugador lo toque durante el segundo de animación
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# 2. Enviar el RPC a todas las máquinas (Host y Clientes)
	rpc_animacion_consumir.rpc()
	
	# 3. Solo el servidor espera a que termine la animación
	# (La animación dura ~0.83s; 0.9s da un margen perfecto)
	await get_tree().create_timer(0.9).timeout
	
	# 4. El servidor destruye el nodo. 
	# MultiplayerSpawner se encarga de eliminarlo en todos los clientes
	queue_free()

## Este RPC se ejecuta en todas las máquinas cuando el Servidor lo invoca
@rpc("authority", "call_local", "reliable")
func rpc_animacion_consumir() -> void:
	if _instancia_escena is ItemVisual:
		var visual: ItemVisual = _instancia_escena as ItemVisual
		visual.despawn_animation_play()
		
