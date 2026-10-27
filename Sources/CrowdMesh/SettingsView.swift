import SwiftUI

/// Vista de Ajustes del Nodo Mesh
struct SettingsView: View {
    @ObservedObject var network = MeshNetworkEngine.shared
    @ObservedObject var monitor = DeviceResourceMonitor.shared
    @State private var tempName: String = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Identidad de tu Celular en la Malla") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nombre con el que te ven tus amigos:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("Ej: Esteban, Goku, Dani...", text: $tempName)
                                .focused($isNameFocused)
                                .submitLabel(.done)
                                .foregroundStyle(.cyan)
                                .font(.body.bold())
                                .onSubmit {
                                    saveName()
                                }

                            if !tempName.isEmpty && tempName != network.myDisplayName {
                                Button("Guardar") {
                                    saveName()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .font(.caption.bold())
                            }
                        }
                    }

                    HStack {
                        Text("Código Único de Antena:")
                        Spacer()
                        Text("#\(network.shortNodeTag)")
                            .font(.subheadline.monospaced().bold())
                            .foregroundStyle(.yellow)
                    }
                }

                Section("Estado de Radios P2P") {
                    Toggle("Radios Mesh Activas", isOn: Binding(
                        get: { network.isRunning },
                        set: { if $0 { network.start() } else { network.stop() } }
                    ))
                    .tint(.cyan)

                    HStack {
                        Text("Amigos conectados ahora:")
                        Spacer()
                        Text("\(network.connectedPeers.count)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
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
                        Text("Modelo Real:")
                        Spacer()
                        Text(MeshNetworkEngine.detectHumanReadableModel())
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
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Ajustes del Nodo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        isNameFocused = false
                        dismissKeyboardGlobally()
                    } label: {
                        Label("Ocultar Teclado", systemImage: "keyboard.chevron.compact.down")
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                    Button("Guardar Nombre") {
                        saveName()
                    }
                    .bold()
                    .foregroundStyle(.cyan)
                }
            }
            .onAppear {
                tempName = network.myDisplayName
            }
        }
    }

    private func saveName() {
        let trimmed = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            network.myDisplayName = trimmed
        }
        isNameFocused = false
        dismissKeyboardGlobally()
    }
}
