import Testing
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
@testable import KakeraServices

/// Vision runs on macOS too, so the adapter is exercised here on a page it must cope with:
/// photographed sideways (a camera held upright writes its orientation into EXIF rather than
/// turning the pixels) and bigger than the recognizer's cap.
@Suite("VisionTextRecognizer")
struct VisionTextRecognizerTests {
    @Test("Reads a page photographed sideways and larger than the cap")
    func readsSidewaysPage() async throws {
        let jpeg = try #require(Self.sidewaysPage(width: 3600, height: 2700))
        let lines = try await VisionTextRecognizer(languages: ["en-US"]).recognizeLines(in: jpeg)
        let text = lines.joined(separator: " ").lowercased()
        #expect(text.contains("serendipity"), "read: \(lines)")
        #expect(text.contains("petrichor"), "read: \(lines)")
    }

    /// A page of text, stored rotated a quarter turn with EXIF orientation 6 — what a camera
    /// held in portrait produces.
    private static func sidewaysPage(width: Int, height: Int) -> Data? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let page = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        page.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        page.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica" as CFString, 160, nil)
        for (row, sentence) in ["The serendipity of a halcyon afternoon", "brought petrichor and quiet diligence."].enumerated() {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: sentence, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
            page.textPosition = CGPoint(x: 150, y: CGFloat(height) * 0.6 - CGFloat(row) * 260)
            CTLineDraw(line, page)
        }
        guard let upright = page.makeImage(),
              let turned = CGContext(data: nil, width: height, height: width, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        turned.translateBy(x: 0, y: CGFloat(width))
        turned.rotate(by: -.pi / 2)
        turned.draw(upright, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let sideways = turned.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, sideways, [kCGImagePropertyOrientation: 6] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
