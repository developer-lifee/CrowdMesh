import SwiftUI

/// Vista de Mensajes P2P Offline: Soporta Mensajes Directos (1 a 1) y Canales Grupales
struct MeshChatView: View {
    @ObservedObject var network = MeshNetworkEngine.shared
    @ObservedObject var customStore = FriendCustomizationStore.shared

    @State private var messageText: String = ""
    @State private var selectedChannel: String = "General"
    @FocusState private var isInputFocused: Bool

    let channels = ["General", "Emergencias", "Tarima"]

    /// El amigo actualmente seleccionado para Mensaje Directo 1 a 1 (si hay uno activo)
    var activeDirectPeer: DiscoveredPeer? {
        guard let directID = network.activeDirectPeerID else { return nil }
        return network.nearbyPeers[directID]
    }

    /// Filtra los mensajes según estemos en un Chat Directo 1 a 1 con un amigo o en un Canal Grupal
    var filteredMessages: [MeshChatMessage] {
        let myID = network.myPeerID.displayName
        if let directPeer = activeDirectPeer {
            return network.chatMessages.filter { msg in
                msg.isDirectMessage &&
                ((msg.senderID == myID && msg.recipientID == directPeer.id) ||
                 (msg.senderID == directPeer.id && msg.recipientID == myID))
            }
        } else {
            return network.chatMessages.filter { !$0.isDirectMessage && $0.channel == selectedChannel }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isInputFocused = false
                        dismissKeyboardGlobally()
                    }

                VStack(spacing: 0) {
                    // Selector superior: Amigos Conectados (Mensaje Directo 1 a 1) + Canales Grupales
                    recipientAndChannelSelector
                        .background(Color.black.opacity(0.55))

                    // Banner de Chat Directo activo con botón claro de "← Volver"
                    if let directPeer = activeDirectPeer {
                        directChatHeaderBanner(for: directPeer)
                    }

                    // Lista de Mensajes
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if filteredMessages.isEmpty {
                                    emptyChatPlaceholder
                                } else {
                                    ForEach(filteredMessages) { msg in
                                        chatBubble(for: msg)
                                            .id(msg.id)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isInputFocused = false
                                dismissKeyboardGlobally()
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: network.chatMessages.count) { _, _ in
                            if let last = filteredMessages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Botones de mensajes rápidos para conciertos
                    quickPresetChips

                    // Barra de entrada de texto con botón para ocultar teclado
                    messageInputBar
                }
            }
            .navigationTitle(activeDirectPeer != nil ? "Mensaje Directo" : "Mensajes P2P")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if activeDirectPeer != nil {
                        Button {
                            withAnimation {
                                network.activeDirectPeerID = nil
                                isInputFocused = false
                                dismissKeyboardGlobally()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Atrás")
                                    .bold()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.yellow)
                        }
                    } else {
                        Text("Tú: \(network.myDisplayName)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isInputFocused {
                        Button {
                            isInputFocused = false
                            dismissKeyboardGlobally()
                        } label: {
                            Label("Cerrar Teclado", systemImage: "keyboard.chevron.compact.down")
                                .font(.caption.bold())
                                .foregroundStyle(.yellow)
                        }
                    } else {
                        Text("\(network.connectedPeers.count) conectados")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        isInputFocused = false
                        dismissKeyboardGlobally()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down.circle.fill")
                            Text("Ocultar Teclado")
                                .bold()
                        }
                        .foregroundStyle(.yellow)
                    }
                    Spacer()
                    Text(activeDirectPeer != nil ? "Para: \(activeDirectPeer!.displayName)" : "Canal #\(selectedChannel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Selector de Mensajes Directos (1 a 1) y Canales Grupales

    private var recipientAndChannelSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. Tira de Amigos Conectados para Mensaje Directo (1 a 1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Botón para ver Canales Grupales (Todos)
                    Button {
                        withAnimation {
                            network.activeDirectPeerID = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "person.3.fill")
                            Text("Todos (Grupal)")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            network.activeDirectPeerID == nil ? Color.cyan : Color.white.opacity(0.08),
                            in: Capsule()
                        )
                        .foregroundStyle(network.activeDirectPeerID == nil ? .black : .white)
                    }

                    // Amigos detectados para Chat Directo 1 a 1
                    let peersArray = Array(network.nearbyPeers.values.enumerated())
                    if peersArray.isEmpty {
                        Text("Conectando amigos cercanos para chat directo...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    } else {
                        ForEach(peersArray, id: \.element.id) { index, peer in
                            let config = customStore.customization(for: peer.displayName, defaultIndex: index)
                            let nick = config.customNickname?.isEmpty == false ? config.customNickname! : peer.displayName
                            let isSelectedDM = (network.activeDirectPeerID == peer.id)

                            Button {
                                withAnimation {
                                    network.activeDirectPeerID = peer.id
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    DragonBallView(stars: config.dragonBallStars, size: 18, isGlowing: false)
                                    Text("💬 \(nick)")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    isSelectedDM ? Color.yellow : Color.white.opacity(0.1),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(Color.yellow.opacity(0.5), lineWidth: isSelectedDM ? 0 : 1)
                                )
                                .foregroundStyle(isSelectedDM ? .black : .white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            // 2. Si estamos en modo Grupal, mostrar sub-selector de canales (#General, #Emergencias, #Tarima)
            if network.activeDirectPeerID == nil {
                HStack(spacing: 8) {
                    ForEach(channels, id: \.self) { ch in
                        Button {
                            selectedChannel = ch
                        } label: {
                            HStack(spacing: 4) {
                                if ch == "Emergencias" {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                } else if ch == "General" {
                                    Image(systemName: "megaphone.fill")
                                } else {
                                    Image(systemName: "music.note")
                                }
                                Text("#\(ch)")
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                selectedChannel == ch
                                    ? (ch == "Emergencias" ? Color.red : Color.cyan.opacity(0.3))
                                    : Color.white.opacity(0.06),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(selectedChannel == ch ? Color.cyan : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 2)
            }
        }
    }

    private func directChatHeaderBanner(for peer: DiscoveredPeer) -> some View {
        let config = customStore.customization(for: peer.displayName)
        let nick = config.customNickname?.isEmpty == false ? config.customNickname! : peer.displayName

        return HStack(spacing: 10) {
            Button {
                withAnimation {
                    network.activeDirectPeerID = nil
                    isInputFocused = false
                    dismissKeyboardGlobally()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title3)
                    Text("Canales")
                        .font(.caption.bold())
                }
                .foregroundStyle(.yellow)
            }

            Divider().frame(height: 18).background(Color.white.opacity(0.2))

            DragonBallView(stars: config.dragonBallStars, size: 22, isGlowing: true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Chat Directo con \(nick)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text("🔒 Mensaje privado P2P • Receptor: \(peer.displayName)")
                    .font(.system(size: 9))
                    .foregroundStyle(.green)
            }

            Spacer()

            Button {
                network.sendFriendPing(to: peer.id)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("PING 🔔")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow, in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.12))
    }

    // MARK: - Burbujas de Mensaje con Emisor y Receptor Explícitos

    private func chatBubble(for msg: MeshChatMessage) -> some View {
        let isMe = (msg.senderID == network.myPeerID.displayName)
        let senderLabel = isMe ? "Tú (\(network.myDisplayName))" : msg.senderName
        let recipientLabel: String = {
            if let recName = msg.recipientName {
                return (msg.recipientID == network.myPeerID.displayName) ? "Tú (\(network.myDisplayName))" : recName
            }
            return "Todos (#\(msg.channel))"
        }()

        return HStack {
            if isMe { Spacer(minLength: 45) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                // Cabecera explícita: Emisor -> Receptor
                HStack(spacing: 5) {
                    Text("De: \(senderLabel)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isMe ? .cyan : .yellow)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text("Para: \(recipientLabel)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    if msg.isDirectMessage {
                        Text("PRIVADO")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.yellow, in: Capsule())
                    }
                }

                Text(msg.text)
                    .font(.subheadline)
                    .foregroundStyle(isMe && msg.isDirectMessage ? .black : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        bubbleColor(isMe: isMe, msg: msg),
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                HStack(spacing: 6) {
                    Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    Text(msg.hopCount == 0 ? "• Directo" : "• \(msg.hopCount) saltos")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(msg.hopCount == 0 ? .green : .orange)
                }
            }

            if !isMe { Spacer(minLength: 45) }
        }
    }

    private func bubbleColor(isMe: Bool, msg: MeshChatMessage) -> Color {
        if msg.channel == "Emergencias" {
            return isMe ? Color.red.opacity(0.85) : Color.red.opacity(0.35)
        }
        if msg.isDirectMessage {
            return isMe ? Color.yellow : Color.purple.opacity(0.45)
        }
        return isMe ? Color.cyan.opacity(0.85) : Color.white.opacity(0.14)
    }

    private var emptyChatPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: activeDirectPeer != nil ? "lock.shield.fill" : "bubble.left.and.bubble.right.fill")
                .font(.system(size: 34))
                .foregroundStyle(activeDirectPeer != nil ? .yellow : .secondary)

            if let peer = activeDirectPeer {
                Text("Chat Directo con \(peer.displayName)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("Los mensajes que escribas aquí solo los recibirá \(peer.displayName) de forma privada sin usar internet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            } else {
                Text("Canal Grupal #\(selectedChannel)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Text("Toca a un amigo arriba para enviarle un Mensaje Directo 1 a 1, o escribe aquí para todo el parche.")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
        .padding(.vertical, 36)
    }

    private var quickPresetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                quickButton("¿Dónde estás? 📍")
                quickButton("Estoy frente a la tarima 🎸")
                quickButton("Nos vemos en la entrada 🚪")
                quickButton("Mira tu radar 🐉")
                if selectedChannel == "Emergencias" {
                    quickButton("🚨 ¡Necesito ayuda!")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func quickButton(_ text: String) -> some View {
        Button {
            network.sendChatMessage(
                text: text,
                channel: selectedChannel,
                recipientPeer: activeDirectPeer
            )
        } label: {
            Text(text)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.1), in: Capsule())
        }
    }

    private var messageInputBar: some View {
        HStack(spacing: 8) {
            // Botón directo para bajar el teclado cuando está abierto
            if isInputFocused {
                Button {
                    isInputFocused = false
                    dismissKeyboardGlobally()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(9)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
            }

            TextField(
                activeDirectPeer != nil
                    ? "Mensaje privado para \(activeDirectPeer!.displayName)..."
                    : "Mensaje para #\(selectedChannel)...",
                text: $messageText
            )
            .focused($isInputFocused)
            .submitLabel(.send)
            .onSubmit {
                sendCurrentText()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            .foregroundStyle(.white)

            Button {
                sendCurrentText()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        messageText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gray
                            : (activeDirectPeer != nil ? Color.yellow : Color.cyan)
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.75))
    }

    private func sendCurrentText() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        network.sendChatMessage(
            text: trimmed,
            channel: selectedChannel,
            recipientPeer: activeDirectPeer
        )
        messageText = ""
    }
}
