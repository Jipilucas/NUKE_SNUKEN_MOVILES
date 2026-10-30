extends Node

const PORT = 8910
var peer = ENetMultiplayerPeer.new()

func create_host_server():
	# Abre el socket en el puerto para recibir clientes
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer

func join_as_client(ip_address: String):
	# Se conecta a la IP del host
	peer.create_client(ip_address, PORT)
	multiplayer.multiplayer_peer = peer
