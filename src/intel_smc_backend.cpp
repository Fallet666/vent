#include "intel_smc_backend.h"
#include "daemon_ipc.h"
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <algorithm>
#include <array>
#include <atomic>
#include <mutex>
#include <thread>
#include <chrono>
#include <IOKit/IOTypes.h>
#include <mach/mach_port.h>
#include <sys/sysctl.h>

namespace mac_fan_control {

IntelSMCBackend::IntelSMCBackend() {
    std::memset(key_info_cache_, 0, sizeof(key_info_cache_));
}

IntelSMCBackend::~IntelSMCBackend() {
    shutdown();
}

uint32_t IntelSMCBackend::strtoul(const char* str, int size, int base) {
    (void)base;
    uint32_t total = 0;
    for (int i = 0; i < size; ++i) {
        total += static_cast<uint32_t>(static_cast<unsigned char>(str[i])) << ((size - 1 - i) * 8);
    }
    return total;
}

void IntelSMCBackend::ultostr(char* str, uint32_t val) {
    str[0] = static_cast<char>((val >> 24) & 0xFF);
    str[1] = static_cast<char>((val >> 16) & 0xFF);
    str[2] = static_cast<char>((val >> 8) & 0xFF);
    str[3] = static_cast<char>(val & 0xFF);
    str[4] = '\0';
}

void IntelSMCBackend::string_to_key(const std::string& str, uint32_t& key) {
    key = strtoul(str.c_str(), 4, 16);
}

std::string IntelSMCBackend::key_to_string(uint32_t key) const {
    char str[5];
    ultostr(str, key);
    return std::string(str);
}

bool IntelSMCBackend::initialize() {
    if (initialized_) return true;

    // Detect Apple Silicon
    char cpu_brand[256];
    size_t cpu_brand_len = sizeof(cpu_brand);
    if (sysctlbyname("machdep.cpu.brand_string", cpu_brand, &cpu_brand_len, nullptr, 0) == 0) {
        is_apple_silicon_ = (std::strstr(cpu_brand, "Apple") != nullptr);
    }

    kern_return_t result;
    mach_port_t master_port;
    io_iterator_t iterator;
    io_object_t device;

    result = IOMainPort(kIOMainPortDefault, &master_port);
    if (result != kIOReturnSuccess) return false;

    // Try different SMC service names for Intel and Apple Silicon
    const char* smc_services[] = {"AppleSMC", "AppleSMCKeysEndpoint"};
    device = 0;

    for (const auto* service : smc_services) {
        CFMutableDictionaryRef matching = IOServiceMatching(service);
        if (!matching) continue;
        result = IOServiceGetMatchingServices(master_port, matching, &iterator);
        if (result != kIOReturnSuccess) continue;

        device = IOIteratorNext(iterator);
        IOObjectRelease(iterator);
        if (device != 0) break;
    }

    if (device == 0) {
        CFMutableDictionaryRef matching = IOServiceMatching("IOService");
        if (matching) {
            CFDictionarySetValue(matching, CFSTR("IOName"), CFSTR("SMCEndpoint1"));
            result = IOServiceGetMatchingServices(master_port, matching, &iterator);
            if (result == kIOReturnSuccess) {
                device = IOIteratorNext(iterator);
                IOObjectRelease(iterator);
            }
        }
    }

    if (device == 0) return false;

    result = IOServiceOpen(device, mach_task_self(), 0, &connection_);
    IOObjectRelease(device);
    if (result != kIOReturnSuccess) return false;

    initialized_ = true;
    return true;
}

void IntelSMCBackend::shutdown() {
    if (initialized_) {
        IOServiceClose(connection_);
        connection_ = 0;
        initialized_ = false;
    }
}

bool IntelSMCBackend::is_initialized() const {
    return initialized_;
}

kern_return_t IntelSMCBackend::smc_call(int index, const SMCKeyData* input, SMCKeyData* output) {
    if (!initialized_) return kIOReturnNotOpen;
    size_t output_size = sizeof(SMCKeyData);
    return IOConnectCallStructMethod(connection_, index, input, sizeof(SMCKeyData), output, &output_size);
}

kern_return_t IntelSMCBackend::get_key_info_cached(uint32_t key, SMCKeyInfo* key_info) {
    os_unfair_lock_lock(&key_info_lock_);

    for (int i = 0; i < key_info_cache_count_; ++i) {
        if (key == key_info_cache_[i].key) {
            *key_info = key_info_cache_[i].info;
            os_unfair_lock_unlock(&key_info_lock_);
            return kIOReturnSuccess;
        }
    }

    os_unfair_lock_unlock(&key_info_lock_);

    SMCKeyData input{};
    SMCKeyData output{};

    input.key = key;
    input.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t result = smc_call(KERNEL_INDEX_SMC, &input, &output);
    if (result != kIOReturnSuccess) return result;

    key_info->data_size = output.keyInfo.dataSize;
    key_info->data_type = static_cast<SMCDataType>(output.keyInfo.dataType);
    key_info->data_attributes = output.keyInfo.dataAttributes;

    os_unfair_lock_lock(&key_info_lock_);
    if (key_info_cache_count_ < KEY_INFO_CACHE_SIZE) {
        key_info_cache_[key_info_cache_count_].key = key;
        key_info_cache_[key_info_cache_count_].info = *key_info;
        ++key_info_cache_count_;
    }
    os_unfair_lock_unlock(&key_info_lock_);

    return kIOReturnSuccess;
}

kern_return_t IntelSMCBackend::read_key_internal(uint32_t key, SMCValue* val) {
    SMCKeyInfo key_info{};
    kern_return_t result = get_key_info_cached(key, &key_info);
    if (result != kIOReturnSuccess) return result;

    SMCKeyData input{};
    SMCKeyData output{};

    input.key = key;
    input.data8 = SMC_CMD_READ_BYTES;
    input.keyInfo.dataSize = key_info.data_size;

    result = smc_call(KERNEL_INDEX_SMC, &input, &output);
    if (result != kIOReturnSuccess) return result;

    val->data_size = key_info.data_size;
    val->data_type = key_info.data_type;
    std::memcpy(val->bytes, output.bytes, std::min<size_t>(sizeof(val->bytes), std::min<size_t>(key_info.data_size, sizeof(output.bytes))));
    ultostr(val->key, key);

    return kIOReturnSuccess;
}

kern_return_t IntelSMCBackend::write_key_internal(const SMCValue& write_val) {
    uint32_t key = strtoul(write_val.key, 4, 16);

    // Read key info to get correct dataType — SMC requires it on write
    SMCKeyInfo key_info{};
    kern_return_t result = get_key_info_cached(key, &key_info);
    if (result != kIOReturnSuccess) return result;

    SMCKeyData input{};
    SMCKeyData output{};

    input.key = key;
    input.data8 = SMC_CMD_WRITE_BYTES;
    input.keyInfo.dataSize = write_val.data_size;
    input.keyInfo.dataType = static_cast<uint32_t>(key_info.data_type);
    std::memcpy(input.bytes, write_val.bytes, std::min<size_t>(sizeof(input.bytes), write_val.data_size));

    return smc_call(KERNEL_INDEX_SMC, &input, &output);
}

std::optional<SMCValue> IntelSMCBackend::read_key(const char* key) {
    if (!initialized_ || !key || std::strlen(key) != 4) return std::nullopt;

    uint32_t key_val = strtoul(key, 4, 16);
    SMCValue val{};
    kern_return_t result = read_key_internal(key_val, &val);
    if (result != kIOReturnSuccess) return std::nullopt;

    return val;
}

bool IntelSMCBackend::write_key(const SMCValue& value) {
    if (!initialized_) return false;
    return write_key_internal(value) == kIOReturnSuccess;
}

SMCKeyInfo IntelSMCBackend::get_key_info(const char* key) {
    if (!initialized_ || !key || std::strlen(key) != 4) return {};

    uint32_t key_val = strtoul(key, 4, 16);
    SMCKeyInfo info{};
    get_key_info_cached(key_val, &info);
    return info;
}

uint32_t IntelSMCBackend::get_key_count() {
    return read_key_count();
}

uint32_t IntelSMCBackend::read_key_count() {
    uint32_t key = strtoul("#KEY", 4, 16);
    SMCValue val{};
    if (read_key_internal(key, &val) != kIOReturnSuccess) return 0;
    return strtoul(reinterpret_cast<const char*>(val.bytes), val.data_size, 10);
}

std::vector<std::string> IntelSMCBackend::list_all_keys() {
    std::vector<std::string> keys;
    if (!initialized_) return keys;

    uint32_t total = read_key_count();
    if (total == 0) return keys;

    for (uint32_t i = 0; i < total; ++i) {
        SMCKeyData input{};
        SMCKeyData output{};

        input.data8 = SMC_CMD_READ_INDEX;
        input.data32 = i;

        kern_return_t result = smc_call(KERNEL_INDEX_SMC, &input, &output);
        if (result != kIOReturnSuccess) continue;

        keys.push_back(key_to_string(output.key));
    }

    return keys;
}

float IntelSMCBackend::get_float_from_val(const SMCValue& val) {
    return bytes_to_float(val.bytes, val.data_type, val.data_size);
}

void IntelSMCBackend::set_float_to_val(float value, SMCValue& val, SMCDataType type, uint32_t size) {
    val.data_size = size;
    val.data_type = type;
    float_to_bytes(value, val.bytes, type, size);
}

std::vector<FanInfo> IntelSMCBackend::get_all_fans() {
    std::vector<FanInfo> fans;
    if (!initialized_) return fans;

    auto fnum_val = read_key("FNum");
    if (!fnum_val) return fans;

    uint32_t total_fans = strtoul(reinterpret_cast<const char*>(fnum_val->bytes), fnum_val->data_size, 10);

    for (uint32_t i = 0; i < total_fans; ++i) {
        auto fan = get_fan(i);
        if (fan) fans.push_back(*fan);
    }

    return fans;
}

std::optional<FanInfo> IntelSMCBackend::get_fan(uint32_t index) {
    if (!initialized_) return std::nullopt;

    FanInfo info{};
    info.index = index;

    char key[8];

    std::snprintf(key, sizeof(key), "F%dID", index);
    auto id_val = read_key(key);
    if (id_val && id_val->data_size >= 4) {
        info.id = reinterpret_cast<const char*>(id_val->bytes + 4);
    }

    std::snprintf(key, sizeof(key), "F%dAc", index);
    auto ac_val = read_key(key);
    if (ac_val) info.current_speed = get_float_from_val(*ac_val);

    std::snprintf(key, sizeof(key), "F%dMn", index);
    auto mn_val = read_key(key);
    if (mn_val) info.min_speed = get_float_from_val(*mn_val);

    std::snprintf(key, sizeof(key), "F%dMx", index);
    auto mx_val = read_key(key);
    if (mx_val) info.max_speed = get_float_from_val(*mx_val);

    std::snprintf(key, sizeof(key), "F%dSf", index);
    auto sf_val = read_key(key);
    if (sf_val) info.safe_speed = get_float_from_val(*sf_val);

    std::snprintf(key, sizeof(key), "F%dTg", index);
    auto tg_val = read_key(key);
    if (tg_val) info.target_speed = get_float_from_val(*tg_val);

    auto fs_val = read_key("FS! ");
    if (fs_val && fs_val->data_size > 0) {
        uint32_t manual_mask = strtoul(reinterpret_cast<const char*>(fs_val->bytes), fs_val->data_size, 10);
        info.manual_mode = (manual_mask & (1 << index)) != 0;
    } else {
        // Apple Silicon: check F%dMd key
        char md_key[8];
        std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
        auto md_val = read_key(md_key);
        if (md_val && md_val->data_size >= 1) {
            info.manual_mode = (md_val->bytes[0] & 1) != 0;
        }
    }

    return info;
}

bool IntelSMCBackend::set_fan_min_speed(uint32_t index, float speed) {
    if (!initialized_) return false;

    char key[8];
    std::snprintf(key, sizeof(key), "F%dMn", index);

    auto current = read_key(key);
    if (!current) return false;

    SMCValue val{};
    std::strncpy(val.key, key, 4);
    set_float_to_val(speed, val, current->data_type, current->data_size);

    return write_key(val);
}

bool IntelSMCBackend::set_fan_max_speed(uint32_t index, float speed) {
    if (!initialized_) return false;

    char key[8];
    std::snprintf(key, sizeof(key), "F%dMx", index);

    auto current = read_key(key);
    if (!current) return false;

    SMCValue val{};
    std::strncpy(val.key, key, 4);
    set_float_to_val(speed, val, current->data_type, current->data_size);

    return write_key(val);
}

bool IntelSMCBackend::write_key_u8(const char* key_str, uint8_t value) {
    SMCValue val{};
    std::strncpy(val.key, key_str, 4);
    val.data_size = 1;
    val.data_type = SMCDataType::UINT8;
    val.bytes[0] = value;
    return write_key(val);
}

bool IntelSMCBackend::write_key_flt(const char* key_str, float value) {
    SMCValue val{};
    std::strncpy(val.key, key_str, 4);
    val.data_size = 4;
    val.data_type = SMCDataType::FLT;
    float_to_bytes(value, val.bytes, SMCDataType::FLT, 4);
    return write_key(val);
}

void IntelSMCBackend::apply_apple_silicon_manual(uint32_t index, bool manual) {
    if (manual) {
        // Unlock Ftst (M3/M4+ needs this to bypass thermalmonitord)
        write_key_u8("Ftst", 1);
        // Write F%dMd = 1
        char md_key[8];
        std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
        write_key_u8(md_key, 1);
    } else {
        // Write F%dMd = 0
        char md_key[8];
        std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
        write_key_u8(md_key, 0);
        // Lock Ftst
        write_key_u8("Ftst", 0);
    }
}

void IntelSMCBackend::apply_apple_silicon_manual_and_target(uint32_t index, float target_speed) {
    write_key_u8("Ftst", 1);
    char md_key[8];
    std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
    write_key_u8(md_key, 1);
    char tg_key[8];
    std::snprintf(tg_key, sizeof(tg_key), "F%dTg", index);
    write_key_flt(tg_key, target_speed);
}

void IntelSMCBackend::apply_apple_silicon_revert(uint32_t index) {
    char md_key[8];
    std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
    write_key_u8(md_key, 0);
    write_key_u8("Ftst", 0);
}

bool IntelSMCBackend::set_fan_target_speed(uint32_t index, float speed) {
    if (!initialized_) return false;

    auto fs_val = read_key("FS! ");
    if (!fs_val || fs_val->data_size == 0) {
        // Apple Silicon: use full sequence
        apply_apple_silicon_manual_and_target(index, speed);
        return true;
    }

    // Intel path
    char key[8];
    std::snprintf(key, sizeof(key), "F%dTg", index);
    auto current = read_key(key);
    if (!current) return false;
    SMCValue val{};
    std::strncpy(val.key, key, 4);
    set_float_to_val(speed, val, current->data_type, current->data_size);
    return write_key(val);
}

bool IntelSMCBackend::set_fan_manual_mode(uint32_t index, bool manual) {
    if (!initialized_) return false;

    auto fs_val = read_key("FS! ");
    if (fs_val && fs_val->data_size > 0) {
        // Intel path: use FS! bitmask
        uint32_t mask = strtoul(reinterpret_cast<const char*>(fs_val->bytes), fs_val->data_size, 10);
        if (manual) mask |= (1 << index);
        else mask &= ~(1 << index);

        SMCKeyInfo key_info = get_key_info("FS! ");
        if (key_info.data_size == 0) {
            key_info.data_size = 2;
            key_info.data_type = SMCDataType::UINT16;
        }
        SMCValue val{};
        std::strncpy(val.key, "FS! ", 4);
        val.data_size = key_info.data_size;
        val.data_type = key_info.data_type;
        float_to_bytes(static_cast<float>(mask), val.bytes, key_info.data_type, val.data_size);
        return write_key(val);
    }

    // Apple Silicon path
    apply_apple_silicon_manual(index, manual);
    return true;
}

std::vector<TemperatureInfo> IntelSMCBackend::get_all_temperatures() {
    std::vector<TemperatureInfo> temps;
    if (!initialized_) return temps;

    uint32_t total = read_key_count();
    if (total == 0) return temps;

    for (uint32_t i = 0; i < total; ++i) {
        SMCKeyData input{};
        SMCKeyData output{};

        input.data8 = SMC_CMD_READ_INDEX;
        input.data32 = i;

        kern_return_t result = smc_call(KERNEL_INDEX_SMC, &input, &output);
        if (result != kIOReturnSuccess) continue;

        std::string key_str = key_to_string(output.key);

        if (key_str.empty() || key_str[0] != 'T') continue;

        SMCValue val{};
        if (read_key_internal(output.key, &val) != kIOReturnSuccess) continue;

        if (val.data_type == SMCDataType::SP78 && val.data_size >= 2) {
            TemperatureInfo temp;
            temp.key = key_str;
            temp.value = get_float_from_val(val);
            temps.push_back(temp);
        }
    }

    return temps;
}

std::string IntelSMCBackend::get_platform_name() const {
    if (is_apple_silicon_) {
        return "Apple Silicon (IOKit)";
    }
    return "Intel (IOKit)";
}

bool IntelSMCBackend::start_persistent_fan_control(uint32_t index, float target_speed) {
    if (!initialized_ || index >= persistent_controls_.size()) return false;

    std::lock_guard<std::mutex> lock(persistent_mutex_);
    auto& control = persistent_controls_[index];

    if (control.running.load()) {
        control.target_speed.store(target_speed);
        return true;
    }

    control.index = index;
    control.target_speed.store(target_speed);
    control.running.store(true);

    control.thread = std::thread([this, index]() {
        auto& control = persistent_controls_[index];
        auto fs_val = read_key("FS! ");
        bool is_apple_silicon = (!fs_val || fs_val->data_size == 0);

        while (control.running.load()) {
            float target = control.target_speed.load();
            if (is_apple_silicon) {
                apply_apple_silicon_manual_and_target(index, target);
            } else {
                set_fan_manual_mode(index, true);
                char key[8];
                std::snprintf(key, sizeof(key), "F%dTg", index);
                auto current = read_key(key);
                if (current) {
                    SMCValue val{};
                    std::strncpy(val.key, key, 4);
                    set_float_to_val(target, val, current->data_type, current->data_size);
                    write_key(val);
                }
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(RECONCILIATION_INTERVAL_MS));
        }

        // Revert on exit
        auto fs_val_after = read_key("FS! ");
        if (!fs_val_after || fs_val_after->data_size == 0) {
            apply_apple_silicon_revert(index);
        } else {
            set_fan_manual_mode(index, false);
        }
    });

    control.thread.detach();
    return true;
}

bool IntelSMCBackend::stop_persistent_fan_control(uint32_t index) {
    if (index >= persistent_controls_.size()) return false;

    std::lock_guard<std::mutex> lock(persistent_mutex_);
    auto& control = persistent_controls_[index];

    if (!control.running.load()) return false;

    control.running.store(false);

    return true;
}

void IntelSMCBackend::stop_all_persistent_fan_control() {
    std::lock_guard<std::mutex> lock(persistent_mutex_);
    for (auto& control : persistent_controls_) {
        if (control.running.load()) {
            control.running.store(false);
        }
    }
}

} // namespace mac_fan_control
