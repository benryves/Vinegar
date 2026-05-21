; VINEGAR by Ben Ryves
; --------------------
; CORE.ASM: Main CHIP-8/SCHIP core

.module Chip8
.using noname
core_start
_max_stack = 64
.var 16,_reg_data           ; C8 Data registers
.var 16, _hp48_flags
.var 2, _data_pointer       ; C8 'I' data pointer
.var _max_stack*2,_stack    ; C8 Stack
.var 1, _delay_timer        ; C8 Delay timer
.var 1, _sound_timer        ; C8 Sound timer
.var 2, _program_counter    ; C8 PC
.var 1, _stack_depth        ; Stack position
.var 2, _video_memory       ; Location of video memory
.var 1, _frame_skip_count
.var 1, _timer_countdown    ; Interrupt count-down

_reg_flag = _reg_data + $F  ; Flag register

; ---------------------------------------------------------------
; Settings flags
; ---------------------------------------------------------------

_inverse_video   = 0
_always_redraw   = 1
_enable_sound    = 2
_ignore_errors   = 3
_shrink_mode     = 4
_x_wrap_sprites  = 5
_y_wrap_sprites  = 6
_alternate_keys  = 7

.define _s_inverse_video _inverse_video,(iy+asm_Flag1)
.define _s_always_redraw _always_redraw,(iy+asm_Flag1)
.define _s_enable_sound _enable_sound,(iy+asm_Flag1)
.define _s_ignore_errors _ignore_errors,(iy+asm_Flag1)
.define _s_inverse_video _inverse_video,(iy+asm_Flag1)
.define _s_shrink_mode _shrink_mode,(iy+asm_Flag1)
.define _s_x_wrap_sprites _x_wrap_sprites,(iy+asm_Flag1)
.define _s_y_wrap_sprites _y_wrap_sprites,(iy+asm_Flag1)
.define _s_alternate_keys _alternate_keys,(iy+asm_Flag1)


; ---------------------------------------------------------------
; Temp flags
; ---------------------------------------------------------------

_shrink_frame = 3
_paused = 6
.define _b_display_dirty 0,(iy+asm_Flag2)
.define _b_schip_video 1,(iy+asm_Flag2)
.define _b_sound_dirty 2,(iy+asm_Flag2)
.define _b_shrink_frame 3,(iy+asm_Flag2)
.define _b_collision 4,(iy+asm_Flag2)
.define _b_wrap_x 5,(iy+asm_Flag2)
.define _b_paused 6,(iy+asm_Flag2)

.define _b_saved 0,(iy+asm_Flag3)


; ---------------------------------------------------------------
; Load a ROM/font and reset the Chip8 core.
; ---------------------------------------------------------------

_load_rom	

; ---------------------------------------------------------------
; Reset. (Does not reload ROM or font, though.)
; ---------------------------------------------------------------
_reset
	xor a
	ld (_delay_timer),a
	ld (_sound_timer),a
	ld (_timer_countdown),a	
	ld (_stack_depth),a
			
	xor a
	ld hl,_reg_data
	ld bc,32
	bcall(_MemSet)


	ld l,0
	ld a,(_custom_load_address)
	ld h,a
	ld (_data_pointer),hl
	ld (_program_counter),hl

	ld hl,(_load_address)
	ld bc,1024*5
	xor a
	bcall(_MemSet)
	res _b_schip_video
	res _b_sound_dirty
	res _b_paused

	; Look up the program (fix for archived ROMs)
	
	ld hl,(_rom_start)
	ld ix,_file_header
	call ionDetect
	
-	inc hl
	ld a,(hl)
	or a
	jr nz,{-}
	inc hl
	
	; hl->rom file
	
	push hl	
	
	ld hl,$FFF
	ld de,(_program_counter)
	xor a
	sbc hl,de
	ld b,h
	ld c,l
	ld hl,(_load_address)	
	add hl,de

	pop de
	ex de,hl
	ldir

	ld a,2
	ld (_scr_offset+1),a
	jp _set_c8_graphics
	
; ---------------------------------------------------------------
; Main loop.
; ---------------------------------------------------------------
_run
	; Load our interrupt handler
	.ifdef load_interrupt
	ld hl,_interrupt
	ld de,_interrupt_location
	ld bc,_interrupt_end - _interrupt
	ldir
	
	ld hl,_interrupt_table
	ld a,_interrupt_base
	ld (hl),a
	ld d,h
	ld e,l
	inc de
	ld bc,256
	ldir
	
	ld a,_interrupt_table >> 8
	ld i,a

	im 2
	ei
	.endif
