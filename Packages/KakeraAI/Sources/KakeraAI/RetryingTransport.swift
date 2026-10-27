import Foundation

/// Retry configuration for transient failures (rate limits, overload, server errors).
public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    /// The first wait, in seconds; each later wait doubles it, up to `maxDelay`.
    public var baseDelay: Double
    public var maxDelay: Double
    /// Random extra seconds added to a backoff wait, so retries don't all land together.
    public var jitter: Double

    public init(maxAttempts: Int, baseDelay: Double, maxDelay: Double = 30, jitter: Double = 0.1) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    /// Waits of 2, 4, 8, 16 and 30 seconds before giving up — about a minute, the window a
    /// rate limit or an overloaded model usually clears in.
    public static let `default` = RetryPolicy(maxAttempts: 6, baseDelay: 2, maxDelay: 30)
}

/// Wraps a transport and retries rate limits (429), overload (529) and server errors with
/// exponential backoff + jitter, honoring cancellation. When the provider says how long to
/// wait (`retry-after`), that is the wait: retrying sooner only fails again.
public struct RetryingTransport: HTTPTransport {
    private let wrapped: HTTPTransport
    private let policy: RetryPolicy
    private let sleep: @Sendable (Double) async throws -> Void

    public init(
        wrapping wrapped: HTTPTransport,
        policy: RetryPolicy = .default,
        sleep: @escaping @Sendable (Double) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
    ) {
        self.wrapped = wrapped
        self.policy = policy
        self.sleep = sleep
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            let (data, response) = try await wrapped.send(request)
            attempt += 1
            if !Self.isRetriable(response.statusCode) || attempt >= policy.maxAttempts {
                return (data, response)
            }
            try await sleep(Self.retryAfter(response) ?? backoff(attempt: attempt))
        }
    }

    /// 408 and 409 are the request timing out or colliding on the way in; 429 is a rate
    /// limit; 5xx (529 among them, "overloaded") is the provider's side.
    static func isRetriable(_ status: Int) -> Bool {
        status == 408 || status == 409 || status == 429 || (500...599).contains(status)
    }

    /// The provider's own wait, when it gives one as seconds and it's reasonable to honor
    /// (an HTTP date, or a wait of many minutes, falls back to the backoff).
    static func retryAfter(_ response: HTTPURLResponse) -> Double? {
        guard let value = response.value(forHTTPHeaderField: "retry-after")?.trimmingCharacters(in: .whitespaces),
              let seconds = Double(value), seconds > 0, seconds <= 120 else { return nil }
        return seconds
    }

    private func backoff(attempt: Int) -> Double {
        min(policy.baseDelay * pow(2.0, Double(attempt - 1)), policy.maxDelay)
            + (policy.jitter > 0 ? Double.random(in: 0...policy.jitter) : 0)
    }
}
