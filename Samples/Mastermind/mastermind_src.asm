TRIES  .=  $E2
RNDL   .=  $E3
RNDH   .=  $E4
RND2L  .=  $E5
N      .=  $E6
GUESS  .=  $EB

COUT   .=  $FFEF
PRBYTE .=  $FFDC
KBD    .=  $D010
STROBE .=  $D011

MSTMND .M  $300
       LDX #$8
MSGLP  LDA MSG-1,X
       JSR COUT
       DEX
       BNE MSGLP
       STX TRIES
RNDLP  INC RNDL
       BNE RND2
       INC RNDH
RND2   LDA STROBE
       BPL RNDLP
       JSR CHARIN
NXTRY  SEC
       SED
       TXA
       ADC TRIES
       STA TRIES
       CLD
NXTLIN JSR CRLF
       LDA TRIES
       JSR PRBYTE
       LDA #$A0
       TAY
       JSR COUT
       LDA RNDL
       STA RND2L
       LDA RNDH
       LDX #$5
DIGEN  STY N-1,X
       LDY #$3
BITGEN LSR
       ROL RND2L
       ROL N-1,X
       DEY
       BNE BITGEN
       DEX
       BNE DIGEN
RDKEY  JSR CHARIN
       CMP #$9B
       BEQ RET
       JSR COUT
       EOR #$B0
       CMP #$8
       BCS NXTLIN
       STA GUESS+4,X
       DEX
       CPX #$FB
       BNE RDKEY
       LDY #$FB
       LDA #$A0
PLUS1  JSR COUT
PLUS2  LDA GUESS+5,X
       CMP N+5,X
       BNE PLUS3
       STY N+5,X
       LDA #$AB
       STA GUESS+5,X
       INY
       BNE PLUS1
       LDX #$11
       BNE MSGLP
PLUS3  INX
       BNE PLUS2
       LDY #$FB
MINUS1 LDX GUESS+5,Y
       TXA
       LDX #$FB
MINUS2 CMP N+5,X
       BNE MINUS3
       STY N+5,X
       LDA #$AD
       JSR COUT
MINUS3 INX
       BNE MINUS2
       INY
       BNE MINUS1
       BEQ NXTRY
MSG    .B  $BF
       .B  $D9
       .B  $C4
       .B  $C1
       .B  $C5
       .B  $D2
       .B  $8D
       .B  $8D
       .B  $CE
       .B  $C9
       .B  $D7
       .B  $A0
       .B  $D5
       .B  $CF
       .B  $D9
       .B  $A0
       .B  $AB
CRLF   LDA #$8D
       JMP COUT
CHARIN LDA STROBE
       BPL CHARIN
       LDA KBD
RET    RTS