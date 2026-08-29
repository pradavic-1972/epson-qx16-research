BITS 16
CPU 8086
ORG 0

; ============================================================================
; QX-16 EPSP READ-ONLY DOS BLOCK DEVICE DRIVER - V1
; ============================================================================
;
; Installs one DOS block unit backed by the EPSP-mounted image.
;
; QX-11-style availability semantics:
;   - the DOS drive unit is always installed
;   - epspd does NOT have to be running during CONFIG.SYS
;   - first media access lazily performs IDENTIFY/PARAMETERS
;   - if epspd is absent, DOS receives "Drive not ready"
;   - starting epspd later allows the same drive to reconnect on Retry/access
;
; CONFIG.SYS:
;     DEVICE=QXEPSP.SYS
;
; DOS assigns the next available drive letter.
;
; V1 is intentionally READ ONLY.
;
; Supported request commands:
;   00h  INIT
;   01h  MEDIA CHECK
;   02h  BUILD BPB
;   04h  READ
;   08h  WRITE              -> write protected
;   09h  WRITE VERIFY       -> write protected
;
; QX-16 serial transport -- exact proven values:
;   uPD7201 DATA = 11h
;   uPD7201 CMD  = 13h
;   8253 CH2     = 06h
;   8253 CTRL    = 07h
;   async x16, divisor 2, ~62,400 baud
;
; The EPSP initialization sequence is done during driver INIT:
;   IDENTIFY   6Bh
;   PARAMETERS 6Dh
;
; Each DOS logical-sector read is translated to:
;   READ 70h
;   GET_BLOCK 73h block 0
;   GET_BLOCK 73h block 1
;   GET_BLOCK 73h block 2
;   GET_BLOCK 73h block 3
;
; First V1 media geometry is the FAT12 image already proven on hardware:
;   512 bytes/sector
;   2 sectors/cluster
;   1 reserved sector
;   2 FATs
;   112 root entries
;   720 total sectors
;   FDh media
;   2 sectors/FAT
;   9 sectors/track
;   2 heads
;
; ============================================================================

SER_DATA equ 11h
SER_CMD  equ 13h
TMR_CH2  equ 06h
TMR_CTRL equ 07h
DIVISOR  equ 2

SOH equ 01h
STX equ 02h
ETX equ 03h
EOT equ 04h
ENQ equ 05h
ACK equ 06h

STATUS_DONE          equ 0100h
STATUS_ERROR         equ 8000h

ERR_WRITE_PROTECT    equ 00h
ERR_NOT_READY        equ 02h
ERR_UNKNOWN_COMMAND  equ 03h
ERR_READ_FAULT       equ 0Bh

SECTORS_PER_TRACK equ 9
HEADS             equ 2
SECTORS_PER_CYL   equ 18

; ============================================================================
; DOS DEVICE HEADER
; ============================================================================

device_header:
    dw 0FFFFh,0FFFFh        ; next driver
    dw 0000h                ; block-device attributes
    dw strategy
    dw interrupt
    db 1                    ; one block unit
    times 7 db 0

; ============================================================================
; DRIVER STATE
; ============================================================================

request_off dw 0
request_seg dw 0

io_lba      dw 0
io_left     dw 0
io_done     dw 0
io_xfer_off dw 0
io_xfer_seg dw 0

drv_cyl     db 0
drv_head    db 0
drv_sector  db 1
drv_block   db 0

drv_dest        dw sector_buffer
drv_block_start dw sector_buffer
drv_rx_checksum db 0

epsp_online     db 0        ; 0=server not connected, 1=last connection succeeded

; ============================================================================
; FAT12 BPB
; ============================================================================

bpb:
    dw 512                  ; bytes/sector
    db 2                    ; sectors/cluster
    dw 1                    ; reserved sectors
    db 2                    ; FAT count
    dw 112                  ; root entries
    dw 720                  ; total sectors
    db 0FDh                 ; media descriptor
    dw 2                    ; sectors/FAT

    ; These later fields are harmless for DOS versions that only consume
    ; the original DOS 2.x BPB and useful to later DOS versions.
    dw 9                    ; sectors/track
    dw 2                    ; heads
    dd 0                    ; hidden sectors

