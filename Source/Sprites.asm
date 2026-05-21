; VINEGAR by Ben Ryves
; --------------------
; SPRITES.ASM: 16x16 and 8x8 SCHIP/CHIP-8 sprite routines, with v/h wrapping.

	ld c,a
	push af
	
	; Set up flags
	xor a
	ld (_reg_flag),a
	res _b_collision
	res _b_wrap_x
	ld a,15
	ld (_col_wrap_x+1),a
	
	set _b_display_dirty

_cur_height
	ld a,32
	sub l
	ld (_max_height_a+1),a
	ld (_max_height_b+1),a
	pop af
	
	ld h,0
	;l = y
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,(_video_memory)
	add hl,de
	;hl->destination Y
	srl a
	srl a
	srl a

_x_wrap_column
	cp 7
	jr nz,{+}
		set _b_wrap_x
		push af
_col_wrap_offset
		ld a,7+16
		ld (_col_wrap_x+1),a
		pop af
+
	ld e,a
	ld d,0
	add hl,de
	;hl->top-left destination byte
	
	;b = height, supposedly.
	ld a,b
	or a
	jp nz,_spr_8x8
	; Double size?
	bit _b_schip_video
	jr nz,_spr_16x16
	ld a,16 ; 16-tall
	ld b,a
	jp _spr_8x8

_spr_16x16	
		ld a,16
		push af
_max_height_a	ld d,0
		cp d
		jr c,{+}
		ld a,d
+		ld b,a
		push bc

_spr_16x16_loop_b
		; So - b = height, c = x position
--		push bc
		push hl
		
		ld d,(ix)
		inc ix
		ld e,(ix)
		inc ix
		ld b,0
		
		ld a,c
		and 7
		jr z,{+}
-		srl d
		rr e
		rr b
		dec a
		jr nz,{-}
+		
		srl c
		srl c
		srl c

		ld a,d
		and (hl)
		jr z,{+} \ set _b_collision
+		
		ld a,d
		xor (hl)
		ld (hl),a
			
		ld a,c
		cp 15
		jr nz,{+}
		bit _s_x_wrap_sprites
		jr z,_finished_16x16_sprite
		push de
		ld de,-16
		add hl,de
		pop de
+
		inc hl

		ld a,e
		and (hl)
		jr z,{+} \ set _b_collision
+		
		ld a,e
		xor (hl)
		ld (hl),a
		inc hl

		ld a,b
		and (hl)
		jr z,{+} \ set _b_collision
+		
		ld a,c
		cp 14
		jr nz,{+}
		bit _s_x_wrap_sprites
		jr z,_finished_16x16_sprite		
		ld de,-16
		add hl,de
+
		ld a,b
		xor (hl)
		ld (hl),a

_finished_16x16_sprite
		pop hl		
		ld de,16
		add hl,de
		pop bc
		djnz {--}

		pop bc
		pop af
		bit _s_y_wrap_sprites
		jp z,_done_sprite
		sub b
		jp z,_done_sprite

		ld b,a
		push bc
		push bc
		
		ld de,-64*16
		add hl,de
		jp _spr_16x16_loop_b


_spr_8x8
		push bc
_max_height_b	ld d,0
		cp d
		jr c,{+}
		ld a,d
+		ld b,a
_spr_8x8_loop_b
		push bc
				
--	
		ld d,(ix)
		inc ix
		ld e,0
		
		ld a,c
		and 7
		jr z,{+}
-		srl d
		rr e
		dec a
		jr nz,{-}
+
		ld a,d
		and (hl)
		jr z,{+} \ set _b_collision
+

		ld a,d
		xor (hl)
		ld (hl),a

		bit _b_wrap_x
		jr z,{+}
		
	
		; We're trying to wrap backwards (is it allowed?)
		bit _s_x_wrap_sprites
		jr nz,_wrap_happily
		
		push bc
		ld bc,(_col_wrap_backtrack+1)
		add hl,bc
		pop bc	
		inc hl
		jr _col_wrap_x	

_wrap_happily	
		push bc
_col_wrap_backtrack
		ld bc,-8
		add hl,bc
		pop bc
+		inc hl

		ld a,e
		and (hl)
		jr z,{+} \ set _b_collision
+
		ld a,e
		xor (hl)
		ld (hl),a

_col_wrap_x
		ld de,15
		add hl,de
		djnz {--}
		
		pop bc
		pop af
		bit _s_y_wrap_sprites
		jp z,_done_sprite		
		sub b
		jr z,_done_sprite
		ld b,a
		ld de,-32*16
		bit _b_schip_video
		jr z,{+}
		ld de,-64*16
+
		add hl,de
		push bc
		jp _spr_8x8_loop_b

_done_sprite
		bit _b_collision
		jp z,_done_opcode
		ld a,1
		ld (_reg_flag),a	
		jp _done_opcode