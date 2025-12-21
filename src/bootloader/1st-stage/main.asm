; The BIOS loads the bootloader in memory (i.e. RAM) starting from address 0x7c00. The `org` directive lets NASM know the base address to calculate offsets (i.e. the absolute addresses represented by labels) from.
org 0x7c00
; Emit 16-bit code.
bits 16

real_mode.main:
  ; Use an intermediary register (i.e. AX) to hold the constant value 0 (that will be copied into the DS and ES registers next) as constant values cannot be directly copied into segment registers (registers with names ending in 'S') (i.e. DS, ES, SS registers).
  xor ax, ax
  ; Initialize the DS and ES registers to 0 as they should have the value 0 and them having that value initially is not guaranteed.
  mov ds, ax
  mov es, ax

  ; Set up the stack.
  mov ss, ax
  ; As the stack grows downwards (i.e. from a higher address to a lower address), make it grow downwards from where the bootloader is currently loaded at in memory.
  mov bp, 0x7c00
  mov sp, bp

  ; Load the 2nd stage of the bootloader into memory.
  call real_mode.get_disk_info
  ; Allocate space on the stack for the result struct populated by the function being called below.
  sub sp, 4
  mov dword [bp - 4], 0
  ;
  sub bp, 4
  push bp
  add bp, 4
  shr dx, 8
  push dx
  xor ch, ch
  push cx
  push 1
  call real_mode.get_chs_address_from_lba
  add sp, 6
  ; Call the interrupt to read disk sectors.
  mov ah, 2
  mov al, BOOTLOADER_STAGE_2_SIZE_IN_SECTORS
  mov ch, [bp - 4]
  mov dh, [bp - 2]
  mov cl, [bp - 1]
  xor dl, dl
  push 0
  pop es
  mov bx, 0x7e00
  int 0x13

  jmp 0x7e00

%include "src/bootloader/shared.asm"

; As the boot sector (which contains the bootloader) must be exactly 512 bytes long, we fill the rest of the sector (excluding the above bytes and the last 2 bytes) with zeros.
times 510-($-$$) db 0
; The BIOS expects the last 2 bytes of the boot sector to be 0xaa55.
dw 0xaa55
