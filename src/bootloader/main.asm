; The BIOS loads the bootloader in memory (i.e. RAM) starting from address 0x7c00. The `org` directive lets NASM know the base address to calculate offsets (i.e. the absolute addresses represented by labels) from.
org 0x7c00
; Emit 16-bit code.
bits 16

%define ENDL 0xd, 0xa
%define BREAK xchg bx, bx
%define NUM_BYTES_PER_SECTOR 512
; The reserved space before a stack frame contains:
; - The return address.
; - The old value of BP.
; Note: This only applies in 16-bit mode.
%define PRE_STACK_FRAME_RESERVED_SPACE_ADDRESS bp + 3

%macro INIT_STACK_FRAME 0
  push bp
  mov bp, sp
%endmacro

%macro DEINIT_STACK_FRAME 0
  mov sp, bp
  pop bp
%endmacro

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

  ; Print the startup message.
  mov si, startup_msg
  call real_mode.print_string

  ; Make sure VGA text mode is enabled.
  mov ah, 0
  mov al, 3
  int 0x10

  ; Load 2nd stage / kernel.
  ; TODO: Derive value from a macro defined via the command-line.
  mov al, 128
  xor dx, dx
  mov es, dx
  mov bx, 0x7e00
  call real_mode.get_disk_info
  ; Allocate space on the stack for the result struct populated by the function being called below.
  sub sp, 4
  mov word [bp], 0
  mov word [bp - 2], 0
  ; ---
  push 1
  xor ch, ch
  push cx
  shr dx, 8
  push dx
  sub bp, 4
  push bp
  add bp, 4
  call real_mode.get_chs_address_from_lba
  add sp, 6
  ; Call the interrupt to read disk sectors.
  mov ah, 2
  mov al, KERNEL_SIZE_IN_SECTORS
  mov ch, [bp - 4]
  mov dh, [bp - 2]
  mov cl, [bp - 1]
  mov dl, 0
  push 0
  pop es
  mov bx, 0x7e00
  int 0x13

  ; Enter protected mode.
  ; Disable all interrupts (except for non-maskable interrupts which cannot be disabled solely via software).
  cli
  call real_mode.enable_a20_line
  ; Load the GDT (Global Descriptor Table).
  lgdt [gdt_desc]
  ; Set the lowest bit (bit 0) of the CR0 register to enable protected mode.
  mov eax, cr0
  or eax, 1
  mov cr0, eax

  ; Set up segment registers.
  mov ax, 0x10
  mov ds, ax
  mov ss, ax

  ; Perform a far jump to selector 0x8 (which is an offset into the GDT that points to a 32-bit protected mode code segment descriptor) to load the CS register with a proper PM32 (protected mode 32-bit) descriptor.
  jmp 0x8:0x7e00

  .end:
      hlt
      jmp .end

; Returns:
; - cl: Number of sectors per track.
; - dh: Number of heads.
real_mode.get_disk_info:
  push ax

  mov ah, 0x8
  xor dl, dl
  int 0x13

  add dh, 1
  and cl, 0x3f

  pop ax

  ret