_fetch	
	res _b_display_dirty

	ld a,(_frame_skip)
_frame_skip_loop
	ld (_frame_skip_count),a

	ld hl,(_program_counter)
	push hl
		inc hl \ inc hl
		ld (_program_counter),hl
	pop hl
	ld de,(_load_address)
	add hl,de
	ld d,(hl)
	inc hl
	ld e,(hl)
	ld h,d
	ld l,e
		
	ld a,h
	ld b,l
	and $F0
	jp nz,_not_0
		; 0
		ld a,l
		cp $E0 \ jr nz,_not_clear
			; Clear the screen
			ld hl,(_video_memory)
			ld bc,1024
			xor a
			bcall(_MemSet)			
			set _b_display_dirty
			jp _done_opcode

_not_clear	cp $EE  \ jr nz,_not_return
			; Return from a subroutine
			ld a,(_stack_depth)
			or a
			jr nz,{+}
			ld hl,_err_stack
			jp _disp_error
+			
			dec a
			ld (_stack_depth),a
			call _get_stack_pointer
			ld e,(hl)
			inc hl
			ld d,(hl)
			ld (_program_counter),de
			jp _done_opcode

			
_not_return	cp $FB \ jr nz,_not_sc4r
			; Scroll 4 pixels right
			ld a,2
			bit _b_schip_video
			jr nz,{+}
			ld a,2
+
--			ld hl,(_video_memory)
			ld b,64
-			srl (hl) \ inc hl
			.for x,1,15
			rr (hl) \ inc hl
			.loop			
			djnz {-}
			dec a
			jr nz,{--}			
			jp _done_opcode
_not_sc4r	cp $FC \ jr nz,_not_sc4l
			; Scroll 4 pixels left
			ld a,4
			bit _b_schip_video
			jr nz,{+}
			ld a,2
+
			ld hl,(_video_memory)
			ld de,1023
			add hl,de
			ld (_scroll_start_address+1),hl
_scroll_start_address
--			ld hl,0
			ld b,64
-			sla (hl) \ dec hl
			.for x,1,15
			rl (hl) \ dec hl
			.loop			
			djnz {-}
			dec a
			jr nz,{--}			
			jp _done_opcode
_not_sc4l	cp $FD \ jr nz,_not_quit
			; Quit the emulator (just clear the screen and jump backwards)
			ld hl,(_program_counter)
			dec hl
			dec hl
			ld (_program_counter),hl			

			ld hl,(_video_memory)
			ld c,64			

--			ld b,16
-			ld a,(hl)
_quit_dither
			and  %01010101
			ld (hl),a
			inc hl
			djnz {-}
			
			ld a,(_quit_dither+1)
			cpl
			ld (_quit_dither+1),a
			dec c

			jr nz,{--}
			set _b_display_dirty
			set _b_paused
			jp _done_opcode
			
_not_quit	cp $FE \ jr nz,_not_set8
			; Set Chip8 graphics mode
			call _set_c8_graphics
			jp _done_opcode
_not_set8	cp $FF \ jr nz,_not_sets
			; Set SCHIP graphics mode
			call _set_sc_graphics
			jp _done_opcode
_not_sets	and $F0 \ cp $C0 \ jr nz,_not_scroll_n
			; Scroll N rows down
			ld a,l
			and $0F
			; a = rows to scroll
			add a,a
			add a,a
			add a,a
			add a,a
			neg
			ld e,a
			ld d,0
			ld hl,1024
			add hl,de
			ld b,h
			ld c,l
			push bc
			dec bc
			ld hl,(_video_memory)
			add hl,bc
			ld d,h
			ld e,l
			ld bc,16
			add hl,bc
			pop bc
			ex de,hl
			lddr
			ld hl,(_video_memory)
			ld bc,16
			xor a
			bcall(_MemSet)		
			set _b_display_dirty
			jp _done_opcode
_not_scroll_n	
		ld hl,_err_instruction
		jp _disp_error

_not_0	cp $10 \ jr nz,_not_1
		; 1 [jump]
		ld a,h
		and $0F
		ld h,a
		ld (_program_counter),hl
		jp _done_opcode

_not_1	cp $20 \ jr nz,_not_2
		; 2 [call]
		ld a,(_stack_depth)
		cp _max_stack
		jr nz,{+}
		ld hl,_err_stack
		jp _disp_error

