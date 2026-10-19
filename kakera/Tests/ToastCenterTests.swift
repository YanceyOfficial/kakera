import Testing
@testable import Kakera
import KakeraUI
import KakeraServices

@Suite("ToastCenter")
@MainActor
struct ToastCenterTests {
    @Test("show presents a success toast with the message")
    func showSuccess() {
        let center = ToastCenter()
        center.show("Word added")
        #expect(center.current?.message == "Word added")
        #expect(center.current?.style == .success)
    }

    @Test("error presents an error-styled toast and records it in the log")
    func errorTogglesStyleAndLogs() {
        LogCollector.shared.clear()
        let center = ToastCenter()
        center.error("Couldn't save", category: "test")
        #expect(center.current?.style == .error)
        #expect(LogCollector.shared.snapshot().contains { $0.message == "Couldn't save" })
    }
}
