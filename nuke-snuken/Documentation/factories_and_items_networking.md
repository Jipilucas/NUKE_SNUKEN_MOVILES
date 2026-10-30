# Arquitectura del Sistema de Fábricas e Ítems en Red (Godot 4)

Este documento detalla la estructura orientada a objetos (UML), el proceso de instanciación distribuida y el control de comportamiento en red de las entidades del juego.

---

## 1. Diagrama de Clases UML (Fábricas, Recursos e Ítems)

El sistema combina tres patrones de diseño:
1. **Abstract Factory / Factory Method:** Desacopla la creación del objeto físico de su configuración de datos.
2. **Flyweight / Data-Driven Design (Resource):** Los datos y la lógica de efectos (`ItemData`) se definen en recursos `.tres` reutilizables.
3. **Composite / Decorator (Visual Polymorphism):** `ItemWorld` funciona como contenedor físico y de red genérico (`Area3D`), mientras que la representación visual y sus animaciones se delegan polimórficamente a `ItemVisual` (`Huevo`).

```mermaid
classDiagram
    direction TB

    class Node3D
    class Area3D
    class Resource

    Node3D <|-- FabricaAbstracta
    FabricaAbstracta <|-- Fabrica
    Node3D <|-- RepartidorItems
    Area3D <|-- ItemWorld
    Resource <|-- ItemData
    Node3D <|-- ItemVisual
    ItemVisual <|-- Huevo

    class FabricaAbstracta {
        <<abstract>>
        +Node3D spawn_path
        +PackedScene escena_base_item
        +obtener_item_data()* ItemData
        +fabricar() ItemWorld
        +spawn_en_pos(Vector3 posicion) ItemWorld
        +spawn_en_nodo(Node3D nodo) ItemWorld
    }

    class Fabrica {
        +ItemData item_data
        +obtener_item_data() ItemData
    }

    class RepartidorItems {
        +Fabrica Fabrica1
        +Array~Node3D~ Fabrica1_Spawns
        +float tiempo_respawn_Fabrica1
        +Fabrica Fabrica2
        +Array~Node3D~ Fabrica2_Spawns
        +float tiempo_respawn_Fabrica2
        +Fabrica Fabrica3
        +Array~Node3D~ Fabrica3_Spawns
        +float tiempo_respawn_Fabrica3
        -Dictionary _items_activos
        +limpiar_previsualizaciones_editor() void
        +generar_todos_los_items() void
        +llenar_usando(Fabrica f, Array spawns, float t) void
        -_spawn_con_respawn(Fabrica f, Node3D p, float t) void
        -_on_item_consumido(Fabrica f, Node3D p, float t) void
        +punto_esta_ocupado(Node3D punto) bool
    }

    class ItemData {
        +String nombre
        +PackedScene modelo_escena
        +Mesh modelo_mesh
        +Material material_override
        +Vector3 escala_visual
        +int puntos
        +float cura_vida
        +aplicar_efecto(Node3D actor) void
    }

    class ItemWorld {
        +String data_path
        +ItemData data
        +MeshInstance3D mesh_instance
        +CollisionShape3D collision_shape
        -Node3D _instancia_escena
        +_ready() void
        -_actualizar_visuales() void
        -_on_body_entered(Node3D body) void
        +despawn() void
        +rpc_animacion_consumir() void
    }

    class ItemVisual {
        <<abstract>>
        +despawn_animation_play()* void
    }

    class Huevo {
        +MeshInstance3D huevomodel
        +MeshInstance3D pintas
        +AnimationPlayer animation_player
        +_ready() void
        -_hacer_materiales_unicos() void
        +despawn_animation_play() void
    }

    RepartidorItems o-- Fabrica : coordina
    RepartidorItems o-- ItemWorld : monitorea ciclo de vida
    Fabrica o-- ItemData : almacena receta
    Fabrica ..> ItemWorld : crea y ensambla
    ItemWorld *-- ItemData : data inyectada
    ItemWorld o-- ItemVisual : instancia visual hija
```

---

## 2. Diagrama de Secuencia: Instanciación y Sincronización en Red

Muestra el flujo desde que el Servidor decide colocar un ítem hasta que todos los clientes tienen el modelo renderizado con materiales independientes.

```mermaid
sequenceDiagram
    autonumber
    participant Repartidor as RepartidorItems (Servidor)
    participant Fabrica as Fabrica (Servidor)
    participant ItemServidor as ItemWorld (Servidor)
    participant Spawner as MultiplayerSpawner (ItemsSpawnPath)
    participant Cliente as Cliente (Remoto)
    participant ItemCliente as ItemWorld (Cliente)

    Note over Repartidor,Cliente: 1. Inicio de Partida (Host conectado)
    Repartidor->>Fabrica: spawn_en_pos(posicion)
    Fabrica->>Fabrica: fabricar() (Instancia Item.tscn)
    Fabrica->>ItemServidor: Asigna data e inyecta data_path = "res://...tres"
    Fabrica->>Spawner: destino.add_child(item, true)
    Fabrica->>ItemServidor: global_position = posicion

    Note over Spawner,Cliente: 2. Replicación Automática de Red
    Spawner-->>Cliente: Paquete de Spawn (instanciar Item.tscn con mismo nombre)
    Cliente->>ItemCliente: Instancia Item.tscn en ItemsSpawnPath

    Note over ItemServidor,ItemCliente: 3. Sincronización de Propiedades
    ItemServidor-->>ItemCliente: MultiplayerSynchronizer envía data_path y position
    ItemCliente->>ItemCliente: Setter data_path recibe ruta
    ItemCliente->>ItemCliente: data = load(data_path)
    ItemCliente->>ItemCliente: _actualizar_visuales()
    ItemCliente->>ItemCliente: Instancia modelo_escena (Huevo) como hijo
    ItemCliente->>ItemCliente: Huevo._hacer_materiales_unicos() (Duplica StandardMaterial3D)
```