bpb_array:
    dw bpb

; ============================================================================
; STRATEGY
; ============================================================================

strategy:
    push ds
    push cs
    pop ds

    mov [request_off],bx
    mov [request_seg],es

    pop ds
    retf

; ============================================================================
; INTERRUPT ENTRY
; ============================================================================

interrupt:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    push cs
    pop ds

    call load_request_ptr
    mov al,es:[bx+2]

    cmp al,00h
    je short command_init

    cmp al,01h
    je short command_media_check

    cmp al,02h
    je short command_build_bpb

    cmp al,04h
    jne short .not_read
    jmp command_read
.not_read:

    cmp al,08h
    jne short .not_write
    jmp command_write_protected
.not_write:

    cmp al,09h
    jne short .not_write_verify
    jmp command_write_protected
.not_write_verify:

    jmp command_unknown

; ============================================================================
; COMMAND 00h - INIT
; ============================================================================

command_init:
    mov si,msg_init
    call bios_print

    ; Mimic the QX-11 external-drive behavior:
    ; install the block unit whether or not an EPSP server is currently present.
    ; The first real media access will attempt to connect.
    mov byte [epsp_online],0

    call load_request_ptr

    mov byte es:[bx+13],1

    mov word es:[bx+14],end_resident
    mov ax,cs
    mov word es:[bx+16],ax

    mov word es:[bx+18],bpb_array
    mov word es:[bx+20],ax

    mov word es:[bx+3],STATUS_DONE

    mov si,msg_ready
    call bios_print

    mov si,msg_not_ready_hint
    call bios_print

    jmp interrupt_exit

; ============================================================================
; COMMAND 01h - MEDIA CHECK
; ============================================================================

command_media_check:
    call ensure_epsp_online
    jnc short .media_ready

    ; Drive exists, but the remote EPSP media/server is unavailable.
    call load_request_ptr
    mov word es:[bx+3],STATUS_DONE | STATUS_ERROR | ERR_NOT_READY
    jmp interrupt_exit

.media_ready:
    call load_request_ptr

    ; 1 = media has not changed.
    mov byte es:[bx+14],1
    mov word es:[bx+3],STATUS_DONE
    jmp interrupt_exit

; ============================================================================
; COMMAND 02h - BUILD BPB
; ============================================================================

command_build_bpb:
    mov word es:[bx+18],bpb
    mov ax,cs
    mov word es:[bx+20],ax

    mov word es:[bx+3],STATUS_DONE
    jmp interrupt_exit

; ============================================================================
; COMMAND 04h - READ
;
; Request packet:
;   +14 DWORD transfer address
;   +18 WORD  sector count
;   +20 WORD  zero-based starting logical sector
; ============================================================================

command_read:
    ; DOS/BIOS startup code may have touched the 7201.
    ; Restore the exact known-good EPSP serial state for each DOS request.
    call serial_init

    ; C: remains installed even when epspd is absent.  Lazily establish
    ; the EPSP session when DOS actually accesses the drive.
    call ensure_epsp_online
    jnc short .server_ready

    call load_request_ptr
    mov word es:[bx+18],0
    mov word es:[bx+3],STATUS_DONE | STATUS_ERROR | ERR_NOT_READY
    jmp interrupt_exit

.server_ready:
    call load_request_ptr

    mov ax,es:[bx+20]
    mov [io_lba],ax

    mov ax,es:[bx+18]
    mov [io_left],ax

    mov word [io_done],0

    mov ax,es:[bx+14]
    mov [io_xfer_off],ax

    mov ax,es:[bx+16]
    mov [io_xfer_seg],ax

.read_loop:
    cmp word [io_left],0
    je short .read_success

    mov ax,[io_lba]
    call lba_to_chr

    call epsp_read_current_sector
    jnc short .sector_ok

    ; Treat a broken/lost EPSP session like removable media becoming
    ; unavailable.  Mark it offline so the next Retry/access reconnects.
    mov byte [epsp_online],0

    call load_request_ptr
    mov ax,[io_done]
    mov es:[bx+18],ax
    mov word es:[bx+3],STATUS_DONE | STATUS_ERROR | ERR_NOT_READY
    jmp interrupt_exit

