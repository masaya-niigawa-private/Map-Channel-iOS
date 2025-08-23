import SwiftUI
import UIKit

// MARK: - Theme（色・サイズを集中管理：グラデ版）

public struct ActionButtonTheme {
    public struct GradientSpec {
        public var colors: [Color]
        public var startPoint: UnitPoint
        public var endPoint: UnitPoint
        public init(colors: [Color],
                    startPoint: UnitPoint = .topLeading,
                    endPoint: UnitPoint = .bottomTrailing) {
            self.colors = colors
            self.startPoint = startPoint
            self.endPoint = endPoint
        }
        var linear: LinearGradient { LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint) }
    }
    
    public var primary: GradientSpec
    public var secondary: GradientSpec
    public var destructive: GradientSpec
    
    public var foregroundColor: Color   // 文字色
    public var height: CGFloat          // 高さ
    public var cornerRadius: CGFloat    // 角丸
    public var shadowMajor: Color       // 影（大）
    public var shadowMinor: Color       // 影（小）
    
    public init(primary: GradientSpec = .init(colors: [Color(hue: 0.58, saturation: 0.82, brightness: 0.95),
                                                       Color(hue: 0.65, saturation: 0.70, brightness: 0.88)]),
                secondary: GradientSpec = .init(colors: [Color(hue: 0.56, saturation: 0.70, brightness: 0.94),
                                                         Color(hue: 0.50, saturation: 0.65, brightness: 0.86)]),
                destructive: GradientSpec = .init(colors: [Color(hue: 0.00, saturation: 0.84, brightness: 0.95),
                                                           Color(hue: 0.97, saturation: 0.74, brightness: 0.88)]),
                foregroundColor: Color = .white.opacity(0.96),
                height: CGFloat = 48,
                cornerRadius: CGFloat = 12,
                shadowMajor: Color = .black.opacity(0.14),
                shadowMinor: Color = .black.opacity(0.08)) {
        self.primary = primary
        self.secondary = secondary
        self.destructive = destructive
        self.foregroundColor = foregroundColor
        self.height = height
        self.cornerRadius = cornerRadius
        self.shadowMajor = shadowMajor
        self.shadowMinor = shadowMinor
    }
    
    public static var `default` = ActionButtonTheme()
    
    func gradient(for kind: ActionButton.Kind) -> LinearGradient {
        switch kind {
        case .primary:     return primary.linear
        case .secondary:   return secondary.linear
        case .destructive: return destructive.linear
        }
    }
}

// MARK: - Environment hook

private struct ActionButtonThemeKey: EnvironmentKey {
    static let defaultValue: ActionButtonTheme = .default
}
public extension EnvironmentValues {
    var actionButtonTheme: ActionButtonTheme {
        get { self[ActionButtonThemeKey.self] }
        set { self[ActionButtonThemeKey.self] = newValue }
    }
}
public extension View {
    /// サブツリーに ActionButton のテーマを適用
    func actionButtonTheme(_ theme: ActionButtonTheme) -> some View {
        environment(\.actionButtonTheme, theme)
    }
}

// MARK: - Button（純正らしさ＋リッチ：グラデ＋グロス＋影）

public struct ActionButton: View {
    public enum Kind { case primary, secondary, destructive }
    
    let title: String
    let systemName: String
    var kind: Kind = .secondary
    var fullWidth: Bool = false
    var action: () -> Void
    
    @Environment(\.actionButtonTheme) private var theme
    
    public init(title: String,
                systemName: String,
                kind: Kind = .secondary,
                fullWidth: Bool = false,
                action: @escaping () -> Void) {
        self.title = title
        self.systemName = systemName
        self.kind = kind
        self.fullWidth = fullWidth
        self.action = action
    }
    
    private var role: ButtonRole? { kind == .destructive ? .destructive : nil }
    
    public var body: some View {
        Button(role: role, action: wrappedAction) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } icon: {
                Image(systemName: systemName).imageScale(.medium)
            }
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .foregroundStyle(theme.foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: theme.height)
            .padding(.horizontal, 12)
            .background {
                let r = theme.cornerRadius
                RoundedRectangle(cornerRadius: r, style: .continuous)
                // 1) ベース：上質グラデ
                    .fill(theme.gradient(for: kind))
                // 2) 微グロス（斜めの光）
                    .overlay(
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(LinearGradient(colors: [
                                .white.opacity(0.25),
                                .white.opacity(0.08),
                                .clear
                            ], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .blendMode(.overlay)
                    )
                // 3) 境界のにじみ防止（極薄枠）
                    .overlay(
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
                // 4) 影（上品に二段）
                    .shadow(color: theme.shadowMajor, radius: 9, y: 5)
                    .shadow(color: theme.shadowMinor, radius: 2, y: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(title))
    }
    
    // 軽いハプティクスのみ（機能は不変）
    private func wrappedAction() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        action()
    }
}

// 押下中のスプリング & わずかなハイライト
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0))
                    .blendMode(.overlay)
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4) }
            }
    }
}

