import Foundation
import VentGUIModels

var testsRun = 0
var testsPassed = 0

func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

func expect(_ condition: Bool, _ message: String) {
    testsRun += 1
    if !condition {
        fail(message)
    }
    testsPassed += 1
}

func expectNear(_ actual: Double, _ expected: Double, _ tolerance: Double, _ message: String) {
    testsRun += 1
    if abs(actual - expected) > tolerance {
        fputs("FAIL: \(message): expected \(expected), got \(actual)\n", stderr)
        exit(1)
    }
    testsPassed += 1
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    testsRun += 1
    if actual != expected {
        fputs("FAIL: \(message): expected \(expected), got \(actual)\n", stderr)
        exit(1)
    }
    testsPassed += 1
}

func expectNil<T>(_ value: T?, _ message: String) {
    testsRun += 1
    if value != nil {
        fail(message)
    }
    testsPassed += 1
}

func expectNonNil<T>(_ value: T?, _ message: String) {
    testsRun += 1
    if value == nil {
        fail(message)
    }
    testsPassed += 1
}

// ============================================================
// VentMode
// ============================================================

func testVentMode_initFromDaemonValue() {
    expect(VentMode(daemonValue: "AUTO") == .auto, "AUTO")
    expect(VentMode(daemonValue: "MANUAL_RPM") == .manualRPM, "MANUAL_RPM")
    expect(VentMode(daemonValue: "AUTO_TEMP") == .autoTemp, "AUTO_TEMP")
    expect(VentMode(daemonValue: "UNKNOWN") == nil, "UNKNOWN -> nil")
    expect(VentMode(daemonValue: "") == nil, "empty -> nil")
    expect(VentMode(daemonValue: "auto") == nil, "lowercase auto -> nil")
    expect(VentMode(daemonValue: "MANUAL") == nil, "MANUAL (wrong) -> nil")
}

func testVentMode_title() {
    expect(VentMode.auto.title == "Auto", "auto title")
    expect(VentMode.manualRPM.title == "Manual RPM", "manualRPM title")
    expect(VentMode.autoTemp.title == "Auto Temp", "autoTemp title")
}

func testVentMode_rawValue() {
    expect(VentMode.auto.rawValue == "auto", "auto rawValue")
    expect(VentMode.manualRPM.rawValue == "manualRPM", "manualRPM rawValue")
    expect(VentMode.autoTemp.rawValue == "autoTemp", "autoTemp rawValue")
}

// ============================================================
// TemperatureUnit
// ============================================================

func testTemperatureUnit_convert() {
    expectNear(TemperatureUnit.celsius.convert(0), 0, 0.001, "celsius 0")
    expectNear(TemperatureUnit.celsius.convert(100), 100, 0.001, "celsius 100")
    expectNear(TemperatureUnit.fahrenheit.convert(0), 32, 0.001, "fahrenheit 0")
    expectNear(TemperatureUnit.fahrenheit.convert(100), 212, 0.001, "fahrenheit 100")
    expectNear(TemperatureUnit.fahrenheit.convert(-40), -40, 0.001, "fahrenheit -40 (same in both)")
    expectNear(TemperatureUnit.fahrenheit.convert(37), 98.6, 0.1, "fahrenheit 37C = 98.6F")
}

func testTemperatureUnit_symbol() {
    expect(TemperatureUnit.celsius.symbol == "°C", "celsius symbol")
    expect(TemperatureUnit.fahrenheit.symbol == "°F", "fahrenheit symbol")
}

// ============================================================
// Protocol Parsing: VERSION
// ============================================================

func testParseVersion_valid() {
    expect(VentDaemonClient.parseVersion("VERSION 1.2.15") == "1.2.15", "VERSION 1.2.15")
    expect(VentDaemonClient.parseVersion("VERSION 2.0.0") == "2.0.0", "VERSION 2.0.0")
    expect(VentDaemonClient.parseVersion("VERSION 1.2.15-beta") == "1.2.15-beta", "VERSION with suffix")
}

func testParseVersion_invalid() {
    expect(VentDaemonClient.parseVersion("") == nil, "empty")
    expect(VentDaemonClient.parseVersion("VERSION") == nil, "VERSION only")
    expect(VentDaemonClient.parseVersion("VERSIO 1.2.15") == nil, "typo")
    expect(VentDaemonClient.parseVersion("1.2.15") == nil, "no prefix")
    expect(VentDaemonClient.parseVersion("VERSION  ") == " ", "maxSplits=1, no trim -> VERSION + single space")
}

