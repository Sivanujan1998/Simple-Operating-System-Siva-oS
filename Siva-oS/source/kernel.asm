

[SEGMENT .text]

;START #####################################################
    mov ax, 0x0100			;location where kernel is loaded
    mov ds, ax
    mov es, ax
    
    cli
    mov ss, ax				;stack segment
    mov sp, 0xFFFF			;stack pointer at 64k limit
    sti

    push dx
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x21*4], _int0x21	; setup interrupt service
    mov [es:0x21*4+2], cs
    sti
    pop es
    pop dx

    mov si, strWelcomeMsg   ; load message
    mov al, 0x01            ; request sub-service 0x01
    int 0x21

	call _shell				; call the shell
    
    int 0x19                ; reboot
;END #######################################################

_int0x21:
    _int0x21_ser0x01:       ;service 0x01
    cmp al, 0x01            ;see if service 0x01 wanted
    jne _int0x21_end        ;goto next check (now it is end)
    
	_int0x21_ser0x01_start:
    lodsb                   ; load next character
    or  al, al              ; test for NUL character
    jz  _int0x21_ser0x01_end
    mov ah, 0x0E            ; BIOS teletype
    mov bh, 0x00            ;he display page 0
    mov bl, 0x07            ; text attribute
    int 0x10                ; invoke BIOS
    jmp _int0x21_ser0x01_start
    _int0x21_ser0x01_end:
    jmp _int0x21_end

    _int0x21_end:
    iret

_shell:
	_shell_begin:
	;move to next line
	call _display_endl

	;display prompt
	call _display_prompt

	;get user command
	call _get_command
	
	;split command into components
	call _split_cmd

	;check command & perform action

	; empty command
	_cmd_none:		
	mov si, strCmd0
	cmp BYTE [si], 0x00
	jne	_cmd_ver		;next command
	jmp _cmd_done
	
	; display version
		_cmd_ver:		
		mov si, strCmd0
		mov di, cmdVer
		mov cx, 8
		repe	cmpsb
		jne	_cmd_help		;next command
		call _display_endl
		call _display_endl
		mov si, strOsName		;display version
		mov al, 0x01
	    int 0x21
		call _display_space
		mov si, txtVersion		;display version
		mov al, 0x01
	    int 0x21
		call _display_space

		mov si, strMajorVer		
		mov al, 0x01
	    int 0x21
		mov si, strMinorVer
		mov al, 0x01
	    int 0x21
	    call _display_endl
		jmp _cmd_done
		




_cmd_help:
	call _display_endl		
	mov si, strCmd0
	mov di, cmdHelp
	mov cx, 5
	repe	cmpsb
	jne	_cmd_HardwareInfo
	
	
	call _display_endl
	mov si, strHelpMsg1
	mov al, 0x01
	int 0x21
	call _display_endl
	mov si, strHelpMsg2
	mov al, 0x01
	int 0x21
	call _display_endl
	mov si, strHelpMsg3
	mov al, 0x01
	int 0x21
	call _display_endl
	mov si, strHelpMsg4
	mov al, 0x01
	int 0x21
	call _display_endl
	mov si, strHelpMsg5
	mov al, 0x01
	int 0x21
	call _display_endl
	jmp _cmd_done
	
	
	;display hardware info
	
