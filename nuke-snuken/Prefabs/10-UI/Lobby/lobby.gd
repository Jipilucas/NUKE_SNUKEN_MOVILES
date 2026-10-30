extends Control


signal comenzar_partida

@onready var jugador_listo: CheckBox = $JugadorListo
@onready var boton_comenzar: Button = $Comenzar
@onready var lista_jugadores: VBoxContainer = $ListaDeJugadores
@onready var label_id_lobby: Label = $IDLobby

var modo: String = "crear"
var id_lobby: int = 0
var filas_jugadores: Dictionary = {}

func _ready() -> void:
	jugador_listo.toggled.connect(_on_jugador_listo_toggled)
	boton_comenzar.pressed.connect(_on_comenzar_pressed)

	# Solo el anfitrión puede comenzar.
	boton_comenzar.visible = multiplayer.is_server()
	boton_comenzar.disabled = true

	actualizar_lista_jugadores()


func iniciar(nuevo_modo: String, nuevo_id_lobby: int = 0) -> void:
	modo = nuevo_modo
	id_lobby = nuevo_id_lobby

	#Conectamos primero las señales del administrador de Steam a sus respectivas funciones acá.

	if not NetworkManagerSteam.lobby_preparado.is_connected(_on_lobby_preparado):
		NetworkManagerSteam.lobby_preparado.connect(_on_lobby_preparado)

	if not NetworkManagerSteam.lobby_union_completada.is_connected(_on_lobby_union_completada):
		NetworkManagerSteam.lobby_union_completada.connect(_on_lobby_union_completada)

	if not NetworkManagerSteam.lobby_error.is_connected(_on_lobby_error):
		NetworkManagerSteam.lobby_error.connect(_on_lobby_error)
	
	if not NetworkManagerSteam.estados_listos_actualizados.is_connected(_on_estados_listos_actualizados):
		NetworkManagerSteam.estados_listos_actualizados.connect(_on_estados_listos_actualizados)
	
	if not NetworkManagerSteam.partida_iniciada.is_connected(_on_partida_iniciada):
		NetworkManagerSteam.partida_iniciada.connect(_on_partida_iniciada)
	
	if not NetworkManagerSteam.miembros_lobby_actualizados.is_connected(_on_miembros_lobby_actualizados):
		NetworkManagerSteam.miembros_lobby_actualizados.connect(_on_miembros_lobby_actualizados)
	#Una vez conectadas las señales, iniciamos la operación solicitada por el modo que nos pasa la pantalla de inicio.

	if modo == "crear":
		NetworkManagerSteam.crear_lobby_sala()

	elif modo == "unirse":
		NetworkManagerSteam.unirse_lobby_sala(id_lobby)

	else:
		print("[Lobby] Modo desconocido: ", modo)


func _on_lobby_preparado(nuevo_id: int) -> void:
	id_lobby = nuevo_id
	label_id_lobby.text = "Lobby de Nuke Snuken nº: " + str(id_lobby)
	print("Lobby listo: ", id_lobby)
	actualizar_lista_jugadores()
	_actualizar_boton_comenzar()


func _on_lobby_union_completada(nuevo_id: int) -> void:
	id_lobby = nuevo_id
	label_id_lobby.text = "Lobby de Nuke Snuken nº: " + str(id_lobby)
	print("Unión al lobby completada: ", id_lobby)
	actualizar_lista_jugadores()
	


func _on_lobby_error(mensaje: String) -> void:
	print("[Lobby] Error: ", mensaje)


func _on_jugador_listo_toggled(activado: bool) -> void:
	print("Estado de preparación local: ", activado)
	NetworkManagerSteam.cambiar_estado_listo(activado)

func _on_comenzar_pressed() -> void:
	if not multiplayer.is_server():
		return

	print("El host solicitó comenzar la partida.")
	NetworkManagerSteam.solicitar_inicio_partida()

func _on_estados_listos_actualizados(estados: Dictionary) -> void:
	print("[Lobby] Estados de preparación recibidos: ", estados)
	_actualizar_estados_visuales()
	#Si están todos listos habilitamos el botón para comenzar la partida en el host.
	_actualizar_boton_comenzar()

func _actualizar_boton_comenzar():
	if not multiplayer.is_server():
		boton_comenzar.disabled = true
		return

	if id_lobby <= 0:
		boton_comenzar.disabled = true
		return

	var cantidad := Steam.getNumLobbyMembers(id_lobby)

	if cantidad == 0:
		boton_comenzar.disabled = true
		return

	for i in range(cantidad):
		var id_steam: int = Steam.getLobbyMemberByIndex(id_lobby, i)

		if not NetworkManagerSteam.jugadores_listos.get(id_steam, false):
			boton_comenzar.disabled = true
			return

	boton_comenzar.disabled = false

func actualizar_lista_jugadores() -> void:
	# Eliminamos las filas anteriores.
	for hijo in lista_jugadores.get_children():
		hijo.queue_free()

	filas_jugadores.clear()

	if id_lobby <= 0:
		return

	var cantidad: int = Steam.getNumLobbyMembers(id_lobby)

	for i in range(cantidad):
		var id_steam: int = Steam.getLobbyMemberByIndex(id_lobby, i)
		var nombre: String = Steam.getFriendPersonaName(id_steam)

		# Contenedor de la fila del jugador.
		var fila := VBoxContainer.new()
		fila.name = "Jugador_" + str(id_steam)

		# Nombre del jugador.
		var label_nombre := Label.new()
		label_nombre.name = "Nombre"
		label_nombre.text = nombre

		# Steam ID del jugador.
		var label_id := Label.new()
		label_id.name = "ID"
		label_id.text = "ID: " + str(id_steam)

		# Estado de preparación.
		var label_estado := Label.new()
		label_estado.name = "Estado"
		label_estado.text = "No preparado"

		fila.add_child(label_nombre)
		fila.add_child(label_id)
		fila.add_child(label_estado)

		lista_jugadores.add_child(fila)

		# Guardamos la fila para actualizar su estado después.
		filas_jugadores[id_steam] = fila

	# Aplicamos los estados que ya conocemos.
	_actualizar_estados_visuales()

func _actualizar_estados_visuales() -> void:
	for id_jugador in filas_jugadores:
		var fila: VBoxContainer = filas_jugadores[id_jugador]
		var label_estado: Label = fila.get_node("Estado")

		var esta_listo: bool = NetworkManagerSteam.jugadores_listos.get(id_jugador, false)

		if esta_listo:
			label_estado.text = "Preparado"
		else:
			label_estado.text = "No preparado"

func _on_partida_iniciada() -> void:
	comenzar_partida.emit()

func _on_miembros_lobby_actualizados() -> void:
	print("[Lobby] Actualizando lista de jugadores.")

	actualizar_lista_jugadores()
	_actualizar_boton_comenzar()

#Desconectamos las señales del global network al comenzar la partida.
func _exit_tree() -> void:
	if NetworkManagerSteam.miembros_lobby_actualizados.is_connected(_on_miembros_lobby_actualizados):
		NetworkManagerSteam.miembros_lobby_actualizados.disconnect(_on_miembros_lobby_actualizados)