// ============================================================
// Protocol Parsing: FANS
// ============================================================

func testParseFans_valid() {
    let response = "FANS 2\n0 1200 1000 6000 4000 1\n1 1100 800 5500 3500 0"
    guard let fans = VentDaemonClient.parseFans(response) else { fail("parseFans returned nil") }
    expect(fans.count == 2, "2 fans parsed")
    expect(fans[0].index == 0, "fan 0 index")
    expect(fans[0].currentRPM == 1200, "fan 0 currentRPM")
    expect(fans[0].minRPM == 1000, "fan 0 minRPM")
    expect(fans[0].maxRPM == 6000, "fan 0 maxRPM")
    expect(fans[0].targetRPM == 4000, "fan 0 targetRPM")
    expect(fans[0].manualMode == true, "fan 0 manual")
    expect(fans[1].manualMode == false, "fan 1 auto")
}

func testParseFans_singleFan() {
    let response = "FANS 1\n0 1350 1000 6000 1350 0"
    guard let fans = VentDaemonClient.parseFans(response) else { fail("parseFans returned nil") }
    expect(fans.count == 1, "1 fan")
    expect(fans[0].manualMode == false, "manual=false")
}

func testParseFans_invalidHeader() {
    expect(VentDaemonClient.parseFans("FAN 2\n0 1200 1000 6000 4000 1") == nil, "wrong command")
    expect(VentDaemonClient.parseFans("FANS") != nil && VentDaemonClient.parseFans("FANS")!.isEmpty, "FANS only (empty array, not nil)")
    expect(VentDaemonClient.parseFans("") == nil, "empty")
}

func testParseFans_malformedLine() {
    let response = "FANS 2\n0 1200 1000 6000 4000 1\nnot_a_number 1100 800 5500 3500 0"
    guard let fans = VentDaemonClient.parseFans(response) else { fail("parseFans returned nil") }
    expect(fans.count == 1, "malformed line skipped")
}

func testParseFans_insufficientColumns() {
    let response = "FANS 1\n0 1200 1000"
    guard let fans = VentDaemonClient.parseFans(response) else { fail("parseFans returned nil") }
    expect(fans.count == 0, "insufficient columns -> 0 fans")
}

func testParseFans_manualModeEdgeCases() {
    let auto = VentDaemonClient.parseFans("FANS 1\n0 1200 1000 6000 4000 0")!
    let manual = VentDaemonClient.parseFans("FANS 1\n0 1200 1000 6000 4000 1")!
    let nonzero = VentDaemonClient.parseFans("FANS 1\n0 1200 1000 6000 4000 999")!
    expect(auto[0].manualMode == false, "0 -> auto")
    expect(manual[0].manualMode == true, "1 -> manual")
    expect(nonzero[0].manualMode == true, "999 -> manual (non-zero)")
}

// ============================================================
// Protocol Parsing: TEMPS
// ============================================================

func testParseTemperatures_valid() {
    let response = "TEMPS 3\nTC0P 45.5\nTG0P 60.0\nTB0T 25.3"
    guard let temps = VentDaemonClient.parseTemperatures(response) else { fail("parseTemperatures returned nil") }
    expect(temps.count == 3, "3 temperatures")
    expect(temps[0].key == "TC0P", "key TC0P")
    expectNear(temps[0].value, 45.5, 0.01, "TC0P value")
    expect(temps[1].key == "TG0P", "key TG0P")
    expectNear(temps[2].value, 25.3, 0.01, "TB0T value")
}

func testParseTemperatures_empty() {
    let response = "TEMPS 0"
    guard let temps = VentDaemonClient.parseTemperatures(response) else { fail("parseTemperatures returned nil") }
    expect(temps.count == 0, "empty temps")
}

func testParseTemperatures_invalidHeader() {
    expect(VentDaemonClient.parseTemperatures("TEMP 3\nTC0P 45.5") == nil, "wrong command")
    expect(VentDaemonClient.parseTemperatures("") == nil, "empty")
    expect(VentDaemonClient.parseTemperatures("TEMPS") != nil && VentDaemonClient.parseTemperatures("TEMPS")!.isEmpty, "TEMPS only (empty array, not nil)")
}

func testParseTemperatures_malformedLine() {
    let response = "TEMPS 2\nTC0P 45.5\nnot_a_key abc"
    guard let temps = VentDaemonClient.parseTemperatures(response) else { fail("parseTemperatures returned nil") }
    expect(temps.count == 1, "malformed line skipped")
    expect(temps[0].key == "TC0P", "only TC0P")
}

