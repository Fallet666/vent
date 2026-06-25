#include "daemon_ipc.h"
#include "vent_config.h"
#include "smc_types.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

using namespace vent;

namespace {

int tests_run = 0;
int tests_passed = 0;

void Fail(const std::string& message) {
    std::cerr << "FAIL: " << message << "\n";
    std::exit(1);
}

void Expect(bool condition, const std::string& message) {
    tests_run++;
    if (!condition) {
        Fail(message);
    }
    tests_passed++;
}

void ExpectNear(float actual, float expected, float tolerance, const std::string& message) {
    tests_run++;
    if (std::fabs(actual - expected) > tolerance) {
        Fail(message + ": expected " + std::to_string(expected) + ", got " + std::to_string(actual));
    }
    tests_passed++;
}

// ============================================================
// split_command tests
// ============================================================

void TestSplitCommand_Basic() {
    auto parts = split_command("SETALL 3000");
    Expect(parts.size() == 2, "SETALL 3000 => 2 parts");
    Expect(parts[0] == "SETALL", "first token is SETALL");
    Expect(parts[1] == "3000", "second token is 3000");
}

void TestSplitCommand_MultipleSpaces() {
    auto parts = split_command("  MODE\tTEMP 55\r\n");
    Expect(parts.size() == 3, "whitespace collapse => 3 parts");
    Expect(parts[0] == "MODE", "token 0");
    Expect(parts[1] == "TEMP", "token 1");
    Expect(parts[2] == "55", "token 2");
}

void TestSplitCommand_Empty() {
    auto parts = split_command("");
    Expect(parts.empty(), "empty string => no parts");
}

void TestSplitCommand_SingleToken() {
    auto parts = split_command("HEARTBEAT");
    Expect(parts.size() == 1, "single token");
    Expect(parts[0] == "HEARTBEAT", "HEARTBEAT token");
}

void TestSplitCommand_TrailingWhitespace() {
    auto parts = split_command("FANS  \n");
    Expect(parts.size() == 1, "trailing whitespace ignored");
    Expect(parts[0] == "FANS", "FANS token");
}

void TestSplitCommand_AllWhitespace() {
    auto parts = split_command("   \t  \n  ");
    Expect(parts.empty(), "all whitespace => no parts");
}

// ============================================================
// daemon_ipc.h constants
// ============================================================

void TestDaemonConstants() {
    Expect(std::string(APP_VERSION).find('.') != std::string::npos,
           "APP_VERSION should contain a dot");
    Expect(std::string(DAEMON_SOCKET_PATH) == "/tmp/ventd.sock",
           "socket path stable");
    Expect(std::string(DAEMON_PID_PATH) == "/tmp/ventd.pid",
           "pid path stable");
    Expect(WATCHDOG_TIMEOUT_SECONDS == 10, "watchdog timeout 10s");
    Expect(RECONCILIATION_INTERVAL_MS == 300, "reconciliation 300ms");
    Expect(MAX_FANS == 16, "max fans 16");
}

// ============================================================
// vent_config.h temperature tests
// ============================================================

void TestTemperatureConfig_Usable() {
    Expect(is_temperature_usable("TC0P", 45.0f), "TC0P 45C usable");
    Expect(is_temperature_usable("TG0P", 80.0f), "TG0P 80C usable");
    Expect(is_temperature_usable("TB0T", 25.0f), "TB0T 25C usable");
    Expect(is_temperature_usable("Ts0P", 100.0f), "Ts0P 100C usable");
}

void TestTemperatureConfig_Boundaries() {
    Expect(!is_temperature_usable("TC0P", MIN_USABLE_TEMPERATURE_C - 0.1f),
           "below min => not usable");
    Expect(is_temperature_usable("TC0P", MIN_USABLE_TEMPERATURE_C),
           "at min => usable");
    Expect(is_temperature_usable("TC0P", MAX_USABLE_TEMPERATURE_C - 0.1f),
           "just below max => usable");
    Expect(!is_temperature_usable("TC0P", MAX_USABLE_TEMPERATURE_C),
           "at max => not usable (exclusive)");
}

void TestTemperatureConfig_ExcludedKeys() {
    Expect(!is_temperature_usable("Ta0P", 45.0f), "Ta prefix excluded");
    Expect(!is_temperature_usable("Tp0P", 45.0f), "Tp prefix excluded");
    Expect(!is_temperature_usable("TaAB", 50.0f), "Ta prefix any suffix excluded");
    Expect(!is_temperature_usable("TpCD", 50.0f), "Tp prefix any suffix excluded");
}

void TestTemperatureConfig_CalibrationExcluded() {
    Expect(!is_temperature_usable("PMU_tcal", 52.0f), "cal in key excluded");
    Expect(!is_temperature_usable("TCAL", 50.0f), "CAL uppercase excluded");
    Expect(!is_temperature_usable("calibration", 50.0f), "cal lowercase start excluded");
}

void TestTemperatureConfig_KeyUsable() {
    Expect(is_temperature_key_usable("TC0P"), "TC0P key usable");
    Expect(is_temperature_key_usable("TG0P"), "TG0P key usable");
    Expect(!is_temperature_key_usable("Ta0P"), "Ta0P key not usable");
    Expect(!is_temperature_key_usable("Tp0P"), "Tp0P key not usable");
    Expect(!is_temperature_key_usable("PMU_tcal"), "PMU_tcal key not usable");
}

void TestTemperatureConfig_Constants() {
    Expect(DEFAULT_TARGET_TEMPERATURE_C >= MIN_TARGET_TEMPERATURE_C,
           "default >= min target");
    Expect(DEFAULT_TARGET_TEMPERATURE_C <= MAX_TARGET_TEMPERATURE_C,
           "default <= max target");
    Expect(MIN_USABLE_TEMPERATURE_C > 0.0f, "min usable is positive");
    Expect(MAX_USABLE_TEMPERATURE_C > MIN_USABLE_TEMPERATURE_C, "max > min usable");
    Expect(AUTO_TEMPERATURE_RESPONSE_OFFSET_C > 0.0f, "response offset positive");
    Expect(AUTO_TEMPERATURE_FULL_SPEED_SPAN_C > 0.0f, "full speed span positive");
}

void TestTemperatureConfig_KnownKeysCount() {
    Expect(KNOWN_TEMPERATURE_KEYS.size() == 16, "16 known temperature keys");
}

// ============================================================
// smc_types.h roundtrip tests
// ============================================================

void TestByteConversions_UINT8() {
    uint8_t bytes[4] = {0};
    float_to_bytes(0.0f, bytes, SMCDataType::UINT8, 1);
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT8, 1), 0.0f, 0.0f, "UINT8 zero");

    float_to_bytes(255.0f, bytes, SMCDataType::UINT8, 1);
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT8, 1), 255.0f, 0.0f, "UINT8 max");

    float_to_bytes(42.0f, bytes, SMCDataType::UINT8, 1);
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT8, 1), 42.0f, 0.0f, "UINT8 arbitrary");
}

