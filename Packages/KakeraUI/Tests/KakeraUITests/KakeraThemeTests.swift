import Testing
@testable import KakeraUI

@Test("Hex splits into normalized sRGB components")
func hexComponents() {
    let tokiwa = KakeraColor.rgbComponents(hex: 0x1B813E)
    #expect(abs(tokiwa.red - 27.0 / 255.0) < 1e-9)
    #expect(abs(tokiwa.green - 129.0 / 255.0) < 1e-9)
    #expect(abs(tokiwa.blue - 62.0 / 255.0) < 1e-9)

    let white = KakeraColor.rgbComponents(hex: 0xFFFFFF)
    #expect(white.red == 1.0 && white.green == 1.0 && white.blue == 1.0)

    let black = KakeraColor.rgbComponents(hex: 0x000000)
    #expect(black.red == 0.0 && black.green == 0.0 && black.blue == 0.0)
}