func testParseTemperatures_negativeAndInteger() {
    let neg = VentDaemonClient.parseTemperatures("TEMPS 1\nTC0P -10.5")!
    expectNear(neg[0].value, -10.5, 0.01, "negative temperature")

    let integer = VentDaemonClient.parseTemperatures("TEMPS 1\nTC0P 45")!
    expectNear(integer[0].value, 45, 0.01, "integer temperature")
}

// ============================================================
// Protocol Parsing: MODESTATUS
// ============================================================

func testParseModeStatus_validAuto() {
    let response = "MODE AUTO 0 0 0"
    guard let status = VentDaemonClient.parseModeStatus(response) else { fail("parseModeStatus returned nil") }
    expect(status.mode == .auto, "mode is auto")
    expect(status.targetTemperature == 0, "target temp 0")
    expectNil(status.averageTemperature, "average nil when 0")
    expectNil(status.autoRPM, "autoRPM nil when 0")
}

func testParseModeStatus_validAutoTemp() {
    let response = "MODE AUTO_TEMP 45 42.5 2500"
    guard let status = VentDaemonClient.parseModeStatus(response) else { fail("parseModeStatus returned nil") }
    expect(status.mode == .autoTemp, "mode is autoTemp")
    expect(status.targetTemperature == 45, "target 45")
    expectNonNil(status.averageTemperature, "average non-nil")
    expectNear(status.averageTemperature!, 42.5, 0.01, "average 42.5")
    expectNonNil(status.autoRPM, "autoRPM non-nil")
    expect(status.autoRPM == 2500, "autoRPM 2500")
}

func testParseModeStatus_validManualRPM() {
    let response = "MODE MANUAL_RPM 0 35.0 0"
    guard let status = VentDaemonClient.parseModeStatus(response) else { fail("parseModeStatus returned nil") }
    expect(status.mode == .manualRPM, "mode is manualRPM")
    expect(status.targetTemperature == 0, "target 0")
    expectNonNil(status.averageTemperature, "average non-nil")
    expect(status.autoRPM == nil, "autoRPM nil in manual mode")
}

func testParseModeStatus_invalid() {
    expect(VentDaemonClient.parseModeStatus("") == nil, "empty")
    expect(VentDaemonClient.parseModeStatus("MODE") == nil, "MODE only")
    expect(VentDaemonClient.parseModeStatus("MODE AUTO_TEMP") == nil, "missing fields")
    expect(VentDaemonClient.parseModeStatus("MODE_UNKOWN 45 42.5 2500") == nil, "wrong format")
    expect(VentDaemonClient.parseModeStatus("MODE AUTO_TEMP abc 42.5 2500") == nil, "non-numeric temp")
}

// ============================================================
// Protocol Parsing: CONFIG
// ============================================================

func testParseConfig_valid() {
    let response = "CONFIG 20 95 55 20 130"
    guard let config = VentDaemonClient.parseConfig(response) else { fail("parseConfig returned nil") }
    expect(config.minTargetTemperature == 20, "minTarget")
    expect(config.maxTargetTemperature == 95, "maxTarget")
    expect(config.defaultTargetTemperature == 55, "defaultTarget")
    expect(config.minUsableTemperature == 20, "minUsable")
    expect(config.maxUsableTemperature == 130, "maxUsable")
}

func testParseConfig_invalid() {
    expect(VentDaemonClient.parseConfig("") == nil, "empty")
    expect(VentDaemonClient.parseConfig("CONFIG") == nil, "CONFIG only")
    expect(VentDaemonClient.parseConfig("CONFIG 20") == nil, "only 1 field")
    expect(VentDaemonClient.parseConfig("CONFIGS 20 95 55 20 130") == nil, "typo")
    expect(VentDaemonClient.parseConfig("CONFIG abc 95 55 20 130") == nil, "non-numeric")
}

// ============================================================
// Version Comparison
// ============================================================

func testNormalizedReleaseVersion() {
    expect(VentUtils.normalizedReleaseVersion("1.2.15") == "1.2.15", "plain version")
    expect(VentUtils.normalizedReleaseVersion("v1.2.15") == "1.2.15", "v prefix")
    expect(VentUtils.normalizedReleaseVersion("  v1.2.15  ") == "1.2.15", "whitespace")
    expect(VentUtils.normalizedReleaseVersion("1.2.15-beta") == "1.2.15", "pre-release stripped")
    expect(VentUtils.normalizedReleaseVersion("v2.0.0-rc1") == "2.0.0", "rc stripped")
    expect(VentUtils.normalizedReleaseVersion("1.2") == "1.2", "no patch")
    expect(VentUtils.normalizedReleaseVersion("") == "", "empty string")
}

