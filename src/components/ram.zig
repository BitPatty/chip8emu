// --- std --- //
const Allocator = @import("std").mem.Allocator;

// --- common --- //
const memory = @import("../common/memory.zig");

const DEFAULT_SIZE = 4096;

/// The configuration of the RAM
pub const RAMConfig = struct {
    size: u32 = DEFAULT_SIZE
};

pub const RAM = struct {
    /// The allocator through which the RAM is allocated
    _allocator: *const Allocator,

    /// The pointer to the allocated buffer
    _ptr: *const RAM,

    /// The RAM data
    data: *const memory.Buffer(u16),

    /// Deallocates the RAM on the heap
    pub fn deallocate(self: *const RAM) void {
        self.data.deallocate();
        self._allocator.destroy(self._ptr);
    }
};

/// Creates a new RAM
pub fn init(allocator: *const Allocator, config: RAMConfig) Allocator.Error!*const RAM {
    const buff = try memory.allocateBuffer(u16, allocator, config.size);
    errdefer buff.deallocate();

    const ram = try allocator.create(RAM);
    errdefer allocator.destroy(ram);

    ram._allocator = allocator;
    ram._ptr = ram;
    ram.data = buff;

    return ram;
}