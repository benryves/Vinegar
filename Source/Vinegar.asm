;+=============================================================+;
;|                                                             |;
;|    ##    #   #  ######  ######  ######   ######  #######    |;
;|    ##    #   #  #    #          #        #    #  #     #    |;
;|    ##    #   #  #    #  ###     #        ######  #######    |;
;|     ##  ##  ##  ##   #  #       ##   #  ##    #  #    #     |;
;|      ###    ##  ##   #  ######  ##   #  ##    #  #    ##    |;
;|       #     ##  ##   #  ######  ######  ##    #  #    ##    |;
;|                                                             |;
;+=============================================================+;
;|          A MaxCoderz Production by Ben Ryves 2006           |;
;+=============================================================+;
;| CHIP-8/SCHIP "emulator" (interpreter) for the TI-83 series  |;
;| calculator.                                                 |;
;+=============================================================+;
;| CHIP-8/SCHIP ROMs must be given a header to be detected by  |;
;| the software; like this: .db "CHIP8<title>",0               |;
;| <title> is the title of the ROM (eg "Spacefight") to allow  |;
;| for ROM titles in the listing with more than 8 characters   |;
;+=============================================================+;
;| See README.HTM for more information.                        |;
;+=============================================================+;


; ===============================================================
; Compile-time definitions
; ===============================================================

.define load_interrupt

_gui_top = 7
_gui_rows = 8

; ===============================================================
; Required Headers
; ===============================================================


.include "Includes/headers.inc"

.module Chip8
.using noname

.if platform == ti8x
_interrupt_base = $98
	.varloc saveSScreen,768
	.define  move_9_to_op1() rst rMOV9TOOP1
.else
_interrupt_base  = $82
	.varloc statVars,512
	.define  move_9_to_op1() ld de,op1\ ld bc,9\ ldir
.endif
_interrupt_table = (_interrupt_base << 8)+$200
_interrupt_location = _interrupt_base|(_interrupt_base<<8)

.var 2, _load_address       ; RAM address we're loading to.
.var 2, _file_loc           ; Location of the current file
.var 2, _top_of_gui_file 
.var 1, _highlight_offset
.var 1, _rows_drawn
.var 2, _rom_start          ; Pointer to start of actual ROM.
.var 1, _rom_count          ; Number of ROMs on the calculator

; ===============================================================
; Main entry point
; ===============================================================
main
	im 1
	di
	
	ld hl,5*1024+32
	bcall(_EnoughMem)
	jp nc,{+}
	bcall(_homeup)
	ld hl,_insufficient_ram
	bcall(_PutS)
-	bcall(_GetCSC)
	or a
	jr z,{-}
	ret
	
_insufficient_ram
.asc "Vinegar requires"
.asc "~5KB free RAM to"
.asc "run happily.    "
.asc "Please free some"
.asc "up before trying"
.asc "to run it again."
.asc "________________"
.asc "Press any key.",0
+

	; Allocate 5KB
	ld hl,_temp_name
	move_9_to_op1()
	bcall(_ChkFindSym)
	ret nc
	

	ld hl,_temp_name
	move_9_to_op1()
	ld hl,5*1024
	bcall(_CreateProtProg)
	inc de
	inc de
	ld (_load_address),de
	ld hl,4*1024
	add hl,de
	ld (_video_memory),hl
	
	; See if we can create a saved state file

_state_file_size = 1+1+128+1+16+16+2+2+1+(5*1024)

	; Create state file...
	ld hl,_state_file_size+32
	bcall(_EnoughMem)
	jr c,_cannot_save_state

	ld hl,_state_filename
	move_9_to_op1()
	ld hl,_state_file_size
	bcall(_CreateProtProg)

_cannot_save_state
	; Check for any files...
	ld hl,(progPtr)
	ld ix,_file_header
	call ionDetect
	jr z,{+}
	bcall(_homeup)
	bcall(_newline)
	ld hl,_no_progs
	bcall(_PutS)
-	bcall(_GetCSC)
	or a
	jr z,{-}
	ret
