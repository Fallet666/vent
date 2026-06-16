#include "smc_backend.h"
#include "daemon_ipc.h"
#include "vent_config.h"
#include <iostream>
#include <cstring>
#include <cstdio>
#include <csignal>
#include <chrono>
#include <thread>
#include <atomic>
#include <algorithm>
#include <unordered_map>
#include <vector>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <poll.h>

using namespace vent;

static std::atomic<bool> g_running{true};

static void handle_signal(int) {
    g_running = false;
}

static bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0;
}

struct ClientState {
    int fd;
    std::string buffer;
};

enum class ControlMode {
    Auto,
    ManualRPM,
    AutoTemp,
};

static const char* control_mode_to_string(ControlMode mode) {
    switch (mode) {
        case ControlMode::Auto: return "AUTO";
        case ControlMode::ManualRPM: return "MANUAL_RPM";
        case ControlMode::AutoTemp: return "AUTO_TEMP";
    }
    return "AUTO";
}

static float hottest_temperature(const std::vector<TemperatureInfo>& temperatures) {
    float maximum = 0.0f;
    for (const auto& temperature : temperatures) {
        if (is_temperature_usable(temperature.key, temperature.value)) {
            maximum = std::max(maximum, temperature.value);
        }
    }
    return maximum;
}

static float common_min_speed(const std::vector<FanInfo>& fans) {
    float speed = 0.0f;
    for (const auto& fan : fans) {
        speed = std::max(speed, fan.min_speed);
    }
    return speed;
}

static float common_max_speed(const std::vector<FanInfo>& fans) {
    if (fans.empty()) {
        return 0.0f;
    }
    float speed = fans.front().max_speed;
    for (const auto& fan : fans) {
        speed = std::min(speed, fan.max_speed);
    }
    return speed;
}

static float rpm_for_temperature(float current_temperature, float target_temperature, float min_speed, float max_speed) {
    if (max_speed <= min_speed) {
        return min_speed;
    }
    float normalized = (current_temperature - target_temperature + AUTO_TEMPERATURE_RESPONSE_OFFSET_C) /
        AUTO_TEMPERATURE_FULL_SPEED_SPAN_C;
    normalized = std::clamp(normalized, 0.0f, 1.0f);
    return min_speed + (max_speed - min_speed) * normalized;
}

static bool write_raw_key(SMCBackend& backend, const std::string& key, float value) {
    if (key.size() != 4) {
        return false;
    }

    auto current = backend.read_key(key.c_str());
    if (!current) {
        return false;
    }

    SMCValue write_value{};
    std::strncpy(write_value.key, key.c_str(), 4);
    write_value.data_size = current->data_size;
    write_value.data_type = current->data_type;
    float_to_bytes(value, write_value.bytes, current->data_type, current->data_size);
    return backend.write_key(write_value);
}

