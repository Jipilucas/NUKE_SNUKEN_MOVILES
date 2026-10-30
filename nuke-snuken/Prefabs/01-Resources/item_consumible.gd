extends Resource
class_name ConsecuenciaConsumible

signal consumido
signal consecuencia (caracteristica:String,variacion:int)

#Estaría bien ponerlo así y asignarle la consecuencia en el momento de crear el item o debería haber un recurso para cada tipo de item con la consecuencia ya codeada? O debería haber uno solo con todas las consecuencias posibles que detecte que tipo de objeto se está consumiendo y devuelva la consecuencia adecuada?
func _consecuencia(_caracteristica,_variacion):
	consecuencia.emit(_caracteristica,_variacion)
