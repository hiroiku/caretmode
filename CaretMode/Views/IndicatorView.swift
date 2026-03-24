import SwiftUI

struct IndicatorView: View {
    let source: InputSourceInfo
    let settings: AppSettings

    var body: some View {
        let config = settings.config(for: source)
        let size = settings.indicatorSize
        let radius = settings.cornerRadius
        let textLineHeight = ceil(size.fontSize * 1.3)
        let contentHeight = textLineHeight + settings.paddingVertical * 2
        let minSide = max(size.frameSize, contentHeight)

        Text(config.label)
            .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, settings.paddingHorizontal)
            .padding(.vertical, settings.paddingVertical)
            .frame(minWidth: minSide, minHeight: size.frameSize)
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
