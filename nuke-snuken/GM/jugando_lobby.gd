extends Estado
class_name EstadoJugandoLobby

# 1. Cargamos el molde del nivel en la memoria (Reemplazá con tu ruta exacta)
var escena_nivel = preload("res://Prefabs/13-Worlds/World-MP.tscn") 
var nivel_actual = null

func enter(juego):
	print("--- ESTADO ACTUAL: NIVEL 1 (JUGANDO) ---")
	
	# 2. Creamos una instancia (una copia real) del nivel de tu compañero
	nivel_actual = escena_nivel.instantiate()
	nivel_actual.tipo_coneccion = "lobby"
	
	# 3. Se lo enchufamos al GameManager por código para que aparezca en pantalla
	juego.add_child(nivel_actual)

func update(juego, delta):
	pass

func exit(juego):
	print("--- FIN DEL NIVEL 1 ---")
	# Si en el futuro pasás a "Derrotado" o "Victoria", borramos el nivel para limpiar la pantalla
	if nivel_actual:
		nivel_actual.queue_free()
