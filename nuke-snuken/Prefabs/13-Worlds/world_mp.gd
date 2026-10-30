# res://Scripts/World.gd
extends Node3D

const PLAYER_SCENE = preload("res://Prefabs/12-Players/Player-red.tscn")

@export var tipo_coneccion: String = "local"
@onready var players_container: Node3D = $Players
@onready var ui_lobby: Control = $UI/LobbyPanel
@onready var host_btn: Button = $UI/LobbyPanel/VBoxContainer/HostButton
@onready var join_btn: Button = $UI/LobbyPanel/VBoxContainer/ClientButton
@onready var ip_input: LineEdit = $UI/LobbyPanel/VBoxContainer/IPInput

@onready var camera1 : Camera3D = $Seguimiento/Camera3D

func _ready() -> void:
	
	
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	# Escuchar los eventos del NetworkManager correspondiente

	match tipo_coneccion:
		"local":
			print("Estableciendo conexión local.")
			NetworkManager.player_connected.connect(_on_player_connected)
			NetworkManager.player_disconnected.connect(_on_player_disconnected)
			NetworkManager.server_disconnected.connect(_on_server_disconnected)
			ui_lobby.visible = true

		"steam":
			print("Estableciendo conexión directa por Steam.")
			NetworkManagerSteam.player_connected.connect(_on_player_connected)
			NetworkManagerSteam.player_disconnected.connect(_on_player_disconnected)
			NetworkManagerSteam.server_disconnected.connect(_on_server_disconnected)
			ui_lobby.visible = true

		"lobby":
			print("Entrando a partida mediante lobby de Steam.")
			NetworkManagerSteam.player_connected.connect(_on_player_connected)
			NetworkManagerSteam.player_disconnected.connect(_on_player_disconnected)
			NetworkManagerSteam.server_disconnected.connect(_on_server_disconnected)
			ui_lobby.visible = false
			_inicializar_jugadores_lobby()

		_:
			push_error("Tipo de conexión desconocido: " + tipo_coneccion)

func _on_host_pressed() -> void:
	var err:int
	if tipo_coneccion=="steam":
		err = NetworkManagerSteam.create_host()
	else:
		err = NetworkManager.create_host()
	if err == OK:
		ui_lobby.visible = false
		# El Host (Peer 1) spawnea su propio avatar
		_spawn_player(1)
		# El Servidor spawnea los items del mapa para todos los clientes
		if has_node("FabricasItems"):
			$FabricasItems.generar_todos_los_items()
		var id_host = NetworkManagerSteam.steam_id
		var label_id_host:Label = $Hud.ID_host
		label_id_host.text = "ID del Host: " + str(id_host)

#Unirse a la partida como cliente
func _on_join_pressed() -> void:
	var identificador = ip_input.text.strip_edges()
	
	if tipo_coneccion=="steam":
#region Asignacion ID por steam e ingreso al juego
		print("[World] Steam ID del host ingresado: ", identificador)
		#Se fija que el campo no esté vació
		if identificador.is_empty():
			print("Ingresar el ID del host.")
			return
		#Solicita a NetworkManagerSteam que cree el cliente y se conecte directamente al host utilizando su Steam ID.
		NetworkManagerSteam.join_game(int(identificador))
		#Ocultamos el panel del lobby.
		ui_lobby.visible = false
#endregion
	elif tipo_coneccion == "local":
#region Asignacion ID local e ingreso al juego
		if identificador.is_empty():
			identificador = "127.0.0.1"
		
		var err = NetworkManager.join_game(identificador)
		if err == OK:
			ui_lobby.visible = false
#endregion

#region uniones para la conección por lobby
func _inicializar_jugadores_lobby() -> void:
	if not multiplayer.is_server():
		return

	# Crear el personaje del servidor.
	_spawn_player(multiplayer.get_unique_id())

	# Crear los personajes de los clientes que ya están conectados.
	for peer_id in multiplayer.get_peers():
		if players_container.has_node(str(peer_id)):
			continue
		_spawn_player(peer_id)

	if has_node("FabricasItems"):
		$FabricasItems.generar_todos_los_items()
#endregion

func _on_player_connected(peer_id: int) -> void:
	# REGLA OBLIGATORIA: Solo el servidor spawnea nodos de red
	if multiplayer.is_server():
		_spawn_player(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		var player = players_container.get_node_or_null(str(peer_id))
		if player:
			player.queue_free() # MultiplayerSpawner lo eliminará en todos los clientes

func _spawn_player(peer_id: int) -> void:
	var player_instance = PLAYER_SCENE.instantiate()
	# CRUCIAL: El nombre del nodo debe ser el String del peer_id
	player_instance.name = str(peer_id)
	# Punto inicial simple (puedes variarlo si deseas)
	player_instance.position = $SpawnPos.position #Vector3(randf_range(-3, 3), 1, randf_range(-3, 3))
	players_container.add_child(player_instance)
	#El gestor de datos registra el nuevo jugador usando su id como referencia.
	GestorDeDatosPjs.registrar_jugador(peer_id)
	#El gestor de datos del servidor envía los datos a los gestores de los clientes.
	GestorDeDatosPjs.sincronizar_datos_a_clientes()

func _on_server_disconnected() -> void:
	ui_lobby.visible = true
	for child in players_container.get_children():
		child.queue_free()
	if has_node("ItemsSpawnPath"):
		for child in $ItemsSpawnPath.get_children():
			child.queue_free()
