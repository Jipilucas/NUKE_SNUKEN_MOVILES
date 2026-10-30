# res://Scripts/NetworkManager.gd
extends Node

#const DEFAULT_PORT: int = 8910
#const MAX_CLIENTS: int = 4

#Variables relacionadas a la inicialización por SteamGodot
var steam_id: int = 0
var steam_iniciado: bool = false
var modo_lobby_ui: bool = false

var peer: SteamMultiplayerPeer
#Esta variable se calcula al crear el host dando la id del lobby. No se utiliza.
var lobby_id: int = 0
const LOBBY_MAX_MIEMBROS: int = 4
#Esta variable guarda los jugadores listos en el modo lobby la key es su Steam ID y el valor es un bool.
var jugadores_listos: Dictionary = {}



# Señales para que otras escenas (como el menú o el mundo) reaccionen
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_failed()
signal connection_success()
signal lobby_preparado(id_lobby: int)
signal lobby_union_completada(id_lobby: int)
signal lobby_error(mensaje: String)
# Señal para MatchMaking Multijugador
signal estados_listos_actualizados(estados: Dictionary)
signal partida_iniciada
signal miembros_lobby_actualizados

func _ready() -> void:
	#Inicialización y conección de señales de Steam
	_inicializar_steam()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	# Conectar las señales globales del MultiplayerAPI de Godot
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


#Esto lo pide el addon ㄟ ▔, ▔ )ㄏ, es para recibir los eventos que suceden en steamnetworking.
func _process(_delta: float) -> void:
	if steam_iniciado:
		Steam.run_callbacks()

#Función que inicializa el sistema multpiplayer de steam.
func _inicializar_steam() -> void:
	var inic_resultados: Dictionary = Steam.steamInitEx()
	print("[NetworkManager] Resultado de inicialización de Steam: ", inic_resultados)
	if inic_resultados["status"] > 0:
		push_error("[NetworkManager] No se pudo inicializar Steam.")
		return
	steam_iniciado = true
	steam_id = Steam.getSteamID()

	print("[NetworkManager] Steam inicializado correctamente.")
	print("[NetworkManager] Steam ID: ", steam_id)
	print("[NetworkManager] Nombre: ", Steam.getPersonaName())

#######Agregar regiones que distingan lo viejo de lo nuevo del LOBBBY en esta funcion.
#Una vez creado el lobby conecta lo creado por steam con la API multiplayer de Godot.
func _on_lobby_created(resultado: int, id_lobby: int) -> void:
	print("[NetworkManagerSteam] Resultado de creación: ", resultado)
	print("[NetworkManagerSteam] Lobby ID: ", id_lobby)

	if resultado != 1:
		if modo_lobby_ui:
			lobby_error.emit("No se pudo crear el lobby de Steam.")
			modo_lobby_ui = false
		else:
			push_error("[NetworkManagerSteam] Falló la creación del lobby.")
		return

	lobby_id = id_lobby

	var error = peer.host_with_lobby(lobby_id)

	if error != OK:
		if modo_lobby_ui:
			lobby_error.emit("No se pudo iniciar el host.")
			modo_lobby_ui = false
		else:
			push_error("[NetworkManagerSteam] Error al iniciar el host.")
		return

	multiplayer.multiplayer_peer = peer

	Steam.setLobbyData(lobby_id, "nombre", Steam.getPersonaName())
	Steam.setLobbyJoinable(lobby_id, true)

	print("[NetworkManagerSteam] Host de Steam iniciado.")

	if modo_lobby_ui:
		lobby_preparado.emit(lobby_id)

#Creación del cliente conectandolo al host.
func _on_join_requested(id_lobby: int) -> void:
	var error = join_game(id_lobby)
	if error != OK:
		push_error("[NetworkManager] No se pudo entrar al Lobby.")

#Función para que el host invite a otros jugadores. Recibe el ID desde otro lado.
#Actualmente no se utiliza (funcionaba mal, optamos por la conección del cliente al host)
func invitar_jugador(id_steam: int) -> void:
	print("Invitando al jugador: ", id_steam)
	Steam.inviteUserToGame(id_steam, "")

#Creaba el host, ahora crea el lobby.
func create_host():
	#Creamos el peer de steam.
	peer = SteamMultiplayerPeer.new()
	
	#Creamos el lobby en steam
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY,LOBBY_MAX_MIEMBROS)
	
	print("[NetworkManager] Solicitando creación del Lobby de Steam...")
	return OK

func join_game(id_steam_host: int) -> Error:
	print("[NetworkManager] ENTRÓ A join_game()")
	
	peer = SteamMultiplayerPeer.new()

	var error = peer.create_client(id_steam_host)

	print("[NetworkManager] Resultado de create_client(): ", error)

	if error != OK:
		push_error("[NetworkManager] No se pudo crear el cliente.")
		return error

	multiplayer.multiplayer_peer = peer

	print("[NetworkManager] Cliente configurado.")
	return OK

func disconnect_network() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	print("[NetworkManager] Conexión cerrada.")

# Handlers internos de señales
func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Jugador conectado con ID: %d" % id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Jugador desconectado con ID: %d" % id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("[NetworkManager] Conectado exitosamente al servidor. Mi ID local es: %d" % multiplayer.get_unique_id())
	connection_success.emit()

func _on_connection_failed() -> void:
	push_error("[NetworkManager] No se pudo conectar al servidor.")
	disconnect_network()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] El servidor cerró la partida.")
	disconnect_network()
	server_disconnected.emit()

