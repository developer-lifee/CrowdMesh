import SwiftUI
import UniformTypeIdentifiers

/// Vista de Cómputo Distribuido P2P: Modelos IA Reales (BitTorrent P2P + Pipeline Sharding)
struct ComputeGridView: View {
    @ObservedObject var compute = DistributedComputeEngine.shared
    @ObservedObject var monitor = DeviceResourceMonitor.shared
    @ObservedObject var swarm = ModelSwarmManager.shared

    @State private var showingFileImporter = false
    @State private var showingPCUrlInput = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.08)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // 1. Asignación de RAM de tu celular
                        resourceAllocationCard

                        // 2. Red P2P de Modelos (Subir desde PC/Archivos o Alimentarse de la Malla)
                        modelSwarmCatalogSection

                        // 3. Planificador y Ejecutor de Clúster Heterogéneo (iPhones + Xiaomis)
                        heterogeneousClusterSection

                        // 4. Rejilla de Bloques / Shards Procesados en Vivo
                        activeComputeGridSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Enjambre IA & Video")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.data, .item, .movie, .archive],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let firstURL = urls.first {
                    swarm.importModelFileFromDevice(url: firstURL)
                }
            }
        }
    }

    // MARK: - 1. Asignación de Recursos Locales (RAM Slider & Filtros)

    private var resourceAllocationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .foregroundStyle(.cyan)
                    .font(.title3)
                Text("RAM que tu Celular Cede al Enjambre")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(monitor.userAllocatedRAM_MB) MB")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.cyan)
            }

            Slider(
                value: Binding(
                    get: { Double(monitor.userAllocatedRAM_MB) },
                    set: {
                        monitor.userAllocatedRAM_MB = Int($0)
                        swarm.ramPerDeviceMB = Int($0)
                    }
                ),
                in: 256...2048,
                step: 128
            )
            .tint(.cyan)

            HStack {
                Text("256 MB (1 Shard ligero)")
                Spacer()
                Text("1024 MB (Estándar)")
                Spacer()
                Text("2048 MB (Máx)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Toggle(isOn: $monitor.onlyComputeWhileCharging) {
                Text("Procesar solo si está cargando / con batería > 25%")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .tint(.green)
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 2. Catálogo P2P de Modelos (Compartir de tu PC o Descargar de la Red)

    private var modelSwarmCatalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modelos en la Malla P2P (BitTorrent + Shards)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Si un nodo tiene el modelo o lo sube desde su PC, toda la red se alimenta de él por fragmentos")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Botones para Subir Modelo desde el iPhone o Jalar desde la PC
            HStack(spacing: 10) {
                Button {
                    showingFileImporter = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill.badge.plus")
                        Text("Subir Modelo a la Red")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.6), lineWidth: 1))
                    .foregroundStyle(.white)
                }

                Button {
                    withAnimation {
                        showingPCUrlInput.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "laptopcomputer.and.iphone")
                        Text("Jalar de mi PC (LAN)")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.6), lineWidth: 1))
                    .foregroundStyle(.white)
                }
            }

            if showingPCUrlInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL del modelo en tu PC (ej. Deliberate .safetensors o .gguf):")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("http://192.168.1.10:8000/models/deliberate.safetensors", text: $swarm.pcServerURL)
                            .font(.caption.monospaced())
                            .padding(8)
                            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)

                        Button {
                            Task {
                                await swarm.pullModelFromPCServer()
                            }
                        } label: {
                            if swarm.isDownloadingFromPC {
                                ProgressView().tint(.black)
                            } else {
                                Text("Sincronizar")
                                    .font(.caption.bold())
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }

            // Lista de Modelos Disponibles en la Malla P2P
            ForEach(swarm.availableModels) { model in
                let isSelected = (swarm.selectedModel?.id == model.id)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .cyan : .secondary)
                                Text(model.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }

                            Text("\(model.workloadType.rawValue) • \(model.totalSizeMB) MB (\(model.totalShards) shards de \(model.shardSizeMB) MB)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("Origen: \(model.originPeerName) • 🌱 \(model.seederCount) semillas P2P")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        if model.isAvailableLocally {
                            Text("EN TU RAM")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.green, in: Capsule())
                        } else {
                            Button {
                                swarm.selectedModelID = model.id
                                swarm.downloadModelOrShardFromPeers(modelID: model.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Bajar Shard P2P")
                                }
                                .font(.caption2.bold())
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan, in: Capsule())
                            }
                        }
                    }

                    if model.downloadProgress > 0 && model.downloadProgress < 1.0 {
                        ProgressView(value: model.downloadProgress)
                            .tint(.cyan)
                    }
                }
                .padding(12)
                .background(
                    isSelected ? Color.cyan.opacity(0.14) : Color.black.opacity(0.35),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
                )
                .onTapGesture {
                    swarm.selectedModelID = model.id
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - 3. Planificador de Clúster Heterogéneo (iPhones 15 Pro Max + Xiaomis Genéricos)

    private var heterogeneousClusterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(.yellow)
                Text("Clúster Heterogéneo (iOS + Android)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }

            // Controles de cantidad de nodos en el enjambre
            VStack(spacing: 10) {
                HStack {
                    Text("📱 iPhone 15/16 Pro Max (35 TOPS):")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    Stepper("\(swarm.highEndiPhoneCount) equipos", value: $swarm.highEndiPhoneCount, in: 1...50)
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }

                HStack {
                    Text("🤖 Xiaomi / Android Genérico (3.2 TOPS):")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    Stepper("\(swarm.genericAndroidCount) equipos", value: $swarm.genericAndroidCount, in: 0...50)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            if let model = swarm.selectedModel {
                let proj = swarm.calculateClusterProjection(for: model)

                // Métricas comparativas reales
                HStack(spacing: 8) {
                    statBox(
                        title: "RAM Total Pool",
                        value: String(format: "%.1f GB", proj.totalRAM_GB),
                        sub: "\(swarm.highEndiPhoneCount + swarm.genericAndroidCount) nodos × \(swarm.ramPerDeviceMB)MB",
                        color: .cyan
                    )
                    statBox(
                        title: "Potencia IA",
                        value: String(format: "%.0f TOPS", proj.totalTOPS),
                        sub: "NPU + Metal + Vulkan",
                        color: .purple
                    )
                    statBox(
                        title: "Tiempo Clúster",
                        value: String(format: "%.2f s", proj.mixedClusterTimeSeconds),
                        sub: "1 solo: \(String(format: "%.1fs", proj.singleDeviceTimeSeconds))",
                        color: .green
                    )
                }

                // Explicación técnica del balanceador ponderado
                Text(proj.explanation)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(10)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                // Botón de Ejecución Real en el Enjambre
                Button {
                    swarm.executeSwarmWorkload()
                } label: {
                    HStack {
                        if swarm.isExecutingSwarm {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                        }
                        Text(swarm.isExecutingSwarm ? "EJECUTANDO EN EL ENJAMBRE..." : "CORRER '\(model.name.prefix(22).uppercased())' EN EL ENJAMBRE")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(.black)
                }
                .disabled(swarm.isExecutingSwarm)
            }

            // Consola de telemetría del enjambre
            if !swarm.swarmExecutionLogs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(swarm.swarmExecutionLogs, id: \.self) { logLine in
                        Text(logLine)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
        )
    }

    private func statBox(title: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(color)
            Text(sub)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 4. Rejilla de Shards / Bloques Procesados en Vivo

    private var activeComputeGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estado de los Shards / Bloques en el Clúster (16 Particiones)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(compute.tileSlots) { tile in
                    ZStack {
                        if let img = tile.renderedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.white.opacity(tile.status == .computing ? 0.2 : 0.05)
                        }

                        VStack(spacing: 2) {
                            Text("Shard #\(tile.id + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)

                            if tile.status == .computing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.cyan)
                            } else if tile.status == .completed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .frame(height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(tile.status == .completed ? Color.green : Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }
}
