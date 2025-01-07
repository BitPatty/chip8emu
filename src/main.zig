// --- std --- //
const std = @import("std");
const heap = @import("std").heap;
const Allocator = @import("std").mem.Allocator;

// --- lib  --- //
const threads = @import("./threading.zig");
const logging = @import("./logging.zig");
const timing = @import("./timing.zig");

pub fn main() !void {
    var gpa: heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    logging.infoln("Initializing clock", .{});
    var fps_clock = timing.ReferenceClock {
        .ticks_per_second = 30,
    };

    logging.infoln("Starting emulator thread", .{});
    const emu_thread = try threads.spawnBackgroundThread(
        *timing.ReferenceClock, &allocator, runEmu, &fps_clock
    );
    defer emu_thread.deallocate();

    logging.infoln("Sleeping for 10 seconds", .{});
    threads.sleep(10_000_000_000);
    emu_thread.cancel();
    logging.infoln("Done", .{});
}


pub fn runEmu(
   cancellation_token: *const threads.CancellationToken,
   fps_clock: *timing.ReferenceClock
) void {
    var i: u32 = 0;


    var rel_clock = timing.RelativeClock{
        .reference_clock = fps_clock,
        .ticks_per_second = 500,
        .ref_start_tick = fps_clock.ticks
    };

    fps_clock.setState(.RUNNING);

    while(!cancellation_token.is_set) : ( i += 1 ) {

        logging.infoln("FPS Ticks: {}, Emu Ticks: {}", .{
            fps_clock.ticks,
            rel_clock.ticks
        });

        rel_clock.waitForTick(cancellation_token);
    }
}

