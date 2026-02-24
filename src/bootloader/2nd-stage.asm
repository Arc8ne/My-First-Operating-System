; This part of the bootloader's 2nd stage does whatever needs to be done in real mode before switching to protected mode and then transferring control over to the part of itself that is written in C.
; The tasks that this part of the bootloader's 2nd stage completes are:
; - Setting up the 16-bit segment registers and stack. [Implemented]
; - Trying to check for the presence of the PCI using a legacy method that primarily involves calling a BIOS function. [Implemented]
; - Get memory map from BIOS.
; - Get all VESA information.
; - Inform BIOS of target processor mode. [Implemented]

; Before transferring control over to the C entrypoint of this bootloader's 2nd stage, the following variables will be globally accessible at pre-determined addresses:
; - was_pci_already_detected (1 byte)
; - vesa_info (struct)
; And the following variables will be passed on to the stack:
; - A variable length array of MemoryMapEntry structs.
; - A variable length array of VesaVideoModeInfo structs.

%define START_ADDRESS 0x7e00
; This stage will be loaded 512 bytes after the bootloader's 1st stage in memory.
org START_ADDRESS
; Emit 16-bit code.
bits 16

jmp main
%include "src/bootloader/shared.asm"

struc VesaInfo
  .Signature resb 4
  .Version resw 1
  .OEMNamePtr resd 1
  .Capabilities resd 1

  .VideoModesOffset resw 1
  .VideoModesSegment resw 1

  .CountOf64KBlocks resw 1
  .OEMSoftwareRevision resw 1
  .OEMVendorNamePtr resd 1
  .OEMProductNamePtr resd 1
  .OEMProductRevisionPtr resd 1
  .Reserved resb 222
  .OEMData resb 256
endstruc

struc VesaVideoModeInfo
  .ModeAttributes resw 1
  .FirstWindowAttributes resb 1
  .SecondWindowAttributes resb 1
  ; In KB.
  .WindowGranularity resw 1
  ; In KB.
  .WindowSize resw 1
  ; Will be 0 if not supported.
  .FirstWindowSegment resw 1
  ; Will be 0 if not supported.
  .SecondWindowSegment resw 1
  .WindowFunctionPtr resd 1
  .BytesPerScanLine resw 1

  ; Added in Revision 1.2.
  ; In pixels(graphics)/columns(text)
  .Width resw 1
  ; In pixels(graphics)/columns(text)
  .Height resw 1
  ; In pixels.
  .CharWidth resb 1
  ; In pixels.
  .CharHeight resb 1
  .PlanesCount resb 1
  .BitsPerPixel resb 1
  .BanksCount resb 1
  ; For reference: http://www.ctyme.com/intr/rb-0274.htm#Table82
  .MemoryModel resb 1
  ; In KB.
  .BankSize resb 1
  ; Count - 1
  .ImagePagesCount resb 1
  ; In Revision 1.0 to 2.0, this will be set to 0. In Revision 3.0, this will be set to 1.
  .Reserved1 resb 1

  .RedMaskSize resb 1
  .RedFieldPosition resb 1
  .GreenMaskSize resb 1
  .GreenFieldPosition resb 1
  .BlueMaskSize resb 1
  .BlueFieldPosition resb 1
  .ReservedMaskSize resb 1
  .ReservedMaskPosition resb 1
  .DirectColorModeInfo resb 1

  ; Added in Revision 2.0.
  .LinearFrameBufferAddress resd 1
  .OffscreenMemoryOffset resd 1
  ; In KB.
  .OffscreenMemorySize resw 1
  ; Available in Revision 3.0 but is useless for now.
  .Reserved2 resb 206
endstruc

