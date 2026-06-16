#pragma once

#include "smc_types.h"
#include "smc_backend.h"
#include <memory>
#include <vector>
#include <string>
#include <functional>

namespace vent {

class FanController {
public:
    explicit FanController(std::unique_ptr<SMCBackend> backend);
    ~FanController() = default;

    bool is_available() const { return backend_ != nullptr && backend_->is_initialized(); }

    // Fan operations
    std::vector<FanInfo> list_fans();
    std::optional<FanInfo> get_fan(uint32_t index);
    bool set_fan_speed(uint32_t index, float speed_rpm);
    bool set_fan_speed_percent(uint32_t index, float percent);
    bool set_fan_auto_mode(uint32_t index);
    bool set_fan_manual_mode(uint32_t index);

    // Persistent fan control (re-applies settings to overcome system thermal daemon)
    bool start_persistent_control(uint32_t index, float speed_rpm);
    bool start_persistent_control_percent(uint32_t index, float percent);
    bool stop_persistent_control(uint32_t index);
    void stop_all_persistent_control();

    // Monitoring
    std::vector<TemperatureInfo> list_temperatures();
    std::optional<float> get_cpu_temperature();
    std::optional<float> get_gpu_temperature();

    // Key read/write (low-level)
    std::optional<SMCValue> read_key(const std::string& key);
    bool write_key(const std::string& key, float value);

    // Info
    std::string get_platform_name() const;
    std::vector<std::string> list_all_keys();

    // Callback for monitoring
    using MonitorCallback = std::function<void(const std::vector<FanInfo>&, const std::vector<TemperatureInfo>&)>;
    void start_monitoring(int interval_ms, MonitorCallback callback);
    void stop_monitoring();

private:
    std::unique_ptr<SMCBackend> backend_;
    bool monitoring_ = false;
};

} // namespace vent