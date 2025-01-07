// --- std --- //
const std = @import("std");
const heap = @import("std").heap;
const Allocator = @import("std").mem.Allocator;

// --- common  --- //
const threads = @import("./common/threads.zig");
const logging = @import("./common/logging.zig");
const time = @import("./common/time.zig");
const assembler = @import("./assembly/assembler.zig");

// -- components -- //
const framebuffer = @import("./components/frame-buffer.zig");

pub fn main() !void {
    var gpa: heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    logging.infoln("Initializing clock", .{});
    var fps_clock = time.ReferenceClock {
        .ticks_per_second = 30,
    };

    const word1: []const u8 = "AND";
    const word2: []const u8 = "V1";
    const word3: []const u8 = "V3";

    const instr = [_]*const []const u8{
        &word1,
        &word2,
        &word3
    };

    const dyn_instr: *const []const *const []const u8 = &&instr;

    {
      var i : u32 = 0;

      logging.info("Assembling", .{});

      while(i < dyn_instr.len) : (i += 1) {
        logging.info(" {s} ", .{ dyn_instr.*[i] });
      }

      logging.info("\n", .{});


      const assembly_result = assembler.assemble(dyn_instr);

      if(assembly_result) | value | {
          logging.infoln("Assembled: {X}{X}{X}{X}", .{
            value[0],
            value[1],
            value[2],
            value[3],
          });
      } else |err|  {
        logging.errln("Error : {}", .{err});
      }
    }


    logging.infoln("Starting emulator thread", .{});
    const fb = try framebuffer.init(&allocator, .{});
    defer fb.deallocate();

    const emu_thread = try threads.spawnBackgroundThread(
        *time.ReferenceClock, &allocator, runEmu, &fps_clock
    );
    defer emu_thread.deallocate();

    logging.infoln("Sleeping for 10 seconds", .{});
    threads.sleep(10_000_000_000);
    emu_thread.cancel();
    logging.infoln("Done", .{});
}


pub fn runEmu(
   cancellation_token: *const threads.CancellationToken,
   fps_clock: *time.ReferenceClock
) void {
    var rel_clock = time.RelativeClock{
        .reference_clock = fps_clock,
        .ticks_per_second = 500,
        .ref_start_tick = fps_clock.ticks
    };

    fps_clock.setState(.RUNNING);

    var previous = fps_clock.ticks;

    while(!cancellation_token.is_set) {

        if(fps_clock.ticks > previous ) {
            previous = fps_clock.ticks;
            logging.infoln("FPS Ticks: {}, Emu Ticks: {}", .{
                fps_clock.ticks,
                rel_clock.ticks
            });
        }

        if(@mod(rel_clock.ticks, rel_clock.ticks_per_second) == 0) {
            logging.infoln("Sleeping", .{});
            fps_clock.setState(.PAUSED);
            threads.sleep(1_000_000_000);

            // var i: u64 = 1000;
            // while(i > 0) : (i -= 1) {
            //     rel_clock.tick();
            // }

            fps_clock.setState(.RUNNING);
        }

        rel_clock.waitForTick(cancellation_token);
    }
}

