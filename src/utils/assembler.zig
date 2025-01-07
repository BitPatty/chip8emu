// --- std --- //
const meta = @import("std").meta;
const fmt = @import("std").fmt;

// --- common --- //
const logging = @import("../common/logging.zig");

const AssemblerError = error {
    EMPTY_INSTRUCTION,
    UNKNOWN_OPCODE,
    NOT_IMPLEMENTED,
    MISSING_ARGUMENT_ADDR,
    MISSING_ARGUMENT_VX,
    MISSING_ARGUMENT_VY,
    MISSING_ARGUMENT_BYTE,
    TOO_MANY_ARGUMENTS,
    INVALID_ADDRESS,
    INVALID_REGISTER,
    INVALID_ARGUMENT_BYTE
};

const OpCode = enum {
    CALL,
    CLS,
    JP,
    RET,
    SE,
    SNE,
    SYS,
};

const tokens = *const []const *const []const u8;

/// Assembles the specified instruction
pub fn assemble(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len == 0) return AssemblerError.EMPTY_INSTRUCTION;
    logging.infoln("Instruction: ({})", .{ instruction.*.len });

    const opcode = meta.stringToEnum(OpCode, instruction.*[0].*) orelse return AssemblerError.UNKNOWN_OPCODE;
    logging.infoln("Opcode: {}", .{opcode});

    switch(opcode) {
        .CALL => return assembleCALL(instruction),
        .CLS => return assembleCLS(instruction),
        .JP => return assembleJP(instruction),
        .RET => return assembleRET(instruction),
        .SE => return assembleSE(instruction),
        .SNE => return assembleSNE(instruction),
        .SYS => return assembleSYS(instruction),
    }
}

/// SYS - Instruction used to call native routines on the host machine
///       and as such not implemented in the emulator
inline fn assembleSYS(_: tokens) AssemblerError![4]u4 {
    return AssemblerError.NOT_IMPLEMENTED;
}

// CALL - Call subroutine at addr.
inline fn assembleCALL(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;
    const arg1 = getInstructionArgumentAtIndex(instruction, 1) orelse return AssemblerError.MISSING_ARGUMENT_ADDR;
    const addr = try parseAddressArgument(arg1);
    return [4]u4 { 0x2, addr[0], addr[1], addr[2] };
}

/// CLS - Clears the display
inline fn assembleCLS(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len > 1) return AssemblerError.TOO_MANY_ARGUMENTS;
    return [_]u4{ 0x0, 0x0, 0xE, 0x0 };
}

// JP - Jump to location nnn
inline fn assembleJP(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(instruction, 1) orelse return AssemblerError.MISSING_ARGUMENT_ADDR;
    const addr = try parseAddressArgument(arg1);

    return [4]u4 { 0x1, addr[0], addr[1], addr[2] };
}

inline fn assembleLD(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

}

/// RET - Return from a subroutine
inline fn assembleRET(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len > 1) return AssemblerError.TOO_MANY_ARGUMENTS;
    return [_]u4{ 0x0, 0x0, 0xE, 0xE };
}

/// SE - Skip next instruction if Vx == kk or Vx == Vy
inline fn assembleSE(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len > 3) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(instruction, 1) orelse return AssemblerError.MISSING_ARGUMENT_VX;
    const vx = try parseRegisterArgument(arg1);
    const arg2 = getInstructionArgumentAtIndex(instruction, 2) orelse return AssemblerError.MISSING_ARGUMENT_BYTE;

    // SE Vx, Vy
    if(arg2.len > 0 and arg2.*[0] == 'V') {
        const vy = try parseRegisterArgument(arg2);
        return [4]u4 { 0x5, vx, vy, 0 };
    }

    // SE Vx, byte
    const kk = try parseByteArgument(arg2);
    return [4]u4 { 0x3, vx, kk[0], kk[1] };
}

/// SNE - Skip next instruction if Vx != kk or Vx != Vy
inline fn assembleSNE(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len > 3) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(instruction, 1) orelse return AssemblerError.MISSING_ARGUMENT_VX;
    const vx = try parseRegisterArgument(arg1);
    const arg2 = getInstructionArgumentAtIndex(instruction, 2) orelse return AssemblerError.MISSING_ARGUMENT_BYTE;

    // SNE Vx, Vy
    if(arg2.len > 0 and arg2.*[0] == 'V') {
        const vy = try parseRegisterArgument(arg2);
        return [4]u4 { 0x9, vx, vy, 0 };
    }

    // SNE Vx, byte
    const kk = try parseByteArgument(arg2);
    return [4]u4 { 0x4, vx, kk[0], kk[1] };
}

/// Assembles an byte argument
fn parseByteArgument(string: *const []const u8) AssemblerError![2]u4 {
    const parsed = fmt.parseInt(u8, string.*, 0) catch | err | {
        switch(err) {
            fmt.ParseIntError.InvalidCharacter => return AssemblerError.INVALID_ARGUMENT_BYTE,
            fmt.ParseIntError.Overflow => return AssemblerError.INVALID_ARGUMENT_BYTE
        }
    };

    return [2]u4 {
        @truncate(parsed >> 4),
        @truncate(parsed)
    };
}

/// Assembles a register argument
/// These are in the pattern Vx where x is the register index
fn parseRegisterArgument(string: *const []const u8) AssemblerError!u4 {
    if(string.len == 0) return AssemblerError.INVALID_REGISTER;
    if(string.*[0] != 'V') return AssemblerError.INVALID_REGISTER;

    return fmt.parseInt(u4, string.*[1..], 0) catch | err | {
        switch(err) {
            fmt.ParseIntError.InvalidCharacter => return AssemblerError.INVALID_REGISTER,
            fmt.ParseIntError.Overflow => return AssemblerError.INVALID_REGISTER
        }
    };
}

/// Assembles an ADDR argument
fn parseAddressArgument(string: *const []const u8) AssemblerError![3]u4 {
    const parsed = fmt.parseInt(u12, string.*, 0) catch | err | {
        switch(err) {
            fmt.ParseIntError.InvalidCharacter => return AssemblerError.INVALID_ADDRESS,
            fmt.ParseIntError.Overflow => return AssemblerError.INVALID_ADDRESS
        }
    };

    return [3]u4 {
        @truncate(parsed >> 8),
        @truncate(parsed >> 4),
        @truncate(parsed)
    };
}

/// Gets the argument of the instruction at the specified index
/// returns NULL if it doesn't exist
inline fn getInstructionArgumentAtIndex(instruction: tokens, index: u2) ?*const []const u8 {
    if(instruction.len < index + 1) return null;
    return instruction.*[index];
}

