// --- std --- //
const Allocator = @import("std").mem.Allocator;

// --- common --- //
const BackgroundThread = @import("./common/threads.zig");

// --- components --- //
const RAM = @import("./components/ram.zig").RAM;
const FrameBuffer = @import("./components/framebuffer.zig").FrameBuffer;
const Clock = @import("./components/clock.zig").Clock;

pub const EmulatorConfig = struct {
    memory: *const RAM,
    frame_buffer: *const FrameBuffer,
    clock: *const Clock
};


pub const Emulator = struct {
    /// The allocator used to allocate the emulator
    _allocator: *const Allocator,

    /// The pointer to the allocated emulator
    _ptr: *const Emulator,

    /// The emulator's clock
    clock: *const Clock,

    /// The emulator's frame buffer
    frame_buffer: *const FrameBuffer,

    /// The emulator's memory
    memory: *const RAM,

    pub fn deallocate(self: *const Emulator) void {
        self._allocator.destroy(self);
    }
};

/// Inititializes a new emulator
pub fn init(allocator: *const Allocator, config: EmulatorConfig) Allocator.Error!*const Emulator {
    const emu = try allocator.create(Emulator);
    errdefer allocator.destroy(emu);
    emu._allocator = allocator;
    emu._ptr = emu;

    emu.memory = config.memory;
    emu.frame_buffer = config.frame_buffer;
    emu.clock = config.clock;

    return emu;
}