import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Production text recognizer backed by Vision. Compiled for the app; not unit-tested.
public struct VisionTextRecognizer: TextRecognizer {
    private let languages: [String]

    /// - Parameter languages: the languages to read, by preference (`"ja-JP"`, `"en-US"`);
    ///   empty leaves Vision to its default.
    public init(languages: [String] = []) {
        self.languages = languages
    }

    public func recognizeLines(in imageData: Data) async throws -> [String] {
        guard let cgImage = Self.decode(imageData) else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if !languages.isEmpty { request.recognitionLanguages = languages }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) } catch { continuation.resume(throwing: error) }
        }
    }

    private static func decode(_ data: Data) -> CGImage? {
        #if canImport(UIKit)
        return UIImage(data: data)?.cgImage
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
}
