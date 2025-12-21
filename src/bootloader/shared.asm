%define ENDL 10
%define BREAK xchg bx, bx
%define NUM_BYTES_PER_SECTOR 512
; The reserved space before a stack frame contains:
; - The return address.
; - The old value of BP.
; Note: This only applies in 16-bit mode.
; %define PRE_STACK_FRAME_RESERVED_SPACE_ADDRESS bp + 3

%macro INIT_STACK_FRAME 0
  push bp
  mov bp, sp
%endmacro

%macro DEINIT_STACK_FRAME 0
  mov sp, bp
  pop bp
%endmacro

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
  %define LBA_ADDRESS bp + 4
  %define NUM_HEADS_PER_CYLINDER_ADDRESS bp + 6
  %define NUM_SECTORS_PER_TRACK_ADDRESS bp + 8
  %define RESULT_PTR_ADDRESS bp + 10

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