; Params:
; - Stack (2 bytes): LBA
; - Stack (2 bytes): Number of sectors per track
; - Stack (2 bytes): Number of heads per cylinder
; - Stack (2 bytes):
;  - Address of a struct containing the following fields:
;   - Cylinder number (2 bytes)
;   - Head number (1 byte)
;   - Sector number (1 byte)
real_mode.get_chs_address_from_lba:
  %define LBA_ADDRESS bp + 10
  %define NUM_HEADS_PER_CYLINDER_ADDRESS bp + 8
  %define NUM_SECTORS_PER_TRACK_ADDRESS bp + 6
  %define RESULT_PTR_ADDRESS bp + 4

  INIT_STACK_FRAME
  push ax
  push bx
  push cx
  push dx

  ; BX will contain the address of the result struct.
  mov bx, [RESULT_PTR_ADDRESS]

  ; Compute cylinder number.
  mov ax, [NUM_HEADS_PER_CYLINDER_ADDRESS]
  mul word [NUM_SECTORS_PER_TRACK_ADDRESS]
  mov cx, ax
  mov ax, [LBA_ADDRESS]
  div cx
  mov [bx], ax

  ; Compute head number.
  mov ax, [LBA_ADDRESS]
  xor dx, dx
  div word [NUM_SECTORS_PER_TRACK_ADDRESS]
  xor dx, dx
  div word [NUM_HEADS_PER_CYLINDER_ADDRESS]
  mov [bx + 2], dx

  ; Compute sector number.
  mov ax, [LBA_ADDRESS]
  xor dx, dx
  div word [NUM_SECTORS_PER_TRACK_ADDRESS]
  add dx, 1
  mov [bx + 3], dx

  pop dx
  pop cx
  pop bx
  pop ax
  DEINIT_STACK_FRAME
  ret

; Loads data from disk into memory.
; Params:
; - Stack (2 bytes): LBA of start of data.
; - Stack (2 bytes): Number of bytes to load.
; - Stack (2 bytes): Starting address in memory to load data to.
; - Stack (2 bytes): Sectors per track.
; real_mode.load:
;   %define STACK_FRAME_RESERVED_SPACE_ADDRESS bp - 10
;   %define LBA_ADDRESS PRE_STACK_FRAME_RESERVED_SPACE_ADDRESS + 7
;   %define NUM_BYTES_TO_LOAD_ADDRESS PRE_STACK_FRAME_RESERVED_SPACE_ADDRESS + 5
;   %define LOAD_START_ADDRESS_ADDRESS PRE_STACK_FRAME_RESERVED_SPACE_ADDRESS + 3
;   %define SECTORS_PER_TRACK_ADDRESS PRE_STACK_FRAME_RESERVED_SPACE_ADDRESS + 1
;
;   ; Save previous state.
;   enter 0, 0
;   push ax
;   push bx
;   push cx
;   push dx
;
;   ; Compute the sector number using the following formula: Sector number = LBA % Sectors per track + 1
;   mov ax, [LBA_ADDRESS]
;   mov bx, [SECTORS_PER_TRACK_ADDRESS]
;   xor dx, dx
;   div bx
;   add dx, 1
;   ; New local variable => Stack (2 bytes): Sector number
;   push dx
;
;   ; Compute the track/cylinder number using the following formula: LBA / (Sectors per track * 2)
;   mov ax, [SECTORS_PER_TRACK_ADDRESS]
;   mov bx, 2
;   mul bx
;   mov bx, ax
;   mov ax, [LBA_ADDRESS]
;   xor dx, dx
;   div bx
;   ; New local variable => Stack (2 bytes): Track/cylinder number
;   push ax
;
;   ; Compute the head number using the following formula: (LBA % (Sectors per track * 2)) / Sectors per track
;   mov ax, [SECTORS_PER_TRACK_ADDRESS]
;   mov bx, 2
;   mul bx
;   mov bx, ax
;   mov ax, [LBA_ADDRESS]
;   xor dx, dx
;   div bx
;   mov ax, dx
;   mov bx, [SECTORS_PER_TRACK_ADDRESS]
;   xor dx, dx
;   div bx
;   ; New local variable => Stack (2 bytes): Head number
;   push ax
;
;   ; Set the number of the segment to write the loaded data to.
;   xor ax, ax
;   mov es, ax
;   ; Set number of sectors to read.
;   mov ax, [NUM_BYTES_TO_LOAD_ADDRESS]
;   mov bx, [LOAD_START_ADDRESS_ADDRESS]
;   xor dx, dx
;   div bx
;   add ax, 1
;   ; Set head number.
;   mov dh, [STACK_FRAME_RESERVED_SPACE_ADDRESS - 6]
;   ; Set function.
;   mov ah, 0x2
;   ; Set track/cylinder number.
;   mov ch, [STACK_FRAME_RESERVED_SPACE_ADDRESS - 4]
;   ; Set sector number.
;   mov cl, [STACK_FRAME_RESERVED_SPACE_ADDRESS - 2]
;   ; Set drive number.
;   xor dl, dl
;   ; Call the BIOS interrupt.
;   int 0x13
;   ; TODO: Error handling.
;
;   ; Load previous state.
;   add sp, 6
;   pop dx
;   pop cx
;   pop bx
;   pop ax
;   leave
;
;   ret
;
;   %undef RESERVED_SPACE_IN_STACK_FRAME

