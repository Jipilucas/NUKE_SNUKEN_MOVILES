extends Estado
class_name EstadoLobbyOnline

# 1. Cargamos el molde del nivel en la memoria (Reemplazá con tu ruta exacta)
const ESCENA_LOBBY = preload("res://Prefabs/10-UI/Lobby/lobby.tscn")

var modo: String = "crear"
var id_lobby: int = 0
var lobby_actual: Control = null


func enter(juego) -> void:
	print("--- ESTADO ACTUAL: LOBBY ONLINE ---")
	print("Modo: ", modo)

	lobby_actual = ESCENA_LOBBY.instantiate()
	juego.add_child(lobby_actual)
	lobby_actual.comenzar_partida.connect(func():juego.maquina_estados.change_state(juego.maquina_estados.jugando_lobby))

	if lobby_actual.has_method("iniciar"):
		lobby_actual.iniciar(modo, id_lobby)


func update(juego, delta) -> void:
	pass


func exit(juego) -> void:
	print("--- SALIENDO DEL LOBBY ONLINE ---")

	if is_instance_valid(lobby_actual):
		lobby_actual.queue_free()

	lobby_actual = null
