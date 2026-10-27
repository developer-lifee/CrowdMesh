# 📡 Parche Radar — Red Mesh P2P & Cómputo Distribuido (iOS Nativo)

> **Comunicación offline multi-salto para eventos masivos y supercómputo distribuido voluntario entre dispositivos móviles.**

[![Plataforma](https://img.shields.io/badge/Platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![Frameworks](https://img.shields.io/badge/Frameworks-SwiftUI%20%7C%20Multipeer%20%7C%20CoreBluetooth-green.svg)](https://developer.apple.com/documentation/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

---

## 💡 El Problema y la Visión

En festivales de música multitudinarios (como **Rock al Parque**, **Estéreo Picnic**, festivales de verano), estadios o trancones kilométricos, las antenas celulares 4G/5G colapsan de inmediato por saturación. Encontrar a tus amigos o enviar un simple mensaje de texto se vuelve imposible.

**Parche Radar** soluciona esto convirtiendo cada iPhone en un **nodo repetidor** de una red en malla descentralizada (*Peer-to-Peer*), sin requerir conexión a internet, torres celulares ni Wi-Fi público.

Además, incorpora un motor de **Cómputo Distribuido (Grid Computing)**: permite que los dispositivos cercanos presten voluntariamente una porción de su memoria RAM y núcleos de CPU para resolver tareas complejas (renderizado de video, simulaciones científicas o inferencia de modelos de IA) divididas en micro-bloques en paralelo.

---

## ⚡️ Características Principales

### 1. 📡 Radar de Concierto & Radar Dragón 🐉
* **Modo Esferas del Dragón:** Visualiza a tus amigos en el radar como auténticas Esferas del Dragón translúcidas con brillo cristalino y estrellas rojas (de 1 a 7 estrellas con la clásica disposición geométrica, incluyendo la de 4 estrellas de Goku).
* **Tema Retro Anime Dragon Radar:** Conmutador de tema visual entre *Cyberpunk Neon* y el clásico *Dragon Radar Verde* (retícula de cuadrícula verde, flecha direccional roja en el centro y barrido sonar ámbar/amarillo).
* **Personalización Total de Amigos:** Toca cualquier amigo en el radar o en la lista para:
  * Cambiar su apodo o sobrenombre en pantalla.
  * Elegir su esfera (1 a 7 estrellas ★).
  * Asignar un sticker / emoji festivalero (⚡️, 🎸, 🍺, 👽, 🔥, 🐲, 🍕, 🍄, 🚀, 💎, 🤘, 🕶️, etc.).
  * **Subir Foto o PNG transparente** directamente desde la galería del iPhone (`PhotosPicker`).
* **Localización sin cobertura:** Detección automática de amigos cercanos utilizando radios directas de Apple (**AWDL / Wi-Fi Direct + Bluetooth LE**).
* **Círculos de Distancia:** Indicadores visuales de proximidad (*Muy cerca < 5m*, *Cerca ~10m*, *Media distancia ~25m*, *Lejos > 40m*).
* **PING Háptico Sonar:** Envía una señal directa al iPhone de tu amigo que dispara una vibración háptica única para ubicarlo incluso en medio del ruido de la música.

### 2. 💬 Chat Mesh Offline Multi-Salto (Multi-Hop Routing)
* **Repetidor Silencioso:** Si tu amigo está a 80 metros y no hay alcance directo, los teléfonos de los asistentes intermedios reenvían los paquetes de forma transparente (`TTL` y deduplicación por UUID).
* **Canales Especializados:**
  * 📢 **#General:** Mensajes comunitarios y puntos de encuentro.
  * 🚨 **#Emergencias:** Canal de máxima prioridad de propagación en la malla.
  * 🎸 **#Tarima:** Coordinación de recitales.
* **Indicador de Saltos:** La app te informa si el mensaje llegó de forma directa o vía 1, 2 o 3 saltos mesh.

### 3. 🧠 Supercómputo Distribuido (Resource Pooling)
* **Slider de Asignación de RAM:** El usuario decide exactamente cuánta memoria cede a la red (desde **128 MB hasta 2048 MB**).
* **Protección de Batería:**
  * Opción de computar **únicamente si el teléfono está conectado al cargador o powerbank**.
  * Pausa automática si la batería cae por debajo del 25% o si el procesador detecta sobrecalentamiento térmico.
* **Demostración en Tiempo Real (16 Tiles):**
  * Divide un cálculo procedural pesado (Ray Marching fractal / convolución matricial) en una cuadrícula de 16 bloques.
  * Reparte los bloques entre los núcleos Apple Silicon del cluster.
  * Mide los **GigaFLOPS combinados** del enjambre y ensambla el resultado en vivo.
* **Modo Enjambre Virtual:** Incluye simulación local con hilos paralelos para probar la potencia del cluster incluso antes de llegar al concierto.

---

## 🛡️ Seguridad y Resistencia Cuántica

* **Aislamiento en Sandbox (Zero-Trust):** Ningún nodo del cluster tiene acceso a fotos, archivos ni memoria privada del dueño del teléfono; los trabajadores solo procesan tensores o píxeles aislados.
* **Preparado para Criptografía Post-Cuántica (PQC):**
  * Cifrado simétrico de alta entropía (AES-256 / ChaCha20-Poly1305) resistente al algoritmo cuántico de Grover.
  * Arquitectura lista para intercambio de claves tipo **ML-KEM (Kyber-768)**, el estándar internacional contra computadoras cuánticas.
* **Resiliencia Bizantina:** El coordinador puede enviar bloques duplicados a nodos aleatorios para verificar que ningún dispositivo modifique o sabotee los resultados del cómputo.

---

## 🏗️ Arquitectura del Código

```text
CrowdMesh/
├── Sources/
│   └── CrowdMesh/
│       ├── CrowdMeshApp.swift             # Punto de entrada de la aplicación
│       ├── MainTabView.swift              # Barra de navegación principal
│       ├── RadarView.swift                # Radar visual de proximidad con sweep sonar
│       ├── MeshChatView.swift             # Chat offline multi-canal y multi-salto
│       ├── ComputeGridView.swift          # Tablero de cómputo, slider de RAM y tiles
│       ├── SettingsView.swift             # Configuración de nodo, apodo y hardware
│       ├── MeshPacket.swift               # Estructuras de red, paquetes y enrutamiento
│       ├── MeshNetworkEngine.swift        # Motor central MultipeerConnectivity & BLE
│       ├── DistributedComputeEngine.swift # Particionador de tareas, kernels y ensamble
│       └── DeviceResourceMonitor.swift    # Monitoreo de RAM libre, batería y temperatura
├── CrowdMesh-Info.plist                   # Permisos Bonjour, red local y Bluetooth
├── generate_project.rb                    # Generador automatizado de CrowdMesh.xcodeproj
└── README.md
```

---

## 🚀 Instalación y Despliegue en Dispositivo Físico

### Requisitos:
* Mac con **macOS Sonoma** o superior.
* **Xcode 15** o superior.
* iPhone con **iOS 17.0** o superior (conectado por cable USB o Wi-Fi local).

### Pasos:
1. Clonar el repositorio:
   ```bash
   git clone https://github.com/developer-lifee/CrowdMesh.git
   cd CrowdMesh
   ```
2. Abrir el proyecto en Xcode:
   ```bash
   open CrowdMesh.xcodeproj
   ```
3. Seleccionar tu iPhone en la barra superior de dispositivos.
4. Presionar **Cmd + R** para compilar e instalar en tu celular.

*(En el primer inicio en tu iPhone, si aparece "Desarrollador no confiable", ve a **Ajustes > General > VPN y gestión de dispositivos** y presiona en **Confiar en tu cuenta de Apple**).*

---

## 🗺️ Hoja de Ruta (Roadmap)

- [x] Radar de proximidad por Bluetooth / Wi-Fi Direct sin conexión.
- [x] Enrutamiento de chat multi-salto con deduplicación de paquetes.
- [x] Control fino de asignación de RAM y protecciones de batería.
- [x] Motor de cómputo distribuido con ensamblado en vivo de 16 tiles.
- [ ] Puente universal BLE GATT para conectar iPhones con dispositivos **Android**.
- [ ] Integración con radios de largo alcance **LoRa / Meshtastic** (alcance de 5 a 10 km).
- [ ] Distribución de fragmentos para inferencia local de modelos de lenguaje pequeños (SLM tipo Llama 3 / Gemma en Metal).

---

## 📄 Licencia

Este proyecto está bajo la Licencia **MIT** — Siéntete libre de utilizarlo, modificarlo y desplegarlo en tus propios eventos.

