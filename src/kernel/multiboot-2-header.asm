; This has to be done because the 1st part of a Multiboot 2 header is a struct aligned on an 8-byte boundary.
align 8
multiboot_2_header_start:
MAGIC_NUMBER equ 0xe85250d6
dd MAGIC_NUMBER
ARCHITECTURE_FLAGS equ 0
dd ARCHITECTURE_FLAGS
HEADER_LENGTH equ multiboot_2_header_end - multiboot_2_header_start
dd HEADER_LENGTH
CHECKSUM equ 0 - (MAGIC_NUMBER + ARCHITECTURE_FLAGS + HEADER_LENGTH)
dd CHECKSUM

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

; Termination tag
; Type & flags
dd 0
; Size
dd 8

multiboot_2_header_end: