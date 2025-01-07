// --- std --- //
const meta = @import("std").meta;
const fmt = @import("std").fmt;

// --- common --- //
const logging = @import("../common/logging.zig");


pub const AssemblerError = error {
    EMPTY_INSTRUCTION,
    UNKNOWN_OPCODE,
    NOT_IMPLEMENTED,
    TOO_MANY_ARGUMENTS,
    INVALID_ADDRESS,
    INVALID_REGISTER,
    INVALID_BYTE,
    INVALID_ARGUMENT,
    MISSING_ARGUMENT,
};

const OpCode = enum {
    ADD,
    AND,
    CALL,
    CLS,
    DRW,
    JP,
    LD,
    OR,
    RET,
    RND,
    SE,
    SHL,
    SHR,
    SKNP,
    SKP,
    SNE,
    SUB,
    SUBN,
    XOR,
    SYS,
};

// Instruction Patterns (CHIP-8)
// ADD  7xkk ✅
// ADD  8xy4 ✅
// ADD  Fx1E ✅
// AND  8xy2 ✅
// CALL 2nnn ✅
// CLS  00E0 ✅
// DRW  Dxyn ✅
// JP   1nnn ✅
// JP   Bnnn ✅
// LD   6xkk ✅
// LD   8xy0 ✅
// LD   Annn ✅
// LD   Fx07 ✅
// LD   Fx0A ✅
// LD   Fx15 ✅
// LD   Fx18 ✅
// LD   Fx29 ✅
// LD   Fx33 ✅
// LD   Fx55 ✅
// LD   Fx65 ✅
// OR   8xy1 ✅
// RET  00EE ✅
// RND  Cxkk ✅
// SE   3xkk ✅
// SE   5xy0 ✅
// SHL  8xyE ✅
// SHR  8xy6 ✅
// SKNP ExA1 ✅
// SKP  Ex9E ✅
// SNE  4xkk ✅
// SNE  9xy0 ✅
// SUB  8xy5 ✅
// SUBN 8xy7 ✅
// XOR  8xy3 ✅
// (SUPER-CHIP-48)
// SCD nibble    00Cn
// SCR   00FB
// SCL   00FC
// EXIT  00FD
// LOW   00FE
// HIGH  00FF
// DRW Vx, Vy, 0     Dxy0
// LD HF, Vx     Fx30
// LD R, Vx  Fx75
// LD Vx, R//    Fx85

pub const tokens = *const []const *const []const u8;


const EMPTY_ARGUMENTS: tokens = &&([_]*const []const u8{});

/// Assembles the specified instruction
pub fn assemble(instruction: tokens) AssemblerError![4]u4 {
    if(instruction.len == 0) return AssemblerError.EMPTY_INSTRUCTION;
    logging.infoln("Instruction: ({})", .{ instruction.*.len });

    const opcode = meta.stringToEnum(OpCode, instruction.*[0].*) orelse return AssemblerError.UNKNOWN_OPCODE;
    logging.infoln("Opcode: {}", .{opcode});

    const arguments: tokens =
        if(instruction.len > 1) &instruction.*[1..]
        else EMPTY_ARGUMENTS;

    switch(opcode) {
        .ADD => return assembleADD(arguments),
        .AND => return assembleAND(arguments),
        .CALL => return assembleCALL(arguments),
        .CLS => return assembleCLS(arguments),
        .DRW => return assembleDRW(arguments),
        .JP => return assembleJP(arguments),
        .LD => return assembleLD(arguments),
        .OR => return assembleOR(arguments),
        .RET => return assembleRET(arguments),
        .RND => return assembleRND(arguments),
        .SE => return assembleSE(arguments),
        .SHL => return assembleSHL(arguments),
        .SHR => return assembleSHR(arguments),
        .SKNP => return assembleSKNP(arguments),
        .SKP => return assembleSKP(arguments),
        .SNE => return assembleSNE(arguments),
        .SUB => return assembleSUB(arguments),
        .SUBN => return assembleSUBN(arguments),
        .XOR => return assembleXOR(arguments),
        .SYS => return assembleSYS(arguments),
    }
}