_cmd_HardwareInfo:
	mov si, strCmd0
	mov di, cmdInfo
	
	mov cx, 5
	repe	cmpsb
	jne _cmd_greet
	
	call _display_endl
	mov si, heading
	mov al, 0x01
	int 0x21
	call _display_endl


	call _cmd_cpuVendorID
	call _serial_ports
	call _cmd_ProcessorType
	call _hard_info
	call _cmd_memoryinfo
	
	call _display_endl
	call _bottom
	
	
	jmp _cmd_done
	
	_bottom:
	call _display_endl
	mov si, underline
	mov al, 0x01
	int 0x21
	call _display_endl
	ret
	
	
	_cmd_cpuVendorID:
		call _display_endl
		mov si,strcpuid
		mov al, 0x01
		int 0x21

		mov eax,0
		cpuid; call cpuid command
		mov [strcpuid],ebx		; load last string
		mov [strcpuid+4],edx;	 load middle string
		mov [strcpuid+8],ecx		; load first string
		;call _display_endl
		mov si, strcpuid		;print CPU vender ID
		mov al, 0x01
		int 0x21
		ret
		
	_cmd_ProcessorType:
		call _display_endl
		mov si, strtypeofcpu
		mov al, 0x01
		int 0x21

	
		mov eax, 0x80000002		; get first part of the brand
		cpuid
		mov  [strcputype], eax
		mov  [strcputype+4], ebx
		mov  [strcputype+8], ecx
		mov  [strcputype+12], edx

		mov eax,0x80000003
		cpuid; call cpuid command
		mov [strcputype+16],eax
		mov [strcputype+20],ebx
		mov [strcputype+24],ecx
		mov [strcputype+28],edx

		mov eax,0x80000004
		cpuid     ; call cpuid command
		mov [strcputype+32],eax
		mov [strcputype+36],ebx
		mov [strcputype+40],ecx
		mov [strcputype+44],edx

		

		mov si, strcputype           ;print processor type
		mov al, 0x01
		int 0x21
		ret
	

	_cmd_memoryinfo:
		ret
		push ax
		push bx
		push cx
		push dx
		push es
		push si

		call _display_endl
		mov si, strmem	; Prints base memory string
		mov al, 0x01
		int 0x21
		
		; Reading Base Memory -----------------------------------------------
		push ax
		push dx
		
		int 0x12		; call interrupt 12 to get base mem size
		mov dx,ax 
		mov [basemem] , ax
		call _print_dec		; display the number in decimal
		mov al, 0x6b
		mov ah, 0x0E            ; BIOS teletype acts on 'K' 
		mov bh, 0x00
		mov bl, 0x07
		int 0x10
		mov si, basemem	; Prints base memory string
		mov al, 0x01
		int 0x21
	
		

		
		pop dx
		pop ax

		; Reading extended Memory
		call _display_endl
		mov si, strsmallext
		mov al, 0x01
		int 0x21
		
		xor cx, cx		; Clear CX
		xor dx, dx		; clear DX
		mov ax, 0xE801
		int 0x15		; call interrupt 15h
		mov dx, ax		; save memory value in DX as the procedure argument
		mov [extmem1], ax
		call _print_dec		; print the decimal value in DX
		mov al, 0x6b
		mov ah, 0x0E            ; BIOS teletype acts on 'K'
		mov bh, 0x00
		mov bl, 0x07
		int 0x10
		
		xor cx, cx		; clear CX
		xor dx, dx		; clear DX
		mov ax, 0xE801
		int 0x15		; call interrupt 15h
		mov ax, dx		; save memory value in AX for division
		xor dx, dx
		mov si , 16
		div si			; divide AX value to get the number of MB
		mov dx, ax
		mov [extmem2], ax
		push dx			; save dx value

		call _display_endl
		mov si, strbigext
		mov al, 0x01
		int 0x21
		
		pop dx			; retrieve DX for printing
		call _print_dec
		mov al, 0x4D
		mov ah, 0x0E            ; BIOS teletype acts on 'M'
		mov bh, 0x00
		mov bl, 0x07
		int 0x10

		call _display_endl
		mov si, strtotmem
		mov al, 0x01
		int 0x21

		; total memory = basemem + extmem1 + extmem2
		mov ax, [basemem]	
		add ax, [extmem1]	; ax = ax + extmem1
		shr ax, 10
		add ax, [extmem2]	; ax = ax + extmem2
		mov dx, ax
		call _print_dec
		mov al, 0x4D            
		mov ah, 0x0E            ; BIOS teletype acts on 'M'
		mov bh, 0x00
		mov bl, 0x07
		int 0x10
		pop si
		pop es
		pop dx
		pop cx
		pop bx
		pop ax
		ret
		
	
	_hard_info:
		call _display_endl
		mov si, strhard
		mov al, 0x01
		int 0x21
		mov si, number
		mov al, 0x01
		int 0x21

		mov ah, 0x0E            ; BIOS teletype acts on character 
		mov bh, 0x00
		mov bl, 0x07
		int 0x10
		ret
		
	_serial_ports:
		call _display_endl
		mov si, strserialportno
		mov al, 0x01
		int 0x21

		mov ax, [es:0x10]
		shr ax, 9
		and ax, 0x0007
		add al, 30h
		mov ah, 0x0E            ; BIOS teletype acts on character
		mov bh, 0x00
		mov bl, 0x07
		int 0x10
		ret



	
	_cmd_greet:
		call _display_endl		
		mov si, strCmd0
		mov di, cmdgreet
		mov cx, 6
		repe	cmpsb
		jne	_cmd_star1
		
		
		
		mov si, greetMsg1
		mov al, 0x01
		int 0x21
		
		call _display_endl
		mov si, greetMsg2
		mov al, 0x01
		int 0x21
		call _display_endl
		mov si, greetMsg3
		mov al, 0x01
		int 0x21
		call _display_endl
		
		jmp _cmd_done
		

					
			
				  

			
	
					
		
	_cmd_star1:
	       		
		mov si, strCmd0
		mov di, cmdstar1
		mov cx, 10
		repe	cmpsb
		jne	_cmd_star2
		
		mov si, starmsg1
		mov al, 0x01
		int 0x21
		call _display_endl
		mov si, ratemsg
		mov al, 0x01
		int 0x21
		call _display_endl
		
	
	
	
	jmp _cmd_done
	_cmd_star2:
	      		
		mov si, strCmd0
		mov di, cmdstar2
		mov cx, 11
		repe	cmpsb
		jne	_cmd_star3
		
		mov si, starmsg2
		mov al, 0x01
		int 0x21
		call _display_endl
		mov si, ratemsg
		mov al, 0x01
		int 0x21
		call _display_endl
		
	
	
	
	jmp _cmd_done
	_cmd_star3:
	      		
		mov si, strCmd0
		mov di, cmdstar3
		mov cx, 11
		repe	cmpsb
		jne	_cmd_star4
		
		mov si, starmsg3
		mov al, 0x01
		int 0x21
		call _display_endl
		mov si, ratemsg
		mov al, 0x01
		int 0x21
		call _display_endl
		
	
	
	
	jmp _cmd_done
	_cmd_star4:
	      		
		mov si, strCmd0
		mov di, cmdstar4
		mov cx, 11
		repe	cmpsb
		jne	_cmd_star5
		
		mov si, starmsg4
		mov al, 0x01
		int 0x21
		call _display_endl
		mov si, ratemsg
		mov al, 0x01
		int 0x21
		call _display_endl
	
	
	
	jmp _cmd_done
	_cmd_star5:
	     		
		mov si, strCmd0
		mov di, cmdstar5
		mov cx, 11
		repe	cmpsb
		jne	_cmd_exit
		
		mov si, starmsg5
		mov al, 0x01
		int 0x21
		call _display_endl
		mov si, ratemsg
		mov al, 0x01
		int 0x21
		call _display_endl
		
	
	
	
	jmp _cmd_done
		
		

	
		


	; exit shell
			_cmd_exit:		
			mov si, strCmd0
			mov di, cmdExit
			mov cx, 5
			repe	cmpsb
			jne	_cmd_unknown		;next command

			je _shell_end			;exit from shell

	_cmd_unknown:
			
			mov si, msgUnknownCmd		;unknown command
			mov al, 0x01
		    int 0x21
		    call _display_endl

			_cmd_done:

			;call _display_endl
			jmp _shell_begin
			
	_shell_end:
	    ret

