import Foundation

/// Tipos de paquetes que viajan a través de la red Mesh P2P
public enum MeshPacketType: String, Codable {
    case chatMessage       // Mensajes de texto en canal general o privado
    case friendPing        // Notificación / vibración para ubicar a un amigo en la multitud
    case proximityBeacon   // Señal de presencia con estado de batería y distancia relativa
    case computeOffer      // Anuncio de un nodo sobre cuánta RAM y potencia ofrece al cluster
    case computeJobAssign  // El coordinador envía un fragmento de tarea a un nodo
    case computeJobResult  // El nodo devuelve el resultado procesado
}

/// Paquete con soporte para enrutamiento multi-salto (Multi-hop Mesh)
public struct MeshPacket: Codable, Identifiable {
    public let id: String                    // Identificador único del paquete (UUID)
    public let type: MeshPacketType
    public let originPeerID: String          // Quién originó el mensaje originalmente
    public let originDisplayName: String     // Nombre legible del emisor original
    public var targetPeerID: String?         // Destino específico (nil = broadcast a toda la red)
    public var ttl: Int                      // Saltos de vida restantes (Time To Live, ej: 3 saltos)
    public var hops: Int                     // Cuántos saltos lleva dados
    public let timestamp: Date
    public let payload: Data                 // Contenido serializado según el tipo

    public init(
        type: MeshPacketType,
        originPeerID: String,
        originDisplayName: String,
        targetPeerID: String? = nil,
        ttl: Int = 4,
        payload: Data
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.originPeerID = originPeerID
        self.originDisplayName = originDisplayName
        self.targetPeerID = targetPeerID
        self.ttl = ttl
        self.hops = 0
        self.timestamp = Date()
        self.payload = payload
    }
}

/// Estructura de un mensaje de chat offline
public struct MeshChatMessage: Codable, Identifiable {
    public let id: String
    public let senderID: String
    public let senderName: String
    public let channel: String       // "General", "Emergencias", "Privado"
    public let text: String
    public let timestamp: Date
    public var hopCount: Int

    public init(senderID: String, senderName: String, channel: String = "General", text: String, hopCount: Int = 0) {
        self.id = UUID().uuidString
        self.senderID = senderID
        self.senderName = senderName
        self.channel = channel
        self.text = text
        self.timestamp = Date()
        self.hopCount = hopCount
    }
}

/// Anuncio de recursos de cómputo que ofrece un dispositivo
public struct ComputeWorkerProfile: Codable, Identifiable {
    public var id: String { peerID }
    public let peerID: String
    public let displayName: String
    public let deviceModel: String
    public let allocatedMemoryMB: Int       // RAM ofrecida para tareas (ej: 512 MB)
    public let cpuCores: Int
    public let batteryLevel: Float           // 0.0 a 1.0
    public let isCharging: Bool
    public var isBusy: Bool
    public var lastSeen: Date

    public init(
        peerID: String,
        displayName: String,
        deviceModel: String,
        allocatedMemoryMB: Int,
        cpuCores: Int,
        batteryLevel: Float,
        isCharging: Bool,
        isBusy: Bool = false
    ) {
        self.peerID = peerID
        self.displayName = displayName
        self.deviceModel = deviceModel
        self.allocatedMemoryMB = allocatedMemoryMB
        self.cpuCores = cpuCores
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.isBusy = isBusy
        self.lastSeen = Date()
    }
}

/// Tarea de cómputo distribuida (ejemplo: bloque de renderizado o cálculo matricial)
public struct ComputeJobTask: Codable, Identifiable {
    public let id: String
    public let jobID: String
    public let tileIndex: Int                // Índice de la cuadrícula o chunk
    public let totalTiles: Int
    public let width: Int
    public let height: Int
    public let seed: UInt32
    public let complexityIterations: Int

    public init(jobID: String, tileIndex: Int, totalTiles: Int, width: Int = 64, height: Int = 64, seed: UInt32, complexityIterations: Int = 100) {
        self.id = UUID().uuidString
        self.jobID = jobID
        self.tileIndex = tileIndex
        self.totalTiles = totalTiles
        self.width = width
        self.height = height
        self.seed = seed
        self.complexityIterations = complexityIterations
    }
}

/// Resultado procesado que un worker devuelve al coordinador
public struct ComputeJobResult: Codable, Identifiable {
    public var id: String { taskID }
    public let jobID: String
    public let taskID: String
    public let tileIndex: Int
    public let workerPeerID: String
    public let executionTimeMs: Double
    public let rawData: Data                // Pixels renderizados o resultado del cálculo

    public init(jobID: String, taskID: String, tileIndex: Int, workerPeerID: String, executionTimeMs: Double, rawData: Data) {
        self.jobID = jobID
        self.taskID = taskID
        self.tileIndex = tileIndex
        self.workerPeerID = workerPeerID
        self.executionTimeMs = executionTimeMs
        self.rawData = rawData
    }
}