main:
  ; Make sure VGA text mode is enabled and set video mode to 80x25 color.
  xor ah, ah
  mov al, 3
  int 0x10

  mov si, startup_msg
  call real_mode.print_string

  ; Load the kernel into memory.
  call real_mode.get_disk_info
  sub sp, 4
  %define CYLINDER_NUMBER_ADDRESS bp - 4
  %define HEAD_NUMBER_ADDRESS bp - 2
  %define SECTOR_NUMBER_ADDRESS bp - 1
  push sp
  push dx
  push cx
  ; Compute the index of the 1st sector that the kernel is located at and then pass it as a function argument.
  lea ax, [end - START_ADDRESS]
  mov bx, NUM_BYTES_PER_SECTOR
  call real_mode.ceil_div
  add ax, 1
  push ax
  call real_mode.get_chs_address_from_lba
  ; Compute the next 16-byte aligned memory address to load the kernel at.
  mov ax, end
  xor dx, dx
  mov bx, 16
  div bx
  sub bx, dx
  mov ax, end
  add ax, bx
  push ax
  ; Call the BIOS interrupt to read disk sectors.
  mov ah, 2
  mov al, KERNEL_SIZE_IN_SECTORS
  mov ch, [CYLINDER_NUMBER_ADDRESS]
  mov dh, [HEAD_NUMBER_ADDRESS]
  ; TODO: Fix bug where value of this register is 2 when its supposed to be 4 in this case.
  mov cl, [SECTOR_NUMBER_ADDRESS]
  ; DBG
  mov cl, 4
  xor dl, dl
  push 0
  pop es
  pop bx
  int 0x13

  ; Try to check for the presence of the PCI by using a legacy method.
  mov ax, 0xb101
  int 0x1a
  // The hexadecimal value below corresponds to `PCI` in ASCII.
  cmp edx, 0x504349
  jne .on_pci_not_detected
  mov [sp], 1
  jmp .end_of_pci_check
  
  .on_pci_not_detected:
    mov [sp], 0

  .end_of_pci_check:

  ; Get all VESA information.
  mov ax, 0x4f00
  mov di, vesa_info
  int 0x10
  cmp ax, 0x004f
  jne .on_failed_to_get_vesa_info
  ; Get all available video mode numbers.
  mov bx, [vesa_info + VesaInfo.VideoModesOffset] ; bx will store the address of the current video mode entry (which is just a 16-bit value corresponding to the current video mode number).

  .get_next_vesa_video_mode_info:
    ; cx will store the current video mode number.
    mov cx, [bx]
    cmp cx, 0xffff
    je .end_of_vesa_info_retrieval
    mov ax, 0x4f01
    sub sp, VesaVideoModeInfo_size
    mov di, sp
    int 0x10
    add bx, 2
    jmp .get_next_vesa_video_mode_info

  .on_failed_to_get_vesa_info:
    mov si, failed_to_get_vesa_info_msg
    call real_mode.print_string

  .end_of_vesa_info_retrieval:

  ; Get memory map from BIOS.
  mov eax, 0xE820
  xor ebx, ebx
  mov ecx, 24
  mov es, bx
  sub sp, 2
  mov di, sp
  int 0x15
  cmp eax, 0x534D4150
  jne .on_memory_map_bios_func_not_avail_or_supported
  
  .get_next_memory_map_entry:
    cmp ebx, 0
    je .end_of_get_memory_map_proc
    mov eax, 0xE820
    mov ecx, 24
    sub sp, 24
    mov di, sp
    int 0x15
    jmp .get_next_memory_map_entry

  .on_memory_map_bios_func_not_avail_or_supported:
    mov si, memory_map_bios_func_not_avail_or_supported_error_msg
    call real_mode.print_string

  .end_of_get_memory_map_proc:

  ; Disable all interrupts (except for non-maskable interrupts which cannot be disabled solely via software).
  cli
  call real_mode.enable_a20_line
  ; Load the GDT (Global Descriptor Table).
  lgdt [gdt_desc]
  ; Enter protected mode by setting the lowest bit (bit 0) of the CR0 register.
  mov eax, cr0
  or eax, 1
  mov cr0, eax

  ; Set up segment registers.
  mov eax, 0x10
  mov ds, eax
  mov ss, eax

  mov eax, [vga_text_buffer_current_offset]
  push eax
  sub esp, 4

  ; Perform a far jump to selector 0x8 (which is an offset into the GDT that points to a 32-bit protected mode code segment descriptor) to load the CS register with a proper PM32 (protected mode 32-bit) descriptor.
  jmp 0x8:end

