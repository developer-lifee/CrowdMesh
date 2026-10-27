import SwiftUI

/// Interfaz principal con pestañas para Parche Radar (CrowdMesh)
struct MainTabView: View {
    @ObservedObject var network = MeshNetworkEngine.shared

    var body: some View {
        TabView(selection: $network.selectedTabIndex) {
            RadarView()
                .tabItem {
                    Label("Radar", systemImage: "radar")
                }
                .tag(0)

            MeshChatView()
                .tabItem {
                    Label("Mensajes", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)

            ComputeGridView()
                .tabItem {
                    Label("Cómputo P2P", systemImage: "cpu.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.cyan)
    }
}
