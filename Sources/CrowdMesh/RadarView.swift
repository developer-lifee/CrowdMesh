import SwiftUI
import CoreLocation

/// Vista principal de Radar de Multitud (para ubicar amigos en conciertos y eventos masivos)
struct RadarView: View {
    @ObservedObject var network = MeshNetworkEngine.shared
    @State private var radarSweepAngle: Double = 0
    @State private var selectedPeer: DiscoveredPeer?

    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo oscuro futurista con degradado suave
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Banner de estado de la red Mesh
                        meshStatusBar

                        // Radar interactivo de proximidad
                        radarVisualizer
                            .frame(height: 320)
                            .padding(.vertical, 10)

                        // Lista de amigos y pares detectados
                        peersListSection
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Radar del Parche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(network.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(network.isRunning ? "Malla Activa" : "Pausada")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                radarSweepAngle = 360
            }
        }
    }

    // MARK: - Componentes Visuales

    private var meshStatusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Red del Parche (Sin Señal)")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
                Text("\(network.connectedPeers.count) amigos enlazados directamente")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Repetidor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(network.totalPacketsRelayed) saltos")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        )
    }

    private var radarVisualizer: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 16

            ZStack {
                // Círculos concéntricos de distancia
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { ratio in
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        .frame(width: maxRadius * 2 * ratio, height: maxRadius * 2 * ratio)
                }

                // Ejes cartesianos cruzados
                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y - maxRadius))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + maxRadius))
                    path.move(to: CGPoint(x: center.x - maxRadius, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + maxRadius, y: center.y))
                }
                .stroke(Color.cyan.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Línea de barrido del sonar (Sweep)
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.clear, .cyan.opacity(0.02), .cyan.opacity(0.4)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(radarSweepAngle)
                        )
                    )
                    .frame(width: maxRadius * 2, height: maxRadius * 2)
                    .rotationEffect(.degrees(radarSweepAngle))

                // Marcador del usuario actual (Centro del radar)
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: .cyan, radius: 8)

                // Marcadores de amigos / nodos en el radar
                ForEach(Array(network.nearbyPeers.values.enumerated()), id: \.element.id) { index, peer in
                    let angle = Double(index * 65 + 35) * .pi / 180.0
                    let normalizedDist = min(1.0, max(0.2, peer.estimatedDistanceMeters / 40.0))
                    let r = maxRadius * normalizedDist
                    let xPos = center.x + CGFloat(cos(angle) * r)
                    let yPos = center.y + CGFloat(sin(angle) * r)

                    VStack(spacing: 2) {
                        Button {
                            selectedPeer = peer
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(peer.isDirectlyConnected ? Color.green : Color.orange)
                                    .frame(width: 22, height: 22)
                                    .shadow(color: peer.isDirectlyConnected ? .green : .orange, radius: 6)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }

                        Text(peer.displayName.prefix(8))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .background(Color.black.opacity(0.6), in: Capsule())
                    }
                    .position(x: xPos, y: yPos)
                }
            }
        }
    }

    private var peersListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu Parche Cercano (\(network.nearbyPeers.count))")
                .font(.headline)
                .foregroundStyle(.white)

            if network.nearbyPeers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 38))
                        .foregroundStyle(.cyan.opacity(0.6))
                    Text("Buscando al parche en la multitud...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Cualquier iPhone con Parche Radar abierto en el festival se conectará automáticamente sin internet.")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(Array(network.nearbyPeers.values)) { peer in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(peer.isDirectlyConnected ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: peer.isDirectlyConnected ? "wifi" : "point.3.connected.trianglepath.dotted")
                                .foregroundStyle(peer.isDirectlyConnected ? Color.green : Color.orange)
                                .font(.system(size: 18))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(peer.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)

                                if peer.isDirectlyConnected {
                                    Text("DIRECTO")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15), in: Capsule())
                                } else {
                                    Text("\(peer.hopDistance) SALTOS")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15), in: Capsule())
                                }
                            }

                            Text(peer.signalStrengthDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Botón de Ping Haptic
                        Button {
                            network.sendFriendPing(to: peer.displayName)
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.badge.fill")
                                Text("PING")
                                    .bold()
                            }
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.cyan, in: Capsule())
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}
