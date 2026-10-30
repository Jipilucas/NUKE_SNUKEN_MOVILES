# res://Scripts/NetworkManager.gd
extends Node

const DEFAULT_PORT: int = 8910
const MAX_CLIENTS: int = 4

# Señales para que otras escenas (como el menú o el mundo) reaccionen
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_failed()
signal connection_success()

var peer: ENetMultiplayerPeer

func _ready() -> void:
	# Conectar las señales globales del MultiplayerAPI de Godot
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_host(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		push_error("[NetworkManager] Error al abrir el servidor: %s" % error)
		return error
	
	# Asignar el peer activa la red en Godot
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Host iniciado en puerto %d. Mi ID es: %d" % [port, multiplayer.get_unique_id()])
	return OK

func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		push_error("[NetworkManager] Error al solicitar conexión a %s:%d -> %s" % [address, port, error])
		return error
	
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Intentando conectar a %s:%d..." % [address, port])
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
