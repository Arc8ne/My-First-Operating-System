Assemble the bootloader's assembly code into a flat binary that can then be used to create a floppy disk image.

Use the ExFAT filesystem for now.

# Relevant information about `nasm`
The 1st argument is the path to the file containing the assembly code that we want to assemble.

## Relevant options
`-f`: Specifies the format, in this case, we use `bin` to select a binary format.
`-o`: Specifies the path to the outputted binary file.

# Going from assembly code in bootloader to C code (in 2nd stage bootloader / kernel)
- Set up environment for protected mode.
- Transition into protected mode.
- Load kernel into memory.
- Jump to the start of the kernel's code.

Note: This assumes that the kernel is a flat binary.

# CHS
Cylinder and track refer to the same thing.

# Bochs emulated 1.44 MB floppy disk specifications
Sectors per track: 18 (0x12)
Heads per cylinder: 2

# BP and SP registers
When the `push` instruction is executed, the value of SP is first updated and then the pushed value is written to the new location pointed to by SP.

BP points to the 1st byte of the lowermost item of the stack.

SP points to the 1st byte of the topmost item of the stack.

When the stack is empty, BP and SP point to the same location in memory.

This does not just apply to real (16-bit) mode, but also to other modes (i.e. protected/32-bit mode, 64-bit mode).

# LBA to CHS addressing scheme conversion formula
C = LBA / (HPC * SPT)
H = (LBA / SPT) % HPC
S = (LBA % SPT) + 1

## Legend
C: Cylinder number
LBA: Logical Block Address
HPC: Heads Per Cylinder
SPT: Sectors Per Track

# TODOs

# Misc
## Workings
SPT: 18 (0x12)
HPC: 2
LBA: 1
C = 1 / (2 * 18) = 0
H = (1 / 18) % 2 = 0
S = (1 % 18) + 1 = 2

### Legend
SPT: Sectors Per Track
HPC: Heads Per Cylinder
LBA: Logical Block Address
C: Cylinder number
H: Head number
S: Sector number

## Discarded workings
LBA: 512

CHS:
- Cylinder number = LBA / (Sectors per track * 2) = 512 / (18 * 2) = 14 (0xE)
- Head number = (LBA % (Sectors per track * 2)) / Sectors per track = (512 % (18 * 2)) / 18 = 0 (0x0)
- Sector number = LBA % Sectors per track + 1 = 512 % 18 + 1 = 9 (0x9)

`int 0x13` parameters:
- AH: 2
- AL: <To be directly specified via a constant defined when invoking `nasm`>
  - Note: A constant is used to optimize away calculations that could be done at compile-time instead of run-time, reducing the size of the bootloader binary and the number of instructions in the bootloader.
- CH: <Cylinder number that needs to be calculated at run-time since the number of sectors per track (part of the drive geometry information) can only be known at run-time>
- CL: <Sector number that needs to be calculated at run-time since the number of sectors per track can only be known at run-time>
- DH: <Head number that needs to be calculated at run-time since the number of sectors per track can only be known at run-time>
- DL: 0x0 (Might need to be evaluated at run-time as well though it is not needed now)
- ES: 0
- BX: 0x7E00
