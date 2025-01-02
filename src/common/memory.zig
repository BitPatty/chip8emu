// --- std --- //
const Allocator = @import("std").mem.Allocator;
const copyForwards = @import("std").mem.copyForwards;

const BoundsError = error {
    INDEX_OUT_OF_BOUNDS
};

pub fn Buffer(comptime element_size: type) type {
    return struct {
        const Self = @This();

        /// The allocator used to allocate the memory
        _allocator: *const Allocator,

        /// The pointer to the allocated buffer
        _ptr: *const Buffer(element_size),

        /// The data held in the memory
        data: []element_size,

        /// Zeroes out the entire allocated memory
        pub fn clear(self: *const Self) void {
            @memset(self.data, 0);
        }

        /// Zeroes out the memory section from `start` over `length` entries .
        /// Indexing starts from 0.
        ///
        /// Example:
        /// `clearSection(0, 3)` will remove the first 3 entries, e.g.
        /// `[a, b, c, d] => [0, 0, 0, d]`
        ///
        pub fn clearSection(self: *const Self, start: usize, length: usize) BoundsError!void {
            if(length == 0) return;
            const end = start + length;
            try checkBounds(self, start, end);
            @memset(self.data[start..end], 0);
        }


        /// Writes the specified section to the buffer starting at `start` offset
        pub fn writeSection(self: *const Self, start: usize, data: []const element_size) BoundsError!void {
            const end = start + data.len;
            if(data.len == 0) return;
            try checkBounds(self, start, end);
            copyForwards(element_size, self.data[start..end], data);
        }

        /// Reads the specified section into the provided slice
        pub fn readSection(self: *const Self, start: usize, out: []element_size) BoundsError!void {
            const end = start + out.len;
            try checkBounds(self, start, end);
            copyForwards(element_size, out, self.data[start..end]);
        }

        /// Creates a slice to the specified section of the buffer
        pub fn sliceToSection(self: *const Self, start: usize, length: usize) BoundsError![]element_size {
            const end = start + length;
            try checkBounds(self, start, end);
            return self.data[start..end];
        }

        /// Deallocates the buffer from the heap
        pub fn deallocate(self: *const Self) void {
            self._allocator.free(self.data);
            self._allocator.destroy(self._ptr);
        }

        /// Checks whether start and end are in bounds
        fn checkBounds(self: *const Self, start: usize, end: usize) BoundsError!void {
            if(start >= self.data.len) return BoundsError.INDEX_OUT_OF_BOUNDS;
            if(end >= self.data.len) return BoundsError.INDEX_OUT_OF_BOUNDS;
        }
    };
}

/// Allocates a buffer on the heap with the specified `element_size` and `length`
pub fn allocateBuffer(comptime element_size: type, allocator: *const Allocator, length: u32) Allocator.Error!*const Buffer(element_size) {
    const buff = try allocator.create(Buffer(element_size));
    errdefer allocator.destroy(buff);

    const data = try allocator.alloc(element_size, length);
    errdefer allocator.free(data);

    buff._allocator = allocator;
    buff._ptr = buff;
    buff.data = data;

    return buff;
}
