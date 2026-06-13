#include "fan_controller.h"
#include "fan_control_config.h"
#include <thread>
#include <chrono>
#include <algorithm>

namespace mac_fan_control {

FanController::FanController(std::unique_ptr<SMCBackend> backend)
    : backend_(std::move(backend)) {}

std::vector<FanInfo> FanController::list_fans() {
    if (!is_available()) return {};
    return backend_->get_all_fans();
}

std::optional<FanInfo> FanController::get_fan(uint32_t index) {
    if (!is_available()) return std::nullopt;
    return backend_->get_fan(index);
}

bool FanController::set_fan_speed(uint32_t index, float speed_rpm) {
    if (!is_available()) return false;

    // Ensure manual mode
    if (!backend_->set_fan_manual_mode(index, true)) return false;

    // Set target speed
    return backend_->set_fan_target_speed(index, speed_rpm);
}

bool FanController::set_fan_speed_percent(uint32_t index, float percent) {
    if (!is_available()) return false;

    auto fan = backend_->get_fan(index);
    if (!fan) return false;

    float min_speed = fan->min_speed;
    float max_speed = fan->max_speed;
    if (max_speed <= min_speed) return false;

    float target = min_speed + (max_speed - min_speed) * (percent / 100.0f);
    return set_fan_speed(index, target);
}

bool FanController::set_fan_auto_mode(uint32_t index) {
    if (!is_available()) return false;
    return backend_->set_fan_manual_mode(index, false);
}

bool FanController::set_fan_manual_mode(uint32_t index) {
    if (!is_available()) return false;
    return backend_->set_fan_manual_mode(index, true);
}

bool FanController::start_persistent_control(uint32_t index, float speed_rpm) {
    if (!is_available()) return false;
    return backend_->start_persistent_fan_control(index, speed_rpm);
}

bool FanController::start_persistent_control_percent(uint32_t index, float percent) {
    if (!is_available()) return false;

    auto fan = backend_->get_fan(index);
    if (!fan) return false;

    float min_speed = fan->min_speed;
    float max_speed = fan->max_speed;
    if (max_speed <= min_speed) return false;

    float target = min_speed + (max_speed - min_speed) * (percent / 100.0f);
    return start_persistent_control(index, target);
}

bool FanController::stop_persistent_control(uint32_t index) {
    if (!is_available()) return false;
    return backend_->stop_persistent_fan_control(index);
}

void FanController::stop_all_persistent_control() {
    if (!is_available()) return;
    backend_->stop_all_persistent_fan_control();
}

std::vector<TemperatureInfo> FanController::list_temperatures() {
    if (!is_available()) return {};
    return backend_->get_all_temperatures();
}

std::optional<float> FanController::get_cpu_temperature() {
    if (!is_available()) return std::nullopt;

    for (const auto& temperature : backend_->get_all_temperatures()) {
        if (temperature.key.rfind("TC", 0) == 0 && is_temperature_usable(temperature.key, temperature.value)) {
            return temperature.value;
        }
    }

    return std::nullopt;
}

std::optional<float> FanController::get_gpu_temperature() {
    if (!is_available()) return std::nullopt;

    for (const auto& temperature : backend_->get_all_temperatures()) {
        if (temperature.key.rfind("TG", 0) == 0 && is_temperature_usable(temperature.key, temperature.value)) {
            return temperature.value;
        }
    }

    return std::nullopt;
}

std::optional<SMCValue> FanController::read_key(const std::string& key) {
    if (!is_available() || key.length() != 4) return std::nullopt;
    return backend_->read_key(key.c_str());
}

bool FanController::write_key(const std::string& key, float value) {
    if (!is_available() || key.length() != 4) return false;

    auto current = backend_->read_key(key.c_str());
    if (!current) return false;

    SMCValue val{};
    std::strncpy(val.key, key.c_str(), 4);
    val.data_size = current->data_size;
    val.data_type = current->data_type;
    float_to_bytes(value, val.bytes, current->data_type, current->data_size);

    return backend_->write_key(val);
}

std::string FanController::get_platform_name() const {
    if (!is_available()) return "No backend";
    return backend_->get_platform_name();
}

std::vector<std::string> FanController::list_all_keys() {
    if (!is_available()) return {};
    return backend_->list_all_keys();
}

void FanController::start_monitoring(int interval_ms, MonitorCallback callback) {
    if (!is_available() || monitoring_) return;

    monitoring_ = true;
    std::thread([this, interval_ms, callback = std::move(callback)]() {
        while (monitoring_) {
            auto fans = backend_->get_all_fans();
            auto temps = backend_->get_all_temperatures();
            if (callback) {
                callback(fans, temps);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(interval_ms));
        }
    }).detach();
}

void FanController::stop_monitoring() {
    monitoring_ = false;
}

} // namespace mac_fan_control
