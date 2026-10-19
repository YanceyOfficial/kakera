import Testing
@testable import KakeraCore

@Test("KakeraCore schema version is readable")
func schemaVersionIsPositive() {
    #expect(KakeraCoreInfo.schemaVersion >= 1)
}
