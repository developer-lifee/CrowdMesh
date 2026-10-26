import SwiftUI

/// Vista de Ajustes del Nodo Mesh
struct SettingsView: View {
    @ObservedObject var network = MeshNetworkEngine.shared
    @ObservedObject var monitor = DeviceResourceMonitor.shared
    @State private var tempName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identidad en la Malla") {
                    HStack {
                        Text("Nombre visible:")
                        Spacer()
                        TextField("Tu apodo o nombre", text: $tempName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.cyan)
                            .onSubmit {
                                if !tempName.isEmpty {
                                    network.myDisplayName = tempName
                                }
                            }
                    }

                    HStack {
                        Text("ID de Nodo:")
                        Spacer()
                        Text(network.myPeerID.displayName.prefix(12) + "...")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Estado de Radios P2P") {
                    Toggle("Radios Mesh Activas", isOn: Binding(
                        get: { network.isRunning },
                        set: { if $0 { network.start() } else { network.stop() } }
                    ))
                    .tint(.cyan)

                    HStack {
                        Text("Tipo de Red:")
                        Spacer()
                        Text("Apple Multipeer (BLE + Wi-Fi Direct)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Paquetes Reenviados (Mesh Relay):")
                        Spacer()
                        Text("\(network.totalPacketsRelayed)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                }

                Section("Hardware del Dispositivo") {
                    HStack {
                        Text("Modelo:")
                        Spacer()
                        Text(monitor.deviceModelName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Núcleos CPU:")
                        Spacer()
                        Text("\(monitor.cpuCoreCount)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Memoria Total:")
                        Spacer()
                        Text("\(monitor.totalSystemRAM_MB) MB")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Privacidad & Modo Concierto") {
                    Text("CrowdMesh no requiere conexión a internet, datos móviles ni servidores centrales. Toda la información viaja encriptada y cifrada directamente de antena a antena entre dispositivos cercanos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes del Nodo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                tempName = network.myDisplayName
            }
        }
    }
}