/// SYS - Instruction used to call native routines on the host machine
///       and as such not implemented in the emulator
inline fn assembleSYS(_: tokens) AssemblerError![4]u4 {
    return AssemblerError.NOT_IMPLEMENTED;
}

/// Assembles the ADD instruction
///
/// ```txt
/// ADD Vx, byte => 7xkk
/// ADD Vx, Vy   => 8xy4
/// ADD I,  Vx   => Fx1E
/// ```
inline fn assembleADD(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;

    const arg2 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;

    // ADD I, Vx
    if(arg1.len == 1) {
        if(arg1.*[0] != 'I') return AssemblerError.INVALID_ARGUMENT;

        const vx = try parseRegisterArgument(arg2);
        return [4]u4{ 0xF, vx, 0x1, 0xE };
    }

    const vx = try parseRegisterArgument(arg1);

    // ADD Vx, Vy
    if(arg2.len > 0 and arg2.*[0] == 'V') {
        const vy = try parseRegisterArgument(arg2);
        return [4]u4{ 0x8, vx, vy, 0x4 };
    }

    const byte = try parseByteArgument(arg2);
    return [4]u4{ 0x7, vx, byte[0], byte[1]};
}

/// Assembles the AND instruction
///
/// ```txt
/// AND Vx, Vy => 8xy2
/// ```
inline fn assembleAND(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    return [4]u4{ 0x8, vx, vy, 2 };
}

/// Assembles the CALL instruction
///
/// ```txt
/// CALL addr => 2nnn
/// ```
inline fn assembleCALL(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 1) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const addr = try parseAddressArgument(arg1);

    return [4]u4{ 0x2, addr[0], addr[1], addr[2] };
}

/// Assembles the CLS instruction
///
/// ```txt
/// CLS => 00E0
/// ```
inline fn assembleCLS(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 0) return AssemblerError.TOO_MANY_ARGUMENTS;
    return [_]u4{ 0x0, 0x0, 0xE, 0x0 };
}

/// Assembles the DRW instruction
///
/// ```txt
/// DRW Vx, Vy, nibble => Dxyn
/// ```
inline fn assembleDRW(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 3) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    const arg3 = getInstructionArgumentAtIndex(arguments, 2) orelse return AssemblerError.MISSING_ARGUMENT;
    const nibble = try parseNibbleArgument(arg3);

    return [4]u4{ 0xD, vx, vy, nibble};
}

/// Assembles the JP instruction
///
/// ```txt
/// JP addr     => 1nnn
/// JP V0, addr => Bnnn
/// ```
inline fn assembleJP(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;

    // JP addr
    if(arguments.len == 1) {
        const addr = try parseAddressArgument(arg1);
        return [4]u4{ 0x1, addr[0], addr[1], addr[2] };
    }

    // JP V0, addr
    if(arg1.*.len != 2) return AssemblerError.INVALID_ARGUMENT;
    if(arg1.*[0] != 'V') return AssemblerError.INVALID_ARGUMENT;
    if(arg1.*[1] != 'V') return AssemblerError.INVALID_ARGUMENT;

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const addr = try parseAddressArgument(arg2);

    return [4]u4{ 0xB, addr[0], addr[1], addr[2] };
}


