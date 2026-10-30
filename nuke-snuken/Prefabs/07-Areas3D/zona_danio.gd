extends Area3D
@export var danio : int = 10
@export var objetivo: String = "Global"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node3D) -> void:
	# Equivalente a if (other.CompareTag("Player")) de Unity:
	if body.is_in_group(objetivo):
		if body.has_method("quitar_cuerpo"):
			body.quitar_cuerpo(danio/10)
		
		
		#Como el host y los clientes ambos tienen la zona que detecta al jugador nos fijamos primero quien está detectando.
		if not multiplayer.is_server():
			return
		
		#Ahora que hicimos que el cliente no modifique nada al la zona detectar, hacemos que el servidor si modifique:
		var id_jugador = int(body.name)
		GestorDeDatosPjs.modificar_vida(id_jugador, -danio)