+		push hl
		call _get_stack_pointer
		ld de,(_program_counter)
		ld (hl),e
		inc hl
		ld (hl),d
		ld a,(_stack_depth)
		inc a
		ld (_stack_depth),a	
		pop hl
		; Perform the jump
		ld a,h
		and $0F
		ld h,a
		ld (_program_counter),hl
		jp _done_opcode

_not_2	cp $30 \ jr nz,_not_3
		; 3 [skip if vx==kk]
		call _get_value_register_x
		cp b
		call z,_skip
		jp _done_opcode

_not_3	cp $40 \ jr nz,_not_4
		; 4 [skip if vx!=kk]
		call _get_value_register_x
		cp b
		call nz,_skip
		jp _done_opcode

_not_4	cp $50 \ jr nz,_not_5
		; 5 [skip if vx==vy]
		push hl
		call _get_value_register_x
		ld b,a
		pop hl
		call _get_value_register_y
		cp b
		call z,_skip
		jp _done_opcode

_not_5	cp $60 \ jr nz,_not_6
		; 6 [vx=kk]
		call _get_register_pointer_x
		ld (hl),b
		jp _done_opcode

_not_6	cp $70 \ jr nz,_not_7
		; 7 [vx+=kk]
		; NO CARRY!
		call _get_value_register_x
		add a,b
		ld (hl),a
		jp _done_opcode

_not_7	cp $80 \ jp nz,_not_8
		; 8
		push hl
			call _get_value_register_y
			ld b,a
		pop hl
		ld a,l
		push af
			call _get_register_pointer_x
			ld c,(hl)
		pop af
		
		; At this point;
		; a = instruction
		; c = vx
		; b = vy
		; hl -> vx
		
		and $F
		jr nz,_not_set_vx_vy
			; vx = vy
			ld (hl),b
			jp _done_opcode

_not_set_vx_vy	cp 1h \	jr nz,_not_or
			; vx = vx | vy
			ld a,c \ or b \ ld (hl),a
			jp _done_opcode

_not_or		cp 2h \	jr nz,_not_and
			; vx = vx & vy
			ld a,c \ and b \ ld (hl),a
			jp _done_opcode

_not_and	cp 3h \ jr nz,_not_xor
			; vx = vx ^ vy
			ld a,c \ xor b \ ld (hl),a					
			jp _done_opcode

_not_xor	cp 4h \	jr nz,_not_add
			; vx += vy
			ld a,c \ add a,b \ ld (hl),a
			ld a,1 \ jr c,{+} \ xor a
+			ld (_reg_flag),a
			jp _done_opcode

_not_add	cp 5h \	jr nz,_not_cp
			; vx = vy-vx
			ld a,c \ sub b \ ld (hl),a
			ld a,1 \ jr nc,{+} \ xor a
+			ld (_reg_flag),a			
			jp _done_opcode

_not_cp		cp 6h \ jr nz,_not_shift_r
			; vx >>= 1
			srl c
			ld (hl),c
			ld a,1 \ jr c,{+} \ xor a
+			ld (_reg_flag),a
			jp _done_opcode

_not_shift_r	cp 7h \	jr nz,_not_sub
			; vx -= vy
			ld a,b \ sub c \ ld (hl),a
			ld a,1 \ jr nc,{+} \ xor a
+			ld (_reg_flag),a			
			jp _done_opcode

_not_sub	cp Eh \  jp nz,_invalid_8
			; vx <<= 1
			sla c
			ld (hl),c			
			ld a,1 \ jr c,{+} \ xor a
+			ld (_reg_flag),a			
			jp _done_opcode

_invalid_8
	ld hl,_err_instruction
	jp _disp_error

_not_8	cp $90 \ jr nz,_not_9
		; 9 [skip if vx!=vy]
		push hl
		call _get_value_register_x
		ld b,a
		pop hl
		call _get_value_register_y
		cp b
		jp z,_done_opcode
		call _skip
		jp _done_opcode

_not_9	cp $A0 \ jr nz,_not_A
		; A [i = nnn]
		ld a,h \ and $0F \ ld h,a
		ld (_data_pointer),hl
		jp _done_opcode

_not_A	cp $B0 \ jr nz,_not_B
		; B [jump nnn + v0]
		ld a,h \ and $0F \ ld h,a
		ld a,(_reg_data)
		ld e,a
		ld d,0
		add hl,de
		ld (_program_counter),hl
		jp _done_opcode