/// Assembles the LD instruction
///
/// ```txt
/// LD Vx, byte => 6xkk
/// LD Vx, Vy => 8xy0
/// LD Vx, DT => Fx07
/// LD Vx, K => Fx0A
///
/// LD DT, Vx => Fx15
/// LD ST, Vx => Fx18
///
/// LD I, addr => Annn
/// LD F, Vx => Fx29
/// LD B, Vx => Fx33
///
/// LD [I], Vx => Fx55
/// LD Vx, [I] => Fx65
/// ```
inline fn assembleLD(arguments: tokens) AssemblerError![4]u4 {
   if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;

    if(arg1.len == 1) {
        const c = arg1.*[0];

        // LD I, addr
        if(c == 'I') {
            const addr = try parseAddressArgument(arg2);
            return [4]u4{ 0xA, addr[0], addr[1], addr[2] };
        }

        // LD F, Vx
        if(c == 'F')  {
            const vx = try parseRegisterArgument(arg2);
            return [4]u4{ 0xF, vx, 0x2, 0x9 };
        }

        // LD B, Vx
        if(c == 'B')  {
            const vx = try parseRegisterArgument(arg2);
            return [4]u4{ 0xF, vx, 0x3, 0x3 };
        }

        return AssemblerError.INVALID_ARGUMENT;
    }

    // LD Vx, ..
    if(arg1.len == 2 and arg1.*[0] == 'V') {
        const vx = try parseRegisterArgument(arg1);

        // LD Vx, K
        if(arg2.len == 1 and arg2.len == 'K') {
            return [4]u4{ 0xF, vx, 0x0, 0xA };
        }

        // LD Vx, [I]
        if(arg2.len == 3 and arg2.*[0] == '[' and arg2.*[1] == 'I' and arg2.*[2] == ']') {
            return [4]u4{ 0xF, vx, 0x6, 0x5 };
        }

        if(arg2.len == 2) {
            // LD Vx, Vy
            if(arg2.*[0] == 'V') {
                const vy = try parseRegisterArgument(arg2);
                return [4]u4{ 0x8, vx, vy, 0 };
            }

            // LD Vx, DT
            if(arg2.*[0] == 'D' and arg2.*[1] == 'T') {
                return [4]u4{ 0xF, vx, 0x0, 0x7 };
            }
        }

        // LD Vx, byte
        const byte = try parseByteArgument(arg2);
        return [4]u4{ 0x6, vx, byte[0], byte[1] };
    }

    // LD [I], Vx
    if(arg1.len == 3 and arg1.*[0] == '[' and arg1.*[1] == 'I' and arg1.*[2] == ']') {
        const vx = try parseRegisterArgument(arg2);
        return [4]u4{ 0xF, vx, 0x5, 0x5 };
    }

    if(arg1.len == 2) {
        const vx = try parseRegisterArgument(arg2);

        // LD DT, Vx
        if(arg1.*[0] == 'D' and arg1.*[1] == 'T') {
            return [4]u4{ 0xF, vx, 0x1, 0x5 };
        }

        // LD ST, Vx
        if(arg1.*[0] == 'S' and arg1.*[1] == 'T') {
            return [4]u4{ 0xF, vx, 0x1, 0x8 };
        }
    }

    return AssemblerError.INVALID_ARGUMENT;
}

/// Assembles the OR instruction
///
/// ```txt
/// OR Vx, Vy => 8xy1
/// ```
inline fn assembleOR(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    return [4]u4{ 0x8, vx, vy, 0x1 };
}

/// Assembles the RET instruction
///
/// ```txt
/// RET => 00EE
/// ```
inline fn assembleRET(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 0) return AssemblerError.TOO_MANY_ARGUMENTS;
    return [_]u4{ 0x0, 0x0, 0xE, 0xE };
}

/// Assembles the RND instruction
///
/// ```txt
/// RND Vx, byte => Cxkk
/// ```
inline fn assembleRND(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const byte = try parseByteArgument(arg2);

    return [4]u4{ 0xC, vx, byte[0], byte[1] };
}

/// Assembles the SE instruction
///
/// ```txt
/// SE Vx, byte => 3xkk
/// SE Vx, Vy   => 5xy0
/// ```
inline fn assembleSE(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;

    // SE Vx, Vy
    if(arg2.len > 0 and arg2.*[0] == 'V') {
        const vy = try parseRegisterArgument(arg2);
        return [4]u4{ 0x5, vx, vy, 0 };
    }

    // SE Vx, byte
    const kk = try parseByteArgument(arg2);
    return [4]u4{ 0x3, vx, kk[0], kk[1] };
}

/// Assembles the SHL instruction
///
/// ```txt
/// SHL Vx     => 8xxE
/// SHL Vx, Vy => 8xyE
/// ```
inline fn assembleSHL(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    // SHL Vx
    if(arguments.len == 1) return [4]u4{ 0x8, vx, vx, 0xE };

    // SHL Vx, Vy
    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    return [4]u4{ 0x8, vx, vy, 0xE };
}

