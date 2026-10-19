import CoreGraphics
import Testing
@testable import KakeraUI

@Suite("Speed dial")
struct SpeedDialTests {
    @Test("Three actions fan out above, diagonally up-left, and to the left of the button")
    func threeActionsFanOut() {
        let spots = (0..<3).map { SpeedDialLayout.offset(index: $0, count: 3, distance: 80) }
        #expect(abs(spots[0].width) < 0.001 && abs(spots[0].height + 80) < 0.001)                  // up
        #expect(abs(spots[1].width + 56.57) < 0.01 && abs(spots[1].height + 56.57) < 0.01)        // up-left
        #expect(abs(spots[2].width + 80) < 0.001 && abs(spots[2].height) < 0.001)                  // left
    }

    @Test("Any number of actions spreads evenly over the same quarter circle")
    func spreadsOverAQuarter() {
        let spots = (0..<5).map { SpeedDialLayout.offset(index: $0, count: 5, distance: 100) }
        for spot in spots {
            #expect(abs((spot.width * spot.width + spot.height * spot.height).squareRoot() - 100) < 0.001)
            #expect(spot.width <= 0.001 && spot.height <= 0.001)
        }
        #expect(SpeedDialLayout.offset(index: 0, count: 1, distance: 70) == CGSize(width: 0, height: -70))
    }
}
