; VINEGAR by Ben Ryves
; --------------------
; TI83.ASM: TI-83 Plus routines/defines not on the 83.


_EnoughMem
	push hl
	bcall(_MemChk)
	pop de
	bcall(_CpHLDE)
	jr c,_not_enough
	xor a
	ret
_not_enough
	xor a
	inc a
	ret

_MemSet
	ld (hl),a
	ld d,h
	ld e,l
	inc de
	dec bc
	ldir
	ret

_CreateProtProg = $448A
ProtProgObj = 5
_DelVarArc = _DelVar