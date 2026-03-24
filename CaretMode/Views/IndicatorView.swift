import SwiftUI

struct IndicatorView: View {
    let source: InputSourceInfo
    let settings: AppSettings

    var body: some View {
        let config = settings.config(for: source)
        let size = settings.indicatorSize
        let radius = settings.cornerRadius

        Text(config.label)
            .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: size.frameSize, height: size.frameSize)
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
