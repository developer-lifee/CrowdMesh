import SwiftUI

/// Vista de Cómputo Distribuido P2P (Grid Computing con control de RAM)
struct ComputeGridView: View {
    @ObservedObject var compute = DistributedComputeEngine.shared
    @ObservedObject var monitor = DeviceResourceMonitor.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.08)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Panel de Asignación de Recursos Locales
                        resourceAllocationCard

                        // 2. Telemetría del Cluster P2P
                        clusterOverviewCard

                        // 3. Demostración en Vivo: Renderizado / Inferencia Distribuida
                        distributedJobDemoSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Cómputo Distribuido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle("Demo Virtual", isOn: $compute.simulationSwarmEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: compute.simulationSwarmEnabled) { _ in
                            compute.updateClusterMetrics()
                        }
                }
            }
        }
    }

    // MARK: - 1. Asignación de Recursos Locales (RAM Slider & Filtros)

    private var resourceAllocationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.cyan)
                    .font(.title3)
                Text("Asignación de Recursos de tu Celular")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("RAM cedida al enjambre:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(monitor.userAllocatedRAM_MB) MB")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(.cyan)
                }

                Slider(
                    value: Binding(
                        get: { Double(monitor.userAllocatedRAM_MB) },
                        set: { monitor.userAllocatedRAM_MB = Int($0) }
                    ),
                    in: 128...2048,
                    step: 128
                )
                .tint(.cyan)

                HStack {
                    Text("128 MB (Mínimo)")
                    Spacer()
                    Text("2048 MB (Alto)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Divider().background(Color.white.opacity(0.1))

            // Interruptores de seguridad de batería
            Toggle(isOn: $monitor.onlyComputeWhileCharging) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Solo con el iPhone cargando")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text("Protege tu batería en el concierto si no tienes cargador portátil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.green)

            // Estado de salud del hardware
            HStack(spacing: 12) {
                metricPill(title: "Batería", value: "\(Int(monitor.batteryLevel * 100))%", icon: "battery.75")
                metricPill(title: "Térmico", value: monitor.thermalStateDescription, icon: "thermometer.medium")
                metricPill(title: "RAM Libre", value: "\(monitor.availableSystemRAM_MB) MB", icon: "memorychip")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func metricPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 2. Telemetría del Cluster P2P

    private var clusterOverviewCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("POTENCIA COMBINADA DEL CLUSTER")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.purple)

                Text("\(Double(compute.totalClusterRAM_MB) / 1024.0, specifier: "%.1f") GB RAM")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Aportada por \(compute.activeWorkers.count + (compute.simulationSwarmEnabled ? 3 : 1)) teléfonos cercanos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("NÚCLEOS DE CPU")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.purple)

                Text("\(compute.totalClusterCores)")
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(.purple)

                Text("Apple Silicon")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 3. Demostración en Vivo: Renderizado / IA Distribuida

    private var distributedJobDemoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demostración de Cómputo Distribuido")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Divide el trabajo en 16 bloques y lo reparte entre los iPhones del cluster")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Botón de Inicio
            Button {
                compute.startDistributedJob(tilesCount: 16)
            } label: {
                HStack {
                    Image(systemName: "cpu.fill")
                    Text("LANZAR TRABAJO DISTRIBUIDO (16 TILES)")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
            }

            // Rejilla de Tiles 4x4
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(compute.tileSlots) { tile in
                    tileView(for: tile)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

            // Resultado ensamblado
            if let assembled = compute.assembledFinalImage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Imagen Final Ensamblada en el Cluster:")
                        .font(.caption.bold())
                        .foregroundStyle(.green)

                    Image(uiImage: assembled)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                        )
                }
            }

            // Estadísticas de ejecución
            switch compute.jobState {
            case .running(let progress, let completed, let total):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(.cyan)
                    Text("Procesando en paralelo... \(completed)/\(total) bloques listos")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }

            case .completed(let time, let gflops):
                HStack {
                    Label("\(time, specifier: "%.2f")s tiempo total", systemImage: "clock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Spacer()
                    Label("\(gflops, specifier: "%.2f") GFLOPS combinados", systemImage: "bolt.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            default:
                EmptyView()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func tileView(for tile: ComputeTileSlot) -> some View {
        ZStack {
            if let img = tile.renderedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(tile.status == .computing ? 0.2 : 0.05)
            }

            VStack(spacing: 2) {
                Text("#\(tile.id + 1)")
                    .font(.system(size: 9, weight: .bold))
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
        .frame(height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tile.status == .completed ? Color.green : Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
