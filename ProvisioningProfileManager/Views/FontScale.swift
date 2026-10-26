import SwiftUI

extension EnvironmentValues {
    /// App-wide text zoom (⌘+ / ⌘- / ⌘0). macOS ignores `dynamicTypeSize`, so text is sized
    /// explicitly through `scaledFont` instead of relying on text styles.
    @Entry var fontScale: CGFloat = 1
}

extension Font.TextStyle {
    /// The macOS point size of each text style at the default size.
    var macOSPointSize: CGFloat {
        switch self {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline: 11
        case .footnote, .caption, .caption2: 10
        @unknown default: 13
        }
    }

    fileprivate var defaultWeight: Font.Weight {
        self == .headline ? .bold : .regular
    }
}

private struct ScaledFont: ViewModifier {
    @Environment(\.fontScale) private var scale
    let style: Font.TextStyle
    let weight: Font.Weight?
    let design: Font.Design
    let monospacedDigit: Bool

    func body(content: Content) -> some View {
        let font = Font.system(size: style.macOSPointSize * scale, weight: weight ?? style.defaultWeight, design: design)
        content.font(monospacedDigit ? font.monospacedDigit() : font)
    }
}

extension View {
    /// Like `.font(style)`, but follows the app's text zoom.
    func scaledFont(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        design: Font.Design = .default,
        monospacedDigit: Bool = false
    ) -> some View {
        modifier(ScaledFont(style: style, weight: weight, design: design, monospacedDigit: monospacedDigit))
    }
}
