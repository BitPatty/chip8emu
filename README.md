# chip-8-emu

An experimental, work in progress emulator for the [CHIP-8](https://en.wikipedia.org/wiki/CHIP-8) platform.


## Instruction Set

The instructions in the following sections are implemented. Chip-8 does not come with any official mnemonics. The emulator in this repository  is designed to have a unique mnemonic per opcode.

The instructions are taken from [COSMAC VIP User's Manual](http://www.bitsavers.org/components/rca/cosmac/COSMAC_VIP_Instruction_Manual_1978.pdf), while some inspiration for the mnemonics has been taken from [Cowgod's Chip-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM).

## Control flow operations

<!-- ------------------------------------------------------------------------------------------------>

### System Call (`SYS` / `0MMM`)

> [!CAUTION]
> The systemcall originally called a routine native to the host CPU at address `MMM`.
> Due to technical limitations this functionality is not implemented.

Executes a machine language subroutine at `0MMM` (subroutine must end with `D4` byte). "Machine language" in this scenario describes native CPU instructions.

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

### Barnch (`JMP` / `1MMM`)

Jumps to the instruction at `MMM`. The call stack is not altered.

**Registers altered**

- `PC` is set to `MMM`

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
| 0x5    | X      | Y      | 0b0000 |
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
| 0x9    | X      | Y      | 0b0000 |
```

<!-- ------------------------------------------------------------------------------------------------>


























### Load Immediate (`LDI` / `6XKK`)

Loads the immediate value `KK` into `VX`.

**Syntax**

```asm
LDI VX KK
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0110 | X      | K      | K      |
| 0x6    | X      | K      | K      |
```

## Arithmetic instructions

### Add Immediate (`ADDI` / `7XKK`)

Adds the immediate value `KK` to the value at register `VX` (i.e. `VX = VX + KK`).

**Syntax**

```asm
ADDI VX KK
```

**Instruction Encoding**

```txt
|   n0   |   n1   |   n2   |   n3   |
| ------ | ------ | ------ | ------ |
| 0b0111 | X      | K      | K      |
| 0x7    | X      | K      | K      |
```


## Misc operations

### Random Byte (`RAND` / `CXKK`)

Writes a random byte masked with `KK` to `VX`, i.e. `VX = <RANDOM BYTE> & KK`.

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

## Frambuffer instructions

### Erase Display (`CLD` / `00E0`)

Sets all bytes in the frame buffer to 0.

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

## References

- [COSMAC VIP User's Manual](http://www.bitsavers.org/components/rca/cosmac/COSMAC_VIP_Instruction_Manual_1978.pdf)
- [Cowgod's Chip-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
- [Chip-8 instruction set](http://devernay.free.fr/hacks/chip8/chip8def.htm)
- [CHIP-8 instruction set](https://github.com/mattmikolay/chip-8/wiki/CHIP%E2%80%908-Instruction-Set)


