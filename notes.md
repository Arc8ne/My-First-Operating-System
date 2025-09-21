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

# TODOs
