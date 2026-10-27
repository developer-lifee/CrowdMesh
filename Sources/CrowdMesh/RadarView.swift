import SwiftUI
import CoreLocation
import PhotosUI

/// Vista principal de Radar de Multitud (para ubicar amigos en conciertos y eventos masivos)
struct RadarView: View {
    @ObservedObject var network = MeshNetworkEngine.shared
    @ObservedObject var customStore = FriendCustomizationStore.shared

    @State private var radarSweepAngle: Double = 0
    @State private var editingPeer: DiscoveredPeer?
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo según tema activo
                if customStore.useDragonRadarTheme {
                    dragonRadarBackground
                        .ignoresSafeArea()
                } else {
                    cyberpunkBackground
                        .ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 20) {
                        // Banner de estado de la red Mesh
                        meshStatusBar

                        // Radar interactivo de proximidad con esferas del dragón / stickers
                        radarVisualizer
                            .frame(height: 340)
                            .padding(.vertical, 8)

                        // Lista de amigos y pares detectados con opción de personalización
                        peersListSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(customStore.useDragonRadarTheme ? "Radar Dragón 🐉" : "Radar del Parche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            customStore.toggleRadarTheme()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 4) {
                            Text(customStore.useDragonRadarTheme ? "🐉 Dragón" : "🌐 Cyber")
                                .font(.caption.bold())
                                .foregroundStyle(customStore.useDragonRadarTheme ? .yellow : .cyan)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1), in: Capsule())
                    }
                }

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
            .sheet(item: $editingPeer) { peer in
                EditFriendCustomizationView(peer: peer, store: customStore)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                radarSweepAngle = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }

    // MARK: - Fondos Temáticos

    private var cyberpunkBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var dragonRadarBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.18, blue: 0.10),
                Color(red: 0.02, green: 0.08, blue: 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Componentes Visuales

    private var meshStatusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(customStore.useDragonRadarTheme ? "Buscador de Esferas y Parche" : "Red del Parche (Sin Señal)")
                    .font(.caption.bold())
                    .foregroundStyle(customStore.useDragonRadarTheme ? .yellow : .cyan)
                Text("\(network.connectedPeers.count) amigos enlazados sin internet")
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
                .stroke(customStore.useDragonRadarTheme ? Color.yellow.opacity(0.3) : Color.cyan.opacity(0.25), lineWidth: 1)
        )
    }

    private var radarVisualizer: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 12
            let isDragon = customStore.useDragonRadarTheme
            let gridColor = isDragon ? Color(red: 0.15, green: 0.65, blue: 0.3).opacity(0.4) : Color.cyan.opacity(0.25)
            let sweepColor = isDragon ? Color.yellow : Color.cyan

            ZStack {
                // Bisel exterior tipo carcasa física de Dragon Radar
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: isDragon ? [.white.opacity(0.8), .gray.opacity(0.4), .white.opacity(0.7)] : [.cyan.opacity(0.6), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: maxRadius * 2 + 8, height: maxRadius * 2 + 8)
                    .shadow(color: isDragon ? .yellow.opacity(0.3) : .cyan.opacity(0.3), radius: 10)

                // Fondo interior del radar (pantalla CRT / verde retro)
                Circle()
                    .fill(
                        isDragon
                            ? RadialGradient(
                                colors: [Color(red: 0.14, green: 0.44, blue: 0.22), Color(red: 0.05, green: 0.22, blue: 0.10)],
                                center: .center,
                                startRadius: 10,
                                endRadius: maxRadius
                            )
                            : RadialGradient(
                                colors: [Color(red: 0.05, green: 0.12, blue: 0.22), Color(red: 0.01, green: 0.03, blue: 0.07)],
                                center: .center,
                                startRadius: 10,
                                endRadius: maxRadius
                            )
                    )
                    .frame(width: maxRadius * 2, height: maxRadius * 2)

                // Cuadrícula clásica de Dragon Radar (líneas verticales y horizontales)
                if isDragon {
                    dragonRadarGrid(center: center, radius: maxRadius)
                }

                // Círculos concéntricos de distancia
                ForEach([0.33, 0.66, 1.0], id: \.self) { ratio in
                    Circle()
                        .stroke(gridColor, lineWidth: 1.2)
                        .frame(width: maxRadius * 2 * ratio, height: maxRadius * 2 * ratio)
                }

                // Ejes cartesianos cruzados
                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y - maxRadius))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + maxRadius))
                    path.move(to: CGPoint(x: center.x - maxRadius, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + maxRadius, y: center.y))
                }
                .stroke(gridColor, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Barrido del sonar (Sweep)
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.clear, sweepColor.opacity(0.03), sweepColor.opacity(0.45)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(radarSweepAngle)
                        )
                    )
                    .frame(width: maxRadius * 2, height: maxRadius * 2)
                    .rotationEffect(.degrees(radarSweepAngle))

                // Marcador del usuario actual (Centro del radar: Triángulo rojo anime clásico de Bulma)
                if isDragon {
                    dragonRadarCenterArrow
                        .position(x: center.x, y: center.y)
                } else {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(color: .cyan, radius: 8)
                        .position(x: center.x, y: center.y)
                }

                // Marcadores de amigos / nodos en el radar
                ForEach(Array(network.nearbyPeers.values.enumerated()), id: \.element.id) { index, peer in
                    let angle = Double(index * 65 + 35) * .pi / 180.0
                    let normalizedDist = min(1.0, max(0.25, peer.estimatedDistanceMeters / 40.0))
                    let r = maxRadius * normalizedDist
                    let xPos = center.x + CGFloat(cos(angle) * r)
                    let yPos = center.y + CGFloat(sin(angle) * r)
                    let config = customStore.customization(for: peer.displayName, defaultIndex: index)
                    let displayName = config.customNickname?.isEmpty == false ? config.customNickname! : peer.displayName

                    VStack(spacing: 3) {
                        Button {
                            editingPeer = peer
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            peerAvatarBadge(config: config, defaultIndex: index)
                        }

                        Text(displayName.prefix(10))
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.black.opacity(0.7), in: Capsule())
                            .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 0.5))
                    }
                    .position(x: xPos, y: yPos)
                }
            }
        }
    }

    /// Flecha roja clásica central del Dragon Radar
    private var dragonRadarCenterArrow: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: -10))
            path.addLine(to: CGPoint(x: 7, y: 7))
            path.addLine(to: CGPoint(x: 0, y: 3))
            path.addLine(to: CGPoint(x: -7, y: 7))
            path.closeSubpath()
        }
        .fill(Color(red: 0.95, green: 0.1, blue: 0.1))
        .overlay(
            Path { path in
                path.move(to: CGPoint(x: 0, y: -10))
                path.addLine(to: CGPoint(x: 7, y: 7))
                path.addLine(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: -7, y: 7))
                path.closeSubpath()
            }
            .stroke(Color.white, lineWidth: 1.5)
        )
        .shadow(color: .red.opacity(0.8), radius: 6)
        .frame(width: 14, height: 14)
    }

    /// Renderiza el avatar personalizado según la opción elegida por el usuario
    @ViewBuilder
    private func peerAvatarBadge(config: FriendCustomization, defaultIndex: Int) -> some View {
        switch config.avatarType {
        case .dragonBall:
            DragonBallView(stars: config.dragonBallStars, size: 30, isGlowing: true)
                .scaleEffect(pulseScale)

        case .sticker:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 32, height: 32)
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 32, height: 32)
                Text(config.selectedSticker)
                    .font(.system(size: 18))
            }
            .shadow(color: .yellow.opacity(0.6), radius: 6)

        case .customImage:
            if let data = config.customImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
                    .shadow(color: .yellow.opacity(0.7), radius: 6)
            } else {
                DragonBallView(stars: config.dragonBallStars, size: 30, isGlowing: true)
            }
        }
    }

    /// Retícula de cuadrícula verde militar / anime Dragon Radar
    private func dragonRadarGrid(center: CGPoint, radius: CGFloat) -> some View {
        Path { path in
            let step: CGFloat = radius / 3.0
            for i in -2...2 {
                let offset = CGFloat(i) * step
                // Verticales
                path.move(to: CGPoint(x: center.x + offset, y: center.y - radius))
                path.addLine(to: CGPoint(x: center.x + offset, y: center.y + radius))
                // Horizontales
                path.move(to: CGPoint(x: center.x - radius, y: center.y + offset))
                path.addLine(to: CGPoint(x: center.x + radius, y: center.y + offset))
            }
        }
        .stroke(Color(red: 0.15, green: 0.55, blue: 0.25).opacity(0.35), lineWidth: 1)
        .clipShape(Circle().size(width: radius * 2, height: radius * 2).offset(x: center.x - radius, y: center.y - radius))
    }

    // MARK: - Lista de Amigos

    private var peersListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tu Parche Cercano (\(network.nearbyPeers.count))")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("Toca para personalizar 🎨")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if network.nearbyPeers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 38))
                        .foregroundStyle(customStore.useDragonRadarTheme ? .yellow.opacity(0.7) : .cyan.opacity(0.6))
                    Text("Buscando señales del parche en la multitud...")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("Cualquier iPhone con Parche Radar abierto en el concierto aparecerá en el radar como una Esfera del Dragón o sticker sin requerir internet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(Array(network.nearbyPeers.values.enumerated()), id: \.element.id) { index, peer in
                    let config = customStore.customization(for: peer.displayName, defaultIndex: index)
                    let displayName = config.customNickname?.isEmpty == false ? config.customNickname! : peer.displayName

                    HStack(spacing: 14) {
                        // Miniatura personalizada del amigo
                        Button {
                            editingPeer = peer
                        } label: {
                            peerAvatarBadge(config: config, defaultIndex: index)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)

                                if config.customNickname != nil && config.customNickname != peer.displayName {
                                    Text("(\(peer.displayName))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if peer.isDirectlyConnected {
                                    Text("DIRECTO")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15), in: Capsule())
                                } else {
                                    Text("\(peer.hopDistance) SALTOS")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15), in: Capsule())
                                }
                            }

                            Text(peer.signalStrengthDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            // Botón de Editar Avatar / Nombre
                            Button {
                                editingPeer = peer
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.yellow)
                            }

                            // Botón de Mensaje Directo 1 a 1
                            Button {
                                network.openDirectChat(with: peer)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "bubble.left.fill")
                                    Text("CHAT")
                                        .bold()
                                }
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.85), in: Capsule())
                            }

                            // Botón de Ping Haptic
                            Button {
                                network.sendFriendPing(to: peer.id)
                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "bell.badge.fill")
                                    Text("PING")
                                        .bold()
                                }
                                .font(.caption2)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color.yellow, in: Capsule())
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}

