# chip-8-emu

An experimental, work in progress emulator for the [CHIP-8](https://en.wikipedia.org/wiki/CHIP-8) platform.


## CHIP-8 programs

CHIP-8 programs are stored in memory

## Terminology & Notations

### Units

The following units are used in the program as well as this documentation.

| Unit        | Abbreviation | Definition                                                 |
| ----------- | ------------ | ---------------------------------------------------------- |
| bit         | b            | A bit can have one of two values: `0` and `1`.             |
| nibble      | n            | A nibble consists of four consecutive bits: `bbbb`         |
| byte        | B            | A byte consists of 8 consecutive bits: `bbbbbbbb`          |
| kibibyte    | KiB          | A kibibyte consists of 1024 (`2^10`) consecutive bytes     |
| kibibyte    | KiB          | A kibibyte consists of 1024 (`2^10`) consecutive bytes     |
| mebibyte    | MiB          | A mebibyte consists of 1024 (`2^10`) consecutive kibibytes |

### Representation of numbers

Numbers in the program and this documentation are represented...

- ...in binary notation (base 2), prefixed via `0b`. E.g. the binary number `0101` is represented as `0b0101`, or
- ...in hexadecimal notation (base 16), prefixed via `0x`. E.g. the binary number `0101` is represented as `0x5`, or
- ...in decimal notation (base 10), without prefix. E.g. the binary number `0101` is represented as `5`.

The underscore character `_` may be used between two characters to split long chains of numbers for readability purposes.
As such `0b0101_0101_0101` is equivalent to `0b010101010101`.

## Display

The program emulates a 64 wide (x-axis) and 32 spots high (y-axis) monochrome display with the zero (0/0) coordinates
being in the top left corner.

```txt
┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
┆0x00/0x00               0x3F/0x00 ┆
┆                                  ┆
┆                                  ┆
┆                                  ┆
┆                                  ┆
┆0x00/0x1F               0x3F/0x1F ┆
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

The contents of the display can be updated using the `SHOW` (`DXYN`) or the `CLD` (`00E0`) instruction, whereas a set bit (`1`)
is considered to be `on` (white spot) and `0` to be `off` (black spot). The `SHOW` instructions will update the contents at coordinates
starting from `X`/`Y` based on the

### Patterns

CHIP-8 uses patterns for drawing. Patterns can be stored at arbitrary memory locations. When using the `SHOW` (`DXYN`) instruction
the screen will be updated starting from `VX`/`VY` based on the `N` bytes at the memory location pointed at by `I`. However, this
is not an overwrite but instead the existing content of the display starting from `VX`/`VY` is XOR'd with the new spot data:

| Current spot | `DXYN` spot | Result |
| ------------ | ----------- | ------ |
| 0            | 0           | 0      |
| 0            | 1           | 1      |
| 1            | 0           | 1      |
| 1            | 1           | 0      |

If the current spot has the value `1` and the `DXYN` spot also has the value `1` then `VF` is set to `0x01`.

## Memory

The addressable memory of the CHIP-8 is byte-sized and ranges from `0x0000` to (including) `0x7FFF` (4 KiB).


### Lower bounds

The memory region from `0x0000` to (including) `0x01FF` is reserved and as it was originally used for installing
the CHIP-8 interpreter on the COSMAC VIP (see instruction manual page 9 and page 13). As such, loaded programs
effectively start at `0x0200`.

The range is technically addressable and the documentation leads me to believe that there were no mechanisms
in place in the COSMAC VIP preventing one from manipulating that memory region. The instruction
manual simply states that you should be "careful not to write into memory locations `0x0000-0x01FF`".

Since the interpreter of this program is not stored in the emulated memory you can modify it as you see fit, however,
I can not make any guarantees that this will work with other interpreters and or this one in the future. As such my
*recommendation* for you is to not use this region.

### Upper bounds

The instruction manual states to only use up to (including) `0x069F` for 2048-byte RAM and `0x0E8F` for 4096-byte RAM
for a program which gives a capacity of 592 and 1608 CHIP-8 instructions, respectively due to the last 352 bytes of
the memory being used "for variables and display refresh".

> It's unclear to me why `0x0E90` to `0x0E9F` are missing. Is it not addressable by the host?

In appendix C of the manual one can find the memory map of the original interpreter, which, extended for 4096-byte RAM,
looks as follows:

| Location (2048)     | Location (4096)     | Use                                       |
| ------------------- | ------------------- | ----------------------------------------- |
| `0x0000` - `0x01FF` | `0x0000` - `0x01FF` | CHIP-8 language interpreter               |
| `0x0200` - `0x069F` | `0x0200` - `0x0E8F` | User program                              |
| `0x06A0` - `0x06FF` | `0x0EA0` - `0x0EFF` | Interpreter work area                     |
| `0x0700` - `0x07FF` | `0x0F00` - `0x0FFF` | RAM area for display refresh              |

The registers `V0` to `VF` are stored in the last 16 bytes of the interpreter work area.

## Registers

### I-Pointer register

CHIP-8 has a special-purpose 2-byte register labeled `I` that is used to store pointers to a memory location.

### Variable registers

CHIP-8 defines 16 variable registers, labeled `V0` to `VF`, each one with a capacity of 1 byte.

## Instruction Set

The instructions in the following sections are implemented. Each instruction consists of a 2-byte opcode.

CHIP-8 does not come with any official mnemonics. This program extends each opcode with a unique mnemonic.

<!-- ------------------------------------------------------------------------------------------------>

### System Call (`SYS` / `0MMM`)

> [!CAUTION]
> The system call originally called a routine native to the host CPU at address `0x0MMM`.
> This functionality is not yet going to be implemented.

Executes a machine language subroutine at `0MMM` (subroutine must end with `D4` byte).
"Machine language" in this scenario describes native CPU instructions.

**Syntax**

```asm
SYS MMM
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0000 | M      | M      | M      |
| 0x0    | M      | M      | M      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Unconditional Jump (`JMP` / `1MMM`)

Jumps to the instruction at `0MMM` without altering the call stack.

**Registers altered**

- `PC` is set to `0MMM`

**Syntax**

```asm
JMP MMM
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0001 | M      | M      | M      |
| 0x1    | M      | M      | M      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Call subroutine (`CALL` / `2MMM`)

Call the subroutine at `MMM`. The subroutine must end with `00EE` (`RET`). `PC + 2` is pushed onto the call stack.

**Registers altered**

- `PC` is set to `0MMM`
- `SP` is set to `SP + 2`

**Syntax**

```asm
CALL MMM
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0010 | M      | M      | M      |
| 0x2    | M      | M      | M      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Return from subroutine (`RET` / `00EE`)

Returns from a subroutine to the address stored at the top of the call stack.

**Registers altered**

- `PC` is set to the 16-bit value at `SP`
- `SP` is decremented by 2

**Syntax**

```asm
RET
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0000 | 0b0000 | 0b1110 | 0b1110 |
| 0x0    | 0x0    | 0xE    | 0xE    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Skip if equal immediate (`SEI` / `3XKK`)

Skips the next instruction if `VX` is equal to `KK`.

**Registers altered**

- If `VX == KK`, `PC` is set to `PC + 4`

**Syntax**

```asm
SEI VX, KK
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0011 | X      | K      | K      |
| 0x3    | X      | K      | K      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Skip if not equal immediate (`SNEI` / `4XKK`)

Skips the next instruction if `VX` is not equal to `KK`.

**Registers altered**

- If `VX != KK`, `PC` is set to `PC + 4`

**Syntax**

```asm
SNEI VX, KK
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0100 | X      | K      | K      |
| 0x4    | X      | K      | K      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Skip if equal (`SE` / `5XY0`)

Skips the next instruction if `VX` is equal to `VY`.

**Registers altered**

- If `VX == VY`, `PC` is set to `PC + 4`

**Syntax**

```asm
SE VX, VY
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0101 | X      | Y      | 0b0000 |
| 0x5    | X      | Y      | 0x0    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Skip if not equal (`SNE` / `9XY0`)

Skips the next instruction if `VX` is not equal to `VY`.

**Registers altered**

- If `VX != VY`, `PC` is set to `PC + 4`

**Syntax**

```asm
SNE VX, VY
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1001 | X      | Y      | 0b0000 |
| 0x9    | X      | Y      | 0x0    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Skip if equal hex key (`SEX` / `EX9E`)

Skips the next instruction if `VX` is equal to `LSD`.

**Registers altered**

- If `VX == LSD`, `PC` is set to `PC + 4`

**Syntax**

```asm
SEX VX
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1110 | X      | 0b1001 | 0b1110 |
| 0xE    | X      | 0x9    | 0xE    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Skip if not equal hex key (`SNEX` / `EXA1`)

Skips the next instruction if `VX` is not equal to `LSD`.

**Registers altered**

- If `VX != LSD`, `PC` is set to `PC + 4`

**Syntax**

```asm
SNEX VX
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1110 | X      | 0b1010 | 0b0001 |
| 0xE    | X      | 0xA    | 0x1    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Load Immediate (`LDI` / `6XKK`)

Loads the immediate value `KK` into `VX`.

**Registers altered**

- `VX` is set to `KK`

**Syntax**

```asm
LDI VX, KK
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0110 | X      | K      | K      |
| 0x6    | X      | K      | K      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Add Immediate (`ADDI` / `7XKK`)

Adds the immediate value `KK` to the value at register `VX` (i.e. `VX = VX + KK`).

**Registers altered**

- `VX` is set to `VX + KK`

**Syntax**

```asm
ADDI VX, KK
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0111 | X      | K      | K      |
| 0x7    | X      | K      | K      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Divide (`DIV` / `8XY1`)

Divides `VX` by `VY` and puts the result in `VX`

**Registers altered**

- `VX` is set to `VX / VY`
- `VF` is set to @TODO

**Syntax**

```asm
DIV VX, VY
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1000 | X      | Y      | 0b0001 |
| 0x8    | X      | Y      | 0x1    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Binary AND (`AND` / `8XY2`)

Masks `VX` with `VY` and puts the result in `VX`.

**Registers altered**

- `VX` is set to `VX & VY`
- `VF` is set to @TODO

**Syntax**

```asm
AND VX, VY
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1000 | X      | Y      | 0b0010 |
| 0x8    | X      | Y      | 0x2    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Add with carry (`ADD` / `8XY4`)

Adds `VY` to `VX` and puts the result i n `VX`.

**Registers altered**

- `VX` is set to `VX + VY`
- `VF` is set to `0x00` if `VX + VY <= 0xFF`, else `0x01`

**Syntax**

```asm
ADD VX, VY
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1000 | X      | Y      | 0b0100 |
| 0x8    | X      | Y      | 0x4    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Subtract with carry (`SUB` / `8XY5`)

Subtracts `VY` from `VX` and puts the result i n `VX`.

**Registers altered**

- `VX` is set to `VX - VY`
- `VF` is set to `0x00` if `VX < VY`, else `0x01`

**Syntax**

```asm
SUB VX, VY
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1000 | X      | Y      | 0b0101 |
| 0x8    | X      | Y      | 0x5    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Load timer value (`LC` / `FX07`)

Sets `VX` to the current timer value.

**Registers altered**

- `VX` is set to the current timer value

**Syntax**

```asm
LC VX
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1111 | X      | 0b0000 | 0b0111 |
| 0xF    | X      | 0x0    | 0x7    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Store timer value (`SC` / `FX15`)

Sets the current timer value to `VX`.

**Registers altered**

\-

**Syntax**

```asm
SC VX
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1111 | X      | 0b0001 | 0b0101 |
| 0xF    | X      | 0x1    | 0x5    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Store tone duration (`STD` / `FX18`)

Sets the tone duration to `VX`.

**Registers altered**

\-

**Syntax**

```asm
STD VX
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1111 | X      | 0b0001 | 0b1000 |
| 0xF    | X      | 0x1    | 0x8    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Load hex key value (`LX` / `FX0A`)

Sets `VX` to the pressed hex digit key.

The instruction waits for a key to be pressed.

**Registers altered**

- `VX` is set to the pressed key

**Syntax**

```asm
LX VX
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1111 | X      | 0b0000 | 0b1010 |
| 0xF    | X      | 0x0    | 0xA    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Load Random Byte (`RAND` / `CXKK`)

Writes a random byte masked with `KK` to `VX`.

**Registers altered**

- `VX` is set to `<RANDOM BYTE> & KK`

**Syntax**

```asm
RAND VX KK
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1100 | X      | K      | K      |
| 0xC    | X      | K      | K      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Erase Display (`CLD` / `00E0`)

Sets all bytes in the frame buffer to 0.

**Registers altered**

\-

**Syntax**

```asm
CLD
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0000 | 0b0000 | 0b1110 | 0b0000 |
| 0x0    | 0x0    | 0xE    | 0x0    |
```

<!-- ------------------------------------------------------------------------------------------------>

### Load into Memory Pointer (`IL` / `AMMM`)

Loads the value `0MMM` into the memory pointer `I`.

**Registers altered**

- `I` is set to `0MMM`

**Syntax**

```asm
IL MMM
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1010 | M      | M      | M      |
| 0xA    | M      | M      | M      |
```

<!-- ------------------------------------------------------------------------------------------------>

### Add to Memory Pointer (`IADD` / `FX1E`)

Adds the value of `VX` to `I` and stores the result `I`.

**Registers altered**

- `I` is set to `I + VX`

**Syntax**

```asm
IADD VX
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b1111 | X      | 0b0001 | 0b1110 |
| 0xF    | X      | 0x1    | 0xE    |
```

<!-- ------------------------------------------------------------------------------------------------>

## References

1. [RCA COSMAC VIP CDP188711 Instruction Manual](http://www.bitsavers.org/components/rca/cosmac/COSMAC_VIP_Instruction_Manual_1978.pdf)
2. [Cowgod's CHIP-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
3. [CHIP-8 instruction set](http://devernay.free.fr/hacks/chip8/chip8def.htm)
4. [CHIP-8 instruction set](https://github.com/mattmikolay/chip-8/wiki/CHIP%E2%80%908-Instruction-Set)


