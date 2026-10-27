import Foundation
import MultipeerConnectivity
import UIKit
import Combine

/// Utilidad global para ocultar el teclado desde cualquier vista en iOS
@MainActor
public func dismissKeyboardGlobally() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Información de un peer / amigo cercano en la red
public struct DiscoveredPeer: Identifiable, Equatable {
    public var id: String { peerID.displayName }
    public let peerID: MCPeerID
    public var displayName: String
    public var isDirectlyConnected: Bool
    public var hopDistance: Int             // 1 = directo, 2+ = a través de otro nodo
    public var estimatedDistanceMeters: Double
    public var lastSeen: Date
    public var workerProfile: ComputeWorkerProfile?

    public static func == (lhs: DiscoveredPeer, rhs: DiscoveredPeer) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.isDirectlyConnected == rhs.isDirectlyConnected &&
        lhs.hopDistance == rhs.hopDistance
    }

    public var signalStrengthDescription: String {
        if estimatedDistanceMeters < 5 { return "Muy Cerca (< 5m)" }
        if estimatedDistanceMeters < 15 { return "Cerca (~10m)" }
        if estimatedDistanceMeters < 30 { return "Media distancia (~25m)" }
        return "Lejos (> 40m)"
    }
}

/// Motor central de red Mesh P2P Descentralizada
@MainActor
public final class MeshNetworkEngine: NSObject, ObservableObject {
    public static let shared = MeshNetworkEngine()

    public static let serviceType = "parche-radar"

    // Navegación entre pestañas y chat directo 1 a 1
    @Published public var selectedTabIndex: Int = 0
    @Published public var activeDirectPeerID: String? = nil   // nil = Canales grupales, o ID del amigo para Mensaje Directo 1 a 1

    // Identidad única e irrepetible del nodo local
    public let shortNodeTag: String
    @Published public var myPeerID: MCPeerID
    @Published public var myDisplayName: String {
        didSet {
            UserDefaults.standard.set(myDisplayName, forKey: "parcheradar_username_v2")
            restartSession()
        }
    }

    // Estado de la red
    @Published public var connectedPeers: [MCPeerID] = []
    @Published public var nearbyPeers: [String: DiscoveredPeer] = [:]
    @Published public var chatMessages: [MeshChatMessage] = []
    @Published public var receivedPings: [String] = [] // Lista de amigos que te han hecho ping
    @Published public var isRunning: Bool = false
    @Published public var totalPacketsRelayed: Int = 0

    // Callbacks para el motor de cómputo y modelos P2P
    public var onComputeJobTaskReceived: ((ComputeJobTask, String) -> Void)?
    public var onComputeJobResultReceived: ((ComputeJobResult) -> Void)?
    public var onWorkerProfileUpdated: ((ComputeWorkerProfile) -> Void)?
    public var onModelManifestReceived: ((SwarmModelDescriptor) -> Void)?
    public var onModelChunkReceived: ((SwarmModelChunkPacket) -> Void)?

    // Multipeer Connectivity
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    // Caché de deduplicación de paquetes (evita bucles infinitos en la red mesh)
    private var seenPacketIDs = Set<String>()
    private var broadcastTimer: AnyCancellable?

    override public init() {
        // 1. Generar o recuperar un tag único por hardware para que dos iPhones jamás se confundan entre sí
        let tagKey = "parcheradar_node_short_tag"
        let existingTag = UserDefaults.standard.string(forKey: tagKey)
        let resolvedTag: String
        if let existingTag = existingTag, !existingTag.isEmpty {
            resolvedTag = existingTag
        } else {
            let randomHex = String(UUID().uuidString.prefix(4)).uppercased()
            UserDefaults.standard.set(randomHex, forKey: tagKey)
            resolvedTag = randomHex
        }
        self.shortNodeTag = resolvedTag

        // 2. Detectar el modelo real del iPhone (ej. "iPhone 15 Pro Max" vs "iPhone 14 Pro") en lugar del genérico "iPhone"
        let modelFriendly = Self.detectHumanReadableModel()
        let savedName = UserDefaults.standard.string(forKey: "parcheradar_username_v2")
        let initialDisplayName: String
        if let saved = savedName, !saved.isEmpty, saved.lowercased() != "iphone" {
            initialDisplayName = saved
        } else {
            let autoName = "\(modelFriendly) #\(resolvedTag.prefix(2))"
            UserDefaults.standard.set(autoName, forKey: "parcheradar_username_v2")
            initialDisplayName = autoName
        }

        self.myDisplayName = initialDisplayName
        self.myPeerID = MCPeerID(displayName: "\(initialDisplayName) [\(resolvedTag)]")
        super.init()

        setupSession()
        start()
    }

