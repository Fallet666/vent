#pragma once

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
#include <optional>

namespace vent {

enum class SMCDataType : uint32_t {
    // Values are FOUR_CHARACTER_CODE big-endian: (c0<<24)|(c1<<16)|(c2<<8)|c3
    // Must match what the SMC kernel driver returns (AppleSMC uses FC_CODE).
    UINT8  = 0x75693820,  // "ui8 "
    UINT16 = 0x75693136,  // "ui16"
    UINT32 = 0x75693332,  // "ui32"
    SINT8  = 0x73693820,  // "si8 "
    SINT16 = 0x73693136,  // "si16"
    FLT    = 0x666C7420,  // "flt "
    FP1F   = 0x66703166,  // "fp1f"
    FP4C   = 0x66703463,  // "fp4c"
    FP5B   = 0x66703562,  // "fp5b"
    FP6A   = 0x66703661,  // "fp6a"
    FP79   = 0x66703739,  // "fp79"
    FP88   = 0x66703838,  // "fp88"
    FPA6   = 0x66706136,  // "fpa6"
    FPC4   = 0x66706334,  // "fpc4"
    FPE2   = 0x66706532,  // "fpe2"
    SP1E   = 0x73703165,  // "sp1e"
    SP3C   = 0x73703363,  // "sp3c"
    SP4B   = 0x73703462,  // "sp4b"
    SP5A   = 0x73703561,  // "sp5a"
    SP69   = 0x73703639,  // "sp69"
    SP78   = 0x73703738,  // "sp78"
    SP87   = 0x73703837,  // "sp87"
    SP96   = 0x73703936,  // "sp96"
    SPB4   = 0x73706234,  // "spb4"
    SPF0   = 0x73706630,  // "spf0"
    PWM    = 0x7B70776D,  // "{pwm"
    CH8    = 0x63683820,  // "ch8 "
    FLAG   = 0x666C6167,  // "flag"
    HEX    = 0x6865785F,  // "hex_"
    IOFT   = 0x696F6674,  // "ioft"
    UNKNOWN = 0
};

struct SMCKeyInfo {
    uint32_t data_size = 0;
    SMCDataType data_type = SMCDataType::UNKNOWN;
    uint8_t data_attributes = 0;
};

struct SMCValue {
    char key[5] = {0};
    uint32_t data_size = 0;
    SMCDataType data_type = SMCDataType::UNKNOWN;
    uint8_t bytes[32] = {0};
};

struct FanInfo {
    uint32_t index = 0;
    std::string id;
    float current_speed = 0.0f;
    float min_speed = 0.0f;
    float max_speed = 0.0f;
    float safe_speed = 0.0f;
    float target_speed = 0.0f;
    bool manual_mode = false;
};

struct TemperatureInfo {
    std::string key;
    float value = 0.0f;
};

enum class SMCError {
    SUCCESS = 0,
    NOT_FOUND,
    PERMISSION_DENIED,
    INVALID_ARGUMENT,
    IO_ERROR,
    KEY_NOT_FOUND,
    DATA_SIZE_MISMATCH,
    UNSUPPORTED_PLATFORM,
    UNKNOWN
};

class SMCException : public std::exception {
public:
    explicit SMCException(SMCError error, const std::string& message)
        : error_(error), message_(message) {}

