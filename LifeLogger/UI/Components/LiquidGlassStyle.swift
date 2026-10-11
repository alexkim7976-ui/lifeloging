import SwiftUI
import AppKit

// MARK: - Palette

enum LiquidGlassStyle {
    // Base — deep ocean to frost
    static let midnight = Color(red: 0.04, green: 0.08, blue: 0.17)
    static let deepOcean = Color(red: 0.07, green: 0.22, blue: 0.42)
    static let azure = Color(red: 0.14, green: 0.44, blue: 0.76)
    static let skyBlue = Color(red: 0.32, green: 0.66, blue: 0.96)
    static let deepSky = Color(red: 0.17, green: 0.46, blue: 0.80)
    static let iceBlue = Color(red: 0.74, green: 0.91, blue: 1.00)
    static let frost = Color(red: 0.86, green: 0.95, blue: 1.00)
    static let aquaGlow = Color(red: 0.38, green: 0.86, blue: 0.88)
    static let mintGlow = Color(red: 0.42, green: 0.92, blue: 0.78)
    static let lavenderMist = Color(red: 0.58, green: 0.62, blue: 0.92)
    static let bloomAccent = Color(red: 0.93, green: 0.58, blue: 0.82)

    // Glass surfaces
    static let glassFill = Color.white.opacity(0.16)
    static let glassFillStrong = Color.white.opacity(0.24)
    static let glassInnerTint = Color(red: 0.72, green: 0.88, blue: 1.0).opacity(0.10)
    static let glassBorderSoft = Color.white.opacity(0.22)
    static let glassBorder = Color.white.opacity(0.48)
    static let glassShadow = Color(red: 0.04, green: 0.14, blue: 0.30).opacity(0.38)
    static let glassShadowSoft = Color(red: 0.20, green: 0.50, blue: 0.82).opacity(0.22)

    // Typography
    static let titleText = Color.white
    static let bodyText = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.74)
    static let tertiaryText = Color.white.opacity(0.54)

    // Status
    static let statusActive = mintGlow
    static let statusPaused = Color(red: 1.0, green: 0.72, blue: 0.38)
    static let statusAfk = Color(red: 1.0, green: 0.58, blue: 0.44)

    // Gradients
    static let dashboardGradientDeepOcean = LinearGradient(
        colors: [
            Color(red: 0.22, green: 0.52, blue: 0.88),
            Color(red: 0.12, green: 0.36, blue: 0.72),
            Color(red: 0.06, green: 0.18, blue: 0.42),
            midnight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelGradient = LinearGradient(
        colors: [
            azure.opacity(0.82),
            deepOcean.opacity(0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryButtonGradient = LinearGradient(
        colors: [skyBlue, deepSky],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let focusRingGradient = AngularGradient(
        colors: [frost, iceBlue, aquaGlow, mintGlow, frost],
        center: .center
    )

    static let barChartFocusGradient = LinearGradient(
        colors: [frost, skyBlue, deepSky],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let barChartMutedGradient = LinearGradient(
        colors: [Color.white.opacity(0.28), Color.white.opacity(0.12)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let specularHighlight = LinearGradient(
        colors: [
            Color.white.opacity(0.62),
            Color.white.opacity(0.14),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .center
    )

    static let rimHighlight = LinearGradient(
        colors: [
            Color.white.opacity(0.72),
            Color.white.opacity(0.18),
            Color.white.opacity(0.04)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let borderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.58),
            Color.white.opacity(0.22),
            aquaGlow.opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let insetPanelFill = Color.white.opacity(0.08)
    static let insetPanelBorder = Color.white.opacity(0.18)
    static let divider = Color.white.opacity(0.18)
}

enum GlassThemePreset: String, CaseIterable, Identifiable, Sendable {
    case deepOcean
    case midnight
    case forest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .deepOcean: return "딥 오션"
        case .midnight: return "미드나잇"
        case .forest: return "포레스트"
        }
    }
}

enum GlassThemeStore {
    private static let key = "lifelogger.glass.theme"
    static var preset: GlassThemePreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let p = GlassThemePreset(rawValue: raw) else { return .deepOcean }
            return p
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    static var dashboardGradient: LinearGradient {
        switch preset {
        case .deepOcean:
            return LiquidGlassStyle.dashboardGradientDeepOcean
        case .midnight:
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.28),
                    Color(red: 0.06, green: 0.08, blue: 0.18),
                    Color(red: 0.02, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .forest:
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.38, blue: 0.32),
                    Color(red: 0.06, green: 0.22, blue: 0.20),
                    Color(red: 0.03, green: 0.10, blue: 0.12)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Background

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            GlassThemeStore.dashboardGradient

            Circle()
                .fill(
                    RadialGradient(
                        colors: [LiquidGlassStyle.aquaGlow.opacity(0.42), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .blur(radius: 8)
                .offset(x: -260, y: -200)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [LiquidGlassStyle.lavenderMist.opacity(0.32), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 6)
                .offset(x: 300, y: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [LiquidGlassStyle.frost.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 4)
                .offset(x: 100, y: -160)

            Circle()
                .fill(LiquidGlassStyle.mintGlow.opacity(0.12))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -80, y: 280)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, LiquidGlassStyle.midnight.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card & Panel

struct LiquidGlassSurface: View {
    var cornerRadius: CGFloat = 22
    var padding: CGFloat = 0
    var strong: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                strong ? LiquidGlassStyle.glassFillStrong : LiquidGlassStyle.glassFill,
                                LiquidGlassStyle.glassInnerTint
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LiquidGlassStyle.borderGradient, lineWidth: 1.1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LiquidGlassStyle.specularHighlight)
                    .blendMode(.overlay)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LiquidGlassStyle.rimHighlight, lineWidth: 1)
                    .padding(1)
            }
            .shadow(color: LiquidGlassStyle.glassShadowSoft, radius: 24, y: 12)
            .shadow(color: LiquidGlassStyle.glassShadow, radius: 8, y: 4)
            .padding(padding)
    }
}

struct LiquidGlassInsetPanel: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LiquidGlassStyle.insetPanelFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(LiquidGlassStyle.insetPanelBorder, lineWidth: 1)
                    }
            }
    }
}

struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 22
    var strong: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                LiquidGlassSurface(cornerRadius: cornerRadius, strong: strong)
            }
    }
}

struct LiquidGlassSectionHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [LiquidGlassStyle.frost, LiquidGlassStyle.aquaGlow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)
        }
        .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
    }
}