/// Assembles the SHR instruction
///
/// ```txt
/// SHR Vx     => 8xx6
/// SHR Vx, Vy => 8xy6
/// ```
inline fn assembleSHR(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    // SHR Vx
    if(arguments.len == 1) return [4]u4{ 0x6, vx, vx, 0xE };

    // SHR Vx, Vy
    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    return [4]u4{ 0x8, vx, vy, 0x6 };
}

/// Assembles the SKNP instruction
///
/// ```txt
/// SKNP Vx => ExA1
/// ```
inline fn assembleSKNP(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 1) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    return [4]u4{ 0xE, vx, 0xA, 0x1 };
}

/// Assembles the SKP instruction
///
/// ```txt
/// SKP Vx => Ex9E
/// ```
inline fn assembleSKP(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 1) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    return [4]u4{ 0xE, vx, 0x9, 0xE };
}

/// Assembles the SNE instruction
///
/// ```txt
/// SKP Vx, byte => 4xkk
/// SNE Vx, Vy   => 9xy0
/// ```
inline fn assembleSNE(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;

    // SNE Vx, Vy
    if(arg2.len > 0 and arg2.*[0] == 'V') {
        const vy = try parseRegisterArgument(arg2);
        return [4]u4{ 0x9, vx, vy, 0 };
    }

    // SNE Vx, byte
    const kk = try parseByteArgument(arg2);
    return [4]u4{ 0x4, vx, kk[0], kk[1] };
}

/// Assembles the SUB instruction
///
/// ```txt
/// SUB Vx, Vy => 8xy5
/// ```
inline fn assembleSUB(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    return [4]u4{ 0x8, vx, vy, 0x5 };
}

/// Assembles the SUBN instruction
///
/// ```txt
/// SUBN Vx, Vy => 8xy7
/// ```
inline fn assembleSUBN(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    return [4]u4{ 0x8, vx, vy, 0x7 };
}

/// Assembles the XOR instruction
///
/// ```txt
/// XOR Vx, Vy => 8xy3
/// ```
inline fn assembleXOR(arguments: tokens) AssemblerError![4]u4 {
    if(arguments.len > 2) return AssemblerError.TOO_MANY_ARGUMENTS;

    const arg1 = getInstructionArgumentAtIndex(arguments, 0) orelse return AssemblerError.MISSING_ARGUMENT;
    const vx = try parseRegisterArgument(arg1);

    const arg2 = getInstructionArgumentAtIndex(arguments, 1) orelse return AssemblerError.MISSING_ARGUMENT;
    const vy = try parseRegisterArgument(arg2);

    return [4]u4{ 0x8, vx, vy, 0x3 };
}


/// Assembles an nibble argument
pub fn parseNibbleArgument(string: *const []const u8) AssemblerError!u4 {
    return fmt.parseInt(u4, string.*, 0) catch | err | {
        switch(err) {
            fmt.ParseIntError.InvalidCharacter => return AssemblerError.INVALID_BYTE,
            fmt.ParseIntError.Overflow => return AssemblerError.INVALID_BYTE
        }
    };
}

/// Assembles an byte argument
pub fn parseByteArgument(string: *const []const u8) AssemblerError![2]u4 {
    const parsed = fmt.parseInt(u8, string.*, 0) catch | err | {
        switch(err) {
            fmt.ParseIntError.InvalidCharacter => return AssemblerError.INVALID_BYTE,
            fmt.ParseIntError.Overflow => return AssemblerError.INVALID_BYTE
        }
    };

    return [2]u4 {
        @truncate(parsed >> 4),
        @truncate(parsed)
    };
}

/// Assembles a register argument
/// These are in the pattern Vx where x is the register index
pub fn parseRegisterArgument(string: *const []const u8) AssemblerError!u4 {
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
pub fn parseAddressArgument(string: *const []const u8) AssemblerError![3]u4 {
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
pub inline fn getInstructionArgumentAtIndex(instruction: tokens, index: u2) ?*const []const u8 {
    if(instruction.len < index + 1) return null;
    return instruction.*[index];
}