; Params:
; - si: Address of the string's 1st character.
; Note: This implementation makes use of a BIOS interrupt to print text to the screen.
; real_mode.print_string:
;   ; Save registers.
;   push ax
;   push bx
;   push si
;
;   mov ah, 0xe
;   xor bh, bh
;   mov bl, 0xf
;
;   .loop:
;     mov al, [si]
;     test al, al
;     jz .end
;     int 0x10
;     add si, 1
;     add dword [context], 2
;     jmp .loop
;
;   .end:
;     ; Restore registers.
;     pop si
;     pop bx
;     pop ax
;
;     ret

; Params:
; - si: Address of the string's 1st character.
; Note: This implementation writes directly to the VGA text buffer.
real_mode.print_string:
  ; Save registers.
  push ax
  push bx
  push cx
  push si
  push es

  mov ax, 0xb800
  mov es, ax
  mov bx, [vga_text_buffer_current_offset]

  .loop:
    mov cl, [si]
    test cl, cl
    jz .end
    cmp cl, 10
    jne .write_to_vga_text_buffer
    call real_mode.move_to_next_line_in_vga_text_buffer
    mov bx, [vga_text_buffer_current_offset]
    jmp .loop_end

  .write_to_vga_text_buffer:
    mov [es:bx], cl
    mov byte [es:bx + 1], 0xF
    add bx, 2

  .loop_end:
    add si, 1
    jmp .loop

  .end:
    mov [vga_text_buffer_current_offset], bx

    ; Restore registers.
    pop es
    pop si
    pop cx
    pop bx
    pop ax

    ret

real_mode.move_to_next_line_in_vga_text_buffer:
  ; Save registers.
  push ax
  push bx
  push dx

  mov ax, [vga_text_buffer_current_offset]
  mov bx, 159
  div bx
  mov ax, dx
  add ax, 1
  mov dx, 160
  mul dx
  mov [vga_text_buffer_current_offset], ax

  ; Restore registers.
  pop dx
  pop bx
  pop ax

  ret

; Parameters:
; - AX: Dividend
; - BX: Divisor
; Returns:
; - AX: Resulting number
real_mode.ceil_div:
  add ax, bx
  sub ax, 1
  xor dx, dx
  div bx
  ret

; Returns:
; - CF: Will be clear if the A20 line is enabled, otherwise will be set.
real_mode.is_a20_line_enabled:
  ; Save registers.
  push ax
  push ds
  push es
  push di
  push si

  ; Set ds:si to 0:0x500
  xor ax, ax
  mov ds, ax
  mov si, 0x500
  ; Set es:di to 0xffff:0x510
  mov ax, 0xffff
  mov es, ax
  mov di, 0x510
  ; Save the original byte value at 0:0x500
  mov al, ds:si
  push ax
  ; Set the byte at 0:0x500 to 0.
  mov byte ds:si, 0
  ; Set the byte at 0xffff:0x510 to 0. If the A20 line is disabled, this address should wrap around and thus become 0:0x500.
  mov byte es:di, 0xff
  ; Check if the byte at 0:0x500 is 0xff. If so, that means that the A20 line is disabled (since the address wrapped around), otherwise, the A20 line is enabled.
  mov al, [ds:si]
  cmp al, 0xff
  ; Restore the byte at 0:0x500 to its original value.
  pop ax
  mov byte ds:si, al
  ; Set the return value accordingly based on the comparison result.
  stc
  je .end
  clc

  .end:
    ; Restore registers.
    pop si
    pop di
    pop es
    pop ds
    pop ax
    
    ret

real_mode.wait_until_keyboard_input_buffer_is_empty:
  ; Save registers.
  push ax

  .read_status_reg:
    in al, 0x64
    test al, 2
    jnz .read_status_reg

  ; Restore registers.
  pop ax

  ret

real_mode.wait_until_keyboard_output_buffer_is_full:
  ; Save registers.
  push ax

  .read_status_reg:
    in al, 0x64
    test al, 1
    jz .read_status_reg

  ; Restore registers.
  pop ax

  ret