_no_progs
.asc "You must install"
.asc "some CHIP8/SCHIP"
.asc "games to use the"
.asc "emulator.       "
.asc "________________"
.asc "Press any key.",0
+

	
	; Set the defaults
	ld a,(_saved_settings)
	ld (iy+asm_Flag1),a
	
	res 0,(iy+asm_Flag3) ; Clear saved flag
	
	; Set the highlighted file
	
	ld hl,(_load_address)
	ld (_top_of_gui_file),hl
	xor a
	ld (_highlight_offset),a
	ld (_option_index),a
	ld (_settings_offset),a
	
_reload_program_index
	ld hl,(_load_address)
	xor a
	ld (_rom_count),a
	ld bc,4*1024
	bcall(_MemSet)

	; Catalogue the VAT entries for all the CHIP8 games:
	ld ix,(_load_address)
	dec ix
	dec ix
	ld de,(progPtr)
	
-	inc ix
	inc ix
	ld (ix+0),e
	ld (ix+1),d
	ld a,(_rom_count)
	inc a
	jr z,{+} ; Prevent overflows (hacky, but I'm lazy).
	ld (_rom_count),a
+
	push ix
	ld h,d
	ld l,e
	ld ix,_file_header
	call ionDetect
	pop ix
	jr z,{-}
	ld (ix+0),0
	ld (ix+1),0

	; Draw the ROM loading GUI...


_draw_rom_menu
	bcall(_GrBufClr)
	ld hl,_banner
	ld de,plotSScreen
	ld bc,12*7
	ldir
	set textWrite,(iy+sGrFlags)
	
	ld a,_gui_top
	ld (penRow),a
	xor a
	ld (_rows_drawn),a
	ld ix,(_top_of_gui_file)

	ld b,_gui_rows
-	push bc
	ld a,2
	ld (penCol),a
	
	ld a,(ix+0)
	or (ix+1)
	jr z,_no_more_files
	ld l,(ix+0)
	ld h,(ix+1)


	push ix
	ld ix,_file_header
	call ionDetect
	pop ix
	; hl->data
	bcall(_VPutS)
	inc ix
	inc ix
	ld a,(penRow)
	add a,7
	ld (penRow),a
	ld hl,_rows_drawn
	inc (hl)
	pop bc
	djnz {-}
	push bc
_no_more_files
	pop bc
	
	; Draw the highlight...
	ld a,(_highlight_offset)
	call _draw_gui_highlight
	
	
	ld hl,(_top_of_gui_file)
	ld de,(_load_address)
	xor a
	sbc hl,de
	srl h
	rr l
	ld a,h
	or a
	jr z,_normal_scrollbars
	ld bc,$1010
	jr _force_bottom
_normal_scrollbars
	ld a,(_rom_count)
	dec a
	dec a
	ld c,a
	
	ld a,(_highlight_offset)
	add a,l
	ld b,a

_force_bottom


	call _draw_gui_scrollbars
	
	call ionFastCopy
-	bcall(_GetCSC)
	or a
	jr z,{-}
	cp skClear
	jp z,_quit_from_rom_menu
	cp skMode
	jp z,_quit_from_rom_menu
	cp skDown
	jp z,_rom_down
	cp skUp
	jp z,_rom_up
	cp skEnter
	jp z,_run_rom
	cp sk2nd
	jp z,_run_rom
	cp skAlpha
	jr nz, {-}
	call _options
	jp _draw_rom_menu
		
_rom_down
	ld a,(_rows_drawn)
	ld b,a
	
	ld a,(_highlight_offset)
	inc a
	cp b
	jr z,_off_bottom
	ld (_highlight_offset),a
	jp _draw_rom_menu
_off_bottom
	ld hl,(_top_of_gui_file)
	inc hl
	inc hl
	push hl
	ld de,(_gui_rows-1)*2
	add hl,de
	ld a,(hl)
	inc hl
	or (hl)
	jr z,_not_bottom_roms
	pop hl
	ld (_top_of_gui_file),hl
	jp _draw_rom_menu
_not_bottom_roms
	pop hl
	jp _draw_rom_menu	
	
_rom_up
	ld a,(_highlight_offset)
	dec a
	cp -1
	jr z,_off_top
	ld (_highlight_offset),a
	jp _draw_rom_menu
_off_top
	ld hl,(_top_of_gui_file)
	ld de,(_load_address)
	ld a,h
	xor d
	ld d,a
	ld a,l
	xor e
	or d
	jp z,_draw_rom_menu
	dec hl
	dec hl
	ld (_top_of_gui_file),hl
	jp _draw_rom_menu

_run_rom

	; Load the ROM
	ld hl,(_top_of_gui_file)
	ld a,(_highlight_offset)
	add a,a
	ld e,a
	ld d,0
	add hl,de
	push hl
	pop ix
	ld l,(ix+0)
	ld h,(ix+1)
	
	ld (_rom_start),hl
	
	
	call _load_rom
	call _run
	jp _reload_program_index


_quit_from_rom_menu

	; Preserve settings (writeback)
	ld a,(iy+asm_Flag1)
	ld (_saved_settings),a

	; Clean up:
	ld hl,_temp_name
	move_9_to_op1()
	bcall(_ChkFindSym)
	ret c
	bcall(_DelVarArc)
	

	ld hl,_state_filename
	move_9_to_op1()
	bcall(_ChkFindSym)
	ret c
	bcall(_DelVarArc)
	ret

_draw_gui_highlight	
	ld l,a
	ld h,0
	;*84 = *4+*16+*64
	add hl,hl
	add hl,hl
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	ld b,h
	ld c,l
	add hl,hl
	add hl,hl
	add hl,de
	add hl,bc
	ld de,plotSScreen+_gui_top*12
	add hl,de
	ld bc,7*12
-	ld a,(hl)
	cpl
	ld (hl),a
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,{-}
	ret
	
_draw_gui_scrollbars
	push bc
	
	; Draw the line on the left...
	ld hl,plotSScreen+12*7
	ld de,12
	ld b,64-8
-	ld a,%10000000
	or (hl)
	ld (hl),a
	add hl,de
	djnz {-}
	; Draw the main bar on the right...
	
	ld hl,plotSScreen+12*7+11
	ld b,64-8
-	ld a,%11100000
	and (hl)
_mask
	or %00010101
	ld (hl),a
	add hl,de
	ld a,(_mask+1)
	xor %00001110
	ld (_mask+1),a
	djnz {-}

	pop bc
	
	; b = Position
	; c = Total
	; Scrollbar Y = topy + (scrollbarheight - buttonheight) * (b/c)
	
	ld h,(64-8)-6
	ld l,b
	bcall(_HTimesL)
	ld a,c
	bcall(_DivHLByA)
	ld a,l
	add a,6
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ld de,plotSScreen+11
	add hl,de
	ld de,12
	
	ld a,(hl)
	or %00011111
	ld (hl),a
	add hl,de

	ld b,6
-	ld a,(hl)
	and %11110001
	ld (hl),a
	add hl,de
	djnz {-}

	ld a,(hl)
	or %00011111
	ld (hl),a
	
	; Draw the bottom border
	ld hl,plotSScreen+12*63
	ld (hl),$FF
	ld d,h
	ld e,l
	inc de
	ld bc,11
	ldir
	
	ret
	
_temp_name
.db ProtProgObj, "ch8.tmpf"
_file_header
.db "CHIP8",0

.include "Core.asm"
.include "Settings.asm"
.include "Includes/keyval.inc"
.if platform == ti83
	.include "TI83.asm"
.endif
	
_video_size = video_end - video_start
_sprites_size = sprites_end - sprites_start
_core_size = (core_end - core_start) - (_video_size + _sprites_size)
_states_size = states_end - states_start

;.echo "Core:    ",_core_size," bytes\n"
;.echo "Video:   ",_video_size," bytes\n"
;.echo "Sprites: ",_sprites_size," bytes\n"
;.echo "States:  ",_states_size," bytes\n"

; ===============================================================
; Misc...
; ===============================================================
_banner
.incbmp "Resources/banner.gif"


.endmodule