_not_B	cp $C0 \ jr nz,_not_C
		; C [vx = rand() & kk]
		push hl
			call _get_register_pointer_x
			push hl
				ld b,255
				call ionRandom
			pop hl
		pop de
		and e
		ld (hl),a
		jp _done_opcode

_not_C	cp $D0 \ jp nz,_not_D
		; D [draw sprite @ (vx,vy) height n]
				
		xor a
		ld (_reg_flag),a
		
		push hl
		ld hl,(_data_pointer)
		ld de,(_load_address)
		add hl,de
		push hl
		pop ix
		pop hl
					
		push hl
			push hl
				call _get_value_register_y
_sprite_y_clip
				and 31
			pop hl
			push af
				call _get_value_register_x
_sprite_x_clip
				and 63
			pop hl
			ld l,h
		pop bc
		push af
		ld a,c
		and $F
		ld b,a
		pop af
sprites_start
		.include "Sprites.asm"		
sprites_end
		jp _done_opcode

_not_D	cp $E0 \ jr nz,_not_E
		; E (Keypresses)
		ld a,l
		cp $9E \ jr nz,_not_ck_down
			; Is the key pressed? If so, skip.
			call _get_value_register_x
			call _get_key_status
			call z,_skip		
			jp _done_opcode
_not_ck_down
		cp $A1 \ jp nz,_done_opcode
			; Is the key not pressed? If so, skip.
			call _get_value_register_x
			call _get_key_status
			call nz,_skip
			jp _done_opcode
_not_E
		; F
		push hl
		call _get_value_register_x
		ld b,a
		pop de
		ld a,e
		; a = instruction; b = value in vx; hl->vx

		cp $07 \ jr nz,_not_timer
			; vx->timer
			ld a,(_delay_timer) \ ld (hl),a
			jp _done_opcode

_not_timer	cp $0A \ jr nz,_not_wait_key
			; Wait for key, then save away in register
		
			push hl
			
			ld b,16
-			ld a,b
			dec a
			call _get_key_status
			jr z,_waited_key
			djnz {-}
			
			ld hl,(_program_counter)
			dec hl
			dec hl
			ld (_program_counter),hl
			pop hl
			jp _done_opcode
_waited_key
			ld a,b
			dec a
			pop hl
			ld (hl),a
			
			; Wait for the key to be released:
-			push af
			call _get_key_status
			jr nz,{+}
			pop af
			jr {-}

+			pop af
			jp _done_opcode

		
_not_wait_key	cp $15 \ jr nz,_not_set_d
			; vx->delay timer
			ld a,b \ ld (_delay_timer),a
			jp _done_opcode

_not_set_d	cp $18 \ jr nz,_not_set_s
			; vx->sound timer
			ld a,b \ ld (_sound_timer),a
			jp _done_opcode

_not_set_s	cp $1E \ jr nz,_not_add_i
			; i+=vx
			ld e,b
			ld d,0
			ld hl,(_data_pointer)
			add hl,de
			ld (_data_pointer),hl
			jp _done_opcode

_not_add_i	cp $29 \ jr nz,_not_get_font
			; Get pointer to font -> i
			ld a,b
			add a,a
			add a,a
			add a,b		
			ld l,a
			ld h,0
_set_font_location
			ld de,_font
			add hl,de
			ld de,(_load_address)
			xor a
			sbc hl,de			
			ld (_data_pointer),hl
			jp _done_opcode

_not_get_font	cp $30 \ jr nz,_not_get_lfont
			; Get pointer to large font -> i
			ld a,b
			add a,a
			ld b,a
			add a,a
			add a,a
			add a,b
			ld l,a
			ld h,0
			ld de,5*16
			add hl,de
			jr _set_font_location
			
_not_get_lfont	cp $33 \ jr nz,_not_bcd
			ld a,b
			
			ld c,0 ; c = 100s
			ld b,0 ; b = 10s

-			cp 100
			jr c,{+}
			sub 100
			inc c
			jr {-}
+

-			cp 10
			jr c,{+}
			sub 10
			inc b
			jr {-}
+
			ld hl,(_data_pointer)
			ld de,(_load_address)
			add hl,de
			ld (hl),c
			inc hl
			ld (hl),b
			inc hl
			ld (hl),a
			jp _done_opcode

_not_bcd	cp $55 \ jr nz,_not_save_mem
			; v0..vx->i
			push de
			ld a,d
			and $F
			ld e,a
			ld d,0
			ld hl,(_data_pointer)
			push hl
			ld a,h
			and $F0
			jr z,{+}
			pop hl
			ld hl,_err_data
			jp _disp_error
			