void TestByteConversions_SINT8() {
    uint8_t bytes[4] = {0};
    float_to_bytes(0.0f, bytes, SMCDataType::SINT8, 1);
    ExpectNear(bytes_to_float(bytes, SMCDataType::SINT8, 1), 0.0f, 0.0f, "SINT8 zero");

    float_to_bytes(-128.0f, bytes, SMCDataType::SINT8, 1);
    ExpectNear(bytes_to_float(bytes, SMCDataType::SINT8, 1), -128.0f, 0.0f, "SINT8 min");

    float_to_bytes(-2.0f, bytes, SMCDataType::SINT8, 1);
    ExpectNear(bytes_to_float(bytes, SMCDataType::SINT8, 1), -2.0f, 0.0f, "SINT8 negative");
}

void TestByteConversions_UINT16() {
    uint8_t bytes[4] = {0};
    float_to_bytes(0.0f, bytes, SMCDataType::UINT16, 2);
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT16, 2), 0.0f, 0.0f, "UINT16 zero");

    float_to_bytes(256.0f, bytes, SMCDataType::UINT16, 2);
    Expect(bytes[0] == 0x01 && bytes[1] == 0x00, "UINT16 256 big-endian");
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT16, 2), 256.0f, 0.0f, "UINT16 256 roundtrip");

    float_to_bytes(258.0f, bytes, SMCDataType::UINT16, 2);
    Expect(bytes[0] == 0x01 && bytes[1] == 0x02, "UINT16 258 big-endian");
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT16, 2), 258.0f, 0.0f, "UINT16 258 roundtrip");
}

void TestByteConversions_SINT16() {
    uint8_t bytes[4] = {0};
    float_to_bytes(-258.0f, bytes, SMCDataType::SINT16, 2);
    ExpectNear(bytes_to_float(bytes, SMCDataType::SINT16, 2), -258.0f, 0.0f, "SINT16 roundtrip");

    float_to_bytes(32767.0f, bytes, SMCDataType::SINT16, 2);
    ExpectNear(bytes_to_float(bytes, SMCDataType::SINT16, 2), 32767.0f, 0.0f, "SINT16 max positive");
}

void TestByteConversions_UINT32() {
    uint8_t bytes[4] = {0};
    float_to_bytes(100000.0f, bytes, SMCDataType::UINT32, 4);
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT32, 4), 100000.0f, 0.0f, "UINT32 roundtrip");
}

