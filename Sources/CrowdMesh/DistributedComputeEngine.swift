import Foundation
import UIKit
import Combine
import CoreGraphics

/// Estado de un trabajo de cómputo distribuido
public enum ComputeJobState: Equatable {
    case idle
    case partitioning
    case running(progress: Float, completedTiles: Int, totalTiles: Int)
    case completed(totalTimeSeconds: Double, totalGigaFlops: Double)
    case error(String)
}

/// Representación visual de un fragmento de tarea (Tile)
public struct ComputeTileSlot: Identifiable {
    public let id: Int
    public var status: TileStatus = .pending
    public var workerName: String = "En espera"
    public var executionTimeMs: Double = 0
    public var renderedImage: UIImage?

    public enum TileStatus {
        case pending
        case assigned
        case computing
        case completed
    }
}

/// Motor de Cómputo Distribuido P2P (Grid Computing)
@MainActor
public final class DistributedComputeEngine: ObservableObject {
    public static let shared = DistributedComputeEngine()

    @Published public var jobState: ComputeJobState = .idle
    @Published public var activeWorkers: [String: ComputeWorkerProfile] = [:]
    @Published public var tileSlots: [ComputeTileSlot] = []
    @Published public var assembledFinalImage: UIImage?
    @Published public var totalClusterRAM_MB: Int = 0
    @Published public var totalClusterCores: Int = 0
    @Published public var simulationSwarmEnabled: Bool = true // Permite probar con nodos virtuales si estás solo

    private let network = MeshNetworkEngine.shared
    private let monitor = DeviceResourceMonitor.shared
    private var jobStartTime: Date?
    private var currentJobID: String = ""

    public init() {
        setupBindings()
    }

    private func setupBindings() {
        // Cuando recibimos oferta de recursos de otro iPhone
        network.onWorkerProfileUpdated = { [weak self] profile in
            self?.registerWorker(profile)
        }

        // Cuando como trabajador recibimos una tarea asignada por un coordinador
        network.onComputeJobTaskReceived = { [weak self] task, coordinatorID in
            self?.executeWorkerTask(task, coordinatorID: coordinatorID)
        }

        // Cuando como coordinador recibimos el resultado de un nodo
        network.onComputeJobResultReceived = { [weak self] result in
            self?.processTaskResult(result)
        }

        // Registrar nodo local
        updateClusterMetrics()
    }

    public func registerWorker(_ profile: ComputeWorkerProfile) {
        activeWorkers[profile.peerID] = profile
        updateClusterMetrics()
    }

    public func updateClusterMetrics() {
        var totalRAM = monitor.userAllocatedRAM_MB
        var totalCores = monitor.cpuCoreCount

        for worker in activeWorkers.values {
            totalRAM += worker.allocatedMemoryMB
            totalCores += worker.cpuCores
        }

        if simulationSwarmEnabled {
            // Añade 3 nodos de demostración simulando amigos en el concierto
            totalRAM += 1536 // + 1.5 GB
            totalCores += 18  // + 18 Cores A17/A18 Pro
        }

        self.totalClusterRAM_MB = totalRAM
        self.totalClusterCores = totalCores
    }

    // MARK: - Ejecución como Coordinador (Master)

