import Foundation
import Testing
@testable import KakeraAI

/// A transport that returns a scripted sequence of status codes, counting calls.
private final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    private var statuses: [Int]
    private let headers: [[String: String]]
    private(set) var callCount = 0
    /// `headers[i]` are the response headers of the i-th call (none past the end).
    init(_ statuses: [Int], headers: [[String: String]] = []) {
        self.statuses = statuses
        self.headers = headers
    }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let status = statuses[min(callCount, statuses.count - 1)]
        let fields = callCount < headers.count ? headers[callCount] : nil
        callCount += 1
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: fields)!
        return (Data("body".utf8), resp)
    }
}

/// Records how long the transport asked to wait, instead of waiting.
private final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []
    var delays: [Double] { lock.withLock { recorded } }
    private func record(_ delay: Double) { lock.withLock { recorded.append(delay) } }
    var sleep: @Sendable (Double) async throws -> Void {
        { [self] delay in record(delay) }
    }
}

private let noSleep: @Sendable (Double) async throws -> Void = { _ in }

@Test("Retries 429 then succeeds on 200")
func retriesOn429() async throws {
    let scripted = ScriptedTransport([429, 200])
    let retrying = RetryingTransport(wrapping: scripted, policy: .init(maxAttempts: 3, baseDelay: 0), sleep: noSleep)
    let (_, resp) = try await retrying.send(URLRequest(url: URL(string: "https://x")!))
    #expect(resp.statusCode == 200)
    #expect(scripted.callCount == 2)
}

@Test("Does not retry 400")
func noRetryOn400() async throws {
    let scripted = ScriptedTransport([400, 200])
    let retrying = RetryingTransport(wrapping: scripted, policy: .init(maxAttempts: 3, baseDelay: 0), sleep: noSleep)
    let (_, resp) = try await retrying.send(URLRequest(url: URL(string: "https://x")!))
    #expect(resp.statusCode == 400)
    #expect(scripted.callCount == 1)
}

@Test("Gives up after maxAttempts on persistent 500")
func gionUpAfterMax() async throws {
    let scripted = ScriptedTransport([500, 500, 500, 500])
    let retrying = RetryingTransport(wrapping: scripted, policy: .init(maxAttempts: 3, baseDelay: 0), sleep: noSleep)
    let (_, resp) = try await retrying.send(URLRequest(url: URL(string: "https://x")!))
    #expect(resp.statusCode == 500)
    #expect(scripted.callCount == 3)
}

@Test("A 429 that says retry-after is retried after exactly that many seconds")
func honorsRetryAfter() async throws {
    let scripted = ScriptedTransport([429, 200], headers: [["retry-after": "7"]])
    let recorder = SleepRecorder()
    let retrying = RetryingTransport(wrapping: scripted, policy: .init(maxAttempts: 3, baseDelay: 0.5, jitter: 0), sleep: recorder.sleep)
    let (_, resp) = try await retrying.send(URLRequest(url: URL(string: "https://x")!))
    #expect(resp.statusCode == 200)
    #expect(recorder.delays == [7])
}

@Test("An overloaded provider (529) is retried like a rate limit")
func retriesOn529() async throws {
    let scripted = ScriptedTransport([529, 200])
    let retrying = RetryingTransport(wrapping: scripted, policy: .init(maxAttempts: 3, baseDelay: 0, jitter: 0), sleep: noSleep)
    let (_, resp) = try await retrying.send(URLRequest(url: URL(string: "https://x")!))
    #expect(resp.statusCode == 200)
    #expect(scripted.callCount == 2)
}

@Test("Without retry-after the wait doubles from baseDelay and stops growing at maxDelay")
func backoffIsCapped() async throws {
    let scripted = ScriptedTransport([500, 500, 500, 500, 500])
    let recorder = SleepRecorder()
    let retrying = RetryingTransport(wrapping: scripted, policy: .init(maxAttempts: 5, baseDelay: 10, maxDelay: 30, jitter: 0), sleep: recorder.sleep)
    let (_, resp) = try await retrying.send(URLRequest(url: URL(string: "https://x")!))
    #expect(resp.statusCode == 500)
    #expect(scripted.callCount == 5)
    #expect(recorder.delays == [10, 20, 30, 30])
}