.sector_ok:
    call copy_sector_to_request_buffer

    inc word [io_lba]
    inc word [io_done]
    dec word [io_left]
    jmp .read_loop

.read_success:
    call load_request_ptr
    mov ax,[io_done]
    mov es:[bx+18],ax
    mov word es:[bx+3],STATUS_DONE
    jmp interrupt_exit

; ============================================================================
; WRITE COMMANDS - READ ONLY V1
; ============================================================================

command_write_protected:
    mov word es:[bx+18],0
    mov word es:[bx+3],STATUS_DONE | STATUS_ERROR | ERR_WRITE_PROTECT
    jmp interrupt_exit

command_unknown:
    mov word es:[bx+3],STATUS_DONE | STATUS_ERROR | ERR_UNKNOWN_COMMAND
    jmp interrupt_exit

; ============================================================================
; COMMON EXIT
; ============================================================================

interrupt_exit:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    retf

load_request_ptr:
    mov bx,[request_off]
    mov ax,[request_seg]
    mov es,ax
    ret

; ============================================================================
; DOS LBA -> QX/EPSP C/H/R
; ============================================================================

lba_to_chr:
    push ax
    push bx
    push dx

    xor dx,dx
    mov bx,SECTORS_PER_CYL
    div bx
    mov [drv_cyl],al

    mov ax,dx
    xor dx,dx
    mov bx,SECTORS_PER_TRACK
    div bx
    mov [drv_head],al

    mov ax,dx
    inc al
    mov [drv_sector],al

    pop dx
    pop bx
    pop ax
    ret

; ============================================================================
; COPY 512 BYTES TO DOS FAR TRANSFER BUFFER
; ============================================================================

copy_sector_to_request_buffer:
    push ax
    push cx
    push si
    push di
    push es

    mov ax,[io_xfer_seg]
    mov es,ax
    mov di,[io_xfer_off]

    mov si,sector_buffer
    mov cx,512

.copy_loop:
    mov al,[si]
    mov es:[di],al

    inc si
    inc di
    jnz short .no_wrap

    ; Maintain a contiguous physical destination when DI wraps.
    mov ax,es
    add ax,1000h
    mov es,ax

.no_wrap:
    loop .copy_loop

    mov [io_xfer_off],di
    mov ax,es
    mov [io_xfer_seg],ax

    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; ============================================================================
; BIOS-LEVEL STATUS OUTPUT
;
; Safe for CONFIG.SYS initialization: does not call DOS INT 21h.
; DS:SI -> zero-terminated string.
; ============================================================================

bios_print:
    push ax
    push bx
    push si

.bp_next:
    lodsb
    or al,al
    jz short .bp_done

    mov ah,0Eh
    mov bh,00h
    mov bl,07h
    int 10h
    jmp short .bp_next

.bp_done:
    pop si
    pop bx
    pop ax
    ret

msg_init:
    db 13,10,'QXEPSP: loading EPSP block driver...',13,10,0

msg_ready:
    db 'QXEPSP: driver loaded - EPSP read-only disk support installed.',13,10,0

msg_not_ready_hint:
    db 'QXEPSP: drive remains available; if epspd is offline DOS will report Drive not ready.',13,10,0

; ============================================================================
; PROVEN QX-16 SERIAL INITIALIZATION
; ============================================================================

serial_init:
    cli

    mov al,0B6h
    out TMR_CTRL,al

    mov ax,DIVISOR
    out TMR_CH2,al
    mov al,ah
    out TMR_CH2,al

    mov al,18h
    out SER_CMD,al
    nop
    nop
    nop
    nop

    ; WR4 = async x16, 1 stop, no parity
    mov al,04h
    out SER_CMD,al
    mov al,44h
    out SER_CMD,al

    ; WR3 = 8-bit RX enabled
    mov al,03h
    out SER_CMD,al
    mov al,0E1h
    out SER_CMD,al

    ; WR5 = 8-bit TX enabled
    mov al,05h
    out SER_CMD,al
    mov al,0EAh
    out SER_CMD,al

    mov al,02h
    out SER_CMD,al
    mov al,10h
    out SER_CMD,al

    mov al,10h
    out SER_CMD,al

    mov al,01h
    out SER_CMD,al
    xor al,al
    out SER_CMD,al

    sti
    ret