+
			pop hl
			add hl,de	
			pop de
			ld a,h
			and $F0
			jr z,{+}
			ld hl,_err_data
			jp _disp_error
+
			
			call _get_copy_pointers
			ex de,hl
			ldir
			jp _done_opcode

_not_save_mem	cp $65 \ jr nz,_not_load_mem
			; i->v0..vx
			call _get_copy_pointers
			ldir
			
			jp _done_opcode
_not_load_mem	cp $75 \ jr nz,_not_save_HP48
			; Save to HP48 flags
			call _get_hp48_pointers
			ldir
			jp _done_opcode
_not_save_HP48	cp $85 \ jr nz,_not_load_HP48
			; Load from HP48 flags
			call _get_hp48_pointers
			ex de,hl
			ldir
	
			jp _done_opcode
_not_load_HP48
		ld hl,_err_instruction
		jp _disp_error
_done_opcode

	ld a,(_program_counter+1)
	and $F0
	jr z,{+}
	ld hl,_err_pc
	jp _disp_error
+

	; Per-instruction delay
	ld a,(_instruction_delay)
	or a
	jr z,{+}
	ld b,a
-	push hl
	inc de
	push de
	pop de
	dec de
	pop hl
	djnz {-}
+

	; Frame skip...
	ld a,(_frame_skip_count)
	or a
	jr z,{+}
	dec a
	ld (_frame_skip_count),a
	jp _frame_skip_loop
+


_error_recover
	ei
	bcall(_GetCSC)
	
	cp skClear
	jp z,_exit_emulator

	push af
	cp skDel
	call z,_reset
	pop af
	
	push af
	cp skGraph
	call z,_save_state
	pop af
	
	push af
	cp skTrace
	call z,_load_state
	pop af

	cp skComma
	jr nz,{+}
	ld b,a
	ld a,(iy+asm_Flag2)
	xor 1<<_paused
	ld (iy+asm_Flag2),a
	ld a,b
+	
	
	push af
	cp skAlpha
	call z,_options
	pop af

	cp skMode
	jr nz,{+}
	push af
	ld a,(iy+asm_Flag1)
	xor 1<<_inverse_video
	ld (iy+asm_Flag1),a
	call _lcd_clear
	set _b_display_dirty
	pop af
+	
	bit _b_schip_video
	jr z,_not_schip
	cp skLeft \ call z,_crop_left
	cp skRight \ call z,_crop_right
_not_schip

	cp skDown
	jr z,_contrast_down
	cp skUp
	jr z,_contrast_up
	jr _no_contrast

_contrast_up
	ld b,1
	jr _set_contrast
_contrast_down
	ld b,-1
_set_contrast
	ld a,(contrast)
	add a,b
	cp -1
	jr z,_no_contrast
	cp $28
	jr z,_no_contrast
	ld (contrast),a
	add a,$18
	or $C0
	call _lcd_pause
	out ($10),a

_no_contrast

	; Next, copy to the LCD if need be:
	bit _s_always_redraw
	jr nz,{+}
	bit _b_display_dirty
	jp z,_no_redraw
+
video_start
	.include "Video.asm"
video_end
_no_redraw

	; Sound?
	bit _s_enable_sound
	jr z,_no_sound
	bit _b_sound_dirty
	jr z,_no_sound
	di
	
	ld a,%11010000
	ld c,32	
--	out (bport),a
	ld b,0
-	djnz {-}
	xor 3
	out (bport),a
	ld b,0
-	djnz {-}
	dec c
	jr nz,{--}
	res _b_sound_dirty
	ei
_no_sound
	bit _b_paused
	jp z,_fetch
	jp _error_recover
	

; ---------------------------------------------------------------
; Move crop position
; ---------------------------------------------------------------
_crop_left
	push af
	ld a,(_scr_offset+1)
	dec a
	cp -1
	jr z,{+}
	ld (_scr_offset+1),a
	set _b_display_dirty
+	pop af
	ret
_crop_right
	push af
	ld a,(_scr_offset+1)
	inc a
	cp 5
	jr z,{+}
	ld (_scr_offset+1),a
	set _b_display_dirty
+	pop af
	ret
; ---------------------------------------------------------------
; Safe LCD pause
; ---------------------------------------------------------------
.if platform == ti8x
_lcd_pause = $B
.else
_lcd_pause
	push af
	inc hl
	dec hl
	pop af
	ret
.endif

; ---------------------------------------------------------------
; Pointers used when copying data from RAM(hl)->registers(de)
; ---------------------------------------------------------------
_get_copy_pointers ; hl->i, de->v0, bc=count
	ld a,d
	and $0F
	inc a
	ld c,a
	ld b,0
	ld hl,(_data_pointer)
	ld de,(_load_address)
	add hl,de
	ld de,_reg_data
	ret
; ---------------------------------------------------------------
; Pointers used when copying data from RAM(hl)->registers(de)
; ---------------------------------------------------------------
_get_hp48_pointers
	ld a,d
	and 7
	ld c,a
	ld b,0
	inc bc
	ld hl,_reg_data
	ld de,_hp48_flags
	ret
; ---------------------------------------------------------------
; Get pointer to register y in ??y? instructions
; ---------------------------------------------------------------
_get_register_pointer_y
	ld a,l
	srl a
	srl a
	srl a
	srl a
	jr {+}
; ---------------------------------------------------------------
; Get pointer to register x in ?x?? instructions
; ---------------------------------------------------------------
_get_register_pointer_x
	ld a,h
	and $0F
+	ld l,a
	ld h,0
	ld de,_reg_data
	add hl,de
	ret

; ---------------------------------------------------------------
; Get value of register y in ??y? instructions
; ---------------------------------------------------------------
_get_value_register_y
	call _get_register_pointer_y
	jr {+}
; ---------------------------------------------------------------
; Get value of register x in ?x?? instructions
; ---------------------------------------------------------------
_get_value_register_x
	call _get_register_pointer_x
+	ld a,(hl)
	ret

; ---------------------------------------------------------------
; Call to skip the next instruction (adds 2 to PC)
; ---------------------------------------------------------------

_skip
	ld hl,(_program_counter)
	inc hl \ inc hl
	ld (_program_counter),hl
	ret

; ---------------------------------------------------------------
; Display an error ("calculator protection")
; ---------------------------------------------------------------
; hl->Error string
; ---------------------------------------------------------------

_disp_error
	bit _s_ignore_errors
	jp nz,_error_recover
	push hl
	bcall(_ClrLCDFull)
	bcall(_homeup)
	ld hl,_err
	set textInverse,(iy+textFlags)
	bcall(_PutS)
	pop hl
	bcall(_PutS)
	res textInverse,(iy+textFlags)
	bcall(_newline)
	ld a,'P' \ bcall(_PutC)
	ld a,':' \ bcall(_PutC)	
	ld hl,(_program_counter)
	dec hl
	dec hl
	push hl
	call _put_word
	bcall(_newline)
	ld a,'O' \ bcall(_PutC)
	ld a,':' \ bcall(_PutC)	
	pop hl
	ld de,(_load_address)
	add hl,de
	ld d,(hl)
	inc hl
	ld e,(hl)
	push de
	pop hl
	call _put_word	
	bcall(_newline)
	ld a,'I' \ bcall(_PutC)
	ld a,':' \ bcall(_PutC)		
	ld hl,(_data_pointer)
	call _put_word	
	
-	bcall(_GetCSC)
	or a
	jr z,{-}
	; Runs on to exit VVV

; ---------------------------------------------------------------
; Jump here to exit
; ---------------------------------------------------------------
_exit_emulator
	di
	im 1
	ei
	ret

; ---------------------------------------------------------------
; Display an a 16-bit hexadecimal value
; ---------------------------------------------------------------
; hl = value to display
; ---------------------------------------------------------------
_put_word
	ld a,h
	srl a
	srl a
	srl a
	srl a
	call _put_nibble
	ld a,h
	and $F
	call _put_nibble
	
	ld a,l
	srl a
	srl a
	srl a
	srl a
	call _put_nibble
	ld a,l
	and $F
_put_nibble
	cp 10
	jr c,{+}
	add a,'A'-10
	jr {++}
+	add a,'0'
++	bcall(_PutC)
	ret


; ---------------------------------------------------------------
; Gets the key down status for key 'a'
; ---------------------------------------------------------------
_get_key_status
	push af
	ld a,$FF
	out (1),a
	nop
	pop af
	add a,a
	ld l,a
	ld h,0
	ld de,_keymap
	bit _s_alternate_keys
	jr z,{+}
	ld de,_keymap_2
+
	add hl,de
	ld a,(hl)
	out (1),a
	nop
	in a,(1)
	inc hl
	ld d,(hl)
	and d
	ret

; ---------------------------------------------------------------
; Chip-8 font data
; ---------------------------------------------------------------

