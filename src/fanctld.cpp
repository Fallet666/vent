#include "smc_backend.h"
#include "daemon_ipc.h"
#include <iostream>
#include <cstring>
#include <cstdio>
#include <csignal>
#include <chrono>
#include <thread>
#include <atomic>
#include <unordered_map>
#include <vector>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <poll.h>

using namespace mac_fan_control;

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

int main(int argc, char** argv) {
    bool foreground = false;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--foreground") == 0 || strcmp(argv[i], "-f") == 0) {
            foreground = true;
        }
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            std::cerr << "fanctld - macOS Fan Control Daemon\n";
            std::cerr << "Usage: fanctld [options]\n";
            std::cerr << "  -f, --foreground    Run in foreground (don't daemonize)\n";
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

    auto now_ms = []() -> uint64_t {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count();
    };

    // Daemonize
    if (!foreground) {
        pid_t pid = fork();
        if (pid < 0) {
            std::cerr << "Fork failed\n";
            close(server_fd);
            return 1;
        }
        if (pid > 0) {
            _exit(0);
        }
        setsid();
        int dev_null = open("/dev/null", O_RDWR);
        if (dev_null >= 0) {
            dup2(dev_null, 0);
            dup2(dev_null, 1);
            dup2(dev_null, 2);
            close(dev_null);
        }
    }

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    signal(SIGPIPE, SIG_IGN);

    last_heartbeat = now_ms();
    last_reconciliation = now_ms();

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
                                overrides[fan_idx] = speed;
                                response = "OK";
                            } else {
                                response = "ERR Fan not found";
                            }
                            last_heartbeat = now;
                        } else if (cmd == "AUTO" && parts.size() >= 2) {
                            uint32_t fan_idx = std::stoul(parts[1]);
                            // Revert immediately
                            backend->set_fan_manual_mode(fan_idx, false);
                            overrides.erase(fan_idx);
                            last_heartbeat = now;
                            response = "OK";
                        } else if (cmd == "AUTOALL") {
                            for (auto& [idx, _] : overrides) {
                                backend->set_fan_manual_mode(idx, false);
                            }
                            overrides.clear();
                            last_heartbeat = now;
                            response = "OK";
                        } else if (cmd == "HEARTBEAT") {
                            last_heartbeat = now;
                            response = "OK";
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

        // --- Reconciliation (every 300ms) ---
        if (now - last_reconciliation >= RECONCILIATION_INTERVAL_MS) {
            last_reconciliation = now;
            for (auto& [fan_idx, target_speed] : overrides) {
                backend->set_fan_target_speed(fan_idx, target_speed);
            }
        }

        // --- Watchdog (every cycle, check if expired) ---
        if (!overrides.empty() && (now - last_heartbeat) > (uint64_t)WATCHDOG_TIMEOUT_SECONDS * 1000) {
            for (auto& [idx, _] : overrides) {
                backend->set_fan_manual_mode(idx, false);
            }
            overrides.clear();
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
