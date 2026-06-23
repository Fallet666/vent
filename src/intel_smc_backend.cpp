#include "intel_smc_backend.h"
#include "daemon_ipc.h"
#include "vent_config.h"
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <algorithm>
#include <array>
#include <atomic>
#include <mutex>
#include <thread>
#include <chrono>
#include <cctype>
#include <IOKit/IOTypes.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <mach/mach_port.h>
#include <sys/sysctl.h>
#include <set>

namespace vent {

namespace {

std::vector<TemperatureInfo> read_powermetrics_temperatures() {
    std::vector<TemperatureInfo> temperatures;
    FILE* pipe = popen("/usr/bin/powermetrics --samplers smc -n 1 -i 1 2>/dev/null", "r");
    if (!pipe) return temperatures;

    char line[512];
    int temperature_index = 0;
    while (fgets(line, sizeof(line), pipe)) {
        std::string text(line);
        std::string lowercase = text;
        std::transform(lowercase.begin(), lowercase.end(), lowercase.begin(), [](unsigned char character) {
            return static_cast<char>(std::tolower(character));
        });
        if (lowercase.find("temperature") == std::string::npos) continue;

        char* cursor = line;
        while (*cursor && !std::isdigit(static_cast<unsigned char>(*cursor)) && *cursor != '-') {
            ++cursor;
        }
        if (!*cursor) continue;

        char* end = nullptr;
        float value = std::strtof(cursor, &end);
        if (end == cursor || !is_temperature_usable("PM", value)) continue;

        TemperatureInfo temperature;
        temperature.key = "PM" + std::to_string(temperature_index++);
        temperature.value = value;
        temperatures.push_back(temperature);
    }

    pclose(pipe);
    return temperatures;
}

// Private HID event system API (not in public headers on macOS)
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

extern "C" {
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
extern IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);
} // extern "C"

static constexpr int64_t kIOHIDEventTypeTemperature = 15;
static constexpr int32_t kIOHIDEventFieldBase(int32_t type) { return type << 16; }
static constexpr uint32_t kHIDPage_AppleVendor = 0xFF00;
static constexpr uint32_t kHIDUsage_AppleVendor_TemperatureSensor = 5;

std::vector<TemperatureInfo> read_hid_temperatures() {
    std::vector<TemperatureInfo> temperatures;

    CFNumberRef page_number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &kHIDPage_AppleVendor);
    CFNumberRef usage_number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &kHIDUsage_AppleVendor_TemperatureSensor);

    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *values[] = { page_number, usage_number };

    CFDictionaryRef matching = CFDictionaryCreate(kCFAllocatorDefault,
        keys, values, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFRelease(page_number);
    CFRelease(usage_number);

    if (!matching) return temperatures;

    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) {
        CFRelease(matching);
        return temperatures;
    }

    IOHIDEventSystemClientSetMatching(client, matching);
    CFRelease(matching);

    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) {
        CFRelease(client);
        return temperatures;
    }

    std::set<std::string> seen_names;

    CFIndex count = CFArrayGetCount(services);
    for (CFIndex i = 0; i < count; ++i) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);

        CFStringRef name_ref = (CFStringRef)IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
        if (!name_ref) continue;

        char name_buffer[128];
        if (!CFStringGetCString(name_ref, name_buffer, sizeof(name_buffer), kCFStringEncodingUTF8)) {
            CFRelease(name_ref);
            continue;
        }
        CFRelease(name_ref);

        std::string name(name_buffer);

        // Replace spaces in sensor names with underscores to avoid breaking
        // the space-delimited socket protocol between daemon and GUI.
        for (char& ch : name) {
            if (ch == ' ') ch = '_';
        }

        // Skip duplicates (same sensor appears multiple times)
        if (!seen_names.insert(name).second) continue;

        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;

        double temp_value = IOHIDEventGetFloatValue(event, kIOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);

        float temp_float = static_cast<float>(temp_value);
        if (temp_float < MIN_USABLE_TEMPERATURE_C || temp_float >= MAX_USABLE_TEMPERATURE_C) continue;

        TemperatureInfo temperature;
        temperature.key = name;
        temperature.value = temp_float;
        temperatures.push_back(temperature);
    }

    CFRelease(services);
    CFRelease(client);
    return temperatures;
}

} // namespace

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

    // Detect platform for diagnostics only; behavior is capability-based below.
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

    // Try known SMC service names across macOS platforms.
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
        // Some platforms expose per-fan mode keys instead of the FS! bitmask.
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

