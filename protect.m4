dnl  $Id$  M4 file to handle siwtching from to preotected mode
dnl Copyright(2000): Albert van der Horst, HCC FIG Holland by GNU Public License
divert(-1)
_BITS16_1_( {define({IDENTIFY_PROT},{IDENTIFY_16})})
_BITS32_1_( {define({IDENTIFY_PROT},{IDENTIFY_32})})
dnl NOTE: $+..+CW is the address of the next instruction in the
dnl protected mode code segment. the offset makes it relative w.r.t. switch segment.
define({SAVE_SP},{
        MOV     _CELL_PTR[SPSAVE],STACKPOINTER
        AND     AX,AX
        MOV     STACKPOINTER,AX})dnl
define({JMPHERE_FROM_PROT},{
        JMP     GDT_SWITCH: $+3+CW+M4_SWITCHOFFSET
        MOV EAX,CR0
        DEC AL
        MOV CR0,EAX            ;set real mode
dnl The curly brackets prevent AX to be expanded to EAX
        SET_16_BIT_MODE
        MOV     {AX},SWITCHSEGMENT
        MOV     DS,{AX}
        MOV     ES,{AX}
        MOV     {AX},DS_SANDBOX ; {Make stack valid}
        MOV     SS,{AX}
        STI})dnl
define({JMPHERE_FROM_FORTH},{
        SAVE_SP
        JMPHERE_FROM_PROT})dnl
define({JMPHERE_FROM_REAL},{
        CLI
        MOV EAX,CR0
        INC AL
        MOV CR0,EAX            ;set protected mode
        SET_16_BIT_MODE
        JMP    GDT_CS:$+5
        _BITS32_1_({SET_32_BIT_MODE})
        MOV     AX,GDT_DS
        MOV     DS,AX
        MOV     ES,AX
        MOV     SS,AX})dnl
define({RESTORE_SP},{
        MOV     STACKPOINTER,_CELL_PTR[SPSAVE]})dnl
define({JMPHERE_FROM_OS},{
    JMPHERE_FROM_REAL
    RESTORE_SP})dnl