serial_putc:
    push ax
.wait:
    in   al,SER_CMD
    test al,04h
    jz   .wait
    pop  ax
    out  SER_DATA,al
    ret

; ============================================================================
; LAZY EPSP CONNECTION
;
; The DOS drive is always installed.  When DOS first accesses it, or after a
; failed transaction, establish the EPSP session here.
;
; CF=0 = epspd responded and PARAMETERS completed
; CF=1 = server/media unavailable
; ============================================================================

ensure_epsp_online:
    cmp byte [epsp_online],1
    je short .already_online

    ; Always restore the proven QX-16 serial programming before probing.
    call serial_init

    call epsp_identify
    jc short .offline

    call epsp_parameters
    jc short .offline

    mov byte [epsp_online],1
    clc
    ret

.offline:
    mov byte [epsp_online],0
    stc
    ret

.already_online:
    clc
    ret

; ============================================================================
; EPSP INITIAL HANDSHAKES
; ============================================================================

epsp_identify:
    push ax
    push cx
    push si

    mov al,EOT
    call serial_putc

    mov si,epsp_address
    mov cx,4
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail

    mov si,identify_header
    mov cx,7
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail

    mov si,identify_text
    mov cx,4
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail

    mov al,EOT
    call serial_putc

    mov si,identify_reply_header
    mov cx,7
    call epsp_expect_packet
    jc short .fail

    mov al,ACK
    call serial_putc

    mov si,identify_reply_text
    mov cx,5
    call epsp_expect_packet
    jc short .fail

    mov al,ACK
    call serial_putc

    call epsp_wait_eot
    jc short .fail

    clc
    jmp short .done

.fail:
    stc

.done:
    pop si
    pop cx
    pop ax
    ret

epsp_parameters:
    push ax
    push cx
    push si

    mov al,EOT
    call serial_putc

    mov si,epsp_address
    mov cx,4
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail

    mov si,parameters_header
    mov cx,7
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail

    mov si,parameters_text
    mov cx,4
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail

    mov al,EOT
    call serial_putc

    mov si,parameters_reply_header
    mov cx,7
    call epsp_expect_packet
    jc short .fail

    mov al,ACK
    call serial_putc

    mov si,parameters_reply_text
    mov cx,7
    call epsp_expect_packet
    jc short .fail

    mov al,ACK
    call serial_putc

    call epsp_wait_eot
    jc short .fail

    clc
    jmp short .done

.fail:
    stc

.done:
    pop si
    pop cx
    pop ax
    ret

; ============================================================================
; EPSP 512-BYTE SECTOR READ
; ============================================================================

epsp_read_current_sector:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    push cs
    pop ds

    ; ------------------------------------------------------------
    ; Build READ 70h text block for the requested CHR.
    ; ------------------------------------------------------------

    mov byte [epsp_read_text+0],02h
    mov byte [epsp_read_text+1],01h

    mov al,[drv_head]
    mov [epsp_read_text+2],al

    mov al,[drv_cyl]
    mov [epsp_read_text+3],al

    mov al,[drv_sector]
    mov [epsp_read_text+4],al

    mov byte [epsp_read_text+5],01h
    mov byte [epsp_read_text+6],01h
    mov byte [epsp_read_text+7],02h
    mov byte [epsp_read_text+8],SECTORS_PER_TRACK
    mov byte [epsp_read_text+9],2Ah
    mov byte [epsp_read_text+10],0FFh
    mov byte [epsp_read_text+11],03h

    xor al,al
    mov si,epsp_read_text
    mov cx,12

