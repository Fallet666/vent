#pragma once

#include <array>
#include <string>

namespace vent {

constexpr float MIN_USABLE_TEMPERATURE_C = 20.0f;
constexpr float MAX_USABLE_TEMPERATURE_C = 130.0f;
constexpr float MIN_TARGET_TEMPERATURE_C = 20.0f;
constexpr float MAX_TARGET_TEMPERATURE_C = 95.0f;
constexpr float DEFAULT_TARGET_TEMPERATURE_C = 55.0f;
constexpr float AUTO_TEMPERATURE_RESPONSE_OFFSET_C = 3.0f;
constexpr float AUTO_TEMPERATURE_FULL_SPEED_SPAN_C = 25.0f;
constexpr int AUTO_TEMPERATURE_INTERVAL_MS = 2000;

inline bool is_temperature_key_usable(const std::string& key) {
    return key.rfind("Ta", 0) != 0 && key.rfind("Tp", 0) != 0;
}

inline bool is_temperature_usable(const std::string& key, float value) {
    return value >= MIN_USABLE_TEMPERATURE_C && value < MAX_USABLE_TEMPERATURE_C &&
        is_temperature_key_usable(key);
}

inline constexpr std::array<const char*, 16> KNOWN_TEMPERATURE_KEYS = {
    "TC0P", "TC0E", "TC0F", "TC0D", "TC1C", "TC2C", "TC3C", "TG0P",
    "TG0D", "TG1D", "TG0H", "Tm0P", "TB0T", "Th0H", "Ts0P", "Ts0S"
};

} // namespace vent
