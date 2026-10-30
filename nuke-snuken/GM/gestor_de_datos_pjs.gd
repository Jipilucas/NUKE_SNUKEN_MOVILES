extends Node

@export var vida_inicial:int = 100
@export var puntaje_inicial:int = 0

var jugadores: Dictionary = {}

#señal solo para actualizar el HUD
signal datos_actualizados
#Señal para avisar que murió un jugador
signal jugador_murio(id)

#En esta región del código está la lógica de cómo funciona el gestor si quien lo corre es el servidor.
#region sistema en servidor
#Cuando se instancia un nuevo jugador se llama a esta función para crear sus datos.
func registrar_jugador(id: int) -> void:
	#Se fija que sea el servidor el que está ejecutando la función.
	if not multiplayer.is_server():
		return
	#Se fija que el id no esté ya registrado
	if jugadores.has(id):
		print("ID: "+ str(id)+" ya está registrado.")
		return
	#Crea y guarda los datos del personaje. Guarda un diccionario donde la clave para los datos de cada jugador es su id que es igual a su peer_id.
	jugadores[id] = {"vida": vida_inicial, "puntaje": puntaje_inicial}

#Función para obtener los datos de un jugador en concreto mediante su id.
func obtener_datos_jugador(id:int) -> Dictionary:
	if not jugadores.has(id):
		return {}
	return jugadores[id]

#Modifica la cantidad de vida de un personaje referenciandolo por su id y pasandole la cantidad a cambiar. Para hacer daño utilizar una cantidad negativa.
func modificar_vida(id:int, cantidad:int) -> void:
	if not multiplayer.is_server():
		return
	if not jugadores.has(id):
		return
	jugadores[id]["vida"] += cantidad
	if jugadores[id]["vida"] <= 0:
		jugador_murio.emit(id)
	sincronizar_datos_a_clientes()

#Modifica la cantidad de puntos de un personaje referenciandolo por su id y pasandole la cantidad a cambiar.
func modificar_puntaje(id:int, cantidad:int) -> void:
	if not multiplayer.is_server():
		return
	if not jugadores.has(id):
		return
	jugadores[id]["puntaje"] += cantidad
	sincronizar_datos_a_clientes()

#Función que le envía a los gestores de cada cliente la información actualizada del servidor.
func sincronizar_datos_a_clientes() -> void:
	if not multiplayer.is_server():
		return
	#Recorre los jugadores guardados y envía sus datos a los gestores de los clientes.
	for id in jugadores:
		var datos = jugadores[id]
		recibir_datos_jugador.rpc(id, datos["vida"], datos["puntaje"])
	#El host se avisa a su propio HUD que los datos cambiaron.
	datos_actualizados.emit()
#endregion

#En esta región está la lógica de cómo funciona el gestor en cada cliente.
#region sistema en clientes

#Función que se llama remota mediante el gestor de datos del servidor en cada cliente para sincronizar los datos de los gestores.
@rpc("authority", "call_remote", "reliable")
func recibir_datos_jugador(id: int, vida: int, puntaje: int) -> void:
	jugadores[id] = {"vida": vida, "puntaje": puntaje}
	#El gestor del cliente emite la señal al HUD propio de cada cliente.
	datos_actualizados.emit()
#endregion
