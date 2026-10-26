import Foundation
import MultipeerConnectivity
import UIKit
import Combine

/// Información de un peer / amigo cercano en la red
public struct DiscoveredPeer: Identifiable {
    public var id: String { peerID.displayName }
    public let peerID: MCPeerID
    public var displayName: String
    public var isDirectlyConnected: Bool
    public var hopDistance: Int             // 1 = directo, 2+ = a través de otro nodo
    public var estimatedDistanceMeters: Double
    public var lastSeen: Date
    public var workerProfile: ComputeWorkerProfile?

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

    public static let serviceType = "crowd-mesh"

    // Identidad del nodo local
    @Published public var myPeerID: MCPeerID
    @Published public var myDisplayName: String {
        didSet {
            UserDefaults.standard.set(myDisplayName, forKey: "crowdmesh_username")
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

    // Callbacks para el motor de cómputo
    public var onComputeJobTaskReceived: ((ComputeJobTask, String) -> Void)?
    public var onComputeJobResultReceived: ((ComputeJobResult) -> Void)?
    public var onWorkerProfileUpdated: ((ComputeWorkerProfile) -> Void)?

    // Multipeer Connectivity
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    // Caché de deduplicación de paquetes (evita bucles infinitos en la red mesh)
    private var seenPacketIDs = Set<String>()
    private var broadcastTimer: AnyCancellable?

    override public init() {
        let savedName = UserDefaults.standard.string(forKey: "crowdmesh_username") ?? UIDevice.current.name
        self.myDisplayName = savedName
        self.myPeerID = MCPeerID(displayName: savedName)
        super.init()

        setupSession()
        start()
    }

    private func setupSession() {
        self.myPeerID = MCPeerID(displayName: self.myDisplayName)
        self.session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .none)
        self.session.delegate = self

        self.advertiser = MCNearbyServiceAdvertiser(
            peer: self.myPeerID,
            discoveryInfo: ["model": UIDevice.current.model],
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

    // MARK: - Envío de Paquetes y Enrutamiento Mesh Multi-Salto

    /// Envía un paquete a través de la red Mesh
    public func sendPacket(_ packet: MeshPacket) {
        // Registrar en caché local para no reenviar si nos regresa
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
            print("[CrowdMesh] Error enviando paquete: \(error)")
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
            try session.send(data, toPeers: destinationPeers, with: .unreliable)
        } catch {
            print("[CrowdMesh] Error re-enviando paquete: \(error)")
        }
    }

    // MARK: - Funciones de Usuario (Chat, Ping, Radar)

    /// Envía un mensaje de texto al chat offline
    public func sendChatMessage(text: String, channel: String = "General") {
        let chatMsg = MeshChatMessage(
            senderID: myPeerID.displayName,
            senderName: myDisplayName,
            channel: channel,
            text: text,
            hopCount: 0
        )
        self.chatMessages.append(chatMsg)

        if let payload = try? JSONEncoder().encode(chatMsg) {
            let packet = MeshPacket(
                type: .chatMessage,
                originPeerID: myPeerID.displayName,
                originDisplayName: myDisplayName,
                ttl: 4,
                payload: payload
            )
            sendPacket(packet)
        }
    }

    /// Envía un "Ping" haptic a un amigo para que su iPhone vibre y sepa que estás cerca
    public func sendFriendPing(to peerDisplayName: String) {
        let payload = peerDisplayName.data(using: .utf8) ?? Data()
        let packet = MeshPacket(
            type: .friendPing,
            originPeerID: myPeerID.displayName,
            originDisplayName: myDisplayName,
            targetPeerID: peerDisplayName,
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
}

// MARK: - MCSessionDelegate
extension MeshNetworkEngine: @preconcurrency MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                // Actualizar radar
                let simulatedDist = Double.random(in: 4.0...25.0)
                self.nearbyPeers[peerID.displayName] = DiscoveredPeer(
                    peerID: peerID,
                    displayName: peerID.displayName,
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
            // Deduplicación: si ya vimos este ID de paquete, ignorarlo
            guard !self.seenPacketIDs.contains(packet.id) else { return }
            self.seenPacketIDs.insert(packet.id)

            // Si el paquete no es solo para mí o es broadcast, ayudar a retransmitirlo (Mesh Relay)
            let isForMe = packet.targetPeerID == nil || packet.targetPeerID == self.myPeerID.displayName
            if packet.targetPeerID != self.myPeerID.displayName {
                self.relayPacket(packet, incomingFrom: peerID)
            }

            // Procesar si me concierne
            if isForMe {
                self.processPacketPayload(packet)
            }
        }
    }

    private func processPacketPayload(_ packet: MeshPacket) {
        switch packet.type {
        case .chatMessage:
            if let msg = try? JSONDecoder().decode(MeshChatMessage.self, from: packet.payload) {
                var updatedMsg = msg
                updatedMsg.hopCount = packet.hops
                self.chatMessages.append(updatedMsg)
                // Vibración sutil
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            }

        case .friendPing:
            self.receivedPings.append(packet.originDisplayName)
            // Vibración háptica fuerte tipo sonar para encontrar amigos en concierto ruidoso
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

        case .computeOffer:
            if let profile = try? JSONDecoder().decode(ComputeWorkerProfile.self, from: packet.payload) {
                if var existing = self.nearbyPeers[profile.peerID] {
                    existing.workerProfile = profile
                    existing.lastSeen = Date()
                    self.nearbyPeers[profile.peerID] = existing
                } else {
                    let newPeer = DiscoveredPeer(
                        peerID: MCPeerID(displayName: profile.peerID),
                        displayName: profile.displayName,
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
        // En una red mesh de conciertos libre, aceptamos automáticamente conexiones de pares cercanos
        invitationHandler(true, self.session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MeshNetworkEngine: @preconcurrency MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Invitar al nuevo par para formar la malla
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.connectedPeers.removeAll { $0 == peerID }
            self.nearbyPeers[peerID.displayName]?.isDirectlyConnected = false
        }
    }
}
