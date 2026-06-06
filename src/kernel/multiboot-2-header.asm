MAGIC_NUMBER equ 0xe85250d6
ARCHITECTURE_FLAGS equ 0
HEADER_LENGTH equ multiboot_2_header_end - multiboot_2_header_start
MULTIBOOT_2_HEADER_CHECKSUM equ 0 - (MAGIC_NUMBER + ARCHITECTURE_FLAGS + HEADER_LENGTH)

section .multiboot_2
; The 1st part of a Multiboot 2 header is a struct aligned on an 8-byte boundary.
align 8
multiboot_2_header_start:
dd MAGIC_NUMBER
dd ARCHITECTURE_FLAGS
dd HEADER_LENGTH
dd MULTIBOOT_2_HEADER_CHECKSUM

; The Multiboot 2 specification requires every tag inside a Multiboot 2 header to be aligned on an 8-byte boundary.
align 8
; Framebuffer tag
; Type
dw 5
; Flags
dw 0
; Size
dd 20
; Preferred width (0 if none)
dd 0
; Preferred height (0 if none)
dd 0
; Preferred depth (0 if none)
dd 0

align 8
; Termination tag
; Type & flags
dd 0
; Size
dd 8

multiboot_2_header_end: