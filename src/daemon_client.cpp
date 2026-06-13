#include "daemon_client.h"
#include "daemon_ipc.h"
#include <iostream>
#include <cstring>
#include <cstdio>
#include <string>
#include <vector>
#include <thread>
#include <chrono>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>

namespace mac_fan_control {

static int connect_to_daemon() {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    struct sockaddr_un addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, DAEMON_SOCKET_PATH, sizeof(addr.sun_path) - 1);
    addr.sun_path[sizeof(addr.sun_path) - 1] = '\0';

    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

bool daemon_is_running() {
    int fd = connect_to_daemon();
    if (fd < 0) return false;
    close(fd);
    return true;
}

bool daemon_send_command(const std::string& command, std::string* response_out) {
    int fd = connect_to_daemon();
    if (fd < 0) return false;

    std::string cmd = command + "\n";
    ssize_t n = write(fd, cmd.data(), cmd.size());
    if (n <= 0) {
        close(fd);
        return false;
    }

    char buf[4096];
    n = read(fd, buf, sizeof(buf) - 1);
    close(fd);

    if (n <= 0) return false;

    buf[n] = '\0';
    std::string resp(buf);

    while (!resp.empty() && (resp.back() == '\n' || resp.back() == '\r')) {
        resp.pop_back();
    }

    if (response_out) {
        *response_out = resp;
    }

    return !resp.empty() && resp.substr(0, 2) == "OK";
}

bool daemon_send_set(uint32_t index, float speed_rpm) {
    std::string cmd = "SET " + std::to_string(index) + " " + std::to_string(speed_rpm);
    return daemon_send_command(cmd);
}

bool daemon_send_set_percent(uint32_t index, float percent) {
    std::string cmd = "SETP " + std::to_string(index) + " " + std::to_string(percent);
    return daemon_send_command(cmd);
}

bool daemon_send_set_all(float speed_rpm) {
    std::string cmd = "SETALL " + std::to_string(speed_rpm);
    return daemon_send_command(cmd);
}

bool daemon_send_write_key(const std::string& key, float value) {
    std::string cmd = "WRITE " + key + " " + std::to_string(value);
    return daemon_send_command(cmd);
}

bool daemon_send_auto(uint32_t index) {
    std::string cmd = "AUTO " + std::to_string(index);
    return daemon_send_command(cmd);
}

bool daemon_send_auto_all() {
    return daemon_send_command("AUTOALL");
}

bool daemon_send_heartbeat() {
    return daemon_send_command("HEARTBEAT");
}

static bool run_with_sudo(const std::string& script_content) {
    const char* home = getenv("HOME");
    if (!home) return false;

    std::string tmp = std::string(home) + "/.fanctl_tmp.sh";
    {
        FILE* f = fopen(tmp.c_str(), "w");
        if (!f) return false;
        fprintf(f, "%s", script_content.c_str());
        fclose(f);
        chmod(tmp.c_str(), 0755);
    }

    std::string cmd = "osascript -e 'do shell script \"" + tmp + "\" with administrator privileges' 2>/dev/null";
    int ret = system(cmd.c_str());
    unlink(tmp.c_str());
    return ret == 0;
}

bool daemon_cmd_install(const std::vector<std::string>& /*args*/) {
    if (daemon_is_running()) {
        std::cout << "Daemon is already running.\n";
        return true;
    }

    std::cout << "Installing fanctld daemon (requires admin privileges)...\n";

    // Get path of fanctld binary
    char self_path[4096];
    uint32_t self_size = sizeof(self_path);
    std::string fanctld_src = "/usr/local/bin/fanctld";

    // Try to find fanctld next to fanctl
    if (_NSGetExecutablePath(self_path, &self_size) == 0) {
        std::string self(self_path);
        auto pos = self.rfind('/');
        if (pos != std::string::npos) {
            std::string dir = self.substr(0, pos + 1);
            std::string sibling = dir + "fanctld";
            if (access(sibling.c_str(), X_OK) == 0) {
                fanctld_src = sibling;
            }
        }
    }

    std::string script =
        "#!/bin/bash\n"
        "set -e\n"
        "# Kill old daemon\n"
        "launchctl bootout system/com.fanctl.daemon 2>/dev/null || true\n"
        "killall fanctld 2>/dev/null || true\n"
        "rm -f '" + std::string(DAEMON_SOCKET_PATH) + "'\n"
        "rm -f '" + std::string(DAEMON_PID_PATH) + "'\n"
        "touch /var/log/fanctl.log /var/log/fanctl.err\n"
        "chmod 644 /var/log/fanctl.log /var/log/fanctl.err\n"
        "\n"
        "# Copy binary\n"
        "cp -f '" + fanctld_src + "' /usr/local/bin/fanctld 2>/dev/null || {\n"
        "    echo 'fanctld binary not found at " + fanctld_src + "'\n"
        "    exit 1\n"
        "}\n"
        "chmod 755 /usr/local/bin/fanctld\n"
        "chown root:wheel /usr/local/bin/fanctld 2>/dev/null || true\n"
        "\n"
        "# Create plist\n"
        "cat > /Library/LaunchDaemons/com.fanctl.daemon.plist << 'PLISTEOF'\n"
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
        "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
        "<plist version=\"1.0\">\n"
        "<dict>\n"
        "    <key>Label</key>\n"
        "    <string>com.fanctl.daemon</string>\n"
        "    <key>ProgramArguments</key>\n"
        "    <array>\n"
        "        <string>/usr/local/bin/fanctld</string>\n"
        "    </array>\n"
        "    <key>RunAtLoad</key>\n"
        "    <true/>\n"
        "    <key>KeepAlive</key>\n"
        "    <true/>\n"
        "    <key>ThrottleInterval</key>\n"
        "    <integer>5</integer>\n"
        "    <key>StandardOutPath</key>\n"
        "    <string>/var/log/fanctl.log</string>\n"
        "    <key>StandardErrorPath</key>\n"
        "    <string>/var/log/fanctl.err</string>\n"
        "</dict>\n"
        "</plist>\n"
        "PLISTEOF\n"
        "chmod 644 /Library/LaunchDaemons/com.fanctl.daemon.plist\n"
        "\n"
        "# Load daemon\n"
        "launchctl bootstrap system /Library/LaunchDaemons/com.fanctl.daemon.plist 2>/dev/null || "
        "launchctl load /Library/LaunchDaemons/com.fanctl.daemon.plist\n"
        "echo 'Daemon installed and started.'\n";

    if (!run_with_sudo(script)) {
        std::cerr << "Installation failed or was cancelled.\n";
        return false;
    }

    // Wait for daemon to start
    for (int i = 0; i < 20; ++i) {
        if (daemon_is_running()) {
            std::cout << "Daemon is running.\n";
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    std::cerr << "Daemon may not have started. Check /var/log/fanctl.log\n";
    return false;
}

bool daemon_cmd_uninstall(const std::vector<std::string>& /*args*/) {
    std::cout << "Uninstalling fanctld daemon (requires admin privileges)...\n";

    std::string script =
        "#!/bin/bash\n"
        "launchctl bootout system/com.fanctl.daemon 2>/dev/null || "
        "launchctl unload /Library/LaunchDaemons/com.fanctl.daemon.plist 2>/dev/null || true\n"
        "killall fanctld 2>/dev/null || true\n"
        "rm -f '" + std::string(DAEMON_SOCKET_PATH) + "'\n"
        "rm -f '" + std::string(DAEMON_PID_PATH) + "'\n"
        "rm -f /Library/LaunchDaemons/com.fanctl.daemon.plist\n"
        "rm -f /var/log/fanctl.log /var/log/fanctl.err\n"
        "echo 'Daemon uninstalled.'\n";

    return run_with_sudo(script);
}

bool daemon_cmd_status(const std::vector<std::string>& /*args*/) {
    bool running = daemon_is_running();
    std::cout << "Daemon: " << (running ? "\033[32mrunning\033[0m" : "\033[31mnot running\033[0m") << "\n";

    if (running) {
        std::string resp;
        daemon_send_command("STATUS", &resp);
        std::cout << resp << "\n";

        // Parse and show formatted status
        if (resp.substr(0, 6) == "STATUS") {
            auto parts = split_command(resp);
            if (parts.size() >= 2) {
                int count = std::stoi(parts[1]);
                std::cout << "Active overrides: " << count << "\n";
            }
        }
    }

    return true;
}

bool daemon_cmd_shutdown(const std::vector<std::string>& /*args*/) {
    if (daemon_send_command("SHUTDOWN")) {
        std::cout << "Shutdown signal sent to daemon.\n";
        for (int i = 0; i < 10; ++i) {
            if (!daemon_is_running()) {
                std::cout << "Daemon stopped.\n";
                return true;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
    } else {
        std::cerr << "Failed to contact daemon.\n";
        return false;
    }
    return true;
}

} // namespace mac_fan_control