int main(int argc, char** argv) {
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            std::cerr << "ventd - macOS Vent Daemon\n";
            std::cerr << "Usage: ventd [options]\n";
            std::cerr << "  -f, --foreground    Accepted for compatibility; daemon always stays in foreground\n";
            std::cerr << "  -h, --help          Show this help\n";
            return 0;
        }
    }

    // Open SMC
    auto backend = create_smc_backend();
    if (!backend) {
        std::cerr << "Failed to open SMC\n";
        return 1;
    }
    std::cerr << "SMC opened: " << backend->get_platform_name() << "\n";

    // Single-instance guard via PID file
    int pid_fd = open(DAEMON_PID_PATH, O_CREAT | O_WRONLY, 0644);
    if (pid_fd >= 0) {
        struct flock fl = {};
        fl.l_type = F_WRLCK;
        fl.l_whence = SEEK_SET;
        if (fcntl(pid_fd, F_SETLK, &fl) < 0) {
            std::cerr << "Another daemon instance is running.\n";
            close(pid_fd);
            return 0;
        }
        // Truncate and write PID
        ftruncate(pid_fd, 0);
        dprintf(pid_fd, "%d\n", getpid());
    }

    // Remove old socket file
    unlink(DAEMON_SOCKET_PATH);

    // Create Unix domain socket
    int server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_fd < 0) {
        std::cerr << "Failed to create socket\n";
        return 1;
    }

    struct sockaddr_un addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, DAEMON_SOCKET_PATH, sizeof(addr.sun_path) - 1);
    addr.sun_path[sizeof(addr.sun_path) - 1] = '\0';

    umask(0);
    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        std::cerr << "Failed to bind socket\n";
        close(server_fd);
        return 1;
    }
    chmod(DAEMON_SOCKET_PATH, 0666);

    if (listen(server_fd, 8) < 0) {
        std::cerr << "Failed to listen on socket\n";
        close(server_fd);
        return 1;
    }

    if (!set_nonblocking(server_fd)) {
        std::cerr << "Failed to set non-blocking\n";
        close(server_fd);
        return 1;
    }

    // Daemon state
    std::unordered_map<uint32_t, float> overrides;
    std::vector<ClientState> clients;
    uint64_t last_heartbeat = 0;
    uint64_t last_reconciliation = 0;
    uint64_t last_temperature_control = 0;
    ControlMode control_mode = ControlMode::Auto;
    float target_temperature = DEFAULT_TARGET_TEMPERATURE_C;
    float last_hottest_temperature = 0.0f;
    float last_auto_temperature_rpm = 0.0f;

    auto now_ms = []() -> uint64_t {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count();
    };

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    signal(SIGPIPE, SIG_IGN);

    last_heartbeat = now_ms();
    last_reconciliation = now_ms();
    last_temperature_control = now_ms();

    // Main loop
    while (g_running) {
        uint64_t now = now_ms();

        // --- Socket I/O ---
        std::vector<struct pollfd> pfds;
        pfds.push_back({server_fd, POLLIN, 0});
        for (auto& c : clients) {
            pfds.push_back({c.fd, POLLIN, 0});
        }

        int poll_ret = poll(pfds.data(), pfds.size(), 50);
        if (poll_ret < 0) {
            if (errno == EINTR) continue;
            break;
        }

        // Accept new connections
        if (pfds[0].revents & POLLIN) {
            while (true) {
                int client_fd = accept(server_fd, nullptr, nullptr);
                if (client_fd < 0) break;
                if (set_nonblocking(client_fd)) {
                    clients.push_back({client_fd, ""});
                } else {
                    close(client_fd);
                }
            }
        }

        // Read from clients
        auto it = clients.begin();
        while (it != clients.end()) {
            int idx = 1 + std::distance(clients.begin(), it);
            bool disconnected = false;

            if (idx < (int)pfds.size() && (pfds[idx].revents & POLLIN)) {
                char buf[4096];
                ssize_t n = read(it->fd, buf, sizeof(buf) - 1);
                if (n > 0) {
                    buf[n] = '\0';
                    it->buffer.append(buf, n);

                    // Process all complete lines
                    size_t pos;
                    while ((pos = it->buffer.find('\n')) != std::string::npos) {
                        std::string line = it->buffer.substr(0, pos);
                        it->buffer.erase(0, pos + 1);

                        // Trim trailing \r
                        if (!line.empty() && line.back() == '\r') {
                            line.pop_back();
                        }

                        auto parts = split_command(line);
                        if (parts.empty()) continue;

                        const std::string& cmd = parts[0];
                        std::string response;

                        if (cmd == "SET" && parts.size() >= 3) {
                            uint32_t fan_idx = std::stoul(parts[1]);
                            float speed = std::stof(parts[2]);
                            control_mode = ControlMode::ManualRPM;
                            overrides[fan_idx] = speed;
                            last_heartbeat = now;
                            response = "OK";
                        } else if (cmd == "SETP" && parts.size() >= 3) {
                            uint32_t fan_idx = std::stoul(parts[1]);
                            float percent = std::stof(parts[2]);
                            // Calculate RPM from percent using min/max
                            auto fan = backend->get_fan(fan_idx);
                            if (fan) {
                                float range = fan->max_speed - fan->min_speed;
                                float speed = fan->min_speed + range * (percent / 100.0f);
                                control_mode = ControlMode::ManualRPM;
                                overrides[fan_idx] = speed;
                                response = "OK";
                            } else {
                                response = "ERR Fan not found";
                            }
                            last_heartbeat = now;
                        } else if (cmd == "SETALL" && parts.size() >= 2) {
                            float speed = std::stof(parts[1]);
                            auto fans = backend->get_all_fans();
                            control_mode = ControlMode::ManualRPM;
                            for (const auto& fan : fans) {
                                overrides[fan.index] = speed;
                            }
                            last_heartbeat = now;
                            response = "OK";
                        } else if (cmd == "WRITE" && parts.size() >= 3) {
                            const std::string& key = parts[1];
                            float value = std::stof(parts[2]);
                            bool ok = write_raw_key(*backend, key, value);
                            response = ok ? "OK" : "ERR Failed to write key";
                        } else if (cmd == "AUTO" && parts.size() >= 2) {
                            uint32_t fan_idx = std::stoul(parts[1]);
                            // Revert immediately
                            bool ok = backend->set_fan_manual_mode(fan_idx, false);
                            overrides.erase(fan_idx);
                            if (overrides.empty()) {
                                control_mode = ControlMode::Auto;
                            }
                            last_heartbeat = now;
                            response = ok ? "OK" : "ERR Failed to set auto mode";
                        } else if (cmd == "AUTOALL") {
                            bool ok = true;
                            auto fans = backend->get_all_fans();
                            for (const auto& fan : fans) {
                                ok = backend->set_fan_manual_mode(fan.index, false) && ok;
                            }
                            for (auto& [idx, _] : overrides) {
                                ok = backend->set_fan_manual_mode(idx, false) && ok;
                            }
                            overrides.clear();
                            control_mode = ControlMode::Auto;
                            last_heartbeat = now;
                            response = ok ? "OK" : "ERR Failed to set auto mode";
                        } else if (cmd == "MODE" && parts.size() >= 2) {
                            if (parts[1] == "AUTO") {
                                bool ok = true;
                                auto fans = backend->get_all_fans();
                                for (const auto& fan : fans) {
                                    ok = backend->set_fan_manual_mode(fan.index, false) && ok;
                                }
                                overrides.clear();
                                control_mode = ControlMode::Auto;
                                response = ok ? "OK" : "ERR Failed to set auto mode";
                            } else if (parts[1] == "MANUAL") {
                                control_mode = ControlMode::ManualRPM;
                                response = "OK";
                            } else if (parts[1] == "TEMP" && parts.size() >= 3) {
                                target_temperature = std::clamp(
                                    std::stof(parts[2]),
                                    MIN_TARGET_TEMPERATURE_C,
                                    MAX_TARGET_TEMPERATURE_C
                                );
                                control_mode = ControlMode::AutoTemp;
                                last_temperature_control = 0;
                                response = "OK";
                            } else {
                                response = "ERR Invalid mode";
                            }
                            last_heartbeat = now;
                        } else if (cmd == "HEARTBEAT") {
                            last_heartbeat = now;
                            response = "OK";
                        } else if (cmd == "VERSION") {
                            response = "VERSION " + std::string(APP_VERSION);
                        } else if (cmd == "MODESTATUS") {
                            response = "MODE " + std::string(control_mode_to_string(control_mode)) + " " +
                                std::to_string(target_temperature) + " " +
                                std::to_string(last_hottest_temperature) + " " +
                                std::to_string(last_auto_temperature_rpm);
                        } else if (cmd == "CONFIG") {
                            response = "CONFIG " + std::to_string(MIN_TARGET_TEMPERATURE_C) + " " +
                                std::to_string(MAX_TARGET_TEMPERATURE_C) + " " +
                                std::to_string(DEFAULT_TARGET_TEMPERATURE_C) + " " +
                                std::to_string(MIN_USABLE_TEMPERATURE_C) + " " +
                                std::to_string(MAX_USABLE_TEMPERATURE_C);
                        } else if (cmd == "FANS") {
                            auto fans = backend->get_all_fans();
                            response = "FANS " + std::to_string(fans.size());
                            for (const auto& fan : fans) {
                                response += "\n" + std::to_string(fan.index) + " " +
                                    std::to_string((int)fan.current_speed) + " " +
                                    std::to_string((int)fan.min_speed) + " " +
                                    std::to_string((int)fan.max_speed) + " " +
                                    std::to_string((int)fan.target_speed) + " " +
                                    std::to_string(fan.manual_mode ? 1 : 0);
                            }
                        } else if (cmd == "TEMPS") {
                            auto temperatures = backend->get_all_temperatures();
                            response = "TEMPS " + std::to_string(temperatures.size());
                            for (const auto& temperature : temperatures) {
                                response += "\n" + temperature.key + " " + std::to_string(temperature.value);
                            }
                        } else if (cmd == "STATUS") {
                            response = "STATUS " + std::to_string(overrides.size());
                            for (auto& [idx, speed] : overrides) {
                                response += "\n" + std::to_string(idx) + " " + std::to_string((int)speed);
                            }
                        } else if (cmd == "QUIT") {
                            response = "BYE";
                            disconnected = true;
                        } else if (cmd == "SHUTDOWN") {
                            response = "OK";
                            // Revert all fans
                            for (auto& [idx, _] : overrides) {
                                backend->set_fan_manual_mode(idx, false);
                            }
                            overrides.clear();
                            g_running = false;
                        } else {
                            response = "ERR Unknown command";
                        }

                        if (!response.empty()) {
                            response += "\n";
                            write(it->fd, response.data(), response.size());
                        }

                        if (disconnected) break;
                    }
                } else {
                    disconnected = true;
                }
            }

            if (disconnected) {
                close(it->fd);
                it = clients.erase(it);
            } else {
                ++it;
            }
        }

        // --- Auto temperature control (every 2 seconds) ---
        if (control_mode == ControlMode::AutoTemp &&
            (now - last_temperature_control >= static_cast<uint64_t>(AUTO_TEMPERATURE_INTERVAL_MS)))
        {
            last_temperature_control = now;
            auto temperatures = backend->get_all_temperatures();
            auto fans = backend->get_all_fans();
            last_hottest_temperature = hottest_temperature(temperatures);
            
            if (last_hottest_temperature > 0.0f && !fans.empty()) {
                float min_speed = common_min_speed(fans);
                float max_speed = common_max_speed(fans);
                last_auto_temperature_rpm = rpm_for_temperature(
                    last_hottest_temperature,
                    target_temperature,
                    min_speed,
                    max_speed
                );
                for (const auto& fan : fans) {
                    overrides[fan.index] = last_auto_temperature_rpm;
                }
            }
        }

        // --- Reconciliation (every 300ms) ---
        if (now - last_reconciliation >= RECONCILIATION_INTERVAL_MS) {
            last_reconciliation = now;
            for (auto& [fan_idx, target_speed] : overrides) {
                bool ok = backend->set_fan_target_speed(fan_idx, target_speed);
                if (!ok) {
                    std::cerr << "reconcile: fan " << fan_idx << " -> " << target_speed
                              << " RPM [FAIL]\n";
                }
            }
        }

        // --- Watchdog (every cycle, check if expired) ---
        if (control_mode == ControlMode::ManualRPM && !overrides.empty() &&
            (now - last_heartbeat) > (uint64_t)WATCHDOG_TIMEOUT_SECONDS * 1000)
        {
            for (auto& [idx, _] : overrides) {
                backend->set_fan_manual_mode(idx, false);
            }
            overrides.clear();
            control_mode = ControlMode::Auto;
            last_heartbeat = now;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }

    // Cleanup all fans on exit
    for (auto& [idx, _] : overrides) {
        backend->set_fan_manual_mode(idx, false);
    }
    overrides.clear();

    for (auto& c : clients) close(c.fd);
    close(server_fd);
    unlink(DAEMON_SOCKET_PATH);

    return 0;
}