#region Lobby
func crear_lobby_sala() -> void:
	if not steam_iniciado:
		lobby_error.emit("Steam no está inicializado.")
		return
	modo_lobby_ui = true

	# Creamos el peer antes de solicitar el lobby a Steam.
	peer = SteamMultiplayerPeer.new()
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY,LOBBY_MAX_MIEMBROS)

	print("[NetworkManagerSteam] Solicitando creación del lobby...")


func unirse_lobby_sala(id: int) -> void:
	if not steam_iniciado:
		lobby_error.emit("Steam no está inicializado.")
		return

	if id <= 0:
		lobby_error.emit("El ID del lobby no es válido.")
		return

	modo_lobby_ui = true
	Steam.joinLobby(id)

func _on_lobby_joined(id_lobby: int,_permisos: int,_bloqueado: bool,resultado: int) -> void:
	print("[NetworkManagerSteam] Resultado al unirse: ", resultado)
	print("[NetworkManagerSteam] Lobby ID: ", id_lobby)

	if not modo_lobby_ui:
		return

	if resultado != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_error.emit("No se pudo entrar al lobby.")
		modo_lobby_ui = false
		return

	lobby_id = id_lobby

	var id_anfitrion = Steam.getLobbyOwner(lobby_id)

	# El anfitrión no debe conectarse a sí mismo como cliente.
	if id_anfitrion == steam_id:
		lobby_preparado.emit(lobby_id)
		return

	peer = SteamMultiplayerPeer.new()

	var error = peer.create_client(id_anfitrion)

	if error != OK:
		lobby_error.emit("No se pudo conectar con el anfitrión.")
		modo_lobby_ui = false
		return

	multiplayer.multiplayer_peer = peer

	print("[NetworkManagerSteam] Conectando con el host: ", id_anfitrion)

	lobby_union_completada.emit(lobby_id)
	
#Recibe el cambio de preparación de un jugador. Si el servidor lo recibe de un cliente, identifica quién lo envió y registra el nuevo estado.
@rpc("any_peer", "call_remote", "reliable")
func solicitar_cambio_listo(id_steam:int, esta_listo: bool) -> void:
	if not multiplayer.is_server():
		return
	_registrar_estado_listo(id_steam, esta_listo)

#Registramos el estado en el servidor y lo distribuimos a los clientes.
func _registrar_estado_listo(id_steam: int, esta_listo: bool) -> void:
	if not multiplayer.is_server():
		return

	jugadores_listos[id_steam] = esta_listo
	
	# Actualizamos también la interfaz del anfitrión.
	estados_listos_actualizados.emit(jugadores_listos.duplicate())

	# Enviamos el estado actualizado a todos los clientes.
	rpc("recibir_estados_listos", jugadores_listos)


# Recibe el estado de preparación enviado por el servidor.
@rpc("authority", "call_remote", "reliable")
func recibir_estados_listos(estados: Dictionary) -> void:
	jugadores_listos = estados.duplicate()
	estados_listos_actualizados.emit(jugadores_listos.duplicate())


# Función pública que llama la interfaz cuando cambia el CheckButton.
func cambiar_estado_listo(esta_listo: bool) -> void:
	if not multiplayer.has_multiplayer_peer():
		print("[Lobby] Todavía no hay una conexión de red.")
		return

	var id_local: int = Steam.getSteamID()

	if multiplayer.is_server():
		_registrar_estado_listo(id_local, esta_listo)
	else:
		rpc_id(1, "solicitar_cambio_listo",id_local, esta_listo)

# El host solicita iniciar la partida.
func solicitar_inicio_partida() -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.is_server():
		_validar_inicio_partida()
	else:
		rpc_id(1, "solicitud_inicio_partida")


# El servidor recibe la solicitud de inicio.
@rpc("any_peer", "call_remote", "reliable")
func solicitud_inicio_partida() -> void:
	if not multiplayer.is_server():
		return

	# Solo aceptamos la solicitud del host.
	# El host inicia mediante la llamada local a solicitar_inicio_partida().
	# Los clientes no tienen permiso para iniciar.
	print("[NetworkManagerSteam] Solicitud de inicio recibida de un cliente.")
	return


# Comprueba que todos los miembros del lobby estén preparados.
func _validar_inicio_partida() -> void:
	if not multiplayer.is_server():
		return

	if lobby_id <= 0:
		return

	var cantidad := Steam.getNumLobbyMembers(lobby_id)

	if cantidad == 0:
		return

	for i in range(cantidad):
		var id_steam: int = Steam.getLobbyMemberByIndex(lobby_id, i)

		if not jugadores_listos.get(id_steam, false):
			print("[NetworkManagerSteam] Falta un jugador por prepararse: ", id_steam)
			return

	print("[NetworkManagerSteam] Todos están preparados. Iniciando partida.")

	# Avisamos a los clientes.
	rpc("notificar_inicio_partida")

	# El host también debe cambiar de estado.
	partida_iniciada.emit()


# Los clientes reciben la orden de inicio del servidor.
@rpc("authority", "call_remote", "reliable")
func notificar_inicio_partida() -> void:
	partida_iniciada.emit()

#Función para comprobar si salen o entran personas al lobby (se usa la del chat porque es como steam lo registra).
func _on_lobby_chat_update(id_lobby: int, id_cambiado: int, _id_usuario_responsable: int, _estado_cambio: int) -> void:
	if id_lobby != lobby_id:
		return
	print("[NetworkManagerSteam] Cambió la membresía del lobby. ", "Jugador: ", id_cambiado)
	miembros_lobby_actualizados.emit()
#endregion
