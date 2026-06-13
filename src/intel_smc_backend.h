#pragma once

#include "smc_backend.h"
#include <IOKit/IOKitLib.h>
#include <os/lock.h>
#include <memory>
#include <array>
#include <atomic>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <chrono>

namespace mac_fan_control {

// SMCKeyData struct matching Apple's SMC kernel driver exactly.
// These sub-struct types match the IOKit AppleSMC header definitions.

struct SMCVersion {
    uint8_t major;
    uint8_t minor;
    uint8_t build;
    uint8_t reserved;
    uint16_t release;
};

struct SMCPLimitData {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
};

struct SMCKeyInfoData {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
};

struct SMCKeyData {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfoData keyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
};

class IntelSMCBackend : public SMCBackend {
public:
    IntelSMCBackend();
    ~IntelSMCBackend() override;

    bool initialize() override;
    void shutdown() override;
    bool is_initialized() const override;

    std::optional<SMCValue> read_key(const char* key) override;
    bool write_key(const SMCValue& value) override;
    SMCKeyInfo get_key_info(const char* key) override;
    std::vector<std::string> list_all_keys() override;
    uint32_t get_key_count() override;

    std::vector<FanInfo> get_all_fans() override;
    std::optional<FanInfo> get_fan(uint32_t index) override;
    bool set_fan_min_speed(uint32_t index, float speed) override;
    bool set_fan_max_speed(uint32_t index, float speed) override;
    bool set_fan_target_speed(uint32_t index, float speed) override;
    bool set_fan_manual_mode(uint32_t index, bool manual) override;
    bool start_persistent_fan_control(uint32_t index, float target_speed) override;
    bool stop_persistent_fan_control(uint32_t index) override;
    void stop_all_persistent_fan_control() override;

    std::vector<TemperatureInfo> get_all_temperatures() override;

    std::string get_platform_name() const override;

private:
    struct KeyInfoCacheEntry {
        uint32_t key;
        SMCKeyInfo info;
    };

    static constexpr int KEY_INFO_CACHE_SIZE = 100;
    static constexpr uint32_t KERNEL_INDEX_SMC = 2;
    static constexpr uint8_t SMC_CMD_READ_BYTES = 5;
    static constexpr uint8_t SMC_CMD_WRITE_BYTES = 6;
    static constexpr uint8_t SMC_CMD_READ_INDEX = 8;
    static constexpr uint8_t SMC_CMD_READ_KEYINFO = 9;

    io_connect_t connection_ = 0;
    bool initialized_ = false;
    bool is_apple_silicon_ = false;
    KeyInfoCacheEntry key_info_cache_[KEY_INFO_CACHE_SIZE];
    int key_info_cache_count_ = 0;
    mutable os_unfair_lock key_info_lock_ = OS_UNFAIR_LOCK_INIT;

    struct PersistentFanControl {
        uint32_t index = 0;
        std::atomic<float> target_speed{0.0f};
        std::thread thread;
        std::atomic<bool> running{false};
    };
    std::array<PersistentFanControl, 16> persistent_controls_;
    mutable std::mutex persistent_mutex_;

    static uint32_t strtoul(const char* str, int size, int base);
    static void ultostr(char* str, uint32_t val);
    static void string_to_key(const std::string& str, uint32_t& key);

    kern_return_t smc_call(int index, const SMCKeyData* input, SMCKeyData* output);
    kern_return_t get_key_info_cached(uint32_t key, SMCKeyInfo* key_info);
    kern_return_t read_key_internal(uint32_t key, SMCValue* val);
    kern_return_t write_key_internal(const SMCValue& write_val);

    std::string key_to_string(uint32_t key) const;
    uint32_t read_key_count();
    float get_float_from_val(const SMCValue& val);
    void set_float_to_val(float value, SMCValue& val, SMCDataType type, uint32_t size);

    bool write_key_u8(const char* key_str, uint8_t value);
    bool write_key_flt(const char* key_str, float value);
    bool uses_fan_mode_keys();
    bool apply_keyed_manual_mode(uint32_t index, bool manual);
    bool apply_keyed_manual_and_target(uint32_t index, float target_speed);
    void apply_keyed_revert(uint32_t index);
};

} // namespace mac_fan_control

static_assert(sizeof(mac_fan_control::SMCKeyData) == 80,
              "SMCKeyData must be exactly 80 bytes to match kernel driver");