    SMCError error() const noexcept { return error_; }
    const char* what() const noexcept override { return message_.c_str(); }

private:
    SMCError error_;
    std::string message_;
};

inline std::string smc_error_to_string(SMCError error) {
    switch (error) {
        case SMCError::SUCCESS: return "Success";
        case SMCError::NOT_FOUND: return "Not found";
        case SMCError::PERMISSION_DENIED: return "Permission denied";
        case SMCError::INVALID_ARGUMENT: return "Invalid argument";
        case SMCError::IO_ERROR: return "I/O error";
        case SMCError::KEY_NOT_FOUND: return "Key not found";
        case SMCError::DATA_SIZE_MISMATCH: return "Data size mismatch";
        case SMCError::UNSUPPORTED_PLATFORM: return "Unsupported platform";
        case SMCError::UNKNOWN: return "Unknown error";
    }
    return "Unknown error";
}

inline SMCDataType string_to_data_type(const char* str) {
    if (!str) return SMCDataType::UNKNOWN;
    uint32_t val = 0;
    for (int i = 0; i < 4 && str[i]; ++i) {
        val |= (static_cast<uint32_t>(static_cast<unsigned char>(str[i])) << (24 - i * 8));
    }
    return static_cast<SMCDataType>(val);
}

inline float bytes_to_float(const uint8_t* bytes, SMCDataType type, uint32_t size) {
    if (size == 0) return 0.0f;

    switch (type) {
        case SMCDataType::FLT: {
            if (size >= 4) {
                float f;
                std::memcpy(&f, bytes, sizeof(float));
                return f;
            }
            break;
        }
        case SMCDataType::FP1F:
        case SMCDataType::FP4C:
        case SMCDataType::FP5B:
        case SMCDataType::FP6A:
        case SMCDataType::FP79:
        case SMCDataType::FP88:
        case SMCDataType::FPA6:
        case SMCDataType::FPC4:
        case SMCDataType::FPE2: {
            if (size >= 2) {
                uint16_t raw = (bytes[0] << 8) | bytes[1];
                float divisor = 1.0f;
                switch (type) {
                    case SMCDataType::FP1F: divisor = 32768.0f; break;
                    case SMCDataType::FP4C: divisor = 4096.0f; break;
                    case SMCDataType::FP5B: divisor = 2048.0f; break;
                    case SMCDataType::FP6A: divisor = 1024.0f; break;
                    case SMCDataType::FP79: divisor = 512.0f; break;
                    case SMCDataType::FP88: divisor = 256.0f; break;
                    case SMCDataType::FPA6: divisor = 64.0f; break;
                    case SMCDataType::FPC4: divisor = 16.0f; break;
                    case SMCDataType::FPE2: divisor = 4.0f; break;
                    default: break;
                }
                return static_cast<float>(raw) / divisor;
            }
            break;
        }
        case SMCDataType::SP1E:
        case SMCDataType::SP3C:
        case SMCDataType::SP4B:
        case SMCDataType::SP5A:
        case SMCDataType::SP69:
        case SMCDataType::SP78:
        case SMCDataType::SP87:
        case SMCDataType::SP96:
        case SMCDataType::SPB4: {
            if (size >= 2) {
                int16_t raw = static_cast<int16_t>((bytes[0] << 8) | bytes[1]);
                float divisor = 1.0f;
                switch (type) {
                    case SMCDataType::SP1E: divisor = 16384.0f; break;
                    case SMCDataType::SP3C: divisor = 4096.0f; break;
                    case SMCDataType::SP4B: divisor = 2048.0f; break;
                    case SMCDataType::SP5A: divisor = 1024.0f; break;
                    case SMCDataType::SP69: divisor = 512.0f; break;
                    case SMCDataType::SP78: divisor = 256.0f; break;
                    case SMCDataType::SP87: divisor = 128.0f; break;
                    case SMCDataType::SP96: divisor = 64.0f; break;
                    case SMCDataType::SPB4: divisor = 16.0f; break;
                    default: break;
                }
                return static_cast<float>(raw) / divisor;
            }
            break;
        }
        case SMCDataType::SPF0: {
            if (size >= 2) {
                uint16_t raw = (bytes[0] << 8) | bytes[1];
                return static_cast<float>(raw);
            }
            break;
        }
        case SMCDataType::UINT8: {
            if (size >= 1) return static_cast<float>(bytes[0]);
            break;
        }
        case SMCDataType::UINT16: {
            if (size >= 2) {
                return static_cast<float>((bytes[0] << 8) | bytes[1]);
            }
            break;
        }
        case SMCDataType::UINT32: {
            if (size >= 4) {
                return static_cast<float>((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]);
            }
            break;
        }
        case SMCDataType::SINT8: {
            if (size >= 1) return static_cast<float>(static_cast<int8_t>(bytes[0]));
            break;
        }
        case SMCDataType::SINT16: {
            if (size >= 2) {
                return static_cast<float>(static_cast<int16_t>((bytes[0] << 8) | bytes[1]));
            }
            break;
        }
        case SMCDataType::PWM: {
            if (size >= 2) {
                uint16_t raw = (bytes[0] << 8) | bytes[1];
                return static_cast<float>(raw) * 100.0f / 65536.0f;
            }
            break;
        }
        default:
            break;
    }
    return 0.0f;
}

inline void float_to_bytes(float value, uint8_t* bytes, SMCDataType type, uint32_t size) {
    if (size == 0) return;

    switch (type) {
        case SMCDataType::FLT: {
            if (size >= 4) {
                std::memcpy(bytes, &value, sizeof(float));
            }
            break;
        }
        case SMCDataType::FP1F:
        case SMCDataType::FP4C:
        case SMCDataType::FP5B:
        case SMCDataType::FP6A:
        case SMCDataType::FP79:
        case SMCDataType::FP88:
        case SMCDataType::FPA6:
        case SMCDataType::FPC4:
        case SMCDataType::FPE2: {
            if (size >= 2) {
                float divisor = 1.0f;
                switch (type) {
                    case SMCDataType::FP1F: divisor = 32768.0f; break;
                    case SMCDataType::FP4C: divisor = 4096.0f; break;
                    case SMCDataType::FP5B: divisor = 2048.0f; break;
                    case SMCDataType::FP6A: divisor = 1024.0f; break;
                    case SMCDataType::FP79: divisor = 512.0f; break;
                    case SMCDataType::FP88: divisor = 256.0f; break;
                    case SMCDataType::FPA6: divisor = 64.0f; break;
                    case SMCDataType::FPC4: divisor = 16.0f; break;
                    case SMCDataType::FPE2: divisor = 4.0f; break;
                    default: break;
                }
                uint16_t raw = static_cast<uint16_t>(value * divisor);
                bytes[0] = (raw >> 8) & 0xFF;
                bytes[1] = raw & 0xFF;
            }
            break;
        }
        case SMCDataType::UINT8: {
            if (size >= 1) {
                bytes[0] = static_cast<uint8_t>(value);
            }
            break;
        }
        case SMCDataType::SINT8: {
            if (size >= 1) {
                bytes[0] = static_cast<uint8_t>(static_cast<int8_t>(value));
            }
            break;
        }
        case SMCDataType::UINT16: {
            if (size >= 2) {
                uint16_t raw = static_cast<uint16_t>(value);
                bytes[0] = (raw >> 8) & 0xFF;
                bytes[1] = raw & 0xFF;
            }
            break;
        }
        case SMCDataType::UINT32: {
            if (size >= 4) {
                uint32_t raw = static_cast<uint32_t>(value);
                bytes[0] = (raw >> 24) & 0xFF;
                bytes[1] = (raw >> 16) & 0xFF;
                bytes[2] = (raw >> 8) & 0xFF;
                bytes[3] = raw & 0xFF;
            }
            break;
        }
        case SMCDataType::SINT16: {
            if (size >= 2) {
                int16_t raw = static_cast<int16_t>(value);
                bytes[0] = (static_cast<uint16_t>(raw) >> 8) & 0xFF;
                bytes[1] = static_cast<uint16_t>(raw) & 0xFF;
            }
            break;
        }
        case SMCDataType::PWM: {
            if (size >= 2) {
                uint16_t raw = static_cast<uint16_t>(value * 65536.0f / 100.0f);
                bytes[0] = (raw >> 8) & 0xFF;
                bytes[1] = raw & 0xFF;
            }
            break;
        }
        default:
            break;
    }
}

} // namespace vent