Assemble the bootloader's assembly code into a flat binary that can then be used to create a floppy disk image.

Use the ExFAT filesystem for now.

# Steps
1. The bootloader's 1st stage (512 bytes in size) loads its 2nd stage.
1. Control is passed over to the bootloader's 2nd stage.
1. The bootloader's 2nd stage completes the tasks that can only be done via Assembly code in real (16-bit) mode.
1. The bootloader's 2nd stage loads the kernel into memory.
1. The bootloader's 2nd stage enables long (64-bit) mode if it is supported by the device, otherwise it enables protected (32-bit) mode if it is supported by the device, otherwise it ends execution with a message indicating that the device is not supported.
1. Control is passed over to the kernel.
1. The kernel completes the tasks that it needs to perform.

## Note
The bootloader is split in to 2 stages because more space is needed to contain the code that allows it to complete all the necessary tasks.

# Requirements that a kernel should meet so that it can be loaded by a custom bootloader or an existing bootloader (e.g. GRUB)
1. Kernel should be multiboot compliant.
1. Kernel should be a file (either a raw binary file or an ELF executable) in a filesystem (i.e. FAT16, FAT32, ext4 etc.).

# Bootloader sequence checklist
- Setup 16-bit segment registers and stack. [Done, A, R]
- Print startup message. [Done]
- Check presence of PCI, CPUID, MSRs.
  - PCI
  - CPUID
  - MSRs
- Enable and confirm enabled A20 line. [Done, A]
- Load GDTR. [Done, A]
- Inform BIOS of target processor mode. [Done, A, R]
- Get memory map from BIOS. [R]
- Locate kernel in filesystem.
- Allocate memory to load kernel image. [Done, A]
- Load kernel image into buffer. [Done, A]
- Enable graphics mode. [R]
- Check kernel image ELF headers.
- Enable long mode, if 64-bit. [A]
- Allocate and map memory for kernel segments.
- Setup stack. [Done, A]
- Setup COM serial output port. [R]
- Setup IDT. [A]
- Disable PIC.
- Check presence of CPU features (NX, SMEP, x87, PCID, global pages, TCE, WP, MMX, SSE, SYSCALL), and enable them.
- Assign a PAT to write combining.
- Setup FS/GS base.
- Load IDTR. [A]
- Enable APIC and setup using information in ACPI tables. [A]
- Setup GDT and TSS. [A]

## Legend
A: Can only be done using Assembly code.
R: Can only be done in real (16-bit) mode.

## PCI presence check
The ordered list of methods below can be used to check if the PCI is present:
1. Call the BIOS 0x1a interrupt.
2. ACPI
3. Assume its there and if not then inform the user that their computer is not supported.

# TODOs

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

# LBA to CHS addressing scheme conversion formula
C = LBA / (HPC * SPT)
H = (LBA / SPT) % HPC
S = (LBA % SPT) + 1

## Legend
C: Cylinder number
LBA: Logical Block Address
HPC: Heads Per Cylinder
SPT: Sectors Per Track

# Formulas and workings for deriving the offset in the VGA text buffer to the next line
Current VGA text buffer offset = 0
Current row number = Current VGA text buffer offset % (Number of bytes per row - 1) = 0 % (160 -1) = 0 % 159 = 0
Next row number = Current row number + 1 = 0 + 1 = 1
Offset to start of next line in VGA text buffer = Next row number * Number of bytes per row = 1 * 160 = 160

# Bug/issue reports
## 1
Issues:
- The 1st couple (i.e. 6) characters of the kernel startup message were not being printed to the screen.
  - Upon inspection of the kernel's disassembly using both `bochs` and `ndisasm`, it was observed that the address of the kernel startup message did not point to the start of the string but to a character that was a few bytes after the 1st character which was (why the 1st couple of characters were not being printed to the screen).
- Top-level initialization of a global variable was not occurring and the global variable had to be manually initialized in the kernel's entrypoint function or else it would contain a garbage value (as a result of not being initialized).

Relevant context:
- The kernel was being loaded at `0x800a` in memory.
- The kernel was written in C, `clang` was used to compile it, and `ld` with a custom linker script was being used to link it and explicitly control the ordering of sections within the resulting binary file.

Fix: Load the kernel at a memory address that is divisible by 16 (i.e. aligned to 16 bytes). For example, instead of loading the kernel at `0x800a` (which is not divisible by 16) in memory, load it at `0x8010` in memory instead.

Explanation of the fix:
- Since the 1st 6 characters of the kernel startup message were not being printed to the screen, the memory address of the kernel startup message string was 6 bytes ahead of the actual location, since `0x800a + 6 = 0x8010`, the kernel should be loaded at `0x8010` instead.
- Although the kernel's starting address was explicitly specified in the custom linker script, it might be possible that the linker adjusted the memory addresses of the variables and literals in the C code (i.e. the global variable and the kernel startup message string literal) to use a sane alignment, thus causing their memory addresses to be incorrect (more specifically off by a few bytes).

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

## `int 0x13` parameters:
- AH: 2
- AL: <Number of sectors to load>
  - To be directly specified via a constant defined when invoking `nasm`.
  - Note: A constant is used to optimize away calculations that could be done at compile-time instead of run-time, reducing the size of the bootloader binary and the number of instructions in the bootloader.
- CH: <Cylinder number>
  - Needs to be calculated at run-time since the number of sectors per track (part of the drive geometry information) can only be known at run-time.
- CL: <Sector number>
  - Needs to be calculated at run-time since the number of sectors per track can only be known at run-time.
- DH: <Head number>
  - Needs to be calculated at run-time since this value can only be known at run-time.
- DL: 0x0
  - Might need to be evaluated at run-time as well though it is not needed now.
- ES: 0
- BX: 0x7E00
