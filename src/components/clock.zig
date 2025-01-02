// --- std --- //
const builtin = @import("builtin");
const posix = @import("std").posix;
const time = @import("std").time;
const Thread = @import("std").Thread;
const Allocator = @import("std").mem.Allocator;

// --- common --- //
const log = @import("../common/log.zig");


/// The frequency of the CHIP-8 can vary as it is also
/// just emulated on other platforms. Frequency needs to
/// be adjustable from the outside for the program that
/// executed.
///
/// Default is set to 500 as this is what a lot of
/// people seem to suggest
const DEFAULT_FREQUENCY: u64 = 500;

/// The configuration for the clock
pub const ClockConfiguration = struct {
    /// The clock frequency in Hz
    frequency: u64 = DEFAULT_FREQUENCY,
};

/// The state of the clock
pub const ClockState = enum {
    PAUSED,
    RUNNING
};

pub const Clock = struct {
    /// The allocator used to allocate the clock
    _allocator: *const Allocator,

    /// The pointer to the allocated clock
    _ptr: *const Clock,

    /// The current state of the clock
    state: *ClockState,

    /// The frequency of the clock in Hz
    frequency: *u64,

    /// The number of ticks since the clock staretd
    ticks: *u64,

    /// The timestamp of when the last tick happened
    last_tick_ns: *u64,

    /// The timestamp of when the next tick should occur
    next_tick_ns: *u64,

    /// The timestamp of when a pause started
    pause_ns: *u64,

    /// Progresses the tick counter by 1 and updates
    /// the timestamps of the last and next tick
    pub fn progressTicks(self: *const Clock) void {
        if(self.frequency.* == 0) {
            const n = nowNs();
            self.next_tick_ns.* = n;
            self.last_tick_ns.* = n + 1;
            self.ticks.* += 1;
            return;
        }

        // Increment the ticks
        self.ticks.* += 1;

        // Number of entire nanoseconds that should pass between two
        // emulated ticks
        var tick_diff: u64 = @divFloor(1_000_000_000, self.frequency.*);

        // At the end of each second, skip the amount of nanoseconds
        // that are not covered by the emulator's frequency
        if(@mod(self.ticks.*, self.frequency.*) == 0) {
            const correction_diff: u64 = @mod(1_000_000_000, self.frequency.*);
            tick_diff += correction_diff;
        }


        // On first tick, set the timestamps
        if(self.ticks.* == 1) self.next_tick_ns.* = nowNs();

        // Update the last and next tick timestamp
        const t = self.next_tick_ns.*;
        self.next_tick_ns.* = self.next_tick_ns.* + tick_diff;
        self.last_tick_ns.* = t;
    }

    /// Gives the number of nanoseconds to the next tick
    /// relative to the current time.
    ///
    /// If the next tick is in the past it will return 0
    pub fn nanosecondsToNextTick(self: *const Clock) u64 {
        const n = nowNs();
        if(n > self.next_tick_ns.*) return 0;
        return self.next_tick_ns.* - n;
    }

    /// Updates the timer's state
    pub fn setState(self: *const Clock, state: ClockState) void {
        if(self.state.* == state) return;

        switch(state) {
            .PAUSED => self.pause_ns.* = nowNs(),
            .RUNNING => self.next_tick_ns.* += nowNs() - self.pause_ns.*
        }

        log.infoln("Changing clock state from {} to {}", .{ self.state.*, state });
        self.state.* = state;
    }

    /// Updates the clock frequency to the provided frequency (in Hz)
    ///
    /// Can be set to 0 to unlock the frequency
    pub fn setFrequency(self: *const Clock, frequency: u64) void {
        self.frequency.* = frequency;
    }

    /// Deallocates the allocated resources of the clock
    pub fn deallocate(self: *const Clock) void {
        self._allocator.destroy(self.pause_ns);
        self._allocator.destroy(self.next_tick_ns);
        self._allocator.destroy(self.last_tick_ns);
        self._allocator.destroy(self.ticks);
        self._allocator.destroy(self.frequency);
        self._allocator.destroy(self.state);
        self._allocator.destroy(self);
    }
};


/// Initializes a new clock
pub fn init(allocator: *const Allocator, config: ClockConfiguration) Allocator.Error!*const Clock {
    const clk = try allocator.create(Clock);
    errdefer allocator.destroy(clk);
    clk._allocator = allocator;
    clk._ptr = clk;

    const state = try allocator.create(ClockState);
    errdefer allocator.destroy(state);
    state.* = .RUNNING;
    clk.state = state;

    const frequency = try allocator.create(u64);
    errdefer allocator.destroy(frequency);
    frequency.* = config.frequency;
    clk.frequency = frequency;

    const ticks = try allocator.create(u64);
    errdefer allocator.destroy(ticks);
    ticks.* = 0;
    clk.ticks = ticks;

    const last_tick_ns = try allocator.create(u64);
    errdefer allocator.destroy(last_tick_ns);
    last_tick_ns.* = 0;
    clk.last_tick_ns = last_tick_ns;

    const next_tick_ns = try allocator.create(u64);
    errdefer allocator.destroy(next_tick_ns);
    next_tick_ns.* = 0;
    clk.next_tick_ns = next_tick_ns;

    const pause_ns = try allocator.create(u64);
    errdefer allocator.destroy(pause_ns);
    pause_ns.* = 0;
    clk.pause_ns = pause_ns;

    return clk;
}

/// The current timestamp (since 01.01.1970) in nanoseconds
fn nowNs() u64 {
       const i = time.Instant.now() catch @panic("HW Time not available");
       return timespecToNs(i.timestamp);
}

/// Compile time check on whether it is built on a POXIS platform
const is_posix = switch (builtin.os.tag) {
    .windows, .uefi, .wasi => false,
    else => true,
};

/// Converts a timespec to nano seconds
/// This is some adjusted code from `std.time` to fit our purpose
fn timespecToNs(timestamp: if (is_posix) posix.timespec else u64) u64 {
    const seconds = @as(u64, @intCast(timestamp.sec));
    return (seconds * time.ns_per_s) + @as(u32, @intCast(timestamp.nsec));
}