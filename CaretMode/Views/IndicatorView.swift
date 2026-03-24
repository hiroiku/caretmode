import SwiftUI

struct IndicatorView: View {
    let source: InputSourceInfo
    let settings: AppSettings

    var body: some View {
        let config = settings.config(for: source)
        let radius = settings.cornerRadius
        let font: Font = settings.fontName.isEmpty
            ? .system(size: settings.fontSize, weight: .bold, design: .rounded)
            : .custom(settings.fontName, size: settings.fontSize).bold()

        Text(config.label)
            .font(font)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, settings.paddingHorizontal)
            .padding(.vertical, settings.paddingVertical)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(config.color.color)
            )
            .overlay {
                if settings.borderEnabled {
                    let borderColor = settings.borderUseSourceColor
                        ? config.color.color
                        : settings.borderCustomColor
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            borderColor.opacity(settings.borderOpacity),
                            lineWidth: settings.borderWidth
                        )
                }
            }
            .opacity(settings.opacity)
    }
}