    /// Traduce el identificador de hardware de Apple (ej. iPhone16,2) al nombre comercial real del equipo
    public static func detectHumanReadableModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }

        switch identifier {
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        default:
            if identifier.hasPrefix("iPad") { return "iPad Pro" }
            return "iPhone"
        }
    }

    private func setupSession() {
        let uniquePeerTitle = "\(self.myDisplayName) [\(self.shortNodeTag)]"
        self.myPeerID = MCPeerID(displayName: uniquePeerTitle)
        self.session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .none)
        self.session.delegate = self

        self.advertiser = MCNearbyServiceAdvertiser(
            peer: self.myPeerID,
            discoveryInfo: [
                "displayName": self.myDisplayName,
                "nodeTag": self.shortNodeTag,
                "model": Self.detectHumanReadableModel()
            ],
            serviceType: Self.serviceType
        )
        self.advertiser.delegate = self

        self.browser = MCNearbyServiceBrowser(
            peer: self.myPeerID,
            serviceType: Self.serviceType
        )
        self.browser.delegate = self
    }

    public func start() {
        guard !isRunning else { return }
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        isRunning = true

        // Timer periódico para enviar beacons de presencia y cómputo
        broadcastTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.broadcastPresenceAndComputeProfile()
            }
    }

    public func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        broadcastTimer?.cancel()
        isRunning = false
        connectedPeers.removeAll()
    }

    public func restartSession() {
        stop()
        setupSession()
        start()
    }

    /// Abre directamente la pestaña de Chat en una conversación privada 1 a 1 con el amigo indicado
    public func openDirectChat(with peer: DiscoveredPeer) {
        self.activeDirectPeerID = peer.id
        self.selectedTabIndex = 1
    }

    /// Limpia el sufijo técnico [XXXX] para mostrar solo el nombre limpio del amigo
    public static func cleanName(_ rawPeerName: String) -> String {
        if let bracketRange = rawPeerName.range(of: " [", options: .backwards) {
            return String(rawPeerName[..<bracketRange.lowerBound])
        }
        return rawPeerName
    }

    // MARK: - Envío de Paquetes y Enrutamiento Mesh Multi-Salto

    /// Envía un paquete a través de la red Mesh
    public func sendPacket(_ packet: MeshPacket) {
        seenPacketIDs.insert(packet.id)

        do {
            let data = try JSONEncoder().encode(packet)
            if let target = packet.targetPeerID,
               let directPeer = connectedPeers.first(where: { $0.displayName == target }) {
                // Envío directo si el nodo destino está conectado directamente
                try session.send(data, toPeers: [directPeer], with: .reliable)
            } else {
                // Broadcast a todos los nodos conectados para que hagan de repetidores (Mesh flood)
                if !connectedPeers.isEmpty {
                    try session.send(data, toPeers: connectedPeers, with: .reliable)
                }
            }
        } catch {
            print("[Parche Radar] Error enviando paquete: \(error)")
        }
    }

    /// Re-envía un paquete a los demás pares (función repetidor / Mesh Relay)
    private func relayPacket(_ packet: MeshPacket, incomingFrom: MCPeerID) {
        guard packet.ttl > 0 else { return }

        var relayed = packet
        relayed.ttl -= 1
        relayed.hops += 1

        totalPacketsRelayed += 1

        let destinationPeers = connectedPeers.filter { $0 != incomingFrom }
        guard !destinationPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(relayed)
            try session.send(data, toPeers: destinationPeers, with: .reliable)
        } catch {
            print("[Parche Radar] Error re-enviando paquete: \(error)")
        }
    }

    // MARK: - Funciones de Usuario (Chat Grupal, Mensaje Directo 1 a 1, Ping, Radar)

    /// Envía un mensaje de texto (a un canal grupal o Mensaje Directo 1 a 1 a un amigo específico)
    public func sendChatMessage(
        text: String,
        channel: String = "General",
        recipientPeer: DiscoveredPeer? = nil
    ) {
        let chatMsg = MeshChatMessage(
            senderID: myPeerID.displayName,
            senderName: myDisplayName,
            recipientID: recipientPeer?.id,
            recipientName: recipientPeer?.displayName,
            channel: recipientPeer != nil ? "Directo" : channel,
            text: text,
            hopCount: 0
        )
        self.chatMessages.append(chatMsg)

        if let payload = try? JSONEncoder().encode(chatMsg) {
            let packet = MeshPacket(
                type: .chatMessage,
                originPeerID: myPeerID.displayName,
                originDisplayName: myDisplayName,
                targetPeerID: recipientPeer?.id, // nil = Todos, o el ID del amigo para DM privado
                ttl: 4,
                payload: payload
            )
            sendPacket(packet)
        }
    }

    /// Envía un "Ping" haptic a un amigo para que su iPhone vibre y sepa que estás cerca
    public func sendFriendPing(to targetPeerID: String) {
        let payload = myDisplayName.data(using: .utf8) ?? Data()
        let packet = MeshPacket(
            type: .friendPing,
            originPeerID: myPeerID.displayName,
            originDisplayName: myDisplayName,
            targetPeerID: targetPeerID,
            ttl: 3,
            payload: payload
        )
        sendPacket(packet)
    }

    /// Anuncia el perfil de hardware y RAM asignada a los demás nodos
    public func broadcastPresenceAndComputeProfile() {
        let monitor = DeviceResourceMonitor.shared
        let profile = ComputeWorkerProfile(
            peerID: myPeerID.displayName,
            displayName: myDisplayName,
            deviceModel: monitor.deviceModelName,
            allocatedMemoryMB: monitor.userAllocatedRAM_MB,
            cpuCores: monitor.cpuCoreCount,
            batteryLevel: monitor.batteryLevel,
            isCharging: monitor.isCharging,
            isBusy: false
        )

        if let payload = try? JSONEncoder().encode(profile) {
            let packet = MeshPacket(
                type: .computeOffer,
                originPeerID: myPeerID.displayName,
                originDisplayName: myDisplayName,
                ttl: 2,
                payload: payload
            )
            sendPacket(packet)
        }
    }

    public func broadcastModelManifest(_ manifest: SwarmModelDescriptor) {
        guard let payload = try? JSONEncoder().encode(manifest) else { return }
        let packet = MeshPacket(
            type: .modelManifest,
            originPeerID: myPeerID.displayName,
            originDisplayName: myDisplayName,
            ttl: 4,
            payload: payload
        )
        sendPacket(packet)
    }

    public func requestModelShardFromPeers(modelID: String, shardIndex: Int) {
        let reqDict = ["modelID": modelID, "shardIndex": "\(shardIndex)"]
        guard let payload = try? JSONEncoder().encode(reqDict) else { return }
        let packet = MeshPacket(
            type: .modelChunkRequest,
            originPeerID: myPeerID.displayName,
            originDisplayName: myDisplayName,
            ttl: 3,
            payload: payload
        )
        sendPacket(packet)
    }
}