.sum_read:
    add al,[si]
    inc si
    loop .sum_read

    neg al
    mov [epsp_read_text+12],al

    ; ------------------------------------------------------------
    ; READ 70h
    ; ------------------------------------------------------------

    mov al,EOT
    call serial_putc

    mov si,epsp_address
    mov cx,4
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail_jump1

    mov si,epsp_read_header
    mov cx,7
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail_jump1

    mov si,epsp_read_text
    mov cx,13
    call epsp_send_packet

    call epsp_wait_ack
    jc short .fail_jump1

    mov al,EOT
    call serial_putc

    mov si,epsp_read_reply_header
    mov cx,7
    call epsp_expect_packet
    jc short .fail_jump1

    mov al,ACK
    call serial_putc

    mov si,epsp_read_reply_text
    mov cx,5
    call epsp_expect_packet
    jc short .fail_jump1

    mov al,ACK
    call serial_putc

    call epsp_wait_eot
    jc short .fail_jump1

    jmp short .read_complete

.fail_jump1:
    jmp epsp_read_fail

.read_complete:
    mov byte [drv_block],0
    mov word [drv_dest],sector_buffer

; ------------------------------------------------------------
; GET_BLOCK 0..3
; ------------------------------------------------------------

.block_loop:
    mov al,EOT
    call serial_putc

    mov si,epsp_address
    mov cx,4
    call epsp_send_packet

    call epsp_wait_ack
    jnc short .gb_addr_ok
    jmp .fail_jump2
.gb_addr_ok:

    mov si,epsp_get_header
    mov cx,7
    call epsp_send_packet

    call epsp_wait_ack
    jnc short .gb_header_ok
    jmp .fail_jump2
.gb_header_ok:

    ; 02 block 03 checksum
    mov byte [epsp_get_text+0],02h

    mov al,[drv_block]
    mov [epsp_get_text+1],al

    mov byte [epsp_get_text+2],03h

    mov al,[drv_block]
    add al,05h
    neg al
    mov [epsp_get_text+3],al

    mov si,epsp_get_text
    mov cx,4
    call epsp_send_packet

    call epsp_wait_ack
    jnc short .gb_text_ok
    jmp .fail_jump2
.gb_text_ok:

    mov al,EOT
    call serial_putc

    mov si,epsp_get_reply_header
    mov cx,7
    call epsp_expect_packet
    jnc short .gb_reply_header_ok
    jmp .fail_jump2
.gb_reply_header_ok:

    mov al,ACK
    call serial_putc

    ; ------------------------------------------------------------
    ; Critical 128-byte payload burst.
    ; ------------------------------------------------------------

    cli

.stx_wait:
    in   al,SER_CMD
    test al,01h
    jz   .stx_wait
    in   al,SER_DATA
    cmp  al,02h
    je short .stx_ok
    jmp epsp_read_fail_irqoff

.stx_ok:
    mov bx,[drv_dest]
    mov [drv_block_start],bx
    mov cx,128

.data_loop:
.data_wait:
    in   al,SER_CMD
    test al,01h
    jz   .data_wait
    in   al,SER_DATA
    mov  [bx],al
    inc  bx
    loop .data_loop

.status_wait:
    in   al,SER_CMD
    test al,01h
    jz   .status_wait
    in   al,SER_DATA
    cmp  al,00h
    je short .status_ok
    jmp epsp_read_fail_irqoff

.status_ok:
.etx_wait:
    in   al,SER_CMD
    test al,01h
    jz   .etx_wait
    in   al,SER_DATA
    cmp  al,03h
    je short .etx_ok
    jmp epsp_read_fail_irqoff

.etx_ok:
.checksum_wait:
    in   al,SER_CMD
    test al,01h
    jz   .checksum_wait
    in   al,SER_DATA
    mov  [drv_rx_checksum],al

    ; Payload ACK inline.
.ack_tx_wait:
    in   al,SER_CMD
    test al,04h
    jz   .ack_tx_wait
    mov  al,ACK
    out  SER_DATA,al

.eot_wait:
    in   al,SER_CMD
    test al,01h
    jz   .eot_wait
    in   al,SER_DATA
    cmp  al,EOT
    je short .eot_ok
    jmp epsp_read_fail_irqoff

