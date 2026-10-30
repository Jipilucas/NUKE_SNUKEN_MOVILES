# Arquitectura y Comportamiento en Red del Snake Body System

Este documento detalla la estructura orientada a objetos (UML), la distribución en el árbol de nodos de Godot 4 y el flujo de comunicación y sincronización en red del sistema de cuerpos tipo "Snake".

---

## 1. Diagrama de Clases UML (Estructura de Componentes)

El siguiente diagrama muestra la relación entre el jugador en red (`Player_MP`), su componente de cuerpo (`MPSnakeBodyComponent3D`), los sincronizadores de red y los interactuables del mundo (`ItemWorld` / `ItemData`).

```mermaid
classDiagram
    direction TB

    class CharacterBody3D {
        <<Godot Core>>
    }

    class Node3D {
        <<Godot Core>>
    }

    class MultiplayerSynchronizer {
        <<Godot Core>>
        +SceneReplicationConfig replication_config
        +int multiplayer_authority
    }

    class Player_MP {
        +int id_jugador
        +int cantidad_cuerpos
        +float push_force
        +bool movimiento_local
        +CharacterMovementComponent3D movement_component
        +ScoreSystem score_system
        +HealthSystem health_system
        +MPSnakeBodyComponent3D snake_component
        +_enter_tree() void
        +_ready() void
        +_physics_process(delta) void
        +_sincronizar_segmentos_locales() void
        +agregar_cuerpo() void
        +quitar_cuerpo(cant) void
        +solicitar_historial_snake() void$
        +recibir_historial_snake(historial) void$
    }

    class MPSnakeBodyComponent3D {
        +PackedScene cuerpo_scene
        +PackedScene cola_scene
        +float distancia_segmento
        +float velocidad_rotacion
        +float distancia_muestreo
        +bool crear_cola_al_iniciar
        +bool gravedad_activa
        +float fuerza_gravedad
        +float offset_suelo
        -Array~Node3D~ _cuerpos
        -Node3D _cola
        -Array~Vector3~ _historial_posiciones
        -Node3D _nodo_contenedor
        +actualizar(body, delta) void
        +agregar_cuerpo(body) Node3D
        +quitar_cuerpo() bool
        +obtener_cuerpos() Array~Node3D~
        +obtener_cola() Node3D
        +obtener_cantidad_segmentos() int
        +obtener_historial_empaquetado() PackedVector3Array
        +establecer_historial_empaquetado(historial) void
        +limpiar() void
    }

    class SnakeSegment {
        <<Prefab Node3D>>
        +MeshInstance3D mesh
    }

    class SnakeTail {
        <<Prefab Node3D>>
        +MeshInstance3D mesh
    }

    class ItemWorld {
        +String data_path
        +ItemData data
        +_on_body_entered(body) void
    }

    class ItemData {
        +String nombre
        +int puntos
        +float cura_vida
        +aplicar_efecto(actor) void
    }

    CharacterBody3D <|-- Player_MP
    Node3D <|-- MPSnakeBodyComponent3D
    Node3D <|-- SnakeSegment
    Node3D <|-- SnakeTail

    Player_MP *-- MPSnakeBodyComponent3D : snake_component
    Player_MP *-- MultiplayerSynchronizer : "Client Synchronizer (pos, rot)"
    Player_MP *-- MultiplayerSynchronizer : "Server Synchronizer (cantidad_cuerpos)"

    MPSnakeBodyComponent3D ..> SnakeSegment : instancia
    MPSnakeBodyComponent3D ..> SnakeTail : instancia

    ItemWorld o-- ItemData : data
    ItemWorld ..> Player_MP : invoca agregar_cuerpo() [Server Only]
```

---

## 2. Jerarquía de Árbol de Escenas y Aislamiento de Spawner

Para cumplir con la regla del motor en la que `MultiplayerSpawner` supervisa **exclusivamente a los hijos directos** de su contenedor asignado, los segmentos procedurales del Snake no se instancian dentro de `Players` ni como hijos directos del `CharacterBody3D` (lo cual arrastraría la física y provocaría rotaciones rígidas). En su lugar, se agrupan en un contenedor hermano dedicado (`{PeerID}_SnakeBody`).

```mermaid
graph TD
    WorldMp["WorldMp (current_scene)"]
    
    subgraph RedControlada ["Supervisado por MultiplayerSpawner"]
        Players["Node3D: Players (spawn_path)"]
        P1["CharacterBody3D: '1' (Player_MP Host)"]
        P2["CharacterBody3D: '1794616989' (Player_MP Cliente)"]
        MS1["MultiplayerSynchronizer (Auth: 1)"]
        SS1["ServerSynchronizer (Auth: 1)"]
        MS2["MultiplayerSynchronizer (Auth: 1794616989)"]
        SS2["ServerSynchronizer (Auth: 1)"]
        
        Players --> P1
        Players --> P2
        P1 --> MS1
        P1 --> SS1
        P2 --> MS2
        P2 --> SS2
    end

    subgraph ProceduralLocal ["Simulado Localmente en cada Peer"]
        Cont1["Node3D: '1_SnakeBody'"]
        Cont2["Node3D: '1794616989_SnakeBody'"]
        Seg1A["SnakeSegment_0"]
        Seg1B["SnakeSegment_1"]
        Tail1["SnakeTail"]
        Seg2A["SnakeSegment_0"]
        Tail2["SnakeTail"]

        Cont1 --> Seg1A
        Cont1 --> Seg1B
        Cont1 --> Tail1
        Cont2 --> Seg2A
        Cont2 --> Tail2
    end

    WorldMp --> Players
    WorldMp --> Cont1
    WorldMp --> Cont2
```

