#include "daemon_ipc.h"
#include "fan_control_config.h"
#include "smc_types.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

using namespace mac_fan_control;

namespace {

void Fail(const std::string& message) {
    std::cerr << "FAIL: " << message << "\n";
    std::exit(1);
}

void Expect(bool condition, const std::string& message) {
    if (!condition) {
        Fail(message);
    }
}

void ExpectNear(float actual, float expected, float tolerance, const std::string& message) {
    if (std::fabs(actual - expected) > tolerance) {
        Fail(message + ": expected " + std::to_string(expected) + ", got " + std::to_string(actual));
    }
}

void TestSplitCommand() {
    std::vector<std::string> parts = split_command("  MODE\tTEMP 55\r\n");
    Expect(parts.size() == 3, "split_command should ignore repeated whitespace");
    Expect(parts[0] == "MODE", "split_command command token");
    Expect(parts[1] == "TEMP", "split_command subcommand token");
    Expect(parts[2] == "55", "split_command value token");
}

void TestDaemonConstants() {
    Expect(std::string(APP_VERSION).find('.') != std::string::npos,
           "APP_VERSION should be a visible release version");
    Expect(std::string(DAEMON_SOCKET_PATH) == "/tmp/fanctl.sock", "daemon socket path should stay stable");
    Expect(std::string(DAEMON_PID_PATH) == "/tmp/fanctld.pid", "daemon pid path should stay stable");
}

void TestTemperatureConfig() {
    Expect(is_temperature_usable("TC0P", 45.0f), "TC0P at 45C should be usable");
    Expect(!is_temperature_usable("TC0P", MIN_USABLE_TEMPERATURE_C - 1.0f), "low temperature should be ignored");
    Expect(!is_temperature_usable("TC0P", MAX_USABLE_TEMPERATURE_C), "upper temperature bound should be exclusive");
    Expect(!is_temperature_usable("Ta0P", 45.0f), "ambient-like Ta sensors should be ignored");
    Expect(!is_temperature_usable("Tp0P", 45.0f), "suspicious Tp sensors should be ignored");
    Expect(DEFAULT_TARGET_TEMPERATURE_C >= MIN_TARGET_TEMPERATURE_C, "default target should be above minimum");
    Expect(DEFAULT_TARGET_TEMPERATURE_C <= MAX_TARGET_TEMPERATURE_C, "default target should be below maximum");
}

void TestByteConversions() {
    uint8_t bytes[4] = {0, 0, 0, 0};

    float_to_bytes(1.0f, bytes, SMCDataType::UINT8, 1);
    Expect(bytes[0] == 1, "UINT8 write should encode single byte");
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT8, 1), 1.0f, 0.0f, "UINT8 read should decode single byte");

    float_to_bytes(-2.0f, bytes, SMCDataType::SINT8, 1);
    ExpectNear(bytes_to_float(bytes, SMCDataType::SINT8, 1), -2.0f, 0.0f, "SINT8 roundtrip");

    float_to_bytes(258.0f, bytes, SMCDataType::UINT16, 2);
    Expect(bytes[0] == 0x01 && bytes[1] == 0x02, "UINT16 should be big-endian");
    ExpectNear(bytes_to_float(bytes, SMCDataType::UINT16, 2), 258.0f, 0.0f, "UINT16 roundtrip");

    float_to_bytes(-258.0f, bytes, SMCDataType::SINT16, 2);
    ExpectNear(bytes_to_float(bytes, SMCDataType::SINT16, 2), -258.0f, 0.0f, "SINT16 roundtrip");

    float_to_bytes(1234.5f, bytes, SMCDataType::FLT, 4);
    ExpectNear(bytes_to_float(bytes, SMCDataType::FLT, 4), 1234.5f, 0.001f, "FLT roundtrip");
}

} // namespace

int main() {
    TestSplitCommand();
    TestDaemonConstants();
    TestTemperatureConfig();
    TestByteConversions();
    std::cout << "unit_tests: OK\n";
    return 0;
}
