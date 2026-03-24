import CoreGraphics
import Dispatch
import IOKit.hid
import Observation

@Observable
@MainActor
final class InputMonitoringManager {
    private(set) var isGranted: Bool

    @ObservationIgnored private var timerSource: DispatchSourceTimer?

    init() {
        self.isGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func startPolling() {
        guard timerSource == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: 1.0)
        source.setEventHandler { [weak self] in
            self?.checkPermission()
        }
        source.resume()
        timerSource = source
    }

    func stopPolling() {
        timerSource?.cancel()
        timerSource = nil
    }

    private func checkPermission() {
        // CGPreflightListenEventAccess() はプロセス内でキャッシュされるため、
        // 実際にイベントタップを作成して権限の有無を判定する
        // (AltTabがScreen Recordingで CGDisplayStream 作成テストを使うのと同じパターン)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        let granted = tap != nil
        if let tap { CFMachPortInvalidate(tap) }
        if granted != isGranted {
            isGranted = granted
        }
    }
}
