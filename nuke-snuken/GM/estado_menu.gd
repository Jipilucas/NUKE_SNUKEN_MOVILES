extends Estado
class_name EstadoMenu

func enter(juego):
	print("--- ESTADO ACTUAL: MENÚ PRINCIPAL ---")
	# Le decimos al GameManager (juego) que muestre la UI del menú
	if juego.has_node("MenuUI"):
		juego.get_node("MenuUI").show()

func update(juego, delta):
	pass

func exit(juego):
	print("--- SALIENDO DEL MENÚ ---")
	# Al salir del estado Menú, ocultamos la UI
	if juego.has_node("MenuUI"):
		juego.get_node("MenuUI").hide()
