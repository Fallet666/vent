#pragma once

#include "smc_types.h"
#include <memory>
#include <vector>
#include <string>
#include <optional>

namespace vent {

class SMCBackend {
public:
    virtual ~SMCBackend() = default;

    virtual bool initialize() = 0;
    virtual void shutdown() = 0;
    virtual bool is_initialized() const = 0;

    virtual std::optional<SMCValue> read_key(const char* key) = 0;
    virtual bool write_key(const SMCValue& value) = 0;
    virtual SMCKeyInfo get_key_info(const char* key) = 0;
    virtual std::vector<std::string> list_all_keys() = 0;
    virtual uint32_t get_key_count() = 0;

    virtual std::vector<FanInfo> get_all_fans() = 0;
    virtual std::optional<FanInfo> get_fan(uint32_t index) = 0;
    virtual bool set_fan_min_speed(uint32_t index, float speed) = 0;
    virtual bool set_fan_max_speed(uint32_t index, float speed) = 0;
    virtual bool set_fan_target_speed(uint32_t index, float speed) = 0;
    virtual bool set_fan_manual_mode(uint32_t index, bool manual) = 0;

    virtual bool start_persistent_fan_control(uint32_t index, float target_speed) = 0;
    virtual bool stop_persistent_fan_control(uint32_t index) = 0;
    virtual void stop_all_persistent_fan_control() = 0;

    virtual std::vector<TemperatureInfo> get_all_temperatures() = 0;

    virtual std::string get_platform_name() const = 0;
};

std::unique_ptr<SMCBackend> create_smc_backend();

} // namespace vent