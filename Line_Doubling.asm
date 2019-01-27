#import "helpers.asm"
#import "wait_functions.asm"

.label border = $d020
.label background = $d021

.label cia1_interrupt_control_register = $dc0d
.label cia2_interrupt_control_register = $dd0d

// Raster line 82 is the 8th line of the character row displaying
// "64K RAM SYSTEM  38911 BASIC BYTES FREE"
// that is shown when the Commodore 64 is turn on.
// Note: the '-2' is required because stabilize_irq() takes 2 raster
// lines to synchronize to the raster (more precisely, it _always_ends
// at the 3rd cycle of raster line 81.)
.const RASTER_LINE = 81-2

:BasicUpstart2(main)
main:
  sei
    lda $01
    and #%11111101
    sta $01

    lda #%01111111
    sta cia1_interrupt_control_register
    sta cia2_interrupt_control_register
    lda cia1_interrupt_control_register
    lda cia2_interrupt_control_register

    lda #%00000001
    sta vic2_interrupt_control_register
    sta vic2_interrupt_status_register
    :set_raster(RASTER_LINE)
    :mov16 #irq1 : $fffe
  cli

loop:
  jmp loop

irq1:
  // From http://www.zimmers.net/cbmpics/cbm/c64/vic-ii.txt
  // by Christian Bauer
  //
  // 3.14.5. Doubled text lines
  // --------------------------
  // The display of a text line is normally finished after 8 raster
  // lines, because then RC=7 and in cycle 58 of the last line the
  // sequencer goes to idle state (see section 3.7.2.). But if you now
  // assert a Bad Line Condition between cycles 54-57 of the last line,
  // the sequencer stays in display state and the RC is incremented
  // again (and thus overflows to zero). The VIC will then in the next
  // line start again with the display of the previous text line. But
  // as no new video matrix data has been read, the previous text line
  // is simply displayed twice.

  // This code is the Kick Assembler "translation" of the code at:
  // http://codebase64.org/doku.php?id=base:repeating_char-lines&s[]=hcl
lda #12 // Letter 'L'
sta 1024+40*23 // Leftmost character on 24th row
//jmp exiting_irq1

  :stabilize_irq() //RasterLine 82, after cycle 3 (in short: RL82:3)
  :cycles(-3+ 54 -2*6 -2-4)

  inc background // (6) Display on screen, so
  dec background // (6) we know where we are.

  lda #$1a  // (2) Do repeat char-line..
  sta $d011 // (4) RL82:63

  jsr wait_2_rows_with_20_cycles_bad_lines // RL84:63

  lda #$1b // ..before setting $d011 back to original value.
  sta $d011

exiting_irq1:
  asl vic2_interrupt_status_register
  :set_raster(RASTER_LINE)
  :mov16 #irq1 : $fffe
  rti