void TestByteConversions_FLT() {
    uint8_t bytes[4] = {0};
    float_to_bytes(1234.5f, bytes, SMCDataType::FLT, 4);
    ExpectNear(bytes_to_float(bytes, SMCDataType::FLT, 4), 1234.5f, 0.001f, "FLT roundtrip");

    float_to_bytes(-0.25f, bytes, SMCDataType::FLT, 4);
    ExpectNear(bytes_to_float(bytes, SMCDataType::FLT, 4), -0.25f, 0.001f, "FLT negative");
}

void TestByteConversions_PWM() {
    uint8_t bytes[4] = {0};
    float_to_bytes(50.0f, bytes, SMCDataType::PWM, 2);
    float read_back = bytes_to_float(bytes, SMCDataType::PWM, 2);
    ExpectNear(read_back, 50.0f, 0.1f, "PWM 50% roundtrip");

    float_to_bytes(0.0f, bytes, SMCDataType::PWM, 2);
    ExpectNear(bytes_to_float(bytes, SMCDataType::PWM, 2), 0.0f, 0.1f, "PWM 0%");

    float_to_bytes(99.0f, bytes, SMCDataType::PWM, 2);
    ExpectNear(bytes_to_float(bytes, SMCDataType::PWM, 2), 99.0f, 0.1f, "PWM 99%");
}

void TestByteConversions_SP78() {
    uint8_t bytes[4] = {0x01, 0x00, 0, 0};
    float read_back = bytes_to_float(bytes, SMCDataType::SP78, 2);
    ExpectNear(read_back, 1.0f, 0.01f, "SP78 read 1.0 from raw bytes");

    uint8_t bytes2[4] = {0, 0, 0, 0};
    ExpectNear(bytes_to_float(bytes2, SMCDataType::SP78, 2), 0.0f, 0.01f, "SP78 zero");
}

void TestByteConversions_SP96() {
    uint8_t bytes[4] = {0x06, 0x40, 0, 0};
    ExpectNear(bytes_to_float(bytes, SMCDataType::SP96, 2), 25.0f, 0.1f, "SP96 read 25.0");
}

void TestByteConversions_SPB4() {
    uint8_t bytes[4] = {0x06, 0x40, 0, 0};
    ExpectNear(bytes_to_float(bytes, SMCDataType::SPB4, 2), 100.0f, 0.1f, "SPB4 read 100.0");
}

void TestByteConversions_FPE2() {
    uint8_t bytes[4] = {0x01, 0x90, 0, 0};
    ExpectNear(bytes_to_float(bytes, SMCDataType::FPE2, 2), 100.0f, 0.1f, "FPE2 read 100.0");
}

void TestByteConversions_FP88() {
    uint8_t bytes[4] = {0x32, 0x00, 0, 0};
    ExpectNear(bytes_to_float(bytes, SMCDataType::FP88, 2), 50.0f, 0.1f, "FP88 read 50.0");
}

void TestByteConversions_FPA6() {
    uint8_t bytes[4] = {0x08, 0x00, 0, 0};
    ExpectNear(bytes_to_float(bytes, SMCDataType::FPA6, 2), 32.0f, 0.1f, "FPA6 read 32.0");
}

void TestByteConversions_FPC4() {
    uint8_t bytes[4] = {0x00, 0x80, 0, 0};
    ExpectNear(bytes_to_float(bytes, SMCDataType::FPC4, 2), 8.0f, 0.1f, "FPC4 read 8.0");
}

void TestByteConversions_SPF0() {
    uint8_t bytes[4] = {0x03, 0xE8, 0, 0};
    ExpectNear(bytes_to_float(bytes, SMCDataType::SPF0, 2), 1000.0f, 0.0f, "SPF0 read 1000");
}

void TestByteConversions_ZeroSize() {
    uint8_t bytes[4] = {42, 42, 42, 42};
    float_to_bytes(1.0f, bytes, SMCDataType::UINT8, 0);
    Expect(bytes[0] == 42, "zero size write should not modify bytes");
    Expect(bytes_to_float(bytes, SMCDataType::UINT8, 0) == 0.0f, "zero size read returns 0");
}

void TestByteConversions_UnknownType() {
    uint8_t bytes[4] = {0};
    float_to_bytes(1.0f, bytes, SMCDataType::UNKNOWN, 4);
    Expect(bytes_to_float(bytes, SMCDataType::UNKNOWN, 4) == 0.0f, "unknown type returns 0");
}

// ============================================================
// smc_error_to_string tests
// ============================================================