_get_command:
	;initiate count
	mov BYTE [cmdChrCnt], 0x00
	mov di, strUserCmd

	_get_cmd_start:
	mov ah, 0x10		;get character
	int 0x16

	cmp al, 0x00		;check if extended key
	je _extended_key
	cmp al, 0xE0		;check if new extended key
	je _extended_key

	cmp al, 0x08		;check if backspace pressed
	je _backspace_key

	cmp al, 0x0D		;check if Enter pressed
	je _enter_key

	mov bh, [cmdMaxLen]		;check if maxlen reached
	mov bl, [cmdChrCnt]
	cmp bh, bl
	je	_get_cmd_start

	;add char to buffer, display it and start again
	mov [di], al			;add char to buffer
	inc di					;increment buffer pointer
	inc BYTE [cmdChrCnt]	;inc count

	mov ah, 0x0E			;display character
	mov bl, 0x07
	int 0x10
	jmp	_get_cmd_start

	_extended_key:			;extended key - do nothing now
	jmp _get_cmd_start

	_backspace_key:
	mov bh, 0x00			;check if count = 0
	mov bl, [cmdChrCnt]
	cmp bh, bl
	je	_get_cmd_start		;yes, do nothing
	
	dec BYTE [cmdChrCnt]	;dec count
	dec di

	;check if beginning of line
	mov	ah, 0x03		;read cursor position
	mov bh, 0x00
	int 0x10

	cmp dl, 0x00
	jne	_move_back
	dec dh
	mov dl, 79
	mov ah, 0x02
	int 0x10

	mov ah, 0x09		; display without moving cursor
	mov al, ' '
    mov bh, 0x00
    mov bl, 0x07
	mov cx, 1			; times to display
    int 0x10
	jmp _get_cmd_start

	_move_back:
	mov ah, 0x0E		; BIOS teletype acts on backspace!
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
	mov ah, 0x09		; display without moving cursor
	mov al, ' '
    mov bh, 0x00
    mov bl, 0x07
	mov cx, 1			; times to display
    int 0x10
	jmp _get_cmd_start

	_enter_key:
	mov BYTE [di], 0x00
	ret

