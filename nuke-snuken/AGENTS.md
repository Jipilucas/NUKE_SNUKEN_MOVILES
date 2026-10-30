# UPSO Multiplayer - Guía y Configuración para Agentes

## Depuración y Despliegue en Android (Samsung Galaxy A04)

### Ruta de Platform-Tools (ADB)
- **Directorio:** `F:\25- GODOT\AndroidSDK\platform-tools`
- **ID de Dispositivo (USB):** `R9MW500RQLE`
- **Package ID:** `com.example.upso_multiplayer`

### Comandos para Conectar por Wi-Fi (ADB sobre TCP/IP)
Ejecutar desde PowerShell en `F:\25- GODOT\AndroidSDK\platform-tools`:

```powershell
# 1. Verificar dispositivo conectado por USB
./adb devices

# 2. Habilitar modo TCP/IP en el puerto 5555
./adb tcpip 5555

# 3. Obtener la dirección IP del teléfono en la red local (wlan0)
./adb shell ip route

# 4. Conectar al dispositivo mediante su IP (ejemplo con IP detectada 192.168.100.34)
./adb connect 192.168.100.34
```

Una vez conectado por IP (`connected to 192.168.100.34:5555`), ya se puede desconectar el cable USB y Godot detectará el teléfono inalámbricamente para *One-Click Deploy*.

---

### Solución a Problemas Frecuentes

- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`**:
  Ocurre si la firma del APK no coincide con una versión previamente instalada.
  - Solución manual: Desinstalar la aplicación en el teléfono antes de desplegar.
  - Solución por ADB:
	```powershell
	./adb uninstall com.example.upso_multiplayer
	```

---

## Arquitectura Multijugador (Godot 4 Multiplayer)

### 1. MultiplayerSpawner y Contenedores
- Las escenas que deban replicarse en red deben registrarse obligatoriamente en `_spawnable_scenes` (Auto Spawn List) del `MultiplayerSpawner`. Sin esto, el servidor crea el nodo pero jamás lo replica a los clientes.
- El nodo asignado a `spawn_path` (ej. `Players`) es de **uso exclusivo** para las entidades de red gestionadas por el spawner. Nodos auxiliares o contenedores dinámicos locales (ej. `_SnakeBody`) deben crearse en la raíz del mundo (`current_scene`), fuera de `spawn_path`.

### 2. Invariante de Transformaciones Globales
- **Nunca** leer o escribir `node.global_position` o `node.global_transform` antes de que el nodo esté dentro del árbol de escenas (`is_inside_tree()`). Hacerlo produce `Condition "!is_inside_tree()" is true` y devuelve una transformación vacía.
- Orden obligatorio siempre:
  ```gdscript
  parent.add_child(nuevo_nodo)
  nuevo_nodo.global_position = target_position
  ```

### 3. Modelo de Autoridad en Componentes
- En `_physics_process()`, separar estrictamente:
  - **Inputs y Movimiento Físico:** Filtrar con `if is_multiplayer_authority():` (movimiento WASD, salto, rotación de apuntado, disparo).
  - **Componentes Visuales / Procedurales:** Deben ejecutarse para **todas** las instancias (locales y remotas). Cada cliente simula localmente los efectos visuales (como `SnakeBodyComponent3D`) siguiendo la cabeza que ya viene sincronizada por red.

### 4. Sincronización de Entidades Segmentadas (Snake Pattern)
- No sincronizar las transformaciones de cada eslabón por red (saturaría el ancho de banda). Sincronizar un único entero `@export var cantidad_cuerpos: int` en el `MultiplayerSynchronizer` (`spawn = true`, `replication_mode = ON_CHANGE`).
- Cada máquina reconcilia localmente la cantidad de eslabones físicos en base a ese número.
- Para evitar que los eslabones aparezcan apilados cuando un cliente se une a una partida en curso, el cliente remoto solicita el historial de trayectoria mediante un RPC ligero con `PackedVector3Array` (`@rpc("any_peer", "reliable") solicitar_historial_snake()`).

### 5. Depuración con Múltiples Instancias en el Editor
- Al correr 2 instancias (`Debug -> Run Multiple Instances`), la pestaña **Remoto** del árbol de escenas inspecciona por defecto la **Sesión 1 (Host)**.
- Para inspeccionar el árbol del **Cliente**, cambiar a **Sesión 2** en la barra superior del panel **Depurador (Debugger)**.

### 6. Timing de Spawn y Trampa de `multiplayer.is_server()` en `_ready()`
- En Godot 4, cuando `multiplayer.multiplayer_peer == null` (antes de pulsar Host o Join en un lobby), `multiplayer.is_server()` devuelve `true` por defecto (modo local/offline).
- **Prohibido:** Ejecutar lógica de spawn de red en `_ready()` si el juego cuenta con menú de lobby o conexión pendiente. Hacerlo provoca que el Cliente genere una copia local huérfana de los nodos que luego se superpone con los ítems del servidor y nunca se destruye.
- **Regla obligatoria:** Solo spawnear entidades de red cuando el peer esté conectado y confirmado como servidor:
  ```gdscript
  if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
      # Spawn seguro
  ```
  O invocando la generación explícitamente desde el callback de éxito al crear el host (`_on_host_pressed()`).

### 7. Jerarquía Estricta en `MultiplayerSpawner` (Solo Hijos Directos)
- `MultiplayerSpawner` **únicamente vigila y replica los hijos directos** del nodo configurado en `spawn_path`.
- **Nunca** añadir entidades de red como hijos de subnodos o marcadores (`spawn_path/carpeta/marcador.add_child(item)`). Hacerlo causará que el spawner ignore el nodo por completo (no lo enviará a los clientes y no notificará su `queue_free()`).
- **Patrón correcto:** Los nodos de posición (`SpawnPoints`, `Markers`) deben ser hermanos o estar fuera de `spawn_path`. La entidad de red se agrega siempre como `spawn_path.add_child(item, true)` y se le asigna `item.global_position = marcador.global_position`.

### 8. Previsualizaciones de Diseño de Niveles vs Entidades de Red
- Para permitir colocar modelos 3D de referencia dentro de los marcadores en el editor:
  - En `_ready()` de la escena o del repartidor, ejecutar en **todas** las instancias (Host y Cliente) una limpieza de hijos (`child.queue_free()`) sobre los marcadores.
  - Esto garantiza que en el editor se visualice el mapa completo, pero que en tiempo de ejecución no queden modelos estáticos "zombis" en ningún cliente.

### 9. Sincronización de Componentes / Custom Resources en Red
- `MultiplayerSpawner` solo instancia la escena base declarada en `_spawnable_scenes`, pero no transfiere recursos o variables inyectadas en memoria (`item.data = mi_recurso`).
- **Patrón de Replicación Ligero:**
  1. En la escena base, incluir un `MultiplayerSynchronizer` con `.:data_path` (`spawn = true`, `replication_mode = NEVER`).
  2. Al fabricar el nodo en el servidor, asignar `nuevo_item.data_path = item_data.resource_path`.
  3. En el cliente, el setter de `data_path` ejecuta `data = load(data_path)` y actualiza los visuales localmente. Cero costo de ancho de banda tras el spawn inicial.

### 10. Modelos `.glb` (`PackedScene`) vs `.obj` (`Mesh`)
- En Godot 4, los archivos `.glb`/`.gltf` se importan como `PackedScene`.
- Si un componente o recurso exporta `@export var mesh: Mesh`, el Inspector rechazará los archivos `.glb`.
- **Estándar:** Soportar `@export var modelo_escena: PackedScene` (instanciado como hijo con escala) y alternativamente `@export var modelo_mesh: Mesh` para mallas simples.

### 11. Respawn Reactivo Basado en Señales (`tree_exited`)
- Para regenerar ítems o pickups al quedar vacíos los puntos de spawn, evitar bucles de sondeo (`polling`) con raycasts o timers generales.
- **Estándar:** En el Servidor, conectar la señal `item.tree_exited` con `CONNECT_ONE_SHOT`. Al liberarse el nodo (`queue_free()`), esperar el tiempo de cooldown con `SceneTreeTimer` y volver a spawnear en el marcador solo si el servidor sigue activo.
