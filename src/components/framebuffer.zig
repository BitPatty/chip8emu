// --- std --- //
const Allocator = @import("std").mem.Allocator;

// --- common --- //
const memory = @import("../common/memory.zig");

const DEFAULT_WIDTH = 64;
const DEFAULT_HEIGHT = 32;
const HI_RES_WIDTH = 128;
const HI_RES_HEIGHT = 64;

/// The configuration of the frame buffer
pub const FrameBufferConfig = struct {
    /// Whether to use high resolution mode (128x64) for SUPER-CHIP
    /// otherwise the default 64x32 is used
    high_resolution_mode: bool = false
};

pub const FrameBuffer = struct {
    /// The allocator through which the frame buffer is allocated
    _allocator: *const Allocator,

    /// The pointer to the allocated buffer
    _ptr: *const FrameBuffer,

    /// The width of the image frame
    image_width: u32,

    /// The height of the image frame
    image_height: u32,

    /// The frame buffer data
    buffer: *const memory.Buffer(u8),

    /// Deallocates the frame buffer on the heap
    pub fn deallocate(self: *const FrameBuffer) void {
        self.buffer.deallocate();
        self._allocator.destroy(self._ptr);
    }
};

/// Creates a new frame buffer
pub fn init(allocator: *const Allocator, config: FrameBufferConfig) Allocator.Error!*const FrameBuffer {
    return
        if (config.high_resolution_mode) try allocate(allocator, HI_RES_WIDTH, HI_RES_HEIGHT)
        else try allocate(allocator, DEFAULT_WIDTH, DEFAULT_HEIGHT);
}

/// Allocates a new frame buffer with the specified `width` and `height` on the heap
fn allocate(allocator: *const Allocator, width: u32, height: u32) Allocator.Error!*const FrameBuffer {
    const fb = try allocator.create(FrameBuffer);
    errdefer allocator.destroy(fb);
    fb._allocator = allocator;
    fb._ptr = fb;

    const buff = try memory.allocateBuffer(u8, allocator, width * height);
    errdefer buff.deallocate();
    fb.buffer = buff;

    fb.image_height = height;
    fb.image_width = width;

    return fb;

}