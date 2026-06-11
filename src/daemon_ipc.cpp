#include "daemon_ipc.h"

namespace mac_fan_control {

std::vector<std::string> split_command(const std::string& s) {
    std::vector<std::string> parts;
    std::string current;
    for (char c : s) {
        if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
            if (!current.empty()) {
                parts.push_back(current);
                current.clear();
            }
        } else {
            current += c;
        }
    }
    if (!current.empty()) parts.push_back(current);
    return parts;
}

} // namespace mac_fan_control