bool IntelSMCBackend::uses_fan_mode_keys() {
    auto fs_val = read_key("FS! ");
    return !fs_val || fs_val->data_size == 0;
}

bool IntelSMCBackend::apply_keyed_manual_mode(uint32_t index, bool manual) {
    if (manual) {
        bool ok = write_key_u8("Ftst", 1);
        char md_key[8];
        std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
        ok = write_key_u8(md_key, 1) && ok;
        return ok;
    } else {
        char md_key[8];
        std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
        bool ok = write_key_u8(md_key, 0);
        ok = write_key_u8("Ftst", 0) && ok;
        return ok;
    }
}

bool IntelSMCBackend::apply_keyed_manual_and_target(uint32_t index, float target_speed) {
    bool ok = write_key_u8("Ftst", 1);
    char md_key[8];
    std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
    ok = write_key_u8(md_key, 1) && ok;
    char tg_key[8];
    std::snprintf(tg_key, sizeof(tg_key), "F%dTg", index);
    ok = write_key_flt(tg_key, target_speed) && ok;
    return ok;
}

void IntelSMCBackend::apply_keyed_revert(uint32_t index) {
    char md_key[8];
    std::snprintf(md_key, sizeof(md_key), "F%dMd", index);
    write_key_u8(md_key, 0);
    write_key_u8("Ftst", 0);
}

bool IntelSMCBackend::set_fan_target_speed(uint32_t index, float speed) {
    if (!initialized_) return false;

    if (uses_fan_mode_keys()) {
        return apply_keyed_manual_and_target(index, speed);
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

    return apply_keyed_manual_mode(index, manual);
}

static void merge_temps(std::vector<TemperatureInfo>& dest, std::vector<TemperatureInfo>&& source) {
    for (auto& t : source) {
        bool duplicate = false;
        for (const auto& existing : dest) {
            if (existing.key == t.key) { duplicate = true; break; }
        }
        if (!duplicate) dest.push_back(std::move(t));
    }
}

std::vector<TemperatureInfo> IntelSMCBackend::get_all_temperatures() {
    std::vector<TemperatureInfo> temps;
    if (!initialized_) return temps;

    for (const auto* key : KNOWN_TEMPERATURE_KEYS) {
        auto value = read_key(key);
        if (!value) continue;

        float temperature_value = get_float_from_val(*value);
        if (!is_temperature_usable(key, temperature_value)) continue;

        TemperatureInfo temperature;
        temperature.key = key;
        temperature.value = temperature_value;
        temps.push_back(temperature);
    }

    uint32_t total = read_key_count();
    if (total == 0) {
        auto hid_temps = read_hid_temperatures();
        merge_temps(temps, std::move(hid_temps));
        if (temps.empty()) return read_powermetrics_temperatures();
        return temps;
    }

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
            float temperature_value = get_float_from_val(val);
            if (!is_temperature_usable(key_str, temperature_value)) continue;

            TemperatureInfo temp;
            temp.key = key_str;
            temp.value = temperature_value;
            temps.push_back(temp);
        }
    }

    auto hid_temps = read_hid_temperatures();
    merge_temps(temps, std::move(hid_temps));

    if (temps.empty()) {
        auto pm_temps = read_powermetrics_temperatures();
        merge_temps(temps, std::move(pm_temps));
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
        bool uses_mode_keys = uses_fan_mode_keys();

        while (control.running.load()) {
            float target = control.target_speed.load();
            if (uses_mode_keys) {
                apply_keyed_manual_and_target(index, target);
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
            apply_keyed_revert(index);
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

} // namespace vent
