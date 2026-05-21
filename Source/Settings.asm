; VINEGAR by Ben Ryves
; --------------------
; SETTINGS.ASM: Settings screen

.module Chip8
.using noname
.var 1,_option_index
.var 2,_temp_digit
.var 1,_settings_offset
.var 1,_top_offset


_settings_count = 12

_options
	set _b_display_dirty
_option_gui_loop
	bcall(_GrBufClr)
	ld hl,_banner
	ld de,plotSScreen
	ld bc,12*7
	ldir
	
	ld a,(_settings_offset)
	ld b,a
	add a,a
	ld c,a
	add a,a
	add a,b
	add a,c
	neg
	ld (_top_offset),a
	
	add a,_gui_top
	ld (penRow),a

	ld hl,_options_strings
	ld b,_settings_count
-	push bc
	ld a,2
	ld (penCol),a
	ld a,(penRow)
	cp _gui_top
	jr c,{+}
	cp 64-6
	jr nc,{+}
	bcall(_VPutS)
	jr {++}
+	
--
	inc hl
	ld a,(hl)
	or a
	jr nz,{--}
	inc hl	
	
++
	pop bc
	ld a,(penRow)
	add a,7
	ld (penRow),a
	djnz {-}
	

	
	; Draw the numeric values:
	ld a,(_top_offset)
	add a,_gui_top+7*0
	ld (penRow),a
	
	ld a,(_instruction_delay)
	call _draw_3_digit
	
	ld a,(_frame_skip)
	call _draw_3_digit
	
	ld a,(_interrupt_speed)
	call _draw_3_digit
	
	; Draw all the tickboxes	
	
	bit _s_always_redraw
	call _option_draw_tick

	bit _s_shrink_mode
	call _option_draw_tick

	bit _s_inverse_video
	call _option_draw_tick
	
	bit _s_x_wrap_sprites
	call _option_draw_tick

	bit _s_y_wrap_sprites
	call _option_draw_tick	
	
	bit _s_ignore_errors
	call _option_draw_tick
	
	bit _s_enable_sound
	call _option_draw_tick
	
	; Draw the base address
	
	ld a,(penRow)
	cp 64-6
	jr nc,_no_base_add
	cp _gui_top
	jr c,_no_base_add
	
	ld a,73
	ld (penCol),a
	
	ld a,'$'
	ld (_temp_digit),a
	ld hl,_temp_digit
	bcall(_VPutS)
	ld a,(_custom_load_address)
	call _draw_digit
	xor a
	call _draw_digit
	xor a
	call _draw_digit
	
_no_base_add

	ld a,(penRow)
	add a,7
	ld (penRow),a

	; Optional keymap

	bit _s_alternate_keys
	call _option_draw_tick

	
	; Draw the highlight
	
	ld a,(_settings_offset)
	ld b,a
	ld a,(_option_index)
	sub b
	call _draw_gui_highlight
	
	ld a,(_option_index)
	ld b,a
	ld c,_settings_count-1

	call _draw_gui_scrollbars
	
	call ionFastCopy
-	bcall(_GetCSC)
	or a
	jr z,{-}
	cp skClear
	jr nz,{+}
	call _lcd_clear
	ret
+	cp skAlpha
	jr nz,{+}
	call _lcd_clear
	ret
+
	cp skUp
	jr nz,{+}
	ld a,(_option_index)
	or a
	jp z,_option_gui_loop
	dec a
	ld (_option_index),a

	; Now, handle scrolling off the top...
	ld b,a
	ld a,(_settings_offset)
	neg
	add a,b
	cp -1
	jp nz,_option_gui_loop
	ld a,(_settings_offset)
	dec a
	ld (_settings_offset),a
	jp _option_gui_loop


+	cp skDown
	jr nz,{+}
	ld a,(_option_index)
	cp _settings_count-1
	jp z,_option_gui_loop
	inc a
	ld (_option_index),a
	
	; Now, handle scrolling off the bottom...
	ld b,a
	ld a,(_settings_offset)
	neg
	add a,b
	cp 8
	jp nz,_option_gui_loop
	ld a,(_settings_offset)
	inc a
	ld (_settings_offset),a
	jp _option_gui_loop	
		
+	cp sk2nd
	jr z,_option_2nd
	cp skEnter
	jr z,_option_2nd
	
	cp skLeft
	jp z,_option_left
	cp skRight
	jp z,_option_right
	cp skYEqu
	jr z,_jmp_0
	cp skWindow
	jr z,_jmp_50
	cp skZoom
	jr z,_jmp_100
	cp skTrace
	jr z,_jmp_150
	cp skGraph
	jr z,_jmp_200
	jp {-}

