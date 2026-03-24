import SwiftUI

struct OnboardingView: View {
    let accessibilityManager: AccessibilityManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("アクセシビリティ権限が必要です")
                .font(.headline)

            Text("CaretMode はテキストカーソルの位置を取得するために、アクセシビリティ権限が必要です。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("システム設定を開く") {
                accessibilityManager.requestPermission()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 320)
        .onChange(of: accessibilityManager.isGranted) { _, granted in
            if granted {
                dismiss()
            }
        }
    }
}
