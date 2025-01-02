// --- std --- //
const std = @import("std");
const heap = @import("std").heap;

// --- common  --- //
const threads = @import("./common/threads.zig");
const log = @import("./common/log.zig");
const memory = @import("./common/memory.zig");

// --- components  --- //
const chip8_clock = @import("./components/clock.zig");
const chip8_frame_buffer = @import("./components/framebuffer.zig");
const chip8_ram = @import("./components/ram.zig");
const chip8_emulator = @import("./emulator.zig");

pub fn main() !void {
    var gpa: heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    log.infoln("Initializing memory", .{});
    const emu_ram = try chip8_ram.init(&allocator, .{});
    defer emu_ram.deallocate();

    log.infoln("Initializing frame buffer", .{});
    const emu_fb = try chip8_frame_buffer.init(&allocator, .{});
    defer emu_fb.deallocate();

    log.infoln("Initializing clock", .{});
    const emu_clock = try chip8_clock.init(&allocator, .{});
    defer emu_clock.deallocate();

    log.infoln("Initializing emulator", .{});
    const emu = try chip8_emulator.init(&allocator, .{
        .clock = emu_clock,
        .frame_buffer = emu_fb,
        .memory = emu_ram,
    });
    defer emu.deallocate();

    log.infoln("Starting emulator thread", .{});
    const emu_thread = try threads.spawnBackgroundThread(
        *const chip8_emulator.Emulator, &allocator, runEmulator, emu
    );
    defer emu_thread.deallocate();

    log.infoln("Sleeping for 10 seconds", .{});
    threads.sleep(10_000_000_000);
    emu_thread.cancel();
    log.infoln("Done", .{});
}


pub fn runEmulator(
   cancellation_token: *const threads.CancellationToken,
   emu: *const chip8_emulator.Emulator
) void {
    var i: u32 = 0;

    while(!cancellation_token.is_set) : ( i += 1 ) {
        if(@mod(emu.clock.ticks.*, emu.clock.frequency.* + 1) == 0)
        log.infoln("Ticks {}, state {}", .{ emu.clock.ticks.*, emu.clock.state.* });
        emu.clock.progressTicks();
        const sleepDuration = emu.clock.nanosecondsToNextTick();
        if(sleepDuration < 1000) continue;
        threads.sleep(sleepDuration);
    }
}