_jmp_0   ld b,0 \ jr {+}
_jmp_50  ld b,50 \ jr {+}
_jmp_100 ld b,100 \ jr {+}
_jmp_150 ld b,150 \ jr {+}
_jmp_200 ld b,200
+	ld a,(_option_index)
	or a \	jr nz,{+}
	ld a,b
	ld (_instruction_delay),a
+	cp 1 \ 	jr nz,{+}
	ld a,b
	ld (_frame_skip),a
+	cp 2 \ 	jp nz,_option_gui_loop
	ld a,b
	ld (_interrupt_speed),a
	jp _option_gui_loop
	
	

_option_2nd
	ld a,(_option_index)
	cp  3 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_always_redraw \ ld (iy+asm_Flag1),a \ jp _option_gui_loop
+	cp  4 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_shrink_mode \ ld (iy+asm_Flag1),a \ jp _option_gui_loop 
+	cp  5 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_inverse_video \ ld (iy+asm_Flag1),a \ jp _option_gui_loop
+	cp  6 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_x_wrap_sprites \ ld (iy+asm_Flag1),a \ jp _option_gui_loop
+	cp  7 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_y_wrap_sprites \ ld (iy+asm_Flag1),a \ jp _option_gui_loop
+	cp  8 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_ignore_errors \ ld (iy+asm_Flag1),a \ jp _option_gui_loop
+	cp  9 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_enable_sound \ ld (iy+asm_Flag1),a \ jp _option_gui_loop
+	cp 11 \ jr nz,{+} \ ld a,(iy+asm_Flag1) \ xor 1<<_alternate_keys \ ld (iy+asm_Flag1),a \ jp _option_gui_loop
+

	jp _option_gui_loop

_option_left
	ld b,-1
	jr _option_lr
_option_right
	ld b,1
_option_lr
	ld hl,_instruction_delay
	ld a,(_option_index)
	or a
	jr z,{+}
	ld hl,_frame_skip
	cp 1
	jr z,{+}
	ld hl,_interrupt_speed
	cp 2	
	jr Z,{+}
	cp 10
	jp nz,_option_gui_loop
	
	ld a,(_custom_load_address)
	add a,a
	add a,b
	cp -1 \ jr nz,{++} \ ld a,0		
++	cp 1 \ jr nz,{++} \ ld a,2
++	cp 3 \ jr nz,{++} \ ld a,0
++	cp 5 \ jr nz,{++} \ ld a,6
++	cp 11 \ jr nz,{++} \ ld a,2
++	cp 13 \ jr nz,{++} \ ld a,6
++
		
	ld (_custom_load_address),a
		
	jp _option_gui_loop
	
+	ld a,(hl)
	add a,b
	ld (hl),a
	jp _option_gui_loop

_option_draw_tick
	ld ix,_cross
	jr z,{+}
	ld ix,_tick
+	ld a,(penRow)
	cp 64-5
	jr nc,{+}
	cp _gui_top
	jr c,{+}
	ld b,5
	ld l,a
	inc l
	ld a,85
	call ionPutSprite
+	ld a,(penRow)
	add a,7
	ld (penRow),a
	ret

_draw_3_digit
	push af
	ld a,79
	ld (penCol),a
	ld a,(penRow)
	cp 64-6
	jr nc,_skip_digit_draw
	cp _gui_top
	jr c,_skip_digit_draw
	pop af
	ld c,0
	ld b,C
	
-	cp 100
	jr c,{+}
	sub 100
	inc c
	jr {-}
+


-	cp 10
	jr c,{+}
	sub 10
	inc b
	jr {-}
+	; c,b,a.
	push af
	push bc
	ld a,c
	call _draw_digit
	pop bc
	ld a,b
	call _draw_digit
	pop af
	call _draw_digit
-	ld a,(penRow)
	add a,7
	ld (penRow),a
	ret

_skip_digit_draw
	pop af
	jr {-}
	
_draw_digit
	add a,'0'
	ld (_temp_digit),a
	xor a
	ld (_temp_digit+1),a
	ld hl,_temp_digit
	bcall(_VPutS)
	ret

_options_strings
.asc "Instruction delay",0
.asc "Frame skip",0
.asc "Timer speed",0
.asc "Always refresh LCD",0
.asc "96x64 SCHIP mode",0
.asc "Invert colours",0
.asc "X-Wrap sprites",0
.asc "Y-Wrap sprites",0
.asc "Ignore errors",0
.asc "Enable sound",0
.asc "Load address",0
.asc "Alternate keys",0

_cross
.incbmp "Resources/Cross.gif"
_tick
.incbmp "Resources/Tick.gif"

_saved_settings
.db 1<<_always_redraw|1<<_x_wrap_sprites|1<<_y_wrap_sprites;|1<<_ignore_errors

_instruction_delay
.db 0
_frame_skip
.db 25
_interrupt_speed
.db 60
_custom_load_address
.db $2

.endmodule