// MARK: - Hoja de Edición y Personalización de Amigo (Esferas, Stickers, PNG)

struct EditFriendCustomizationView: View {
    let peer: DiscoveredPeer
    @ObservedObject var store: FriendCustomizationStore
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""
    @State private var avatarType: RadarAvatarType = .dragonBall
    @State private var stars: Int = 4
    @State private var selectedSticker: String = "⚡️"
    @State private var customImageData: Data?
    @State private var photoItem: PhotosPickerItem?

    let stickerPresets = ["⚡️", "🎸", "🍺", "👽", "🔥", "🐲", "🍕", "🍄", "🚀", "💎", "🤘", "🕶️", "🌮", "🪐", "🪩", "🔊"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.08, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Vista previa interactiva
                        previewCard

                        // Botón rápido para ir a Mensaje Directo 1 a 1 con este amigo
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                MeshNetworkEngine.shared.openDirectChat(with: peer)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                Text("Enviar Mensaje Directo a \(nickname.isEmpty ? peer.displayName : nickname)")
                                    .font(.subheadline.bold())
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.cyan.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan, lineWidth: 1))
                        }

                        // Campo de Apodo Personalizado
                        nicknameSection

                        // Selector de Tipo de Avatar
                        avatarTypeSelector

                        // Controles según el tipo de avatar seleccionado
                        switch avatarType {
                        case .dragonBall:
                            dragonBallPickerSection
                        case .sticker:
                            stickerPickerSection
                        case .customImage:
                            customImagePickerSection
                        }

                        // Botón de Guardar
                        Button {
                            saveCustomization()
                        } label: {
                            Text("Guardar en mi Radar")
                                .font(.headline.bold())
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .shadow(color: .orange.opacity(0.4), radius: 8)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Personalizar Amigo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismissKeyboardGlobally()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Atrás")
                        }
                        .foregroundStyle(.yellow)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        dismissKeyboardGlobally()
                        saveCustomization()
                    }
                    .font(.headline)
                    .foregroundStyle(.yellow)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        dismissKeyboardGlobally()
                    } label: {
                        Label("Ocultar Teclado", systemImage: "keyboard.chevron.compact.down")
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                }
            }
            .onAppear {
                loadExistingData()
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.customImageData = data
                            self.avatarType = .customImage
                        }
                    }
                }
            }
        }
    }

    private var previewCard: some View {
        VStack(spacing: 12) {
            Text("VISTA EN EL RADAR")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color(red: 0.08, green: 0.28, blue: 0.15))
                    .frame(width: 90, height: 90)
                    .overlay(Circle().stroke(Color.yellow.opacity(0.6), lineWidth: 2))

                switch avatarType {
                case .dragonBall:
                    DragonBallView(stars: stars, size: 54, isGlowing: true)
                case .sticker:
                    Text(selectedSticker)
                        .font(.system(size: 42))
                case .customImage:
                    if let data = customImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
                    } else {
                        DragonBallView(stars: stars, size: 54, isGlowing: true)
                    }
                }
            }

            Text(nickname.isEmpty ? peer.displayName : nickname)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apodo en el Radar")
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            TextField("Ej: Goku, El Paisa, Dani...", text: $nickname)
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
    }

    private var avatarTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estilo en el Radar")
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            Picker("Tipo de Avatar", selection: $avatarType) {
                Text("🔮 Esfera Dragón").tag(RadarAvatarType.dragonBall)
                Text("🎭 Sticker").tag(RadarAvatarType.sticker)
                Text("🖼️ PNG / Foto").tag(RadarAvatarType.customImage)
            }
            .pickerStyle(.segmented)
        }
    }

    private var dragonBallPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selecciona el número de estrellas (1 - 7):")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(1...7, id: \.self) { starCount in
                        Button {
                            stars = starCount
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 6) {
                                DragonBallView(stars: starCount, size: 44, isGlowing: stars == starCount)
                                    .padding(4)
                                    .background(
                                        Circle()
                                            .fill(stars == starCount ? Color.yellow.opacity(0.25) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(stars == starCount ? Color.yellow : Color.clear, lineWidth: 2)
                                    )

                                Text("\(starCount) ★")
                                    .font(.caption2.bold())
                                    .foregroundStyle(stars == starCount ? .yellow : .secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private var stickerPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elige un sticker para este amigo:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                ForEach(stickerPresets, id: \.self) { sticker in
                    Button {
                        selectedSticker = sticker
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(sticker)
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedSticker == sticker ? Color.yellow.opacity(0.25) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedSticker == sticker ? Color.yellow : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private var customImagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sube un sticker PNG transparente o foto de tu amigo:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                        Text("Elegir de Galería / Archivos")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.yellow, in: RoundedRectangle(cornerRadius: 10))
                }

                if customImageData != nil {
                    Button(role: .destructive) {
                        customImageData = nil
                        photoItem = nil
                        avatarType = .dragonBall
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.15), in: Circle())
                    }
                }
            }

            Text("💡 Consejo: Los PNG con fondo transparente lucen increíbles sobre la cuadrícula del radar!")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private func loadExistingData() {
        let current = store.customization(for: peer.displayName)
        nickname = current.customNickname ?? peer.displayName
        avatarType = current.avatarType
        stars = current.dragonBallStars
        selectedSticker = current.selectedSticker
        customImageData = current.customImageData
    }

    private func saveCustomization() {
        let updated = FriendCustomization(
            customNickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarType: avatarType,
            dragonBallStars: stars,
            selectedSticker: selectedSticker,
            customImageData: customImageData
        )
        store.saveCustomization(updated, for: peer.displayName)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
