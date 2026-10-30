extends HBoxContainer
class_name FilaJugador

@onready var label_nombre:Label = $Nombre
@onready var label_vida:Label = $Vida
@onready var label_puntos:Label = $Puntaje

func establecer(nombre:String, vida:int, puntos:int):
	var vidas_en_10 = vida/10
	label_nombre.text = nombre
	label_vida.text = "🐍".repeat(vidas_en_10)
	label_puntos.text = str(puntos)