.eot_ok:
    sti

    ; Post-receive checksum validation.
    mov al,02h
    mov si,[drv_block_start]
    mov cx,128

.checksum_loop:
    add al,[si]
    inc si
    loop .checksum_loop

    add al,03h
    add al,[drv_rx_checksum]
    cmp al,00h
    je short .checksum_ok
    jmp epsp_read_fail

.checksum_ok:
    add word [drv_dest],128
    inc byte [drv_block]

    cmp byte [drv_block],4
    jb .block_loop

    clc
    jmp short epsp_read_return

.fail_jump2:
    jmp epsp_read_fail

epsp_read_fail_irqoff:
    sti

epsp_read_fail:
    stc

epsp_read_return:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================================
; EPSP PACKET HELPERS
; ============================================================================

epsp_send_packet:
    ; DS:SI = packet, CX = count
.send_loop:
    mov al,[si]
    call serial_putc
    inc si
    loop .send_loop
    ret

epsp_getc_timeout:
    ; Receive one byte with a finite timeout.
    ; CF=0, AL=byte on success
    ; CF=1 on timeout
    ;
    ; The nested loop is deliberately generous compared with a 62,400-baud
    ; character time, but finite so CONFIG.SYS cannot hang forever when epspd
    ; is absent.
    push bx
    push dx

    mov bx,24

.eg_outer:
    mov dx,0FFFFh

.eg_inner:
    in   al,SER_CMD
    test al,01h
    jnz short .eg_ready

    dec dx
    jnz short .eg_inner

    dec bx
    jnz short .eg_outer

    stc
    jmp short .eg_done

.eg_ready:
    in   al,SER_DATA
    clc

.eg_done:
    pop dx
    pop bx
    ret


epsp_expect_packet:
    ; DS:SI = expected bytes, CX = count
.expect_loop:
    call epsp_getc_timeout
    jc short .timeout

    cmp al,[si]
    je short .byte_ok

    stc
    ret

.byte_ok:
    inc si
    loop .expect_loop

    clc
    ret

.timeout:
    stc
    ret


epsp_wait_ack:
    call epsp_getc_timeout
    jc short .fail

    cmp al,ACK
    je short .ok

.fail:
    stc
    ret

.ok:
    clc
    ret


epsp_wait_eot:
    call epsp_getc_timeout
    jc short .fail

    cmp al,EOT
    je short .ok

.fail:
    stc
    ret

.ok:
    clc
    ret

; ============================================================================
; STATIC EPSP PACKETS
; ============================================================================

epsp_address:
    db 31h,31h,25h,05h

; IDENTIFY 6Bh
identify_header:
    db 01h,00h,31h,25h,6Bh,00h,3Eh

identify_text:
    db 02h,00h,03h,0FBh

identify_reply_header:
    db 01h,01h,25h,31h,6Bh,01h,3Ch

identify_reply_text:
    db 02h,32h,01h,03h,0C8h

; PARAMETERS 6Dh
parameters_header:
    db 01h,00h,31h,25h,6Dh,00h,3Ch

parameters_text:
    db 02h,00h,03h,0FBh

parameters_reply_header:
    db 01h,01h,25h,31h,6Dh,03h,38h

parameters_reply_text:
    db 02h,00h,0Ch,08h,00h,03h,0E7h

; READ 70h
epsp_read_header:
    db 01h,00h,31h,25h,70h,09h,30h

epsp_read_text:
    times 13 db 00h

epsp_read_reply_header:
    db 01h,01h,25h,31h,70h,01h,37h

epsp_read_reply_text:
    db 02h,01h,00h,03h,0FAh

; GET_BLOCK 73h
epsp_get_header:
    db 01h,00h,31h,25h,73h,00h,36h

epsp_get_text:
    times 4 db 00h

epsp_get_reply_header:
    db 01h,01h,25h,31h,73h,80h,0B5h

; ============================================================================
; INTERNAL 512-BYTE SECTOR BUFFER
; ============================================================================

sector_buffer:
    times 512 db 00h

; ============================================================================
; DOS keeps everything through this address resident.
; ============================================================================

end_resident:
