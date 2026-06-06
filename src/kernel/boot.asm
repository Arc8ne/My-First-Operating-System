%include "src/kernel/multiboot-header.asm"
%include "src/kernel/multiboot-2-header.asm"

extern kernel_main

; Export all functions defined in this file with their respective sizes as it is required by the ELF format. This is done because it could be useful when debugging or implementing call tracing.
global start:function start_func_size
global enable_paging:function enable_paging_func_size

section .text
start:
  ; At this point of execution:
  ; - The bootloader (i.e. GRUB) has loaded the kernel into 32-bit protected mode on an x86 system.
  ; - Interrupts are disabled.
  ; - Paging is disabled.
  ; - The processor state is as defined in the Multiboot standard.
  ; - The kernel has full control of the CPU.
  ; - The kernel can only make use of hardware features and any code it provides as part of itself.
  ; - There are no security restrictions, safeguards, and debugging mechanisms apart from what the kernel provides itself.

  ; Ensure that interrupts are disabled until we set up an IDT.
  cli

  ; Set up the stack (which is required by higher-level languages like C).
  mov esp, stack_top

  ; At this stage, crucial processor state should be initialized before the high-level kernel is entered as it is best to minimize the early environment where crucial features are offline. Since the processor has not been fully initialized yet, features such as floating point instructions and instruction set extensions will not have been initialized yet. C++ features like global constructors and exceptions will require runtime support to work.
  ; The following tasks should be completed at this stage:
  ; - Loading the GDT.
  ; - Enabling paging.
  ; - Initialize the floating point instructions feature of the processor.
  ; - Initialize the instruction set extensions of the processor.

  call load_gdt

  ; The ABI requires the stack to be 16-byte aligned at the time of the call instruction (which pushes a return pointer that is 4 bytes in size afterwards). Since the stack was originally 16-byte aligned and we have pushed 0 (which is a multiple of 16) bytes of data onto it so far, the alignment has been preserved and thus the call is well-defined.
  call kernel_main

  .halt:
    hlt
    jmp .halt
start_func_size equ $ - start

; Note: It is recommended that interrupts be disabled prior to loading the GDT.
load_gdt:
  ; It is important to reload the segment registers after this instruction.
  lgdt [gdtr]

  ; Perform a far jump to the last instruction of this function to reload the code segment register.
  jmp 0x8:.load_segment_registers

  .load_segment_registers:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ret

; This function enables paging in protected mode.
; Parameters:
; - The page directory's physical address (4 bytes)
enable_paging:
  ; Load the CR3 register with the page directory's address.
  mov eax, [esp + 4]
  mov cr3, eax

  ; Set the paging (PG) and protection (PE) bits of the CR0 register.
  mov eax, cr0
  or eax, 0b10000000000000000000000000000001
  mov cr0, eax

  ret
enable_paging_func_size equ $ - enable_paging

section .data
gdt_start:
; Null descriptor
dq 0

; Kernel mode code segment descriptor
; -----------------------------------
; Limit (least significant 2 bytes)
dw 0xFFFF
; Base (least significant 3 bytes)
dw 0
db 0
; Access byte
db 0b10011111
; Limit (most significant 4 bits) & Flags
db 0b11001111
; Base (most significant byte)
db 0

; Kernel mode data segment descriptor
; -----------------------------------
; Limit (least significant 2 bytes)
dw 0xFFFF
; Base (least significant 3 bytes)
dw 0
db 0
; Access byte
db 0b10010011
; Limit (most significant 4 bits) & Flags
db 0b11001111
; Base (most significant byte)
db 0
gdt_end:

gdtr:
; Size (2 bytes)
dw gdt_end - gdt_start - 1
; Offset (4 bytes)
dd gdt_start

section .bss
align 16
stack_bottom:
; Stack size: 16 KiB
resb 16384
stack_top: