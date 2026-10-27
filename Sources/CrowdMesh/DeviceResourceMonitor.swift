import Foundation
import UIKit
import Combine

/// Monitor en tiempo real de recursos de hardware y batería del iPhone
@MainActor
public final class DeviceResourceMonitor: ObservableObject {
    public static let shared = DeviceResourceMonitor()

    // Límites de recursos definidos por el usuario
    @Published public var userAllocatedRAM_MB: Int = 512
    @Published public var onlyComputeWhileCharging: Bool = false
    @Published public var minBatteryThreshold: Float = 0.25 // Pausar si baja del 25%

    // Métricas en tiempo real
    @Published public var currentUsedRAM_MB: Int = 0
    @Published public var availableSystemRAM_MB: Int = 0
    @Published public var totalSystemRAM_MB: Int = 0
    @Published public var batteryLevel: Float = 1.0
    @Published public var isCharging: Bool = false
    @Published public var thermalStateDescription: String = "Normal"
    @Published public var isEligibleForCompute: Bool = true

    private var timer: AnyCancellable?

    public init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateMetrics()
        startMonitoring()
    }

    public func startMonitoring() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
    }

    public func updateMetrics() {
        // 1. Memoria total del sistema
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        self.totalSystemRAM_MB = Int(totalBytes / (1024 * 1024))

        // 2. Memoria en uso de la app actual (Mach task basic info)
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            self.currentUsedRAM_MB = Int(taskInfo.resident_size / (1024 * 1024))
        }

        // Estimación de memoria libre disponible
        if #available(iOS 13.0, *) {
            let availableBytes = os_proc_available_memory()
            self.availableSystemRAM_MB = Int(availableBytes / (1024 * 1024))
        } else {
            self.availableSystemRAM_MB = max(0, totalSystemRAM_MB - currentUsedRAM_MB)
        }

        // 3. Estado de la batería
        let rawBat = UIDevice.current.batteryLevel
        self.batteryLevel = rawBat >= 0 ? rawBat : 1.0
        let batState = UIDevice.current.batteryState
        self.isCharging = (batState == .charging || batState == .full)

        // 4. Estado térmico del chip
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            self.thermalStateDescription = "Óptimo ❄️"
        case .fair:
            self.thermalStateDescription = "Templado 🌤️"
        case .serious:
            self.thermalStateDescription = "Caliente 🔥"
        case .critical:
            self.thermalStateDescription = "Crítico ⚠️"
        @unknown default:
            self.thermalStateDescription = "Desconocido"
        }

        // 5. Verificación de elegibilidad para cómputo P2P
        evaluateEligibility()
    }

    private func evaluateEligibility() {
        if onlyComputeWhileCharging && !isCharging {
            isEligibleForCompute = false
            return
        }

        if batteryLevel < minBatteryThreshold && !isCharging {
            isEligibleForCompute = false
            return
        }

        if ProcessInfo.processInfo.thermalState == .critical {
            isEligibleForCompute = false
            return
        }

        isEligibleForCompute = true
    }

    /// Modelo de iPhone amigable
    public var deviceModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "iPhone" : identifier
    }

    public var cpuCoreCount: Int {
        ProcessInfo.processInfo.activeProcessorCount
    }
}