    /// Inicia un trabajo de cómputo distribuido (ej: Renderizado Ray Tracing / IA)
    public func startDistributedJob(tilesCount: Int = 16) {
        guard jobState == .idle || true else { return }

        self.currentJobID = UUID().uuidString
        self.jobStartTime = Date()
        self.jobState = .partitioning
        self.assembledFinalImage = nil

        // Preparar las ranuras de trabajo (Tiles)
        self.tileSlots = (0..<tilesCount).map { i in
            ComputeTileSlot(id: i, status: .pending, workerName: "En espera")
        }

        self.jobState = .running(progress: 0.05, completedTiles: 0, totalTiles: tilesCount)

        // Lista de trabajadores disponibles
        var workersList = Array(activeWorkers.values)

        // Si tenemos modo enjambre simulado o estamos solos, añadimos nodos virtuales
        if simulationSwarmEnabled || workersList.isEmpty {
            workersList.append(ComputeWorkerProfile(peerID: "node_amigo_1", displayName: "iPhone 16 Pro (Camilo)", deviceModel: "iPhone17,1", allocatedMemoryMB: 512, cpuCores: 6, batteryLevel: 0.85, isCharging: false))
            workersList.append(ComputeWorkerProfile(peerID: "node_amigo_2", displayName: "iPhone 15 (Laura)", deviceModel: "iPhone15,4", allocatedMemoryMB: 512, cpuCores: 6, batteryLevel: 0.62, isCharging: true))
            workersList.append(ComputeWorkerProfile(peerID: "node_local", displayName: "Este iPhone (\(network.myDisplayName))", deviceModel: monitor.deviceModelName, allocatedMemoryMB: monitor.userAllocatedRAM_MB, cpuCores: monitor.cpuCoreCount, batteryLevel: monitor.batteryLevel, isCharging: monitor.isCharging))
        }

        // Asignar tareas a cada nodo
        for i in 0..<tilesCount {
            let assignedWorker = workersList[i % workersList.count]
            self.tileSlots[i].workerName = assignedWorker.displayName
            self.tileSlots[i].status = .assigned

            let task = ComputeJobTask(
                jobID: self.currentJobID,
                tileIndex: i,
                totalTiles: tilesCount,
                width: 128,
                height: 128,
                seed: UInt32(i * 1337 + 42),
                complexityIterations: 200
            )

            if assignedWorker.peerID.starts(with: "node_amigo") || assignedWorker.peerID == "node_local" {
                // Tarea local o simulada: ejecutar en segundo plano en hilo concurrente
                Task.detached(priority: .userInitiated) {
                    let result = self.computeTileKernel(task: task, workerID: assignedWorker.peerID)
                    await self.processTaskResult(result)
                }
            } else {
                // Tarea enviada a través de la red Mesh P2P a un iPhone real
                if let payload = try? JSONEncoder().encode(task) {
                    let packet = MeshPacket(
                        type: .computeJobAssign,
                        originPeerID: network.myPeerID.displayName,
                        originDisplayName: network.myDisplayName,
                        targetPeerID: assignedWorker.peerID,
                        ttl: 3,
                        payload: payload
                    )
                    network.sendPacket(packet)
                }
            }
        }
    }

    /// Procesa el resultado que devuelve un nodo worker
    public func processTaskResult(_ result: ComputeJobResult) {
        guard result.jobID == self.currentJobID else { return }
        guard result.tileIndex < tileSlots.count else { return }

        // Convertir datos crudos en imagen pequeña del tile
        let tileImage = generateImageFromRawData(result.rawData, width: 128, height: 128)

        self.tileSlots[result.tileIndex].status = .completed
        self.tileSlots[result.tileIndex].executionTimeMs = result.executionTimeMs
        self.tileSlots[result.tileIndex].renderedImage = tileImage

        let completedCount = tileSlots.filter { $0.status == .completed }.count
        let total = tileSlots.count
        let progress = Float(completedCount) / Float(total)

        if completedCount >= total {
            let totalTime = Date().timeIntervalSince(jobStartTime ?? Date())
            // Estimación de GigaFLOPS del cluster = (operaciones por pixel * pixeles * tiles) / tiempo / 1e9
            let totalOps = Double(total) * 128.0 * 128.0 * 200.0 * 35.0
            let gigaFlops = (totalOps / max(0.01, totalTime)) / 1_000_000_000.0

            self.assembledFinalImage = assembleFullImage(from: tileSlots, gridColumns: 4)
            self.jobState = .completed(totalTimeSeconds: totalTime, totalGigaFlops: gigaFlops)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            self.jobState = .running(progress: progress, completedTiles: completedCount, totalTiles: total)
        }
    }

    // MARK: - Ejecución como Nodo Trabajador (Worker)

    /// Ejecuta una micro-tarea respetando la RAM y condiciones asignadas por el usuario
    public func executeWorkerTask(_ task: ComputeJobTask, coordinatorID: String) {
        guard monitor.isEligibleForCompute else {
            print("[CrowdMesh Compute] Nodo no elegible (batería baja o no cargando)")
            return
        }

        Task.detached(priority: .background) {
            let result = self.computeTileKernel(task: task, workerID: await self.network.myPeerID.displayName)

            // Devolver resultado al coordinador a través del Mesh
            if let payload = try? JSONEncoder().encode(result) {
                let packet = await MeshPacket(
                    type: .computeJobResult,
                    originPeerID: self.network.myPeerID.displayName,
                    originDisplayName: self.network.myDisplayName,
                    targetPeerID: coordinatorID,
                    ttl: 3,
                    payload: payload
                )
                await self.network.sendPacket(packet)
            }
        }
    }

    // MARK: - Kernel de Cálculo Matemático / Renderizado

    /// Kernel que simula una carga de trabajo pesada de IA / Ray Tracing fractal
    private nonisolated func computeTileKernel(task: ComputeJobTask, workerID: String) -> ComputeJobResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let width = task.width
        let height = task.height
        var pixelBytes = [UInt8](repeating: 0, count: width * height * 4)

        // Simulación de fractal de Julia / Ray Marching con límite de memoria
        let cRe = -0.7 + Double(task.seed % 100) * 0.002
        let cIm = 0.27015 + Double((task.seed / 100) % 100) * 0.002

        for y in 0..<height {
            for x in 0..<width {
                var zx = 1.5 * Double(x - width / 2) / (0.5 * Double(width))
                var zy = 1.0 * Double(y - height / 2) / (0.5 * Double(height))
                var i = task.complexityIterations

                while zx * zx + zy * zy < 4.0 && i > 0 {
                    let tmp = zx * zx - zy * zy + cRe
                    zy = 2.0 * zx * zy + cIm
                    zx = tmp
                    i -= 1
                }

                let offset = (y * width + x) * 4
                let intensity = UInt8(min(255, (task.complexityIterations - i) * 255 / task.complexityIterations))
                let r = UInt8((Int(intensity) * 200 + Int(task.seed % 50)) % 255)
                let g = UInt8((Int(intensity) * 120 + Int(task.tileIndex * 15)) % 255)
                let b = UInt8((Int(intensity) * 255) % 255)

                pixelBytes[offset] = r
                pixelBytes[offset + 1] = g
                pixelBytes[offset + 2] = b
                pixelBytes[offset + 3] = 255
            }
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        return ComputeJobResult(
            jobID: task.jobID,
            taskID: task.id,
            tileIndex: task.tileIndex,
            workerPeerID: workerID,
            executionTimeMs: elapsed,
            rawData: Data(pixelBytes)
        )
    }

    // MARK: - Ensamble de Imágenes

    private func generateImageFromRawData(_ data: Data, width: Int, height: Int) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private func assembleFullImage(from tiles: [ComputeTileSlot], gridColumns: Int) -> UIImage? {
        let tileSize = 128
        let rows = (tiles.count + gridColumns - 1) / gridColumns
        let fullWidth = gridColumns * tileSize
        let fullHeight = rows * tileSize

        let size = CGSize(width: fullWidth, height: fullHeight)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)

        for (index, tile) in tiles.enumerated() {
            guard let img = tile.renderedImage else { continue }
            let col = index % gridColumns
            let row = index / gridColumns
            let rect = CGRect(x: col * tileSize, y: row * tileSize, width: tileSize, height: tileSize)
            img.draw(in: rect)
        }

        let assembled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return assembled
    }
}
