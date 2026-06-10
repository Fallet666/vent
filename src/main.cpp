#include "fan_controller.h"
#include <iostream>
#include <iomanip>
#include <cstring>
#include <csignal>
#include <thread>
#include <chrono>

using namespace mac_fan_control;

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
              << std::fixed << std::setprecision(1) << temp.value << "°C\n";
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
        std::cout << "\nCPU temp: " << std::fixed << std::setprecision(1) << *cpu << "°C\n";
    }

    auto gpu = ctrl.get_gpu_temperature();
    if (gpu) {
        std::cout << "GPU temp: " << std::fixed << std::setprecision(1) << *gpu << "°C\n";
    }
}

static void cmd_set(FanController& ctrl, int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: fanctl set <fan_index> <speed_rpm>\n";
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
        std::cerr << "Usage: fanctl set-percent <fan_index> <percent>\n";
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
        std::cerr << "Usage: fanctl auto <fan_index>\n";
        return;
    }

    int index = std::atoi(argv[0]);

    if (ctrl.set_fan_auto_mode(index)) {
        std::cout << "Fan #" << index << " returned to automatic mode.\n";
    } else {
        std::cerr << "Failed to set fan #" << index << " to auto mode.\n";
    }
}

static void cmd_info(FanController& ctrl) {
    std::cout << "Platform: " << ctrl.get_platform_name() << "\n";

    auto fans = ctrl.list_fans();
    std::cout << "Fans: " << fans.size() << "\n";

    auto temps = ctrl.list_temperatures();
    std::cout << "Temperature sensors: " << temps.size() << "\n";
}

static void cmd_read(FanController& ctrl, int argc, char** argv) {
    if (argc < 1) {
        std::cerr << "Usage: fanctl read <key>\n";
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
        std::cout << "°C";
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
        std::cerr << "Usage: fanctl write <key> <value>\n";
        return;
    }

    std::string key = argv[0];
    float value = std::atof(argv[1]);

    if (ctrl.write_key(key, value)) {
        std::cout << "Key '" << key << "' set to " << value << "\n";
    } else {
        std::cerr << "Failed to write key '" << key << "'.\n";
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
    std::cerr << "macOS Fan Control Utility v1.0.0\n";
    std::cerr << "Usage: fanctl <command> [args...]\n\n";
    std::cerr << "Commands:\n";
    std::cerr << "  list                             List all fans with speed info\n";
    std::cerr << "  temps                            List all temperature sensors\n";
    std::cerr << "  set <index> <rpm>                 Set fan speed (RPM, manual mode)\n";
    std::cerr << "  set-percent <index> <percent>     Set fan speed (0-100%, manual mode)\n";
    std::cerr << "  auto <index>                     Return fan to automatic mode\n";
    std::cerr << "  info                             Show platform and sensor info\n";
    std::cerr << "  read <key>                       Read raw SMC key value\n";
    std::cerr << "  write <key> <value>               Write raw SMC key value\n";
    std::cerr << "  list-keys                        List all available SMC keys\n";
    std::cerr << "  monitor                          Monitor fans and temperatures (Ctrl+C to stop)\n";
    std::cerr << "  help                             Show this help\n";
}

int main(int argc, char** argv) {
    if (argc < 2) {
        print_usage();
        return 1;
    }

    auto backend = create_smc_backend();
    if (!backend) {
        std::cerr << "Failed to initialize SMC backend.\n";
        std::cerr << "Make sure you're running on a Mac with AppleSMC support.\n";
        std::cerr << "Try running with sudo for full fan control access.\n";
        return 1;
    }

    FanController ctrl(std::move(backend));
    std::string cmd = argv[1];
    int cmd_argc = argc - 2;
    char** cmd_argv = cmd_argc > 0 ? argv + 2 : nullptr;

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
            std::cout << "\033[2J\033[H";  // Clear screen
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
                         << t.value << "°C\n";
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