_font
.db $F0, $90, $90, $90, $F0
.db $20, $60, $20, $20, $70
.db $F0, $10, $F0, $80, $F0
.db $F0, $10, $F0, $10, $F0
.db $90, $90, $F0, $10, $10
.db $F0, $80, $F0, $10, $F0
.db $F0, $80, $F0, $90, $F0
.db $F0, $10, $20, $40, $40
.db $F0, $90, $F0, $90, $F0
.db $F0, $90, $F0, $10, $F0
.db $F0, $90, $F0, $90, $90
.db $E0, $90, $E0, $90, $E0
.db $F0, $80, $80, $80, $F0
.db $E0, $90, $90, $90, $E0
.db $F0, $80, $F0, $80, $F0
.db $F0, $80, $F0, $80, $80

; ---------------------------------------------------------------
; SCHIP font data
; ---------------------------------------------------------------
.db %01111100,%11000110,%11001110,%11011110,%11010110,%11110110,%11100110,%11000110,%01111100,%00000000
.db %00010000,%00110000,%11110000,%00110000,%00110000,%00110000,%00110000,%00110000,%11111100,%00000000
.db %01111000,%11001100,%11001100,%00001100,%00011000,%00110000,%01100000,%11001100,%11111100,%00000000
.db %01111000,%11001100,%00001100,%00001100,%00111000,%00001100,%00001100,%11001100,%01111000,%00000000
.db %00001100,%00011100,%00111100,%01101100,%11001100,%11111110,%00001100,%00001100,%00011110,%00000000
.db %11111100,%11000000,%11000000,%11000000,%11111000,%00001100,%00001100,%11001100,%01111000,%00000000
.db %00111000,%01100000,%11000000,%11000000,%11111000,%11001100,%11001100,%11001100,%01111000,%00000000
.db %11111110,%11000110,%11000110,%00000110,%00001100,%00011000,%00110000,%00110000,%00110000,%00000000
.db %01111000,%11001100,%11001100,%11101100,%01111000,%11011100,%11001100,%11001100,%01111000,%00000000
.db %01111100,%11000110,%11000110,%11000110,%01111100,%00011000,%00011000,%00110000,%01110000,%00000000
.db %00110000,%01111000,%11001100,%11001100,%11001100,%11111100,%11001100,%11001100,%11001100,%00000000
.db %11111100,%01100110,%01100110,%01100110,%01111100,%01100110,%01100110,%01100110,%11111100,%00000000
.db %00111100,%01100110,%11000110,%11000000,%11000000,%11000000,%11000110,%01100110,%00111100,%00000000
.db %11111000,%01101100,%01100110,%01100110,%01100110,%01100110,%01100110,%01101100,%11111000,%00000000
.db %11111110,%01100010,%01100000,%01100100,%01111100,%01100100,%01100000,%01100010,%11111110,%00000000
.db %11111110,%01100110,%01100010,%01100100,%01111100,%01100100,%01100000,%01100000,%11110000,%00000000
_font_end


; ---------------------------------------------------------------
; Error message strings
; ---------------------------------------------------------------

_err             .asc "ERR:",0
_err_stack       .asc "Stack",0
_err_pc          .asc "PC",0
_err_data        .asc "Data",0
_err_instruction .asc "Instruction",0

; ---------------------------------------------------------------
; Set default CHIP-8 resolution graphics
; ---------------------------------------------------------------
_set_c8_graphics
	res _b_schip_video
	ld a,32		\ ld (_screen_height+1),a \ ld (_cur_height+1),a
	ld a,$20+2	\ ld (_screen_x+1),a
	ld a,$20+2+8	\ ld (_screen_x_end+1),a
	ld a,$80+16	\ ld (_screen_y+1),a
	ld hl,-16*32+1	\ ld (_column_offset+1),hl
	ld a,63		\ ld (_sprite_x_clip+1),a
	ld a,31		\ ld (_sprite_y_clip+1),a
	ld a,7		\ ld (_x_wrap_column+1),a
	ld a,16+7	\ ld (_col_wrap_offset+1),a
	ld a,-8		\ ld (_col_wrap_backtrack+1),a
-	set _b_display_dirty
	call _lcd_clear
	ret
