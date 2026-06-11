#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace mac_fan_control {

constexpr const char* DAEMON_SOCKET_PATH = "/tmp/fanctl.sock";
constexpr int WATCHDOG_TIMEOUT_SECONDS = 10;
constexpr int RECONCILIATION_INTERVAL_MS = 300;
constexpr int HEARTBEAT_INTERVAL_MS = 2000;
constexpr int MAX_FANS = 16;

std::vector<std::string> split_command(const std::string& s);

} // namespace mac_fan_control
