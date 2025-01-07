// -- std -- //
const builtin = @import("builtin");
const posix = @import("std").posix;
const time = @import("std").time;

// -- common -- //
const threads = @import("./threads.zig");

pub const ClockState = enum {
    PAUSED,
    RUNNING
};

const NANOSECONDS_PER_MILLISECOND: u64 = 1e6;
const NANOSECONDS_PER_SECOND: u64 = 1e9;

// TODO: Handle case where next timespan is behind current timestamp (drift)

pub const ReferenceClock = struct {
    /// The real-time frequency of the clock in Hz
    ticks_per_second: u64,
    /// The state of the clock
    state: ClockState = .PAUSED,
    /// The number of ticks the clock has performed
    ticks: u64 = 0,
    /// The real-time timestamp of when the clock was started
    start_time_ns: u64 = 0,
    /// The real-time timestamp of when the clock was paused
    pause_time_ns: ?u64  = null,
    /// The total time in real-time the clock spent in paused state
    pause_duration_ns: u64 = 0,

    /// Updates the state of the clock
    pub fn setState(self: *ReferenceClock, state: ClockState) void {
        if(self.state == state) return;

        switch(state) {
            .PAUSED => {
                self.pause_time_ns = epochNanoseconds();
            },
            .RUNNING => {
                if(self.ticks == 0) {
                    self.start_time_ns = epochNanoseconds();
                }
                else {
                    const pause_time = if (self.pause_time_ns == null) 0 else self.pause_time_ns.?;
                    self.pause_duration_ns += epochNanoseconds() - pause_time;
                    self.pause_time_ns = null;
                }
            }
        }

        self.state = state;
    }

    /// Waits for the next tick to occure according to the
    /// real time clock
    pub fn waitForTick(self: *ReferenceClock, cancellation_token: ?*const threads.CancellationToken) void {
        // Wait the frequency is not set or the clock is paused
        // retry after 1ms
        while((self.ticks_per_second == 0) or (self.state == .PAUSED)) {
            if(cancellation_token) | ct | { if(ct.is_set) return; }
            threads.sleep(1e6);
        }

        if(self.ticks == 0) {
            self.ticks += 1;
            return;
        }

        // Number of entire nanoseconds that should pass between two
        // ticks
        var tick_diff_ns: u64 = @divFloor(NANOSECONDS_PER_SECOND, self.ticks_per_second);

        // At the end of each second, skip the amount of nanoseconds
        // that are not covered by the reference's frequency for smoothing
        // and accuracy
        if(@mod(self.ticks + 1, self.ticks_per_second) == 0) {
            const correction_diff_ns: u64 = @mod(NANOSECONDS_PER_SECOND, self.ticks_per_second);
            tick_diff_ns += correction_diff_ns;
        }

        // The runtime in real-time ns that SHOULD have passed while the
        // clock was running according to the current number of ticks
        const ns_per_tick = @divFloor(NANOSECONDS_PER_SECOND, self.ticks_per_second);
        const relative_runtime_ns = self.ticks * ns_per_tick;

        // The runtime in real-time ns that SHOULD pass to the next tick
        const next_tick_relative_runtime_ns = relative_runtime_ns + tick_diff_ns;

        // The runtime in real-time ns that DID pass while the clock was running
        const actual_runtime_ns = epochNanoseconds() - self.start_time_ns - self.pause_duration_ns;

        // Next tick behind schedule
        if(actual_runtime_ns >= next_tick_relative_runtime_ns) {
            self.ticks += 1;
            return;
        }

        // Wait for real time to catch up
        threads.sleep(next_tick_relative_runtime_ns - actual_runtime_ns);
        self.ticks += 1;
    }
};

pub const RelativeClock = struct {
    /// The reference clock
    reference_clock: *ReferenceClock,
    /// The real-time frequency of the clock in seconds
    ticks_per_second: u64,
    /// The number of ticks the clock has performed
    ticks: u64 = 0,
    /// The start tick of the reference clock of when
    /// the relative clock was started
    ref_start_tick: u64,

    /// Increments the tick count by 1
    pub fn tick(self: *RelativeClock) void {
        self.ticks += 1;
    }

    /// Waits for the next tick to occur according to
    /// the reference clock and then performs a tick
    pub fn waitForTick(self: *RelativeClock, cancellation_token: ?*const threads.CancellationToken) void {
        // Wait the frequency is not set retry after 1ms
        while((self.ticks_per_second == 0)) {
            if(cancellation_token) | ct | { if(ct.is_set) return; }
            threads.sleep(1e6);
        }

        const ref_target_ticks = self.ref_start_tick + @divFloor((self.ticks + 1) * self.reference_clock.ticks_per_second, self.ticks_per_second);

        // Wait for reference clock to reach the target ticks
        while(self.reference_clock.ticks < ref_target_ticks)
            self.reference_clock.waitForTick(cancellation_token);

        self.tick();
    }
};

pub fn epochSeconds() u64 {
    return @divFloor(epochNanoseconds(), NANOSECONDS_PER_SECOND);
}

/// The current epoch in milliseconds
pub fn epochMilliseconds() u64 {
    return @divFloor(epochNanoseconds(), NANOSECONDS_PER_MILLISECOND);
}

/// The current epoch in nanoseconds
pub fn epochNanoseconds() u64 {
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
