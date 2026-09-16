import SwiftUI

enum Theme {
    static let bg = Color.black
    static let card = Color(hex: 0x1C1C1E)
    static let elevated = Color(hex: 0x2C2C2E)
    static let separator = Color(hex: 0x2C2C2E)
    static let control = Color(hex: 0x39393D)
    static let secondary = Color(hex: 0x8E8E93)
    static let tertiary = Color(hex: 0x636366)
    static let accent = Color(hex: 0xC6F542)
    static let onAccent = Color(hex: 0x0B0B0D)
    static let warning = Color(hex: 0xFF9F0A)
    static let danger = Color(hex: 0xFF453A)
    static let tabBar = Color(hex: 0x121214)
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 16
    static let rowHeight: CGFloat = 56
    static let buttonHeight: CGFloat = 52
    static let readableWidth: CGFloat = 640
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    static func num(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(_ padding: CGFloat = 16, radius: CGFloat = Theme.cardRadius) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }

    func readable() -> some View {
        frame(maxWidth: Theme.readableWidth).frame(maxWidth: .infinity)
    }

    func screenBackground() -> some View {
        background(Theme.bg.ignoresSafeArea())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.buttonHeight)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
    }
}

struct GrayButtonStyle: ButtonStyle {
    var height: CGFloat = Theme.buttonHeight
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var on = false
    var accentText = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(on ? Theme.onAccent : (accentText ? Theme.accent : Color(hex: 0xD1D1D6)))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(on ? Theme.accent : Theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct Chip: View {
    var text: String
    var on = false
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(on ? Theme.onAccent : Color(hex: 0xD1D1D6))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(on ? Theme.accent : Theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct EmptyState: View {
    var symbol: String
    var title: String
    var message: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(Theme.secondary)
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(message).font(.system(size: 14)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
            if let action {
                Button(action.title, action: action.run).buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 240).padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
