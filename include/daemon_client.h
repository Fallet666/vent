#pragma once

#include <string>
#include <cstdint>
#include <vector>

namespace vent {

// Check if daemon is running
bool daemon_is_running();

// Low-level: send command and get response
bool daemon_send_command(const std::string& command, std::string* response_out = nullptr);

// High-level fan control via daemon
bool daemon_send_set(uint32_t index, float speed_rpm);
bool daemon_send_set_percent(uint32_t index, float percent);
bool daemon_send_set_all(float speed_rpm);
bool daemon_send_write_key(const std::string& key, float value);
bool daemon_send_auto(uint32_t index);
bool daemon_send_auto_all();
bool daemon_send_heartbeat();

// Daemon lifecycle
bool daemon_cmd_install(const std::vector<std::string>& args);
bool daemon_cmd_uninstall(const std::vector<std::string>& args);
bool daemon_cmd_status(const std::vector<std::string>& args);
bool daemon_cmd_shutdown(const std::vector<std::string>& args);

} // namespace vent