_split_cmd:
	;adjust si/di
	mov si, strUserCmd
	;mov di, strCmd0

	;move blanks
	_split_mb0_start:
	cmp BYTE [si], 0x20
	je _split_mb0_nb
	jmp _split_mb0_end

	_split_mb0_nb:
	inc si
	jmp _split_mb0_start

	_split_mb0_end:
	mov di, strCmd0

	_split_1_start:			;get first string
	cmp BYTE [si], 0x20
	je _split_1_end
	cmp BYTE [si], 0x00
	je _split_1_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_1_start

	_split_1_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb1_start:
	cmp BYTE [si], 0x20
	je _split_mb1_nb
	jmp _split_mb1_end

	_split_mb1_nb:
	inc si
	jmp _split_mb1_start

	_split_mb1_end:
	mov di, strCmd1

	_split_2_start:			;get second string
	cmp BYTE [si], 0x20
	je _split_2_end
	cmp BYTE [si], 0x00
	je _split_2_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_2_start

	_split_2_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb2_start:
	cmp BYTE [si], 0x20
	je _split_mb2_nb
	jmp _split_mb2_end

	_split_mb2_nb:
	inc si
	jmp _split_mb2_start

	_split_mb2_end:
	mov di, strCmd2

	_split_3_start:			;get third string
	cmp BYTE [si], 0x20
	je _split_3_end
	cmp BYTE [si], 0x00
	je _split_3_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_3_start

	_split_3_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb3_start:
	cmp BYTE [si], 0x20
	je _split_mb3_nb
	jmp _split_mb3_end

	_split_mb3_nb:
	inc si
	jmp _split_mb3_start

	_split_mb3_end:
	mov di, strCmd3

	_split_4_start:			;get fourth string
	cmp BYTE [si], 0x20
	je _split_4_end
	cmp BYTE [si], 0x00
	je _split_4_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_4_start

	_split_4_end:
	mov BYTE [di], 0x00

	;move blanks
	_split_mb4_start:
	cmp BYTE [si], 0x20
	je _split_mb4_nb
	jmp _split_mb4_end

	_split_mb4_nb:
	inc si
	jmp _split_mb4_start

	_split_mb4_end:
	mov di, strCmd4

	_split_5_start:			;get last string
	cmp BYTE [si], 0x20
	je _split_5_end
	cmp BYTE [si], 0x00
	je _split_5_end
	mov al, [si]
	mov [di], al
	inc si
	inc di
	jmp _split_5_start

	_split_5_end:
	mov BYTE [di], 0x00

	ret

_display_space:
	mov ah, 0x0E                            ; BIOS teletype
	mov al, 0x20
    mov bh, 0x00                            ; display page 0
    mov bl, 0x07                            ; text attribute
    int 0x10                                ; invoke BIOS
	ret

