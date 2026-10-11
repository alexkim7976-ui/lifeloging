import SwiftUI

struct BloomieMessengerThemeData {
    let mode: MessengerThemeMode
    let gradient: [Color]
    let blobA: Color
    let blobB: Color
    let glassTint: Color
    let glassBorder: Color
    let accent: Color

    static func data(for mode: MessengerThemeMode) -> BloomieMessengerThemeData {
        switch mode {
        case .warm:
            return BloomieMessengerThemeData(
                mode: .warm,
                gradient: [
                    Color(red: 1.0, green: 0.83, blue: 0.65),
                    Color(red: 1.0, green: 0.71, blue: 0.73),
                    Color(red: 1.0, green: 0.76, blue: 0.80),
                    Color(red: 1.0, green: 0.63, blue: 0.50)
                ],
                blobA: Color(red: 1.0, green: 0.60, blue: 0.55),
                blobB: Color(red: 1.0, green: 0.76, blue: 0.44),
                glassTint: Color(red: 1.0, green: 0.95, blue: 0.93),
                glassBorder: .white,
                accent: Color(red: 1.0, green: 0.49, blue: 0.47)
            )
        case .cozy:
            return BloomieMessengerThemeData(
                mode: .cozy,
                gradient: [
                    Color(red: 0.63, green: 0.77, blue: 0.99),
                    Color(red: 0.76, green: 0.91, blue: 0.98),
                    Color(red: 0.98, green: 0.76, blue: 0.92),
                    Color(red: 0.65, green: 0.75, blue: 0.99)
                ],
                blobA: Color(red: 0.61, green: 0.55, blue: 1.0),
                blobB: Color(red: 0.31, green: 0.76, blue: 0.97),
                glassTint: .white,
                glassBorder: .white,
                accent: Color(red: 0.31, green: 0.67, blue: 0.99)
            )
        case .deep:
            return BloomieMessengerThemeData(
                mode: .deep,
                gradient: [
                    Color(red: 0.23, green: 0.30, blue: 0.56),
                    Color(red: 0.36, green: 0.36, blue: 0.62),
                    Color(red: 0.48, green: 0.42, blue: 0.71),
                    Color(red: 0.17, green: 0.24, blue: 0.44)
                ],
                blobA: Color(red: 0.42, green: 0.52, blue: 0.95),
                blobB: Color(red: 0.56, green: 0.49, blue: 0.76),
                glassTint: Color(red: 0.90, green: 0.91, blue: 1.0),
                glassBorder: Color.white.opacity(0.72),
                accent: Color(red: 0.58, green: 0.64, blue: 0.98)
            )
        case .chilly:
            return BloomieMessengerThemeData(
                mode: .chilly,
                gradient: [
                    Color(red: 0.78, green: 0.86, blue: 0.90),
                    Color(red: 0.68, green: 0.80, blue: 0.86),
                    Color(red: 0.82, green: 0.90, blue: 0.88),
                    Color(red: 0.62, green: 0.74, blue: 0.80)
                ],
                blobA: Color(red: 0.56, green: 0.78, blue: 0.82),
                blobB: Color(red: 0.72, green: 0.88, blue: 0.84),
                glassTint: Color(red: 0.94, green: 0.98, blue: 0.99),
                glassBorder: Color.white.opacity(0.85),
                accent: Color(red: 0.40, green: 0.68, blue: 0.72)
            )
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: gradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BloomieMessengerBackground: View {
    let theme: BloomieMessengerThemeData

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            Circle()
                .fill(theme.blobA.opacity(0.35))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -180, y: -220)

            Circle()
                .fill(theme.blobB.opacity(0.30))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 200, y: 240)
        }
    }
}