; Params:
; - si: Address of the string's 1st character.
real_mode.print_string:
  ; Save registers.
  push ax
  push bx
  push si

  mov ah, 0xe
  mov bh, 0
  mov bl, 0xf

  .loop:
      mov al, [si]
      test al, al
      jz .end
      int 0x10
      add si, 1
      jmp .loop

  .end:
      ; Restore registers.
      pop si
      pop bx
      pop ax

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
    mov bx, enabled_a20_line_msg
    call real_mode.print_string
    jmp .end

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

; Params:
; - es: Address of the string's 1st character.
; Returns:
; - ax: Length of the string
; real_mode.get_string_length:
;   ; Save registers.
;   push bx

;   mov ax, es
;   mov bx, [ax]
;   test bx, bx
;   jz .end
;   add ax, 1
;   jmp real_mode.get_string_length

;   .end:
;     sub ax, es

;     ; Restore registers.
;     pop bx

;     ret

; bits 32

; protected_mode.main:
;   mov si, entered_protected_mode_msg
;   call protected_mode.print_string

;   ; call protected_mode.enter_long_mode

;   .end:
;     hlt
;     jmp .end

; ; Params:
; ; - si: Address of the string to print.
; protected_mode.print_string:
;   mov [0xb8000], si

;   .end:
;     ret

; ; Checks if CPUID is supported by attempting to flip the ID bit (bit 21 / 22nd bit) in the EFLAGS register. If we can flip it, CPUID is available.
; ; Returns:
; ; - CF: 1 if CPU ID is available, otherwise 0.
; protected_mode.is_cpu_id_available:
;   ; Save used registers.
;   push eax

;   ; Save the EFLAGS register.
;   pushfd

;   ; Since there are is no instruction for directly modifying the EFLAGS register, use EAX and the stack to modify the EFLAGS register.
;   pushfd
;   pop eax
;   xor eax, 0b0000_0000_0010_0000_0000_0000_0000_0000
;   push eax
;   popfd
;   pushfd
;   pop eax

;   ; Restore the EFLAGS register.
;   popfd

;   and eax, 0b0000_0000_0010_0000_0000_0000_0000_0000
;   clc
;   jnz .on_cpu_id_available
  
;   .on_cpu_id_available:
;     stc

;   ; Restore used registers.
;   pop eax

; protected_mode.is_long_mode_extended_function_available:
;   call protected_mode.is_cpu_id_available
;   jc .end

;   .end:
;     ret

; protected_mode.is_long_mode_available:
;   call protected_mode.is_long_mode_extended_function_available
;   jc .end

;   .end:
;     ret

; protected_mode.enter_long_mode:
;   call protected_mode.is_long_mode_available
;   jc .end

;   .end:
;     ret

startup_msg: db "Starting MFOS...", ENDL, 0
enabled_a20_line_msg: db "Enabled A20 line.", ENDL, 0
entered_protected_mode_msg: db "Entered protected mode.", ENDL, 0
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

; As the boot sector (which contains the bootloader) must be exactly 512 bytes long, we fill the rest of the sector (excluding the above bytes and the last 2 bytes) with zeros.
times 510-($-$$) db 0
; The BIOS expects the last 2 bytes of the boot sector to be 0xaa55.
dw 0xaa55