_display_endl:
	mov ah, 0x0E		; BIOS teletype acts on newline!
    mov al, 0x0D
	mov bh, 0x00
    mov bl, 0x07
    int 0x10
	mov ah, 0x0E		; BIOS teletype acts on linefeed!
    mov al, 0x0A
	mov bh, 0x00
    mov bl, 0x07
    int 0x10
	ret

_display_prompt:
	mov si, strPrompt
	mov al, 0x01
	int 0x21
	ret
	
_print_dec:
	push ax			; save AX
	push cx			; save CX
	push si			; save SI
	mov ax,dx		; copy number to AX
	mov si,10		; SI is used as the divisor
	xor cx,cx		; clear CX
	ret



[SEGMENT .data]
	strtypeofcpu		db	"CPU Type: ", 0x00
	strhard		db	"NO of hard drives in this OS: ",0x00
	strserialportno	db	"Number of serial ports: ", 0x00
	strport1		db	"Base I/O address for serial port 1 (communications port 1 - COM 1): ", 0x00
	strtotmem		db	"Total memory: ",0x00
	underline		db      "___________________________________",0x00
	
	strmem		db	"Base Memory size: ", 0x00
	strsmallext	db	"Extended memory between(1M - 16M): ", 0x00
	strbigext		db      "Extended memory above 16M: ", 0x00
		
    strWelcomeMsg   		db  "Welcome to **SivA-OS 6.3.9** type 'help' to display the features in this OS", 0x00
	strPrompt		db	"Siva-oS>>", 0x00
	cmdMaxLen		db	255			;maximum length of commands

	strOsName		db	"Siva-oS", 0x00	;OS details
	strMajorVer		db	"6", 0x00
	strMinorVer		db	".3.9", 0x00


	strHelpMsg1		db  "Type 'version' ==> display version",0x00
	strHelpMsg2		db  "Type 'info' ==> displaying Hardware informations of this machine",0x00
	strHelpMsg3		db  "Type 'exit' ==> rebooting the system",0x00
	strHelpMsg4		db  "Type 'greet'==> recive the greeting message from the machine",0x00
	strHelpMsg5		db  "Type 'give1star' or 'give2stars' or 'give3stars' or 'give4stars' or 'give5stars' ==> rating this OS",0x00
	
	
	greetMsg1		db   "                       *** Wel come to this Siva-OS ***",0x00
	greetMsg2		db   "    our special guests:  We are truly delighted to welcome you here today.",0x00
	greetMsg3        	db "                       type the commands are correctly",0x00
	

	
	cmdVer			db	"version", 0x00		; internal commands
	cmdExit		db	"exit", 0x00
	cmdHelp		db	"help", 0x00
	cmdInfo		db      "info",0x00
	cmdgreet		db      "greet",0x00
	cmdcal			db       "calculater",0x00
	cmdstar1		db       "give1star",0x00
	cmdstar2		db       "give2stars",0x00
	cmdstar3		db       "give3stars",0x00
	cmdstar4		db       "give4stars",0x00
	cmdstar5		db       "give5stars",0x00

	txtVersion		db	"version", 0x00	;messages and other strings
	msgUnknownCmd		db	"Unknown command!!! type 'help' to know the commands in this OS", 0x00
	number  		db 	"1",0x00
	
	starmsg1    		db   " * ", 0x00
	starmsg2  		db   " * * ", 0x00
	starmsg3  		db   " * * * ", 0x00
	starmsg4    		db   " * * * * ", 0x00
	starmsg5    		db   " * * * * * ", 0x00
	ratemsg     		db   "thank you for your rating",0x00
	
	heading		db	"*** Hardware Informations ***",0x00
	strcpuid 		db  	"CPU ID : ",0x00
	
	
	
	
[SEGMENT .bss]
		
	strUserCmd		resb  256;buffer for user commands
	cmdChrCnt		resb	1		;count of characters
	strCmd0		resb	256	;buffers for the command components
	strCmd1		resb	256
	strCmd2		resb	256
	strCmd3		resb	256
	strCmd4		resb	256
	
	strVendorID		resb	16
	strcputype		resb	64
	basemem		resb	2
	extmem1		resb	2
	extmem2		resb	2
	
	
	
	

;********************end of the kernel code********************
