import CoreGraphics
import Testing
@testable import KakeraUI

@Suite("Orientation")
struct KakeraOrientationTests {
    @Test("A phone-sized screen stays upright: every iPhone, and an iPhone Duo folded")
    func phoneSizedScreensStayPortrait() {
        #expect(!KakeraOrientation.allowsLandscape(screen: CGSize(width: 402, height: 874)))   // iPhone 17
        #expect(!KakeraOrientation.allowsLandscape(screen: CGSize(width: 440, height: 956)))   // a Pro Max
        #expect(!KakeraOrientation.allowsLandscape(screen: CGSize(width: 466, height: 678)))   // Duo, folded
        #expect(!KakeraOrientation.allowsLandscape(screen: CGSize(width: 956, height: 440)))   // already turned
    }

    @Test("A tablet-sized screen turns: an iPhone Duo unfolded")
    func largeScreensTurn() {
        #expect(KakeraOrientation.allowsLandscape(screen: CGSize(width: 669, height: 951)))
        #expect(KakeraOrientation.allowsLandscape(screen: CGSize(width: 951, height: 669)))
    }
}