struct LiquidGlassBadge: View {
    let text: String
    var tint: Color = LiquidGlassStyle.deepSky

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.72), tint.opacity(0.48)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.40), lineWidth: 1))
                    .shadow(color: tint.opacity(0.35), radius: 6, y: 2)
            }
    }
}

struct LiquidGlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(LiquidGlassStyle.primaryButtonGradient.opacity(configuration.isPressed ? 0.78 : 1))
                    .overlay(alignment: .top) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.22))
                            .frame(height: 14)
                            .blur(radius: 2)
                            .offset(y: 2)
                    }
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.42), lineWidth: 1))
                    .shadow(color: LiquidGlassStyle.glassShadow, radius: configuration.isPressed ? 4 : 12, y: 4)
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct LiquidGlassBloomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                LiquidGlassStyle.bloomAccent.opacity(configuration.isPressed ? 0.72 : 0.92),
                                LiquidGlassStyle.lavenderMist.opacity(configuration.isPressed ? 0.62 : 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.42), lineWidth: 1))
                    .shadow(color: LiquidGlassStyle.bloomAccent.opacity(0.35), radius: configuration.isPressed ? 4 : 10, y: 4)
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct LiquidGlassKakaoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(Color(red: 0.996, green: 0.898, blue: 0.0).opacity(configuration.isPressed ? 0.82 : 1))
                    .overlay(Capsule(style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
            }
            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct LiquidGlassInstagramButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.44, blue: 0.60).opacity(configuration.isPressed ? 0.78 : 0.95),
                                Color(red: 0.76, green: 0.28, blue: 0.82).opacity(configuration.isPressed ? 0.72 : 0.90),
                                Color(red: 0.98, green: 0.72, blue: 0.28).opacity(configuration.isPressed ? 0.72 : 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1))
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct LiquidGlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.20), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.36), lineWidth: 1))
            }
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.82 : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct LiquidGlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.40), lineWidth: 1))
                    .shadow(color: LiquidGlassStyle.glassShadowSoft, radius: 8, y: 3)
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 22, strong: Bool = false) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius, strong: strong))
    }

    func liquidGlassInsetPanel(cornerRadius: CGFloat = 14) -> some View {
        modifier(LiquidGlassInsetPanel(cornerRadius: cornerRadius))
    }

    func liquidGlassReadableText() -> some View {
        shadow(color: .black.opacity(0.20), radius: 3, y: 1)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6,
              let intValue = Int(hexSanitized, radix: 16) else { return nil }
        let red = Double((intValue >> 16) & 0xFF) / 255
        let green = Double((intValue >> 8) & 0xFF) / 255
        let blue = Double(intValue & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - App Icon

struct AppIconView: View {
    let appName: String
    let bundleIdentifier: String?
    var size: CGFloat = 52
    var cornerRadius: CGFloat = 14

    private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        Group {
            if let icon = Self.resolveIcon(appName: appName, bundleIdentifier: bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.iceBlue)
            }
        }
        .frame(width: size, height: size)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.18))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
    }

    static func resolveIcon(appName: String, bundleIdentifier: String?) -> NSImage? {
        let cacheKey = (bundleIdentifier ?? appName) as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let icon: NSImage?
        if let bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let resolved = NSWorkspace.shared.icon(forFile: url.path)
            resolved.size = NSSize(width: 128, height: 128)
            icon = resolved
        } else if appName == "LifeLogger"
            || appName == (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "") {
            icon = NSApplication.shared.applicationIconImage
        } else {
            icon = NSWorkspace.shared.runningApplications.first(where: {
                ($0.localizedName ?? "") == appName || $0.bundleIdentifier == bundleIdentifier
            })?.icon
        }

        if let icon {
            icon.size = NSSize(width: 128, height: 128)
            cache.setObject(icon, forKey: cacheKey)
        }
        return icon
    }
}