void TestSMCErrorToString() {
    Expect(smc_error_to_string(SMCError::SUCCESS) == "Success", "SUCCESS string");
    Expect(smc_error_to_string(SMCError::NOT_FOUND) == "Not found", "NOT_FOUND string");
    Expect(smc_error_to_string(SMCError::PERMISSION_DENIED) == "Permission denied", "PERMISSION string");
    Expect(smc_error_to_string(SMCError::INVALID_ARGUMENT) == "Invalid argument", "INVALID string");
    Expect(smc_error_to_string(SMCError::IO_ERROR) == "I/O error", "IO_ERROR string");
    Expect(smc_error_to_string(SMCError::KEY_NOT_FOUND) == "Key not found", "KEY_NOT_FOUND string");
    Expect(smc_error_to_string(SMCError::DATA_SIZE_MISMATCH) == "Data size mismatch", "DATA_SIZE string");
    Expect(smc_error_to_string(SMCError::UNSUPPORTED_PLATFORM) == "Unsupported platform", "UNSUPPORTED string");
    Expect(smc_error_to_string(SMCError::UNKNOWN) == "Unknown error", "UNKNOWN string");
}

// ============================================================
// string_to_data_type tests
// ============================================================

void TestStringToDataType() {
    Expect(string_to_data_type("ui8 ") == SMCDataType::UINT8, "ui8 -> UINT8");
    Expect(string_to_data_type("ui16") == SMCDataType::UINT16, "ui16 -> UINT16");
    Expect(string_to_data_type("ui32") == SMCDataType::UINT32, "ui32 -> UINT32");
    Expect(string_to_data_type("si8 ") == SMCDataType::SINT8, "si8 -> SINT8");
    Expect(string_to_data_type("si16") == SMCDataType::SINT16, "si16 -> SINT16");
    Expect(string_to_data_type("flt ") == SMCDataType::FLT, "flt -> FLT");
    Expect(string_to_data_type("sp78") == SMCDataType::SP78, "sp78 -> SP78");
    Expect(string_to_data_type("fpe2") == SMCDataType::FPE2, "fpe2 -> FPE2");
    Expect(string_to_data_type(nullptr) == SMCDataType::UNKNOWN, "null -> UNKNOWN");
    Expect(string_to_data_type("") == SMCDataType::UNKNOWN, "empty string -> UNKNOWN");
}

// ============================================================
// SMCValue / SMCKeyInfo defaults
// ============================================================

void TestSMCValueDefaults() {
    SMCValue val;
    Expect(val.key[0] == '\0', "default key is empty");
    Expect(val.data_size == 0, "default data_size is 0");
    Expect(val.data_type == SMCDataType::UNKNOWN, "default data_type is UNKNOWN");
}

void TestFanInfoDefaults() {
    FanInfo fan;
    Expect(fan.index == 0, "default index 0");
    Expect(fan.current_speed == 0.0f, "default current_speed 0");
    Expect(fan.min_speed == 0.0f, "default min_speed 0");
    Expect(fan.max_speed == 0.0f, "default max_speed 0");
    Expect(!fan.manual_mode, "default manual_mode false");
}

void TestTemperatureInfoDefaults() {
    TemperatureInfo temp;
    Expect(temp.key.empty(), "default key is empty");
    Expect(temp.value == 0.0f, "default value is 0");
}

} // namespace

int main() {
    // split_command
    TestSplitCommand_Basic();
    TestSplitCommand_MultipleSpaces();
    TestSplitCommand_Empty();
    TestSplitCommand_SingleToken();
    TestSplitCommand_TrailingWhitespace();
    TestSplitCommand_AllWhitespace();

    // daemon constants
    TestDaemonConstants();

    // temperature config
    TestTemperatureConfig_Usable();
    TestTemperatureConfig_Boundaries();
    TestTemperatureConfig_ExcludedKeys();
    TestTemperatureConfig_CalibrationExcluded();
    TestTemperatureConfig_KeyUsable();
    TestTemperatureConfig_Constants();
    TestTemperatureConfig_KnownKeysCount();

    // byte conversions - all types
    TestByteConversions_UINT8();
    TestByteConversions_SINT8();
    TestByteConversions_UINT16();
    TestByteConversions_SINT16();
    TestByteConversions_UINT32();
    TestByteConversions_FLT();
    TestByteConversions_PWM();
    TestByteConversions_SP78();
    TestByteConversions_SP96();
    TestByteConversions_SPB4();
    TestByteConversions_FPE2();
    TestByteConversions_FP88();
    TestByteConversions_FPA6();
    TestByteConversions_FPC4();
    TestByteConversions_SPF0();
    TestByteConversions_ZeroSize();
    TestByteConversions_UnknownType();

    // SMC error strings
    TestSMCErrorToString();

    // string_to_data_type
    TestStringToDataType();

    // struct defaults
    TestSMCValueDefaults();
    TestFanInfoDefaults();
    TestTemperatureInfoDefaults();

    std::cout << "unit_tests: OK (" << tests_passed << " assertions)\n";
    return 0;
}