// MARK: - MCSessionDelegate
extension MeshNetworkEngine: @preconcurrency MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            // Ignorar si por alguna razón es nuestro propio peerID
            guard peerID.displayName != self.myPeerID.displayName else { return }

            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                let simulatedDist = Double.random(in: 3.5...18.0)
                let cleanDisplay = Self.cleanName(peerID.displayName)
                self.nearbyPeers[peerID.displayName] = DiscoveredPeer(
                    peerID: peerID,
                    displayName: cleanDisplay,
                    isDirectlyConnected: true,
                    hopDistance: 1,
                    estimatedDistanceMeters: simulatedDist,
                    lastSeen: Date()
                )
                self.broadcastPresenceAndComputeProfile()

            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                self.nearbyPeers[peerID.displayName]?.isDirectlyConnected = false

            case .connecting:
                break

            @unknown default:
                break
            }
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let packet = try? JSONDecoder().decode(MeshPacket.self, from: data) else { return }

        Task { @MainActor in
            guard !self.seenPacketIDs.contains(packet.id) else { return }
            self.seenPacketIDs.insert(packet.id)

            let isForMe = packet.targetPeerID == nil || packet.targetPeerID == self.myPeerID.displayName
            if packet.targetPeerID != self.myPeerID.displayName {
                self.relayPacket(packet, incomingFrom: peerID)
            }

            if isForMe {
                self.processPacketPayload(packet)
            }
        }
    }

    private func processPacketPayload(_ packet: MeshPacket) {
        switch packet.type {
        case .chatMessage:
            if let msg = try? JSONDecoder().decode(MeshChatMessage.self, from: packet.payload) {
                // Evitar duplicar si yo mismo fui el emisor
                guard msg.senderID != self.myPeerID.displayName else { return }
                // Si es un mensaje directo privado para otra persona, no mostrarlo aquí
                if let recID = msg.recipientID, recID != self.myPeerID.displayName {
                    return
                }
                var updatedMsg = msg
                updatedMsg.hopCount = packet.hops
                self.chatMessages.append(updatedMsg)
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            }

        case .friendPing:
            self.receivedPings.append(packet.originDisplayName)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

        case .computeOffer:
            if let profile = try? JSONDecoder().decode(ComputeWorkerProfile.self, from: packet.payload) {
                guard profile.peerID != self.myPeerID.displayName else { return }
                let cleanDisplay = Self.cleanName(profile.displayName)
                if var existing = self.nearbyPeers[profile.peerID] {
                    existing.displayName = cleanDisplay
                    existing.workerProfile = profile
                    existing.lastSeen = Date()
                    self.nearbyPeers[profile.peerID] = existing
                } else {
                    let newPeer = DiscoveredPeer(
                        peerID: MCPeerID(displayName: profile.peerID),
                        displayName: cleanDisplay,
                        isDirectlyConnected: false,
                        hopDistance: packet.hops + 1,
                        estimatedDistanceMeters: Double(packet.hops + 1) * 15.0,
                        lastSeen: Date(),
                        workerProfile: profile
                    )
                    self.nearbyPeers[profile.peerID] = newPeer
                }
                self.onWorkerProfileUpdated?(profile)
            }

        case .computeJobAssign:
            if let task = try? JSONDecoder().decode(ComputeJobTask.self, from: packet.payload) {
                self.onComputeJobTaskReceived?(task, packet.originPeerID)
            }

        case .computeJobResult:
            if let result = try? JSONDecoder().decode(ComputeJobResult.self, from: packet.payload) {
                self.onComputeJobResultReceived?(result)
            }

        case .modelManifest:
            if let manifest = try? JSONDecoder().decode(SwarmModelDescriptor.self, from: packet.payload) {
                self.onModelManifestReceived?(manifest)
            }

        case .modelChunkRequest:
            break

        case .modelChunkData:
            if let chunk = try? JSONDecoder().decode(SwarmModelChunkPacket.self, from: packet.payload) {
                self.onModelChunkReceived?(chunk)
            }

        case .proximityBeacon:
            break
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MeshNetworkEngine: @preconcurrency MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, self.session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MeshNetworkEngine: @preconcurrency MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard peerID.displayName != self.myPeerID.displayName else { return }
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.connectedPeers.removeAll { $0 == peerID }
            self.nearbyPeers[peerID.displayName]?.isDirectlyConnected = false
        }
    }
}
