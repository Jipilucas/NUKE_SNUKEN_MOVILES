extends Node

# 1. Cargamos el archivo original de tus compañeras sin modificarlo
var escena_maquina = preload("res://GM/maquina_de_estados.tscn")
var maquina_estados = null

func _ready():
	# 2. Creamos una copia exacta (instancia) por código
	maquina_estados = escena_maquina.instantiate()
	
	# 3. La agregamos "invisiblemente" al GameManager
	add_child(maquina_estados)
	
	# 4. Le damos arranque
	maquina_estados.init(self)

func _process(delta: float) -> void:
	# Mantenemos la máquina viva
	if maquina_estados:
		maquina_estados.update(delta)

func iniciar_nivel() -> void:
	print(">> Acción: Botón JUGAR presionado!")
	
	# Cambiamos al estado "Jugando" (que a su vez va a instanciar el Nivel 1)
	if maquina_estados:
		match $MenuUI/VBoxContainer/OptionButton.get_selected_id():
			0:
				maquina_estados.change_state(maquina_estados.jugando_local)
			1:
				maquina_estados.change_state(maquina_estados.jugando_online)
			2:
				#Cambia al lobby_online en modo host
				maquina_estados.change_state(maquina_estados.lobby_online)
			3:
				var texto_id: String = $MenuUI/VBoxContainer/LobbyIDN.text.strip_edges()
				if texto_id.is_empty() or not texto_id.is_valid_int():
					print("Ingresá un ID de lobby válido.")
					return

				maquina_estados.lobby_online.modo = "unirse"
				maquina_estados.lobby_online.id_lobby = int(texto_id)
				maquina_estados.change_state(maquina_estados.lobby_online)
			#acá iría la coneccion al estado de lobby_online, pero en modo cliente ya con la info del id del lobby.


func _on_creditos_pressed() -> void:
	$MenuUI/PantallaCreditos.show()


func _on_volver_pressed() -> void:
	$MenuUI/PantallaCreditos.hide()


func _on_option_button_item_selected(index: int) -> void:
	if index == 3:
		$MenuUI/VBoxContainer/LobbyIDN.visible = true
	else:
		$MenuUI/VBoxContainer/LobbyIDN.visible = false
