#include "fan_controller.h"
#include "daemon_client.h"
#include "daemon_ipc.h"
#include <iostream>
#include <iomanip>
#include <cstring>
#include <csignal>
#include <thread>
#include <chrono>

using namespace vent;

static volatile sig_atomic_t g_keep_running = 1;

static void handle_signal(int) {
    g_keep_running = 0;
}

static void print_fan_info(const FanInfo& fan) {
    std::cout << "Fan #" << fan.index << ":\n";
    if (!fan.id.empty()) {
        std::cout << "  ID:           " << fan.id << "\n";
    }
    std::cout << "  Current:      " << std::fixed << std::setprecision(0) << fan.current_speed << " RPM\n";
    std::cout << "  Minimum:      " << fan.min_speed << " RPM\n";
    std::cout << "  Maximum:      " << fan.max_speed << " RPM\n";
    std::cout << "  Safe:         " << fan.safe_speed << " RPM\n";
    std::cout << "  Target:       " << fan.target_speed << " RPM\n";
    std::cout << "  Mode:         " << (fan.manual_mode ? "manual" : "auto") << "\n";
}

static void print_temp_info(const TemperatureInfo& temp) {
    std::cout << "  " << std::left << std::setw(6) << temp.key
              << std::fixed << std::setprecision(1) << temp.value << "\u00b0C\n";
}

static void cmd_list(FanController& ctrl) {
    auto fans = ctrl.list_fans();
    if (fans.empty()) {
        std::cerr << "No fans found or SMC not available.\n";
        return;
    }

    std::cout << "Found " << fans.size() << " fan(s):\n\n";
    for (const auto& fan : fans) {
        print_fan_info(fan);
        std::cout << "\n";
    }
}

static void cmd_temps(FanController& ctrl) {
    auto temps = ctrl.list_temperatures();
    if (temps.empty()) {
        std::cerr << "No temperature sensors found.\n";
        return;
    }

    std::cout << "Temperatures (" << temps.size() << " sensors):\n";
    for (const auto& t : temps) {
        print_temp_info(t);
    }

    auto cpu = ctrl.get_cpu_temperature();
    if (cpu) {
        std::cout << "\nCPU temp: " << std::fixed << std::setprecision(1) << *cpu << "\u00b0C\n";
    }

    auto gpu = ctrl.get_gpu_temperature();
    if (gpu) {
        std::cout << "GPU temp: " << std::fixed << std::setprecision(1) << *gpu << "\u00b0C\n";
    }
}

static void cmd_set(FanController& ctrl, int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: ventctl set <fan_index> <speed_rpm>\n";
        return;
    }

    int index = std::atoi(argv[0]);
    float speed = std::atof(argv[1]);

    if (ctrl.set_fan_speed(index, speed)) {
        std::cout << "Fan #" << index << " speed set to " << speed << " RPM (manual mode)\n";
    } else {
        std::cerr << "Failed to set fan #" << index << " speed.\n";
    }
}

static void cmd_set_percent(FanController& ctrl, int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: ventctl set-percent <fan_index> <percent>\n";
        return;
    }

    int index = std::atoi(argv[0]);
    float percent = std::atof(argv[1]);

    if (ctrl.set_fan_speed_percent(index, percent)) {
        std::cout << "Fan #" << index << " speed set to " << percent << "% (manual mode)\n";
    } else {
        std::cerr << "Failed to set fan #" << index << " speed.\n";
    }
}

static void cmd_auto(FanController& ctrl, int argc, char** argv) {
    if (argc < 1) {
        std::cerr << "Usage: ventctl auto <fan_index>\n";
        return;
    }

    int index = std::atoi(argv[0]);

    if (ctrl.set_fan_auto_mode(index)) {
        std::cout << "Fan #" << index << " returned to automatic mode.\n";
    } else {
        std::cerr << "Failed to set fan #" << index << " to auto mode.\n";
    }
}

