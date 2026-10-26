import SwiftUI

/// Vista de Chat Mesh P2P Offline (comunicación instantánea sin red celular)
struct MeshChatView: View {
    @ObservedObject var network = MeshNetworkEngine.shared
    @State private var messageText: String = ""
    @State private var selectedChannel: String = "General"

    let channels = ["General", "Emergencias", "Tarima"]

    var filteredMessages: [MeshChatMessage] {
        network.chatMessages.filter { $0.channel == selectedChannel }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Selector de canales
                    channelPicker
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4))

                    // Mensajes
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
                        }
                        .onChange(of: network.chatMessages.count) { _ in
                            if let last = filteredMessages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Botones de mensajes rápidos para conciertos
                    quickPresetChips

                    // Barra de entrada de texto
                    messageInputBar
                }
            }
            .navigationTitle("Chat Mesh Offline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(network.connectedPeers.count) pares")
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }
            }
        }
    }

    // MARK: - Componentes

    private var channelPicker: some View {
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
                        Text(ch)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        selectedChannel == ch
                            ? (ch == "Emergencias" ? Color.red : Color.cyan)
                            : Color.white.opacity(0.08),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func chatBubble(for msg: MeshChatMessage) -> some View {
        let isMe = msg.senderID == network.myPeerID.displayName

        return HStack {
            if isMe { Spacer(minLength: 40) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isMe ? "Tú" : msg.senderName)
                        .font(.caption2.bold())
                        .foregroundStyle(isMe ? .cyan : .white.opacity(0.8))

                    if msg.hopCount == 0 {
                        Text("DIRECTO")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(msg.hopCount) SALTOS MESH")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.orange)
                    }
                }

                Text(msg.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        isMe
                            ? (msg.channel == "Emergencias" ? Color.red.opacity(0.8) : Color.cyan.opacity(0.85))
                            : (msg.channel == "Emergencias" ? Color.red.opacity(0.3) : Color.white.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            if !isMe { Spacer(minLength: 40) }
        }
    }

    private var emptyChatPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Canal #\(selectedChannel) vacío")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("Envía un mensaje a través de los teléfonos cercanos sin usar datos celulares ni internet.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding(.vertical, 40)
    }

    private var quickPresetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                quickButton("¿Dónde están? 📍")
                quickButton("Estoy en la tarima 🎸")
                quickButton("Entrada principal 🚪")
                quickButton("¿Tienen agua? 💧")
                if selectedChannel == "Emergencias" {
                    quickButton("🚨 ¡Necesito ayuda médica!")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func quickButton(_ text: String) -> some View {
        Button {
            network.sendChatMessage(text: text, channel: selectedChannel)
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
        HStack(spacing: 10) {
            TextField("Escribe un mensaje mesh...", text: $messageText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)

            Button {
                guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                network.sendChatMessage(text: messageText, channel: selectedChannel)
                messageText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(messageText.isEmpty ? Color.gray : Color.cyan)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
    }
}