---

## 3. Diagrama de Secuencia: Consumo, Animación RPC y Despawn

Ilustra cómo se procesa la física con autoridad de servidor, se despacha la animación a todas las máquinas y se destruye el ítem en red.

```mermaid
sequenceDiagram
    autonumber
    participant Jugador as Jugador (Cuerpo 3D)
    participant ItemServidor as ItemWorld (Servidor)
    participant ItemData as ItemData
    participant GestorPjs as GestorDeDatosPjs
    participant Cliente as Cliente (Remoto)
    participant VisualLocal as ItemVisual (Servidor)
    participant VisualCliente as ItemVisual (Cliente)

    Jugador->>ItemServidor: Colisión (body_entered)
    
    rect rgb(240, 248, 255)
        Note over ItemServidor: Verificación de Autoridad
        ItemServidor->>ItemServidor: is_multiplayer_server()? SÍ
        ItemServidor->>ItemServidor: body.is_in_group("Jugador")? SÍ
    end

    Note over ItemServidor,GestorPjs: Aplicación del Efecto en Servidor
    ItemServidor->>ItemData: aplicar_efecto(Jugador)
    ItemData->>GestorPjs: modificar_puntaje / modificar_vida
    alt Jugador es serpiente
        ItemData->>Jugador: agregar_cuerpo()
    end

    Note over ItemServidor: Inicio de Secuencia Despawn
    ItemServidor->>ItemServidor: collision_shape.set_deferred("disabled", true)
    
    ItemServidor->>ItemServidor: rpc_animacion_consumir() (Local)
    ItemServidor-->>Cliente: RPC rpc_animacion_consumir() (Red)

    par Animación en Servidor
        ItemServidor->>VisualLocal: despawn_animation_play()
        VisualLocal->>VisualLocal: AnimationPlayer.play("consumir")
    and Animación en Clientes
        Cliente->>VisualCliente: despawn_animation_play()
        VisualCliente->>VisualCliente: AnimationPlayer.play("consumir")
    end

    Note over ItemServidor: Servidor espera 0.9s (duración animación)
    ItemServidor->>ItemServidor: queue_free()
    ItemServidor-->>Cliente: MultiplayerSpawner replica eliminación (queue_free en clientes)
```

---

## 4. Diagrama de Estados: Ciclo de Vida del Ítem y Sistema de Respawn

Muestra los estados por los que transita cada marcador de spawn administrado por `RepartidorItems`.

```mermaid
stateDiagram-v2
    [*] --> Vacio : _ready() / limpiar_previsualizaciones_editor()
    
    state Vacio {
        [*] --> EsperandoPartida
        EsperandoPartida --> DisponibleParaSpawn : Host inicia partida (generar_todos_los_items)
    }

    DisponibleParaSpawn --> ActivoEnMundo : Fabrica.spawn_en_pos()
    
    state ActivoEnMundo {
        [*] --> EsperandoInteraccion
        EsperandoInteraccion --> Consumido : Jugador toca Area3D (_on_body_entered)
        Consumido --> DesactivandoColision : Servidor desactiva CollisionShape
        DesactivandoColision --> AnimandoRPC : rpc_animacion_consumir()
        AnimandoRPC --> Destruido : await timer(0.9s) -> queue_free()
    }

    ActivoEnMundo --> CooldownRespawn : Señal tree_exited (CONNECT_ONE_SHOT)
    
    state CooldownRespawn {
        [*] --> Temporizador : await timer(tiempo_cooldown)
        Temporizador --> ComprobacionServidor : timeout
        ComprobacionServidor --> [*] : Servidor activo y peer conectado
    }

    CooldownRespawn --> ActivoEnMundo : _spawn_con_respawn()
```

---

## 5. Resumen de Reglas Clave de Arquitectura

| Aspecto | Implementación | Propósito |
| :--- | :--- | :--- |
| **Punto de Montaje en Red** | `ItemsSpawnPath` (Hijo directo del Spawner) | Requisito estricto de `MultiplayerSpawner` para replicar spawns y despawns automáticos. |
| **Tráfico Cero post-spawn** | `data_path` en `MultiplayerSynchronizer` (`REPLICATION_MODE_NEVER`) | El cliente carga el recurso localmente al nacer. No consume ancho de banda continuo. |
| **Aislamiento de Materiales** | `_hacer_materiales_unicos()` en `huevo.gd` | Clona el material en memoria para que la emisión animada no se propague a otros ítems del mapa. |
| **Seguridad de Efectos** | Colisión validada únicamente con `if multiplayer.is_server():` | Previene que clientes hagan trampa o dupliquen puntuaciones localmente. |
| **Respawn Desacoplado** | Conexión `CONNECT_ONE_SHOT` a `tree_exited` | Evita bucles de sondeo (*polling*) o raycasts continuos; se reactiva solo cuando el ítem realmente desaparece del árbol. |
