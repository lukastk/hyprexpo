#pragma once

#include <cstdint>

namespace Hyprexpo::Capture {

template <typename Framebuffer, typename ImageDescription>
bool prepareFramebuffer(Framebuffer& framebuffer, int width, int height, uint32_t format, const ImageDescription& description) {
    // Hyprland's alloc reuses matching storage and retries failed allocations;
    // unlike a size-only shortcut it also handles live precision changes.
    if (!framebuffer.alloc(width, height, format))
        return false;
    // Allocation can replace the texture, so tag it afterwards on every capture.
    framebuffer.setImageDescription(description);
    return true;
}

}