---

## 3. Diagrama de Secuencia: Flujo y Comportamiento en Red

El modelo desacopla:
1. **Movimiento/Aiming:** Controlado por el cliente dueño (`MultiplayerSynchronizer`).
2. **Lógica de Juego (Pickups/Daño):** Verificada y ejecutada por el Servidor (`ServerSynchronizer`).
3. **Simulación Cinemática de Eslabones:** Calculada localmente en cada máquina (`MPSnakeBodyComponent3D.actualizar()`).
4. **Despliegue al Conectarse:** Reconciliación de trayectoria mediante RPC ligero (`PackedVector3Array`).

```mermaid
sequenceDiagram
    autonumber
    actor Cliente as Cliente (Peer Remoto)
    participant C_Player as Player Cliente (Local)
    participant C_Snake as SnakeComp (Cliente)
    participant Red as Red / ENet
    participant S_Player as Player Cliente (En Servidor)
    participant Servidor as Servidor / Host (Peer 1)
    participant Item as ItemWorld (Banana / Fruta)

    Note over Cliente, Servidor: FASE 1: RECOLECCIÓN AUTORITATIVA DE ÍTEM
    Cliente->>C_Player: Input movimiento (WASD / Stick)
    C_Player->>Red: MultiplayerSynchronizer transmite (position, rotation)
    Red->>S_Player: Actualiza posición en el servidor
    S_Player->>Item: Entra en colisión (body_entered)
    
    critical Verificación en Servidor
        Item->>Servidor: if not multiplayer.is_server(): return
        Servidor->>Item: Aplica efecto (item_data.aplicar_efecto)
        Item->>S_Player: agregar_cuerpo()
        S_Player->>S_Player: cantidad_cuerpos += 1
        Item->>Item: queue_free() (replicado por ItemSpawner)
    end

    Note over Servidor, Cliente: FASE 2: REPLICACIÓN POR SERVERSYNCHRONIZER
    Servidor->>Red: ServerSynchronizer emite ON_CHANGE (cantidad_cuerpos)
    Red->>C_Player: Recibe nuevo valor de cantidad_cuerpos
    C_Player->>C_Player: Setter ejecuta _sincronizar_segmentos_locales()
    C_Player->>C_Snake: agregar_cuerpo(self)
    C_Snake->>C_Snake: Instancia SnakeSegment en contenedor dedicado

    Note over Cliente, Servidor: FASE 3: SIMULACIÓN PROCEDURAL LOCAL
    loop En cada physics frame (Host y Cliente)
        C_Snake->>C_Snake: Registra posición cabeza en _historial_posiciones (Breadcrumbs)
        C_Snake->>C_Snake: Muestrea posición a lo largo de la polilínea histórica
        C_Snake->>C_Snake: Raycast vertical al suelo + gravedad de salto
        C_Snake->>C_Snake: Slerp de rotación hacia el vector director
    end

    Note over Cliente, Servidor: FASE 4: ENTRADA TARDÍA / SINCRONIZACIÓN DE HISTORIAL
    Cliente->>Red: solicitar_historial_snake.rpc_id(Authority)
    Red->>Servidor: Ejecuta solicitar_historial_snake()
    Servidor->>Servidor: Empaqueta _historial_posiciones en PackedVector3Array
    Servidor->>Red: recibir_historial_snake.rpc_id(remitente, historial)
    Red->>Cliente: Recibe PackedVector3Array
    Cliente->>C_Snake: Sobrescribe historial -> Despliega eslabones sin parpadeo
```

---

## 4. Resumen de Invariantes de Red Implementados

| Aspecto | Implementación Técnica | Beneficio |
| :--- | :--- | :--- |
| **Separación de Autoridades** | `MultiplayerSynchronizer` (Peer ID) + `ServerSynchronizer` (Peer 1) | Permite control reactivo de movimiento sin perder autoridad de servidor en vidas, colisiones y crecimiento. |
| **Ancho de Banda Mínimo** | Solo se replica un entero (`cantidad_cuerpos`) en modo `ON_CHANGE`. | Cero envío continuo de transformaciones de eslabones por red. |
| **Simulación Visual Local** | Cada máquina interpola traslación, slerp y raycast de suelo localmente. | Movimiento orgánico a 60 FPS sin jitter ni desincronización de física. |
| **Alineación de Conexión en Curso** | RPC `solicitar_historial_snake` vía `PackedVector3Array`. | Evita que los cuerpos de jugadores ya existentes aparezcan apilados en el punto de spawn inicial. |
