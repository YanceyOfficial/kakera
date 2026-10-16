import CoreGraphics
import Testing
@testable import KaiUI

@Suite("Orientation")
struct KaiOrientationTests {
    @Test("A phone-sized screen stays upright: every iPhone, and an iPhone Duo folded")
    func phoneSizedScreensStayPortrait() {
        #expect(!KaiOrientation.allowsLandscape(screen: CGSize(width: 402, height: 874)))   // iPhone 17
        #expect(!KaiOrientation.allowsLandscape(screen: CGSize(width: 440, height: 956)))   // a Pro Max
        #expect(!KaiOrientation.allowsLandscape(screen: CGSize(width: 466, height: 678)))   // Duo, folded
        #expect(!KaiOrientation.allowsLandscape(screen: CGSize(width: 956, height: 440)))   // already turned
    }

    @Test("A tablet-sized screen turns: an iPhone Duo unfolded")
    func largeScreensTurn() {
        #expect(KaiOrientation.allowsLandscape(screen: CGSize(width: 669, height: 951)))
        #expect(KaiOrientation.allowsLandscape(screen: CGSize(width: 951, height: 669)))
    }
}
