; VINEGAR by Ben Ryves
; --------------------
; STATES.ASM: Save/load state


; STATE FILE FORMAT:
; 4 kbytes: Full RAM dump..!
; 1 byte: Current state flags (iy+asm_Flag2)
; 1024 or 256 bytes: Screen dump
; 2 bytes: Program counter
; 2 bytes: Data pointer
; 16 bytes: CHIP-8 registers
; 16 bytes: HP48 flags
; 1 byte: Stack pointer
; 128 bytes: Stack
; 1 byte: Delay timer
; 1 byte: Sound timer


_save_state
	ld hl,_state_filename
	move_9_to_op1()
	bcall(_ChkFindSym)
	ret c ; It doesn't exist, therefore insufficient RAM to save.
	
	inc de
	inc de
	
	ld hl,(_load_address)
	ld bc,5*1024
	ldir
	
	ld a,(iy+asm_Flag2)
	ld (de),a
	inc de
	
	ex de,hl

	ld de,(_program_counter)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl

	ld de,(_data_pointer)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	
	ex de,hl
	
	ld hl,_reg_data
	ld bc,32
	ldir
	
	ld a,(_stack_depth)
	ld (de),a
	inc de
	
	ld hl,_stack
	ld bc,128
	ldir
	
	ld a,(_delay_timer)
	ld (de),a
	inc de
	ld a,(_sound_timer)
	ld (de),a

	ld hl,_save_icon
	ld a,$07
	call _lcd_pause
	out ($10),a


	di
	ld b,16
	ld c,$80+(64-16)
-	ld a,$20+10
	call _lcd_pause
	out ($10),a
	ld a,c
	inc c
	call _lcd_pause
	out ($10),a	
	ld a,(hl)
	inc hl
	call _lcd_pause
	out ($11),a
	ld a,(hl)
	inc hl	
	call _lcd_pause
	out ($11),a	
	djnz {-}
	ei
	ld b,50
-
	halt
	djnz {-}
	
	di
	ld b,16
	ld c,$80+(64-16)	
-	ld a,$20+10
	call _lcd_pause
	out ($10),a
	ld a,c
	inc c
	call _lcd_pause
	out ($10),a

	xor a
	call _lcd_pause
	out ($11),a
	call _lcd_pause
	out ($11),a
	djnz {-}	
	ld a,$05
	call _lcd_pause
	out ($10),a
	ei
	set _b_display_dirty
	set _b_saved
	ret
	


_save_icon
.incbmp "Resources/Save.GIF"

_load_state
	bit _b_saved
	ret z
	ld hl,_state_filename
	move_9_to_op1()
	bcall(_ChkFindSym)
	ret c ; File doesn't exist
	inc de
	inc de
	
	ex de,hl
	
	ld de,(_load_address)
	ld bc,5*1024
	ldir
	
	ld a,(hl)
	ld (iy+asm_Flag2),a
	inc hl
	
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (_program_counter),de

	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (_data_pointer),de
	
	
	ld de,_reg_data
	ld bc,32
	ldir
	
	ld a,(hl)	
	ld (_stack_depth),a
	inc hl
	
	ld de,_stack
	ld bc,128
	ldir
	
	ld a,(hl)
	ld (_delay_timer),a
	inc hl
	ld a,(hl)
	ld (_sound_timer),a
	
	bit _b_schip_video
	jp z,_set_c8_graphics
	jp _set_sc_graphics
	
_state_filename
	.db ProtProgObj, "ch8.save",0