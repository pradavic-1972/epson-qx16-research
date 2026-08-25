; QX16_INT10_VM6.ASM
; TSR INT 10h hook for Epson QX-16
;
; Intercepts AX=0040h / INT 10h and translates it into:
;   BIOS mode 6
;   APX-ICRT VM6 (640x400, 1 bpp)
;
; Every other INT 10h call is passed to the original BIOS handler.
;
; Build:
;   nasm -f bin QX16_INT10_VM6.ASM -o QX16VM6.COM
;
; Install:
;   QX16VM6

bits 16
cpu 8086
org 100h

        jmp installer

old_int10:
        dw 0
        dw 0

int10_handler:
        cmp ax,0040h
        je  .set_vm6

        jmp far [cs:old_int10]

.set_vm6:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es

        mov ax,0006h
        pushf
        call far [cs:old_int10]

        mov dx,03CEh
        mov al,0C0h
        out dx,al

        mov dx,03CFh
        mov al,0E0h
        out dx,al

        pop es
        pop ds
        pop bp
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        iret

resident_end:

installer:
        push cs
        pop ds

        mov ax,3510h
        int 21h
        mov [old_int10],bx
        mov [old_int10+2],es

        mov dx,int10_handler
        mov ax,2510h
        int 21h

        mov dx,installed_msg
        mov ah,09h
        int 21h

        ; NASM treats resident_end as a relocatable label, so it cannot
        ; apply the shift operator to it at assembly time. Calculate the
        ; paragraph count at run time instead.
        mov dx,resident_end
        add dx,15
        mov cl,4
        shr dx,cl
        mov ax,3100h
        int 21h

installed_msg:
        db 'QX-16 VM6 INT 10h hook installed.',13,10
        db 'Use AX=0040h / INT 10h for 640x400 VM6.',13,10,'$'
