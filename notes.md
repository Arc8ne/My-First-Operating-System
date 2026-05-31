# Overview of plan
- Allow the kernel to be booted by a Multiboot2-compliant bootloader (e.g. GRUB).
- Use `ext2` for the boot and root filesystems.
- Allow the kernel to be booted by a Multiboot-compliant bootloader (e.g. versions of GRUB older than v2).
- Make a dedicated bootloader that can load the kernel.

# New build process
- Compile the kernel.
  - Note: The linker script will either assume that the starting physical address of the kernel in memory will be 1 MiB (commonly assumed when targeting BIOS systems) or 2 MiB (reliable for both BIOS and UEFI systems).
- Generate a bootable ISO containing both the GRUB bootloader and the kernel.

# TODOs - Kernel
- Implement logging via the COM serial output port.
 - Rationale: This could be useful for automated testing of the kernel and the OS.
- Get framebuffer information from the Multiboot 2 compliant bootloader.
- Implement printing of text to the screen.
- Implement retrieval of text input.
- Implement scrolling.
- Implement driver for storage devices using the IDE storage interface.
 - Rationale: This should be implemented because the storage interface used (by default) by the storage devices (e.g. hard disks) emulated by QEMU is IDE.

# Targets
## Bootloaders
- Multiboot 2 compliant bootloaders (e.g. modern versions of GRUB).
- Multiboot compliant bootloaders (e.g. legacy versions of GRUB before v2).
- Dedicated bootloader for this OS.
  - This target should only be supported if there really is a need for this OS to have its own dedicated bootloader.

## Systems
- BIOS
- UEFI

## Architectures
- x86
- x86-64

Note: Targeting the x86 architecture is probably easier than targeting the x86_64 architecture so focus on the former one first.

## Boot filesystems
- ext2
- FAT32 [Optional]

# Steps (Bootloader -> Kernel)
1. The bootloader's 1st stage (512 bytes in size) loads its 2nd stage. [Done]
1. Control is passed over to the bootloader's 2nd stage. [Done]
1. The bootloader's 2nd stage completes the tasks that can only be done via Assembly code in real (16-bit) mode.
1. The bootloader's 2nd stage loads the kernel into memory. [Done]
1. The bootloader's 2nd stage enables long (64-bit) mode if it is supported by the device, otherwise it enables protected (32-bit) mode if it is supported by the device, otherwise it ends execution with a message indicating that the device is not supported.
1. Control is passed over to the kernel. [Done]
1. The kernel completes the tasks that it needs to perform.

## Note
The bootloader is split in to 2 stages because more space is needed to contain the code that allows it to complete all the necessary tasks.

# Requirements that a kernel should meet so that it can be loaded by a custom bootloader or an existing bootloader (e.g. GRUB)
1. Kernel should be multiboot compliant.
1. Kernel should be a file (either a raw binary file or an ELF executable) in a filesystem (i.e. FAT16, FAT32, ext4 etc.).

# Multiboot and Multiboot 2 protocols
By default, a Multiboot compliant bootloader loads the kernel at physical address `0x100000` (at the 1 MiB mark) in memory.

By default, a Multiboot 2 compliant bootloader (i.e. GRUB) reads the ELF headers or the `load_addr` tag in the Multiboot 2 header to determine where to load the kernel at in memory. It typically loads the kernel at physical address `0x100000` (1 MiB).

# Bootloader sequence checklist
- Setup 16-bit segment registers and stack. [Done, R]
- Print startup message. [Done]
- Check presence of PCI. [R]
  - 1 of the methods used for this task requires real mode as it involves calling a BIOS function.
  - As of the time of writing, the part of this task requiring real mode has been implemented, the remainder can be implemented in C.
- Check presence of CPUID.
  - Checking for the availability of this instruction can be implemented via inline assembly in C but it is recommended to implement it in Assembly as the compiler can change EFLAGS at any time. This task does not require real mode.
- Check presence of MSRs.
  - Some Assembly might be required but real mode is not required.
- Test whether A20 line is already enabled. [Done]
 - Its easier for this task to be done in protected mode.
 - As of the time of writing, this task was done in real mode.
- Enable A20 line. [Done, R]
 - 1 of the methods requires real mode as it primarily involves calling a BIOS function.
- Load GDTR (Global Descriptor Table Register). [Done]
- Inform BIOS of target processor mode. [Done, R]
- Get memory map from BIOS. [R]
  - This task can only be done in real mode because it relies on the IVT (Interrupt Vector Table) and BIOS data areas.
  - However, it can be done outside of real mode if a temporary switch back to either real mode or virtual 8086 mode is performed.
- Locate kernel in filesystem.
- Allocate memory to load kernel image. [Done]
- Load kernel image into buffer. [Done]
- Enable graphics mode. [R]
- Check kernel image ELF headers.
- Enable long mode, if 64-bit.
- Allocate and map memory for kernel segments.
- Setup stack. [Done]
- Setup COM serial output port.
- Setup IDT.
- Disable PIC.
- Check presence of CPU features (NX, SMEP, x87, PCID, global pages, TCE, WP, MMX, SSE, SYSCALL), and enable them.
- Assign a PAT to write combining.
- Setup FS/GS base.
- Load IDTR.
- Enable APIC and setup using information in ACPI tables.
- Setup GDT and TSS.

## Legend
A: Can only be done using Assembly code.
R: Can only be done in real (16-bit) mode.

# Characteristics of a task that requires real mode
BIOS Interrupts: It requires at least 1 BIOS interrupt to be called.

16-bit Code/Data: It assumes 16-bit operands and `<segment>:<offset>` addressing (e.g. `segment * 16 + offset`).

Direct Hardware Access: It tries to write directly to VGA display memory at `0xA0000`, direct port I/O to legacy controllers, or depends on the 1 MB memory limit.

Memory Footprint: It operates within the 1st 1 MB of physical RAM.

# [Task] Get memory map from BIOS
Invoke the `INT 0x15, AX = 0xE820` function.

# [Task] Enabling graphics mode
## Steps (for BIOS system)
### Query VESA BIOS for support and modes
1. Invoke `INT 0x10, AX=0x4F00` which queries VBE information to ensure it is supported.
1. Invoke `INT 0x10, AX=0x4F01` which queries a specific VBE mode to confirm it supports a linear framebuffer (which is indicated by bit 7 of the mode attribute being set).
### Configure and set the graphics mode
1. Select a VBE mode number (e.g. a standard mode like `0x118` for `1024x768x32`).
1. Enable Linear Framebuffer (LFB) by OR-ing the mode number with `0x4000` (e.g. `BX = 0x4118`).
1. Invoke `INT 0x10, AX = 0x4F02, BX = <Mode number>` to set the mode.
### Retrieve framebuffer information
1. Invoke `INT 0x10, AX = 0x4F01` to get the framebuffer's 32-bit physical address (a.k.a the `physBasePtr` field).
1. Note the number of bytes per scanline (a.k.a the pitch) as it is important for calculating a pixel's address since it may be larger than `<Width> * <Bytes per pixel>`.
### Set up memory management (protected/long mode)
1. Map the framebuffer's physical address into the kernel's virtual address space (typically using paging).
 - The memory region must be mapped as write-combined or uncached for performance.

For UEFI system, skip BIOS calls (`INT 0x10`) and use Graphics Output Protocol (GOP) which directly provides a linear framebuffer pointer during boot services.

Pixel address formula: `<Framebuffer's starting address> + (<y> * <Pitch>) + (<x> * <Bytes per pixel>)`

## Workings
The following data structure is passed to the C entrypoint of the bootloader's 2nd stage:
```
struct {
  uint8 does_bios_report_pci_present;
  VideoControllerInformation video_controller_information;
  uint32 num_video_modes;
  VideoModeInformation video_mode_information_entries[num_video_modes];
  uint32 num_memory_map_entries;
  MemoryMapEntry memory_map_entries[num_memory_map_entries];
}
```

## PCI presence check
### How to do this?
The ordered list of methods below can be used to check if the PCI is present:
1. Call the BIOS 0x1a interrupt.
2. ACPI
3. Assume its there and if not then inform the user that their computer is not supported.

For BIOS systems, BIOS interrupt `0x1a` with `AX = 0xb101` can be used to check if the system uses Configuration Space Access Mechanism 1 or 2. If this function does not exist, it will be uncertain if the system supports PCI or not.

### Why is it highly recommended / required to do this?
In order for an OS to know what hardware is plugged into a system, the PCI bus must be scanned.

The PCI allows the OS to query devices to discover their Vendor ID (VID) and Device ID (DID) which are required to identify which drivers to load.

### Procedure
Check if the `BIOS 0x1a AX = 0xb101` function exists.
Invoke the function if it exists.

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
