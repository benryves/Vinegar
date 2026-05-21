; VINEGAR by Ben Ryves
; --------------------
; VIDEO.ASM: Copying the buffer to the physical LCD

; ===============================================================
; Unscaled (centred, cropped)
; ===============================================================	
_screen_x
	ld a,$20+2
	ld hl,(_video_memory)
	bit _b_schip_video
	jr z,{+}

	bit _s_shrink_mode
	jp nz,_use_shrink
_scr_offset
		ld de,2
		add hl,de
+
--		ld de,16
		ld c,a
		call _lcd_busy
		out ($10),a

_screen_y
		ld a,$80+16
		call _lcd_busy
		out ($10),a
_screen_height
		ld b,32
-
		ld a,(hl)
		add hl,de
		push af
		pop af
		bit _s_inverse_video \ jp z,{+} \ cpl
+		out ($11),a
		djnz {-}
_column_offset
		ld de,(-16*32)+1
		add hl,de
		
		ld a,c
		inc a
_screen_x_end
		cp $20+8+2
		jp nz,{--}
	jp _done_video

; ===============================================================
; Squashed to 96x94
; ===============================================================	
_use_shrink
	ld a,$07
	call _lcd_busy
	out ($10),a
	ld ixl,$80
	ld a,$80
--	call _lcd_busy
	out ($10),a

	call _lcd_busy
	ld a,$20
	out ($10),a
	

	ld b,4
	bit _b_shrink_frame
	jp z,_pass_2
-		ld a,(hl) ; #1
		ld d,a
		inc hl
		
		and %11100000
		ld e,a
		ld a,d
		add a,a
		and %00011100
		or e
		ld e,a
	
		ld a,(hl) ;#2
		ld d,a
		inc hl
		
		ld a,e
		srl a
		srl a
	
		sla d
		rl a
		sla d
		rl a
		bit _s_inverse_video \ jp z,{+} \ cpl
+		
		out ($11),a ;#1
		
		ld a,d
		and %10000000
		ld e,a
		sla d
		ld a,d
		and %01110000
		or e
		ld e,a
		
		ld a,(hl) ;#3
		srl a
		srl a
		srl a
		ld d,a
		and %00000001
		or e
		ld e,a
		ld a,d
		srl a
		and %00001110
		or e
		bit _s_inverse_video \ jp z,{+} \ cpl
+		
		out ($11),a ;#2
		
		ld a,(hl) ;#3
		inc hl
		add a,a
		add a,a
		add a,a
		add a,a
		add a,a
		and %11000000
		ld e,a
		ld a,(hl) ;#4
		inc hl
		
		srl a
		ld d,a
		and %00000111
		or e
		ld e,a
		ld a,d
		srl a
		and %00111000
		or e
		bit _s_inverse_video \ jp z,{+} \ cpl
+		
		out ($11),a ;#3
	
		djnz {-}
		jp _done_pass_1
	
_pass_2
		scf
		ld a,(hl)
		bit 7,a
		jp nz,{+}
		ccf
		jp {+}
		
-		ld a,(hl) ;#1

+		inc hl
		
		ld e,0 ; Clear E
		rr e ; Stick in CARRY FLAG (from end of loop below)
		
		ld d,a
		and %01110000
		or e
		ld e,a
		ld a,d
		add a,a
		and %00001110
		or e
		ld e,a
		
		ld a,(hl) ; #2
		inc hl
		
		srl e
		add a,a
		sla a
		ld d,a
		rl e
		ld a,e
		bit _s_inverse_video \ jp z,{+} \ cpl
+		
		out ($11),a ;#1
		
		ld a,d
		and %11000000
		ld e,a
		ld a,d
		add a,a
		and %00111000
		or e
		ld e,a
		
		ld a,(hl) ;#3
		inc hl
		ld d,a
		srl a
		srl a
		srl a
		srl a
		and %00000111
		or e
		bit _s_inverse_video \ jp z,{+} \ cpl
+		
		out ($11),a ;#2
		
		ld a,d
		add a,a
		add a,a
		add a,a
		add a,a
		add a,a
		and %11100000
		ld e,a
		
		ld a,(hl) ;#4
		ld d,a
		inc hl
		
		srl a
		srl a
		and %00011100
		or e
		ld e,a
		ld a,d
		srl a
		push af
		and %00000011
		or e
		bit _s_inverse_video \ jp z,{+} \ cpl
+		
		out ($11),a
		pop af	
		djnz {-}

_done_pass_1	
	inc ixl
	ld a,ixl
	cp $80+64
	jp nz,{--}

	ld a,(iy+asm_Flag2)
	xor 1 << _shrink_frame
	ld (iy+asm_Flag2),a
	
	ld a,$05
	out ($10),a
_done_video