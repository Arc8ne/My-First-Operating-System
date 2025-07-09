@REM Build the bootloader.
call nasm src/bootloader/main.asm -f bin -o bin/bootloader.bin

@REM Build the kernel.
@REM call gcc -ffreestanding -fno-pie -m32 src/kernel/main.c -o bin/kernel.bin

@REM Create a floppy disk image.
call dd if=bin/bootloader.bin of=bin/floppy.img
@REM We add this since we are simulating a 1_44 floppy disk (i.e. floppy disk with a total size of 1.44 MB).
call truncate -s 1440k bin/floppy.img
