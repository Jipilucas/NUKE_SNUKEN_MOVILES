extends Area3D

@export var puntaje: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	
func _on_body_entered(body: Node3D):
	if body.is_in_group("Jugador"):
		if body is Player or body is Player_MP:
			#Como el host y los clientes ambos tienen la zona que detecta al jugador nos fijamos que esta modificación la haga solo el servidor.
			if multiplayer.is_server():
				var id_jugador = int(body.name)
				GestorDeDatosPjs.modificar_puntaje(id_jugador, puntaje)
			
			if body.has_method("agregar_cuerpo"):
				body.agregar_cuerpo()
		self.queue_free()
	pass
func _on_body_exited(body: Node3D):
	pass
