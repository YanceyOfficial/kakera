import Foundation
import ImageIO
import Vision

/// Production text recognizer backed by Vision. Compiled for the app; exercised end to end on
/// macOS by `VisionTextRecognizerTests`.
///
/// The picture is decoded through ImageIO at no more than `maxPixelSize` on its long side, turned
/// the way its EXIF orientation says (a camera held upright stores the pixels sideways and the
/// turn in a tag): a 48-megapixel photo neither takes seconds to read nor blows the share
/// extension's memory limit. Recognition runs off the caller's thread — on the main thread it
/// would freeze the screen for the second or two an accurate pass takes.
public struct VisionTextRecognizer: TextRecognizer {
    private let languages: [String]
    private let maxPixelSize: Int

    /// - Parameters:
    ///   - languages: the languages to read, by preference (`"ja-JP"`, `"en-US"`); empty leaves
    ///     Vision to its default.
    ///   - maxPixelSize: the long side the picture is scaled down to before reading, in pixels.
    public init(languages: [String] = [], maxPixelSize: Int = 3000) {
        self.languages = languages
        self.maxPixelSize = maxPixelSize
    }

    public func recognizeLines(in imageData: Data) async throws -> [String] {
        let languages = languages
        let maxPixelSize = maxPixelSize
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = Self.decode(imageData, maxPixelSize: maxPixelSize) else {
                    continuation.resume(returning: [])
                    return
                }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                if !languages.isEmpty { request.recognitionLanguages = languages }
                do {
                    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// The picture upright and no larger than `maxPixelSize` on its long side.
    private static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
