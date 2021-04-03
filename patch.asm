; Build params: ------------------------------------------------------------------------------
JPROM	set 1

	if	JPROM
SOUND_INIT_ADDRESS	set $00000406
PLAY_SFX_ADDRESS	set $000004F2
PLAY_MUSIC_ADDRESS	set	$0000052A
REBOOT_ADDRESS		set $00004016
	else
SOUND_INIT_ADDRESS	set $0000040A
PLAY_SFX_ADDRESS	set $0000050A
PLAY_MUSIC_ADDRESS	set	$00000554
REBOOT_ADDRESS		set $00004040
	endif

; Constants: ---------------------------------------------------------------------------------
	MD_PLUS_OVERLAY_PORT:	equ $0003F7FA
	MD_PLUS_CMD_PORT:		equ $0003F7FE
	PAUSE_STATE:			equ $FFFF04B1
; Overrides: ---------------------------------------------------------------------------------
	org SOUND_INIT_ADDRESS
	jsr		SOUND_INIT_DETOUR
	nop

	org PLAY_SFX_ADDRESS
	jmp		PLAY_SFX_DETOUR

	org PLAY_MUSIC_ADDRESS
	jmp 	PLAY_MUSIC_DETOUR

	org REBOOT_ADDRESS
	jsr		REBOOT_DETOUR

; Detours: ------------------------------------------------------------------------------------
	org $64700

SOUND_INIT_DETOUR
	move.w	#$1300,D1
	jsr		WRITE_MD_PLUS_FUNCTION
	move.w	#$100,$A11100
	rts

PLAY_SFX_DETOUR
	move.b	($7F8,A5),D1
	cmpi.b	#$FD,D1							; Check if play id equals any of the stop, play or fadeout commands
	bcs		NO_PAUSE_RESUME_FADEOUT_COMMAND
	jsr		PAUSE_RESUME_FADEOUT_MD_PLUS
NO_PAUSE_RESUME_FADEOUT_COMMAND
	move.b	($807,A5),($A01FFE)				; Write to RAM shared with Z80, to play via FM
	move.b	($7F8,A5),($A01FFF)
	subq.w	#$1,($802,A5)
	rts

PLAY_MUSIC_DETOUR
	move.w	#$1300,D1						; Make sure we issue the stop command to MD+.
	jsr		WRITE_MD_PLUS_FUNCTION			; This is necessary in case track $15 is played, which is still FM
	move.w	#$1200,D1
	move.b	#$0,D3
	move.b	($806,A5),D1
	move.b	D1,($FFF07C0)
	cmpi.b	#$0,D1
	beq		DO_NOT_PLAY_VIA_MD_PLUS
	cmpi.b	#$10,D1							; $10 is an empty track id
	bcs		DO_NOT_SUBTRACT_FURTHER	
	addi.b	#$1,D3
	cmpi.b	#$13,D1							; $13 is an empty track id
	bcs		DO_NOT_SUBTRACT_FURTHER	
	addi.b	#$1,D3
	cmpi.b	#$14,D1
	bhi		DO_NOT_PLAY_VIA_MD_PLUS			; After $14 there are no more tracks
DO_NOT_SUBTRACT_FURTHER	
	sub.b	D3,D1							; Subtract D1 by D3. This ensures that the track ids for MD+ are a continuous sequence
	jsr		WRITE_MD_PLUS_FUNCTION
	move.b	#$0,($806,A5)
	move.b	#$FE,($806,A5)					; Ensure track $15 which is still played via FM, stops once another track is played
DO_NOT_PLAY_VIA_MD_PLUS
	move.b	($807,A5),($A01FFE)				; Write to RAM shared with Z80, to play via FM
	move.b	($806,A5),($A01FFF)
	move.b	#$0,($806,A5)
	rts

PAUSE_RESUME_FADEOUT_MD_PLUS
	move.b	D1,D3
	move	#$13FF,D1
	cmpi.b	#$FE,D3
	beq 	DO_NOTHING
	cmpi.b	#$FF,D3
	bne		WRITE_COMMAND					; In case D1 is $FE, we want to write the pause command with fadeout
	move.b	#$0,D1							; Else we zero the parameter value of D1 to make it a simple pause
	cmpi.b	#$0,(PAUSE_STATE)
	beq		WRITE_COMMAND
	move	#$1400,D1						; If the pause state is not zero, the game is running and we instead write the resume command to D1
WRITE_COMMAND
	jsr		WRITE_MD_PLUS_FUNCTION
DO_NOTHING
	rts

REBOOT_DETOUR
	move.w	#$1300,D1						; Stop all music on reboot
	jsr		WRITE_MD_PLUS_FUNCTION
	move.w	#$1,($4BA,A5)
	rts

; Helper Function: ----------------------------------------------------------------------------
WRITE_MD_PLUS_FUNCTION:
	move.w  #$CD54,(MD_PLUS_OVERLAY_PORT)	;open interface
	move.w  D1,(MD_PLUS_CMD_PORT)			;send play command to interface
	move.w  #$0000,(MD_PLUS_OVERLAY_PORT)	;close interface
	rts
