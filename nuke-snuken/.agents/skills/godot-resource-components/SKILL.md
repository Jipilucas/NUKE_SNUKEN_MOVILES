---
name: godot-resource-components
description: >-
  Especialista en arquitectura de componentes basados en Resource para Godot 4.
  Usar siempre que el usuario pida crear, refactorizar o integrar un nuevo componente,
  sistema de juego (movimiento, vida, apuntado, puntaje, consumibles), o lógica desacoplada
  siguiendo el patrón de componentes por Resource establecido en el proyecto.
---

# Godot Resource-Based Components (Arquitectura de Componentes)

Esta skill define el estándar y flujo de trabajo para crear e integrar componentes en el proyecto usando **Custom Resources** (`extends Resource`) como bloques de construcción desacoplados.

---

## 1. Filosofía y Reglas del Patrón

1. **Desacoplamiento total**: Los componentes son clases `extends Resource` que residen en `res://Prefabs/01-Resources/`. No heredan de `Node` ni de `CharacterBody3D`, evitando la sobrecarga de nodos físicos y árboles complejos.
2. **Inyección de Dependencias (Actor Passing)**: Si el componente necesita interactuar con el mundo 3D o con físicas, **recibe al nodo por parámetro** en sus métodos (`body: CharacterBody3D`, `nodo: Node3D`, `delta: float`), nunca asume rutas duras (`get_node`) ni guarda referencias cíclicas a largo plazo.
3. **Comunicación por Señales**: Los componentes definen señales para notificar cambios de estado (`signal salud_cambiada`, `signal murio`, `signal consumido`). El actor que posee el recurso se suscribe a estas señales en su `_ready()`.
4. **Acceso Externo Seguro**: Áreas de daño, triggers e ítems interactúan con el actor a través del componente:
   ```gdscript
   if body.is_in_group("Jugador") and body is Player:
       if body.health_system:
           body.health_system.recibir_danio(danio)
   ```
5. **Tipado Estático Obligatorio**: Todo parámetro, retorno y variable `@export` debe estar fuertemente tipado en GDScript 2.0.
6. **Estado Compartido vs Único**:
   - Los Resources por defecto son compartidos entre instancias de la escena.
   - Si un componente almacena estado dinámico individual por entidad (como `actual_health` o `actual_speed`), debe configurarse con `resource_local_to_scene = true` o instanciarse como `SubResource` único en la escena.

---

## 2. Estructura del Proyecto

- `res://Prefabs/01-Resources/`: Todos los scripts de componentes (`health_system.gd`, `char_mov_comp.gd`, `mouse_aim_component.gd`, etc.).
- `res://Prefabs/00-Prefabs-Scripts/`: Scripts de los Actores (`Character_1.gd`, `rigid_charac.gd`) y Triggers/Áreas (`zona_danio.gd`, `zona_item.gd`).
- `res://Prefabs/XX-.../`: Escenas de los personajes, geometrías, armas y proyectiles organizadas por prefijos numéricos.

---

## 3. Plantilla de un Nuevo Componente

Crea el archivo en `res://Prefabs/01-Resources/<nombre_componente>.gd`:

```gdscript
extends Resource
class_name NombreComponente

# 1. SEÑALES (si el componente notifica cambios)
signal estado_cambiado(nuevo_estado: int)
signal evento_disparado

# 2. PROPIEDADES EXPORTADAS (Configuración en Inspector)
@export_group("Configuración")
@export var valor_base: float = 10.0
@export var activo: bool = true

# 3. ESTADO INTERNO (Si almacena datos en tiempo de ejecución)
var valor_actual: float = 0.0

func _init() -> void:
	valor_actual = valor_base

# 4. MÉTODOS DE LÓGICA / PROCESAMIENTO
# Recibe el actor (body/nodo) como argumento para manipularlo
func procesar(body: CharacterBody3D, delta: float) -> void:
	if not activo:
		return
	# Lógica sobre el body...
	# body.velocity = ...
	evento_disparado.emit()

# 5. MÉTODOS DE ACCIÓN (Llamados por triggers, armas o el propio actor)
func aplicar_efecto(cantidad: float) -> void:
	valor_actual += cantidad
	estado_cambiado.emit(valor_actual)
```