; ---------------------------------------------------------------
; Set SCHIP resolution graphics
; ---------------------------------------------------------------	
_set_sc_graphics
	set _b_schip_video
	ld a,64		\ ld (_screen_height+1),a \ ld (_cur_height+1),a
	ld a,$20	\ ld (_screen_x+1),a
	ld a,$20+12	\ ld (_screen_x_end+1),a
	ld a,$80	\ ld (_screen_y+1),a			
	ld hl,-16*64+1	\ ld (_column_offset+1),hl
	ld a,127	\ ld (_sprite_x_clip+1),a
	ld a,63		\ ld (_sprite_y_clip+1),a
	ld a,15		\ ld (_x_wrap_column+1),a
	ld a,16+15	\ ld (_col_wrap_offset+1),a
	ld a,-16	\ ld (_col_wrap_backtrack+1),a
	jr {-}
	
; ---------------------------------------------------------------
; Key map
; ---------------------------------------------------------------

; 1 2 3 C
; 4 5 6 D
; 7 8 9 E
; A 0 B F

_keymap
.db KeyRow_3, ~dKPoint    ; 0
.db KeyRow_2, ~dkSeven    ; 1
.db KeyRow_3, ~dkEight    ; 2
.db KeyRow_4, ~dkNine     ; 3
.db KeyRow_2, ~dkFour     ; 4
.db KeyRow_3, ~dkFive     ; 5
.db KeyRow_4, ~dkSix      ; 6
.db KeyRow_2, ~dkOne      ; 7
.db KeyRow_3, ~dkTwo      ; 8
.db KeyRow_4, ~dkThree    ; 9
.db KeyRow_2, ~dkZero     ; A
.db KeyRow_4, ~dKMinus2   ; B
.db KeyRow_5, ~dkMul      ; C
.db KeyRow_5, ~dkMinus    ; D
.db KeyRow_5, ~dkPlus     ; E
.db KeyRow_5, ~dkEnter    ; F

_keymap_2
.db KeyRow_2, ~dKZero     ; 0
.db KeyRow_2, ~dkOne      ; 1
.db KeyRow_3, ~dkTwo      ; 2
.db KeyRow_4, ~dkThree    ; 3
.db KeyRow_2, ~dkFour     ; 4
.db KeyRow_3, ~dkFive     ; 5
.db KeyRow_4, ~dkSix      ; 6
.db KeyRow_2, ~dkSeven    ; 7
.db KeyRow_3, ~dkEight    ; 8
.db KeyRow_4, ~dkNine     ; 9
.db KeyRow_1, ~dkMath     ; A
.db KeyRow_2, ~dKMatrx    ; B
.db KeyRow_3, ~dkPrgm     ; C
.db KeyRow_1, ~dkX_1      ; D
.db KeyRow_2, ~dkSin      ; E
.db KeyRow_3, ~dkCos      ; F

; ---------------------------------------------------------------
; Clear display
; ---------------------------------------------------------------

_lcd_clear
	ld e,0
	bit _s_inverse_video
	jr z,{+}
	ld e,$FF
+
	ld c,$20
	ld a,$80
	call _lcd_pause
	out ($10),a
	
--	ld a,c
	call _lcd_pause
	out ($10),a
	ld a,$80
	call _lcd_pause
	out ($10),a	
	ld a,e
	ld b,64

-	call _lcd_pause
	out ($11),a
	djnz {-}

	inc c
	ld a,c
	cp $20+12
	ret z
	jr {--}
	
_get_stack_pointer
	ld a,(_stack_depth)
	add a,a
	ld l,a
	ld h,0
	ld de,_stack
	add hl,de
	ret


; ---------------------------------------------------------------
; Timer interrupt
; ---------------------------------------------------------------
_interrupt
.relocate _interrupt_location
	exx
	ex af,af'
	
	bit _b_paused
	jp nz,$3A ; Don't decrement when emulation is paused

	ld a,(_interrupt_speed)
	srl a
	ld b,a
	
	ld a,(_timer_countdown)
	sub b
	ld (_timer_countdown),a
	jp p,$3A ; Not time to count down
	
	ld b,0
-	inc b
	add a,110/2 ; My calc fires 110 interrupts/sec
	jp m,{-}	

	ld (_timer_countdown),a
	
--
	ld a,(_delay_timer)
	or a
	jr z,{+}
	dec a
	ld (_delay_timer),a
+
	ld a,(_sound_timer)
	or a
	jr z,{+}
	dec a
	ld (_sound_timer),a
	set _b_sound_dirty
+

.ifdef test_interrupt_rate
_timer_test
	ld a,%10110000
	out (bport),a
	xor 3
	ld (_timer_test+1),a
.endif
	djnz {--}
	jp $3A
.endrelocate
_interrupt_end


core_end

states_start
.include "States.asm"
states_end

.endmodule
