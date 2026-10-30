extends Control

var info_jugadores = []
@onready var ID_host:Label = $ID_host

func _ready() -> void:
	GestorDeDatosPjs.datos_actualizados.connect(actualizar_visor_datos)

#Actualiza el HUD instanciado.
func actualizar_visor_datos() -> void:
	var texto = ""
	
	for id in GestorDeDatosPjs.jugadores:
		var datos = GestorDeDatosPjs.jugadores[id]
		
		texto += "ID: %s | Puntos: %s | Vida: %s\n" % [
			id,
			datos["puntaje"],
			datos["vida"]
		]
	
	$DatosDeJugadores.text = texto