---

## 4. Integración en el Actor (`Player` / `CharacterBody3D`)

En el script del actor (ej: `Character_1.gd`):

```gdscript
extends CharacterBody3D
class_name Player

@export_category("Components")
@export var mi_componente: NombreComponente

func _ready() -> void:
	# Conexión segura con verificación de existencia
	if mi_componente:
		mi_componente.estado_cambiado.connect(_on_estado_cambiado)

func _physics_process(delta: float) -> void:
	# Delegación de lógica
	if mi_componente:
		mi_componente.procesar(self, delta)
	
	move_and_slide()

func _on_estado_cambiado(nuevo_estado: int) -> void:
	print("El componente notificó cambio:", nuevo_estado)
```

---

## 5. Checklist de Verificación al Crear un Componente

- [ ] ¿Tiene `class_name` en PascalCase?
- [ ] ¿Extiende de `Resource`?
- [ ] ¿Usa tipado estático completo (`var x: float`, `-> void`)?
- [ ] Si manipula físicas/transform, ¿recibe el nodo como parámetro en vez de guardarlo internamente?
- [ ] Si emite señales, ¿el actor las conecta en `_ready()` verificando `if component != null`?
- [ ] Si tiene estado mutable por personaje, ¿se configuró `Local to Scene` en el Inspector?
- [ ] ¿Está categorizado con `@export_category("Components")` en el script del personaje?

---

## 6. Componentes en Entornos Multijugador (Multiplayer Authority)

Al integrar componentes dentro de actores sincronizados por red (`Player_MP`):

1. **Separación de Responsabilidades en `_physics_process`**:
   - **Lógica Autoritativa (Inputs / Movimiento / Disparo):** Debe filtrarse con `if is_multiplayer_authority():`.
   - **Componentes Visuales / Procedurales (Trails, Seguidor Snake, Animaciones):** **NO** deben filtrarse por autoridad; deben ejecutarse para todos los peers para que cada máquina simule localmente el efecto visual siguiendo el nodo raíz sincronizado por red:
   ```gdscript
   func _physics_process(delta: float) -> void:
       # 1. Acciones locales del dueño
       if is_multiplayer_authority():
           if movement_component:
               movement_component.process_movement(self, movimiento_local, delta)
           move_and_slide()
       
       # 2. Simulación visual para todas las máquinas
       if visual_follower_component:
           visual_follower_component.actualizar(self, delta)
   ```
2. **Reconciliación de Estado (Variables vs RPCs)**:
   - Los componentes que agregan o eliminan elementos físicos (ej. eslabones de serpiente) deben sincronizarse mediante contadores enteros en `MultiplayerSynchronizer` (`cantidad_cuerpos`, `ON_CHANGE`), delegando en el componente la creación/destrucción local en cada cliente.
   - En componentes procedurales dependientes de trayectoria, el cliente recién conectado solicita el historial al dueño vía RPC (`PackedVector3Array`) para desplegar el estado visual inmediatamente sin apilamientos.
3. **Replicación de Componentes e Ítems Basados en Resource en Red**:
   - `MultiplayerSpawner` solo replica la escena base declarada en `_spawnable_scenes`, pero no transfiere recursos inyectados en memoria.
   - Para que el cliente reciba la configuración del recurso (`ItemData` / configuración de componente), sincronizar una variable `data_path: String` en el `MultiplayerSynchronizer` (`spawn = true`, `replication_mode = NEVER`).
   - Al fabricar/spawnear en el servidor, asignar `nuevo_nodo.data_path = recurso.resource_path`. En el cliente, el setter ejecuta `recurso = load(data_path)` y actualiza los visuales/comportamiento localmente sin coste de ancho de banda adicional.