func testReleaseVersionComponents() {
    expect(VentUtils.releaseVersionComponents("1.2.15") == [1, 2, 15], "3 components")
    expect(VentUtils.releaseVersionComponents("v1.2.15") == [1, 2, 15], "v prefix stripped")
    expect(VentUtils.releaseVersionComponents("2.0") == [2, 0], "2 components")
    expect(VentUtils.releaseVersionComponents("1.2.15-beta") == [1, 2, 15], "pre-release stripped")
    expect(VentUtils.releaseVersionComponents("abc.def.ghi") == [0, 0, 0], "non-numeric -> 0")
    expect(VentUtils.releaseVersionComponents("1.2.3.4.5") == [1, 2, 3, 4, 5], "5 components")
    expect(VentUtils.releaseVersionComponents("") == [], "empty")
}

func testCompareReleaseVersions_equal() {
    expect(VentUtils.compareReleaseVersions("1.2.15", "1.2.15") == .orderedSame, "same versions")
    expect(VentUtils.compareReleaseVersions("v1.2.15", "1.2.15") == .orderedSame, "v prefix same")
    expect(VentUtils.compareReleaseVersions("1.2.15-beta", "1.2.15") == .orderedSame, "pre-release same")
}

func testCompareReleaseVersions_greater() {
    expect(VentUtils.compareReleaseVersions("1.2.16", "1.2.15") == .orderedDescending, "patch greater")
    expect(VentUtils.compareReleaseVersions("1.3.0", "1.2.15") == .orderedDescending, "minor greater")
    expect(VentUtils.compareReleaseVersions("2.0.0", "1.2.15") == .orderedDescending, "major greater")
}

func testCompareReleaseVersions_less() {
    expect(VentUtils.compareReleaseVersions("1.2.14", "1.2.15") == .orderedAscending, "patch less")
    expect(VentUtils.compareReleaseVersions("1.1.0", "1.2.15") == .orderedAscending, "minor less")
    expect(VentUtils.compareReleaseVersions("0.9.0", "1.0.0") == .orderedAscending, "major less")
}

func testCompareReleaseVersions_differentCounts() {
    expect(VentUtils.compareReleaseVersions("1.2", "1.2.0") == .orderedSame, "1.2 == 1.2.0")
    expect(VentUtils.compareReleaseVersions("1.2", "1.2.1") == .orderedAscending, "1.2 < 1.2.1")
    expect(VentUtils.compareReleaseVersions("1.2.1", "1.2") == .orderedDescending, "1.2.1 > 1.2")
}

// ============================================================
// Hottest Temperature Filtering
// ============================================================

func testHottestTemperature_basic() {
    let temps = [
        VentDaemonTemperature(key: "TC0P", value: 45.0),
        VentDaemonTemperature(key: "TG0P", value: 60.0),
        VentDaemonTemperature(key: "TB0T", value: 25.0)
    ]
    let hottest = VentUtils.hottestTemperature(from: temps, minUsable: 20, maxUsable: 130)
    expectNonNil(hottest, "hottest found")
    expectNear(hottest!, 60.0, 0.01, "TG0P is hottest at 60C")
}

func testHottestTemperature_empty() {
    let temps: [VentDaemonTemperature] = []
    expectNil(VentUtils.hottestTemperature(from: temps, minUsable: 20, maxUsable: 130), "empty -> nil")
}

func testHottestTemperature_calibrationExcluded() {
    let temps = [
        VentDaemonTemperature(key: "TC0P", value: 42.0),
        VentDaemonTemperature(key: "PMU_tcal", value: 52.0),
        VentDaemonTemperature(key: "TB0T", value: 35.0)
    ]
    let hottest = VentUtils.hottestTemperature(from: temps, minUsable: 20, maxUsable: 130)
    expectNear(hottest!, 42.0, 0.01, "PMU_tcal (52C) excluded, TC0P (42C) is max usable")
}

func testHottestTemperature_ambientExcluded() {
    let temps = [
        VentDaemonTemperature(key: "TC0P", value: 80.0),
        VentDaemonTemperature(key: "Ta0P", value: 90.0),
        VentDaemonTemperature(key: "Tp0P", value: 95.0)
    ]
    let hottest = VentUtils.hottestTemperature(from: temps, minUsable: 20, maxUsable: 130)
    expectNear(hottest!, 80.0, 0.01, "Ta/Tp sensors excluded")
}