static void cmd_persist(FanController& ctrl, int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: ventctl persist <fan_index> <speed_rpm>\n";
        return;
    }

    int index = std::atoi(argv[0]);
    float speed = std::atof(argv[1]);

    // Try using daemon first
    if (daemon_is_running()) {
        if (daemon_send_set(index, speed)) {
            std::cout << "Fan #" << index << " persistent control set to " << speed << " RPM via daemon.\n";
            std::cout << "Press Ctrl+C to stop (watchdog reverts after 10s).\n";
            std::signal(SIGINT, handle_signal);
            while (g_keep_running) {
                daemon_send_heartbeat();
                for (int i = 0; i < 20 && g_keep_running; ++i) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                }
            }
            std::cout << "\nDisconnected. Daemon watchdog will revert fan #" << index << " to auto after 10s.\n";
            std::cout << "Use 'ventctl unpersist " << index << "' to revert immediately.\n";
            return;
        }
        std::cerr << "Daemon command failed. Falling back to direct SMC...\n";
    }

    // Fallback: direct SMC persistent control
    if (ctrl.start_persistent_control(index, speed)) {
        std::cout << "Persistent control started for fan #" << index << " at " << speed << " RPM\n";
        std::cout << "Press Ctrl+C to stop.\n";
        std::signal(SIGINT, handle_signal);
        while (g_keep_running) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        ctrl.stop_persistent_control(index);
        std::cout << "\nPersistent control stopped.\n";
    } else {
        std::cerr << "Failed to start persistent control for fan #" << index << ".\n";
    }
}

static void cmd_persist_percent(FanController& ctrl, int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: ventctl persist-percent <fan_index> <percent>\n";
        return;
    }

    int index = std::atoi(argv[0]);
    float percent = std::atof(argv[1]);

    if (daemon_is_running()) {
        if (daemon_send_set_percent(index, percent)) {
            std::cout << "Fan #" << index << " persistent control set to " << percent << "% via daemon.\n";
            std::cout << "Press Ctrl+C to stop (watchdog reverts after 10s).\n";
            std::signal(SIGINT, handle_signal);
            while (g_keep_running) {
                daemon_send_heartbeat();
                for (int i = 0; i < 20 && g_keep_running; ++i) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                }
            }
            std::cout << "\nDisconnected. Daemon watchdog will revert fan #" << index << " to auto after 10s.\n";
            std::cout << "Use 'ventctl unpersist " << index << "' to revert immediately.\n";
            return;
        }
        std::cerr << "Daemon command failed. Falling back to direct SMC...\n";
    }

    // Fallback: convert percent to RPM for direct control
    auto fan = ctrl.get_fan(index);
    if (!fan) {
        std::cerr << "Failed to get fan info.\n";
        return;
    }
    float range = fan->max_speed - fan->min_speed;
    float speed = fan->min_speed + range * (percent / 100.0f);

    if (ctrl.start_persistent_control(index, speed)) {
        std::cout << "Persistent control started for fan #" << index << " at " << percent << "%\n";
        std::cout << "Press Ctrl+C to stop.\n";
        std::signal(SIGINT, handle_signal);
        while (g_keep_running) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        ctrl.stop_persistent_control(index);
        std::cout << "\nPersistent control stopped.\n";
    } else {
        std::cerr << "Failed to start persistent control for fan #" << index << ".\n";
    }
}

static void cmd_unpersist(FanController& ctrl, int argc, char** argv) {
    if (argc < 1) {
        std::cerr << "Usage: ventctl unpersist <fan_index>\n";
        return;
    }

    int index = std::atoi(argv[0]);

    // Try daemon first
    if (daemon_is_running() && daemon_send_auto(index)) {
        std::cout << "Fan #" << index << " persistent control stopped via daemon.\n";
        return;
    }

    // Fallback to direct
    if (ctrl.stop_persistent_control(index)) {
        std::cout << "Persistent control stopped for fan #" << index << ".\n";
    } else {
        // Just try setting auto mode directly
        ctrl.set_fan_auto_mode(index);
        std::cout << "Fan #" << index << " set to auto mode.\n";
    }
}

static void cmd_persist_all(FanController& ctrl, int argc, char** argv) {
    if (argc < 1) {
        std::cerr << "Usage: ventctl persist-all <speed_rpm>\n";
        return;
    }

    float speed = std::atof(argv[0]);

    if (daemon_is_running()) {
        if (daemon_send_set_all(speed)) {
            auto fans = ctrl.list_fans();
            for (const auto& fan : fans) {
                std::cout << "Fan #" << fan.index << " persistent control set to " << speed << " RPM via daemon.\n";
            }
            std::cout << "Press Ctrl+C to stop (watchdog reverts after 10s).\n";
            std::signal(SIGINT, handle_signal);
            while (g_keep_running) {
                daemon_send_heartbeat();
                for (int i = 0; i < 20 && g_keep_running; ++i) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                }
            }
            std::cout << "\nDisconnected. Daemon watchdog will revert all fans to auto after 10s.\n";
            std::cout << "Use 'ventctl unpersist-all' to revert immediately.\n";
            return;
        }
        std::cerr << "Daemon command failed. Falling back to direct SMC...\n";
    }

    // Fallback: start persistent control for each fan
    auto fans = ctrl.list_fans();
    bool any_ok = false;
    for (const auto& fan : fans) {
        if (ctrl.start_persistent_control(fan.index, speed)) {
            std::cout << "Persistent control started for fan #" << fan.index << " at " << speed << " RPM\n";
            any_ok = true;
        }
    }
    if (any_ok) {
        std::cout << "Press Ctrl+C to stop.\n";
        std::signal(SIGINT, handle_signal);
        while (g_keep_running) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        for (const auto& fan : fans) {
            ctrl.stop_persistent_control(fan.index);
        }
        std::cout << "\nPersistent control stopped.\n";
    } else {
        std::cerr << "Failed to start persistent control for any fan.\n";
    }
}

static void cmd_unpersist_all(FanController& ctrl) {
    if (daemon_is_running() && daemon_send_auto_all()) {
        std::cout << "All persistent control stopped via daemon.\n";
        return;
    }
    ctrl.stop_all_persistent_control();
    // Also set auto for all fans directly
    auto fans = ctrl.list_fans();
    for (const auto& fan : fans) {
        ctrl.set_fan_auto_mode(fan.index);
    }
    std::cout << "All persistent control stopped.\n";
}

static void cmd_info(FanController& ctrl) {
    std::cout << "Platform: " << ctrl.get_platform_name() << "\n";

    bool daemon = daemon_is_running();
    std::cout << "Daemon: " << (daemon ? "running" : "not running") << "\n";

    auto fans = ctrl.list_fans();
    std::cout << "Fans: " << fans.size() << "\n";

    auto temps = ctrl.list_temperatures();
    std::cout << "Temperature sensors: " << temps.size() << "\n";
}

static void cmd_read(FanController& ctrl, int argc, char** argv) {
    if (argc < 1) {
        std::cerr << "Usage: ventctl read <key>\n";
        return;
    }

    std::string key = argv[0];
    if (key.length() != 4) {
        std::cerr << "Key must be exactly 4 characters (e.g. F0Ac).\n";
        return;
    }

    auto val = ctrl.read_key(key);
    if (!val) {
        std::cerr << "Failed to read key '" << key << "'.\n";
        return;
    }

    float fval = bytes_to_float(val->bytes, val->data_type, val->data_size);
    std::cout << key << " [" << val->data_size << " bytes, type=";
    {
        char type_str[5] = {0};
        uint32_t type_val = static_cast<uint32_t>(val->data_type);
        for (int i = 0; i < 4; ++i) {
            type_str[i] = static_cast<char>((type_val >> (24 - i * 8)) & 0xFF);
        }
        std::cout << type_str;
    }
    std::cout << "] = " << fval;
    if (key[0] == 'T') {
        std::cout << "\u00b0C";
    }
    std::cout << "\n";

    std::cout << "  Raw bytes: ";
    for (uint32_t i = 0; i < val->data_size; ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0')
                  << static_cast<int>(val->bytes[i]) << " ";
    }
    std::cout << std::dec << "\n";
}

static void cmd_write(FanController& ctrl, int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: ventctl write <key> <value>\n";
        return;
    }

    std::string key = argv[0];
    float value = std::atof(argv[1]);

    if (daemon_is_running()) {
        if (daemon_send_write_key(key, value)) {
            std::cout << "Key '" << key << "' set to " << value << " via daemon\n";
            return;
        }
        std::cerr << "Daemon raw write failed. Falling back to direct SMC write...\n";
    }

    if (ctrl.write_key(key, value)) {
        std::cout << "Key '" << key << "' set to " << value << "\n";
    } else {
        std::cerr << "Failed to write key '" << key << "'. Try running as root or install/start ventd.\n";
    }
}

static void cmd_list_keys(FanController& ctrl) {
    auto keys = ctrl.list_all_keys();
    std::cout << "Total SMC keys: " << keys.size() << "\n";
    for (const auto& key : keys) {
        std::cout << "  " << key << "\n";
    }
}

