import Foundation
import SwiftUI
import Combine

/// Tipo de marcador visual en el radar para un amigo
public enum RadarAvatarType: String, Codable, CaseIterable {
    case dragonBall   // Esfera del dragón con estrellas rojas
    case sticker      // Sticker o emoji temático
    case customImage  // Foto / PNG personalizado subido por el usuario
}

/// Configuración personalizada de un amigo en el radar
public struct FriendCustomization: Codable {
    public var customNickname: String?
    public var avatarType: RadarAvatarType = .dragonBall
    public var dragonBallStars: Int = 4 // Por defecto 4 estrellas (la de Goku)
    public var selectedSticker: String = "⚡️"
    public var customImageData: Data?

    public init(
        customNickname: String? = nil,
        avatarType: RadarAvatarType = .dragonBall,
        dragonBallStars: Int = 4,
        selectedSticker: String = "⚡️",
        customImageData: Data? = nil
    ) {
        self.customNickname = customNickname
        self.avatarType = avatarType
        self.dragonBallStars = dragonBallStars
        self.selectedSticker = selectedSticker
        self.customImageData = customImageData
    }
}

/// Gestor de personalizaciones guardadas localmente
@MainActor
public final class FriendCustomizationStore: ObservableObject {
    public static let shared = FriendCustomizationStore()

    @Published public var customizations: [String: FriendCustomization] = [:]
    @Published public var useDragonRadarTheme: Bool = true // Tema verde clásico de Dragon Radar

    private let storageKey = "parcheradar_customizations"
    private let themeKey = "parcheradar_radar_theme"

    public init() {
        self.useDragonRadarTheme = UserDefaults.standard.object(forKey: themeKey) as? Bool ?? true
        loadCustomizations()
    }

    public func customization(for peerID: String, defaultIndex: Int = 0) -> FriendCustomization {
        if let existing = customizations[peerID] {
            return existing
        }
        // Asignar una esfera del dragón con estrellas del 1 al 7 automáticamente
        let stars = (defaultIndex % 7) + 1
        return FriendCustomization(dragonBallStars: stars)
    }

    public func saveCustomization(_ config: FriendCustomization, for peerID: String) {
        customizations[peerID] = config
        persist()
    }

    public func toggleRadarTheme() {
        useDragonRadarTheme.toggle()
        UserDefaults.standard.set(useDragonRadarTheme, forKey: themeKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customizations) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadCustomizations() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([String: FriendCustomization].self, from: data) {
            self.customizations = loaded
        }
    }
}

// MARK: - Componente Visual de la Esfera del Dragón (Dragon Ball)
public struct DragonBallView: View {
    public let stars: Int
    public let size: CGFloat
    public var isGlowing: Bool = true

    public init(stars: Int = 4, size: CGFloat = 34, isGlowing: Bool = true) {
        self.stars = max(1, min(7, stars))
        self.size = size
        self.isGlowing = isGlowing
    }

    public var body: some View {
        ZStack {
            // Brillo exterior naranja / dorado
            if isGlowing {
                Circle()
                    .fill(Color.orange.opacity(0.4))
                    .frame(width: size * 1.3, height: size * 1.3)
                    .blur(radius: 4)
            }

            // Cuerpo esférico translúcido con degradado cristalino
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.4),  // Centro brillante
                            Color(red: 1.0, green: 0.55, blue: 0.0),  // Naranja ámbar
                            Color(red: 0.85, green: 0.28, blue: 0.0)  // Borde profundo
                        ],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 2,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Reflejo especular superior tipo cristal de anime
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

            // Reflejo de luz interior
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: size * 0.28, height: size * 0.18)
                .rotationEffect(.degrees(-35))
                .offset(x: -size * 0.2, y: -size * 0.2)

            // Estrellas rojas de Dragon Ball en el centro
            starsLayout
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .frame(width: size, height: size)
    }

    // Distribución geométrica de las estrellas rojas clásicas de Dragon Ball (1 a 7)
    @ViewBuilder
    private var starsLayout: some View {
        let starColor = Color(red: 0.85, green: 0.05, blue: 0.05) // Rojo rubí oscuro

        switch stars {
        case 1:
            singleStar(color: starColor, fontSize: size * 0.32)

        case 2:
            HStack(spacing: size * 0.06) {
                singleStar(color: starColor, fontSize: size * 0.2)
                singleStar(color: starColor, fontSize: size * 0.2)
            }

        case 3:
            VStack(spacing: size * 0.02) {
                singleStar(color: starColor, fontSize: size * 0.17)
                HStack(spacing: size * 0.06) {
                    singleStar(color: starColor, fontSize: size * 0.17)
                    singleStar(color: starColor, fontSize: size * 0.17)
                }
            }

        case 4:
            // La clásica de Goku (forma de rombo)
            VStack(spacing: size * 0.03) {
                singleStar(color: starColor, fontSize: size * 0.17)
                HStack(spacing: size * 0.1) {
                    singleStar(color: starColor, fontSize: size * 0.17)
                    singleStar(color: starColor, fontSize: size * 0.17)
                }
                singleStar(color: starColor, fontSize: size * 0.17)
            }

        case 5:
            VStack(spacing: size * 0.02) {
                HStack(spacing: size * 0.08) {
                    singleStar(color: starColor, fontSize: size * 0.15)
                    singleStar(color: starColor, fontSize: size * 0.15)
                }
                singleStar(color: starColor, fontSize: size * 0.15)
                HStack(spacing: size * 0.08) {
                    singleStar(color: starColor, fontSize: size * 0.15)
                    singleStar(color: starColor, fontSize: size * 0.15)
                }
            }

        case 6:
            VStack(spacing: size * 0.02) {
                HStack(spacing: size * 0.06) {
                    singleStar(color: starColor, fontSize: size * 0.14)
                    singleStar(color: starColor, fontSize: size * 0.14)
                }
                HStack(spacing: size * 0.06) {
                    singleStar(color: starColor, fontSize: size * 0.14)
                    singleStar(color: starColor, fontSize: size * 0.14)
                }
                HStack(spacing: size * 0.06) {
                    singleStar(color: starColor, fontSize: size * 0.14)
                    singleStar(color: starColor, fontSize: size * 0.14)
                }
            }

        default: // 7 estrellas
            VStack(spacing: size * 0.01) {
                singleStar(color: starColor, fontSize: size * 0.13)
                HStack(spacing: size * 0.04) {
                    singleStar(color: starColor, fontSize: size * 0.13)
                    singleStar(color: starColor, fontSize: size * 0.13)
                }
                HStack(spacing: size * 0.04) {
                    singleStar(color: starColor, fontSize: size * 0.13)
                    singleStar(color: starColor, fontSize: size * 0.13)
                }
                HStack(spacing: size * 0.04) {
                    singleStar(color: starColor, fontSize: size * 0.13)
                    singleStar(color: starColor, fontSize: size * 0.13)
                }
            }
        }
    }

    private func singleStar(color: Color, fontSize: CGFloat) -> some View {
        Image(systemName: "star.fill")
            .font(.system(size: fontSize))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
    }
}