func testHottestTemperature_belowMinExcluded() {
    let temps = [
        VentDaemonTemperature(key: "TC0P", value: 15.0),
        VentDaemonTemperature(key: "TB0T", value: 30.0)
    ]
    let hottest = VentUtils.hottestTemperature(from: temps, minUsable: 20, maxUsable: 130)
    expectNear(hottest!, 30.0, 0.01, "TC0P (15C < minUsable=20) excluded")
}

func testHottestTemperature_atMaxExcluded() {
    let temps = [
        VentDaemonTemperature(key: "TC0P", value: 130.0),
        VentDaemonTemperature(key: "TB0T", value: 30.0)
    ]
    let hottest = VentUtils.hottestTemperature(from: temps, minUsable: 20, maxUsable: 130)
    expectNear(hottest!, 30.0, 0.01, "TC0P at 130C (maxUsable) excluded — exclusive bound")
}

func testHottestTemperature_nanInfExcluded() {
    let nanTemp = VentDaemonTemperature(key: "TC0P", value: Double.nan)
    let infTemp = VentDaemonTemperature(key: "TG0P", value: Double.infinity)
    let normal = VentDaemonTemperature(key: "TB0T", value: 30.0)

    let nanResult = VentUtils.hottestTemperature(from: [nanTemp, normal], minUsable: 20, maxUsable: 130)
    expectNear(nanResult!, 30.0, 0.01, "NaN excluded")

    let infResult = VentUtils.hottestTemperature(from: [infTemp, normal], minUsable: 20, maxUsable: 130)
    expectNear(infResult!, 30.0, 0.01, "Infinity excluded")
}

func testHottestTemperature_calCaseSensitive() {
    let temps = [
        VentDaemonTemperature(key: "TC0P", value: 42.0),
        VentDaemonTemperature(key: "PMU_tcal", value: 52.0),
        VentDaemonTemperature(key: "TCAL", value: 53.0),
        VentDaemonTemperature(key: "calibration", value: 54.0)
    ]
    let hottest = VentUtils.hottestTemperature(from: temps, minUsable: 20, maxUsable: 130)
    expectNear(hottest!, 42.0, 0.01, "all cal/CAL variants excluded")
}

// ============================================================
// VentProfile
// ============================================================

func testVentProfile_codableRoundtrip() {
    let profile = VentProfile(
        id: UUID(),
        name: "Test Profile",
        mode: .autoTemp,
        targetTemperature: 45,
        separateFans: false,
        fanRPMs: [1200, 1300]
    )

    do {
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(VentProfile.self, from: data)
        expect(decoded.id == profile.id, "id preserved")
        expect(decoded.name == profile.name, "name preserved")
        expect(decoded.mode == profile.mode, "mode preserved")
        expect(decoded.targetTemperature == profile.targetTemperature, "temp preserved")
        expect(decoded.separateFans == profile.separateFans, "separateFans preserved")
        expect(decoded.fanRPMs == profile.fanRPMs, "fanRPMs preserved")
    } catch {
        fail("encode/decode threw: \(error)")
    }
}

func testVentProfile_stockProfiles() {
    let quietID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let normalID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let gamingID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let lapID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    let quiet = VentProfile(id: quietID, name: "Quiet", mode: .auto, targetTemperature: 70, separateFans: false, fanRPMs: [])
    let normal = VentProfile(id: normalID, name: "Normal", mode: .autoTemp, targetTemperature: 45, separateFans: false, fanRPMs: [])
    let gaming = VentProfile(id: gamingID, name: "Gaming", mode: .autoTemp, targetTemperature: 55, separateFans: false, fanRPMs: [])
    let lap = VentProfile(id: lapID, name: "Lap", mode: .autoTemp, targetTemperature: 30, separateFans: false, fanRPMs: [])
    let custom = VentProfile(id: UUID(), name: "Custom", mode: .manualRPM, targetTemperature: 0, separateFans: true, fanRPMs: [1000])

    expect(quiet.isStockProfile == true, "quiet is stock")
    expect(normal.isStockProfile == true, "normal is stock")
    expect(gaming.isStockProfile == true, "gaming is stock")
    expect(lap.isStockProfile == true, "lap is stock")
    expect(custom.isStockProfile == false, "custom is not stock")
}

