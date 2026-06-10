#include "smc_backend.h"
#include "intel_smc_backend.h"
#include <memory>

namespace mac_fan_control {

std::unique_ptr<SMCBackend> create_smc_backend() {
    auto backend = std::make_unique<IntelSMCBackend>();
    if (backend->initialize()) {
        return backend;
    }
    return nullptr;
}

} // namespace mac_fan_control