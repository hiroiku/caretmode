import SwiftUI

@main
struct CaretModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra(
            "CaretMode",
            systemImage: "a.square",
            isInserted: Binding(
                get: { appDelegate.settings.showMenuBarIcon },
                set: { appDelegate.settings.showMenuBarIcon = $0 }
            )
        ) {
            Toggle("インジケーターを表示", isOn: Binding(
                get: { appDelegate.settings.isEnabled },
                set: { appDelegate.settings.isEnabled = $0 }
            ))

            Divider()

            Button("設定…") {
                appDelegate.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("CaretMode を終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