func testVentProfile_customUUIDsNotStock() {
    let customID = UUID()
    let profile = VentProfile(id: customID, name: "Custom", mode: .manualRPM, targetTemperature: 0, separateFans: true, fanRPMs: [1000])
    expect(profile.isStockProfile == false, "random UUID is not stock")
}

// ============================================================
// FanState Equatable
// ============================================================

func testFanState_customEquatable() {
    let fan1 = FanState(index: 0, rpm: 2000, currentRPM: 1950, minRPM: 1000, maxRPM: 6000, manualMode: true)
    let fan1Copy = FanState(index: 0, rpm: 2000, currentRPM: 1950, minRPM: 1000, maxRPM: 6000, manualMode: true)
    let fanDiffRPM = FanState(index: 0, rpm: 2100, currentRPM: 1950, minRPM: 1000, maxRPM: 6000, manualMode: true)
    let fanDiffIndex = FanState(index: 1, rpm: 2000, currentRPM: 1950, minRPM: 1000, maxRPM: 6000, manualMode: true)
    let fanDiffCurrent = FanState(index: 0, rpm: 2000, currentRPM: 1900, minRPM: 1000, maxRPM: 6000, manualMode: true)
    let fanDiffManual = FanState(index: 0, rpm: 2000, currentRPM: 1950, minRPM: 1000, maxRPM: 6000, manualMode: false)

    expect(fan1 == fan1Copy, "identical fans equal")
    expect(fan1 != fanDiffRPM, "different rpm not equal")
    expect(fan1 != fanDiffIndex, "different index not equal")
    expect(fan1 != fanDiffCurrent, "different currentRPM not equal")
    expect(fan1 != fanDiffManual, "different manualMode not equal")
}

func testFanState_idIsIndex() {
    let fan = FanState(index: 3, rpm: 2000, currentRPM: 1950, minRPM: 1000, maxRPM: 6000, manualMode: true)
    expect(fan.id == 3, "fan.id == fan.index")
}

func testFanState_hasValidRange() {
    let fanValid = FanState(index: 0, rpm: 2000, currentRPM: 1950, minRPM: 1000, maxRPM: 6000, manualMode: true)
    let fanSame = FanState(index: 0, rpm: 2000, currentRPM: 1950, minRPM: 6000, maxRPM: 6000, manualMode: true)
    let fanInverted = FanState(index: 0, rpm: 2000, currentRPM: 1950, minRPM: 6000, maxRPM: 1000, manualMode: true)

    expect(fanValid.hasValidRange == true, "normal range valid")
    expect(fanSame.hasValidRange == false, "same min/max not valid")
    expect(fanInverted.hasValidRange == false, "inverted range not valid")
}

// ============================================================
// Main
// ============================================================

func runAllTests() {
testVentMode_title()
testVentMode_rawValue()
testTemperatureUnit_convert()
testTemperatureUnit_symbol()
testParseVersion_valid()
testParseVersion_invalid()
testParseFans_valid()
testParseFans_singleFan()
testParseFans_invalidHeader()
testParseFans_malformedLine()
testParseFans_insufficientColumns()
testParseFans_manualModeEdgeCases()
testParseTemperatures_valid()
testParseTemperatures_empty()
testParseTemperatures_invalidHeader()
testParseTemperatures_malformedLine()
testParseTemperatures_negativeAndInteger()
testParseModeStatus_validAuto()
testParseModeStatus_validAutoTemp()
testParseModeStatus_validManualRPM()
testParseModeStatus_invalid()
testParseConfig_valid()
testParseConfig_invalid()
testNormalizedReleaseVersion()
testReleaseVersionComponents()
testCompareReleaseVersions_equal()
testCompareReleaseVersions_greater()
testCompareReleaseVersions_less()
testCompareReleaseVersions_differentCounts()
testHottestTemperature_basic()
testHottestTemperature_empty()
testHottestTemperature_calibrationExcluded()
testHottestTemperature_ambientExcluded()
testHottestTemperature_belowMinExcluded()
testHottestTemperature_atMaxExcluded()
testHottestTemperature_nanInfExcluded()
testHottestTemperature_calCaseSensitive()
testVentProfile_codableRoundtrip()
testVentProfile_stockProfiles()
testVentProfile_customUUIDsNotStock()
testFanState_customEquatable()
testFanState_idIsIndex()
testFanState_hasValidRange()

print("tests: OK (\(testsPassed)/\(testsRun) assertions passed)")
}

runAllTests()