static void print_usage() {
    std::cerr << "macOS Fan Control Utility v" << APP_VERSION << "\n";
    std::cerr << "Usage: ventctl <command> [args...]\n\n";
    std::cerr << "Commands:\n";
    std::cerr << "  list                             List all fans with speed info\n";
    std::cerr << "  temps                            List all temperature sensors\n";
    std::cerr << "  set <index> <rpm>                 Set fan speed (RPM, single shot)\n";
    std::cerr << "  set-percent <index> <percent>     Set fan speed (0-100%, single shot)\n";
    std::cerr << "  auto <index>                     Return fan to automatic mode\n";
    std::cerr << "  persist <index> <rpm>             Persistent fan control (via daemon or direct)\n";
    std::cerr << "  persist-percent <index> <percent> Persistent fan control (% via daemon or direct)\n";
    std::cerr << "  persist-all <rpm>                 Set ALL fans to same RPM\n";
    std::cerr << "  unpersist <index>                Stop persistent control for fan\n";
    std::cerr << "  unpersist-all                    Stop all persistent control\n";
    std::cerr << "  info                             Show platform, daemon, and sensor info\n";
    std::cerr << "  read <key>                       Read raw SMC key value\n";
    std::cerr << "  write <key> <value>               Write raw SMC key value\n";
    std::cerr << "  list-keys                        List all available SMC keys\n";
    std::cerr << "  monitor                          Monitor fans and temperatures (Ctrl+C to stop)\n";
    std::cerr << "  daemon install                   Install and start the fan control daemon\n";
    std::cerr << "  daemon uninstall                 Stop and remove the fan control daemon\n";
    std::cerr << "  daemon status                    Check daemon status and overrides\n";
    std::cerr << "  daemon shutdown                  Stop the daemon\n";
    std::cerr << "  help                             Show this help\n";
}

int main(int argc, char** argv) {
    if (argc < 2) {
        print_usage();
        return 1;
    }

    std::string cmd = argv[1];
    int cmd_argc = argc - 2;
    char** cmd_argv = cmd_argc > 0 ? argv + 2 : nullptr;

    // Daemon commands don't need SMC backend
    if (cmd == "daemon" && cmd_argc >= 1) {
        std::string sub = cmd_argv[0];
        std::vector<std::string> daemon_args;
        for (int i = 1; i < cmd_argc; ++i) daemon_args.push_back(cmd_argv[i]);

        if (sub == "install") {
            return daemon_cmd_install(daemon_args) ? 0 : 1;
        } else if (sub == "uninstall") {
            return daemon_cmd_uninstall(daemon_args) ? 0 : 1;
        } else if (sub == "status") {
            return daemon_cmd_status(daemon_args) ? 0 : 1;
        } else if (sub == "shutdown") {
            return daemon_cmd_shutdown(daemon_args) ? 0 : 1;
        } else {
            std::cerr << "Unknown daemon command: " << sub << "\n";
            std::cerr << "Usage: ventctl daemon <install|uninstall|status|shutdown>\n";
            return 1;
        }
    }

    // Regular commands need SMC backend
    auto backend = create_smc_backend();
    if (!backend) {
        std::cerr << "Failed to initialize SMC backend.\n";
        std::cerr << "Make sure you're running on a Mac with AppleSMC support.\n";
        std::cerr << "Try running with sudo for full fan control access.\n";
        return 1;
    }

    FanController ctrl(std::move(backend));

    if (cmd == "list") {
        cmd_list(ctrl);
    } else if (cmd == "temps") {
        cmd_temps(ctrl);
    } else if (cmd == "set") {
        cmd_set(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "set-percent") {
        cmd_set_percent(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "auto") {
        cmd_auto(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "persist") {
        cmd_persist(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "persist-percent") {
        cmd_persist_percent(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "persist-all") {
        cmd_persist_all(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "unpersist") {
        cmd_unpersist(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "unpersist-all") {
        cmd_unpersist_all(ctrl);
    } else if (cmd == "info") {
        cmd_info(ctrl);
    } else if (cmd == "read") {
        cmd_read(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "write") {
        cmd_write(ctrl, cmd_argc, cmd_argv);
    } else if (cmd == "list-keys") {
        cmd_list_keys(ctrl);
    } else if (cmd == "help" || cmd == "--help" || cmd == "-h") {
        print_usage();
    } else if (cmd == "monitor") {
        std::cout << "Monitoring fans and temperatures (Ctrl+C to stop):\n\n";
        ctrl.start_monitoring(2000, [](const auto& fans, const auto& temps) {
            std::cout << "\033[2J\033[H";
            std::cout << "=== Fans ===\n";
            for (const auto& fan : fans) {
                std::cout << "  Fan #" << fan.index
                         << " | " << std::fixed << std::setprecision(0)
                         << fan.current_speed << " RPM"
                         << " (target: " << fan.target_speed << " RPM"
                         << ", " << (fan.manual_mode ? "manual" : "auto") << ")"
                         << "\n";
            }
            std::cout << "\n=== Temperatures ===\n";
            for (const auto& t : temps) {
                std::cout << "  " << t.key << ": " << std::fixed << std::setprecision(1)
                         << t.value << "\u00b0C\n";
            }
        });

        std::signal(SIGINT, handle_signal);
        while (g_keep_running) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        ctrl.stop_monitoring();
        std::cout << "\nMonitoring stopped.\n";
    } else {
        std::cerr << "Unknown command: " << cmd << "\n\n";
        print_usage();
        return 1;
    }

    return 0;
}