real_mode.enable_a20_line:
  ; Save registers.
  push ax
  push bx

  ; Check if the A20 line is already enabled.
  call real_mode.is_a20_line_enabled
  jnc .on_a20_line_enabled

  ; Try to enable the A20 line using the `int 0x15 BIOS function 0x2401` method, ignore the returned value (as it might not accurately indicate whether the A20 line is actually enabled), then check if the A20 line is enabled again.
  mov ax, 0x2401
  int 0x15
  call real_mode.is_a20_line_enabled
  jnc .on_a20_line_enabled

  ; Try to enable the A20 line using the keyboard (a.k.a. PS/2) controller method.
  call real_mode.wait_until_keyboard_input_buffer_is_empty
  ; Send the 0xad command to the keyboard controller's command register to disable the keyboard (disable the 1st PS/2 port).
  mov al, 0xad
  out 0x64, al
  call real_mode.wait_until_keyboard_input_buffer_is_empty
  ; Send the 0xd0 command to the keyboard controller's command register to read a byte from the keyboard controller's output port.
  mov al, 0xd0
  out 0x64, al
  call real_mode.wait_until_keyboard_output_buffer_is_full
  in al, 0x60
  ; Save the byte read from the keyboard controller's output port.
  push ax
  ; Send the 0xd1 command to tell the keyboard controller that the next byte we write to the data port should be written to its output port.
  mov al, 0xd1
  out 0x64, al
  call real_mode.wait_until_keyboard_input_buffer_is_empty
  pop ax
  ; Set the 2nd bit of the keyboard controller's output port to enable the A20 gate.
  or al, 2
  out 0x60, al
  call real_mode.wait_until_keyboard_input_buffer_is_empty
  ; Send the 0xae command to the keyboard controller's command register to enable the keyboard (enable the 1st PS/2 port).
  mov al, 0xae
  out 0x64, al
  call real_mode.wait_until_keyboard_input_buffer_is_empty
  call real_mode.is_a20_line_enabled
  jnc .on_a20_line_enabled

  ; Note: As of the time of writing, we do not use all methods of enabling the A20 line for simplicity purposes and since we have not yet set up what is needed to test whether each of these methods work correctly. The default BIOS of QEMU and Bochs already has the A20 line enabled.

  .end:
    ; Restore registers.
    pop bx
    pop ax

    ret
  
  .on_a20_line_enabled:
    mov si, enabled_a20_line_msg
    sti
    call real_mode.print_string
    cli
    jmp .end

startup_msg: db "[Bootloader] Started.", ENDL, 0
enabled_a20_line_msg: db "[Bootloader] Enabled A20 line.", ENDL, 0
failed_to_get_vesa_info_msg: db "[Bootloader - Error] Failed to get VESA information.", ENDL, 0
memory_map_bios_func_not_avail_or_supported_error_msg: db "[Bootloader - Error] BIOS memory map function not available or supported.", ENDL, 0
gdt:
  ; The 0th (null) entry.
  dq 0
  ; The 1st entry for the 32-bit protected mode code segment.
  ; Limit
  dw 0xFFFF
  ; Base (1st part)
  dw 0
  ; Base (2nd part)
  db 0
  ; Access byte
  db 0b1001_1111
  ; Limit + Flags
  db 0b1100_1111
  ; Base (3rd part)
  db 0
  ; The 2nd entry for the 32-bit protected mode data segment.
  ; Limit
  dw 0xFFFF
  ; Base (1st part)
  dw 0
  ; Base (2nd part)
  db 0
  ; Access byte
  db 0b1001_0011
  ; Limit + Flags
  db 0b1100_1111
  ; Base (3rd part)
  db 0
gdt_desc:
  dw gdt_desc - gdt
  dd gdt
vga_text_buffer_current_offset:
  ; The offset from the start to the next unused location in the VGA text buffer.
  ; Note: As the maximum size of a VGA text buffer can be up to 256 KB (which when represented as a numeric literal takes up 3 bytes), the offset is represented as a 32-bit value.
  dd 0
global vesa_info
vesa_info: istruc VesaInfo
  at VesaInfo.Signature, db "VESA"
  times VesaInfo_size db 0
iend
; end:
