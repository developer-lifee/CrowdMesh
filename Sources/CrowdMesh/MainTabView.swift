import SwiftUI

/// Interfaz principal con pestañas para CrowdMesh
struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RadarView()
                .tabItem {
                    Label("Radar", systemImage: "radar")
                }
                .tag(0)

            MeshChatView()
                .tabItem {
                    Label("Chat Mesh", systemImage: "bubble.left.and.bubble.right.fill")
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
