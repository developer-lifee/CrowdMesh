import SwiftUI

@main
struct CrowdMeshApp: App {
    init() {
        // Inicializar motores de red y monitoreo
        _ = MeshNetworkEngine.shared
        _ = DeviceResourceMonitor.shared
        _ = DistributedComputeEngine.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}

