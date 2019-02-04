#import "helpers.asm"

.label border = $d020
.label background = $d021

.label cia1_interrupt_control_register = $dc0d
.label cia2_interrupt_control_register = $dd0d

// Note: the '-2' is required because stabilize_irq() takes 2 raster
// lines to synchronize the raster. More precisely, it _always_ ends
// after completing the 3rd cycle of raster line number RASTER_LINE.
.const RASTER_LINE = (48-1)-2 // We want to "land" at RL:47:03

:BasicUpstart2(main)
main:
  sei
    // Set $D011 to use $18, so YSCROLL is 0
    lda #$18
    sta $D011

    //Display blanks on 1024 bytes, starting from $0400
    clear_screen(32)

    // Display a column of numbers, to make it simpler
    // to see whether the line crunches are working.
    ldx #48
    .for(var index=0; index < 5; index++) {
      stx screen + 0 + index * 40
      stx screen + 200 + index * 40
      stx screen + 400 + index * 40
      stx screen + 600 + index * 40
      stx screen + 800 + index * 40
      inx
    }

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

// In order to avoid seeing the screen flashing, or be a bit jumpy
// and sometimes jerking forward in irs movements, the first part
// of this code has been written counting cycles.
// Notice I am still a beginner, so if some stuff does not look like
// it makes too much sense to you, probably it does not.

irq1:
//jmp exiting_irq1
  // Reset $D011 to use $18 at the start of every frame, so YSCROLL is 0
  lda #$18     // %0001:1000
  sta $D011
  :stabilize_irq() //RasterLine 47, after cycle 3, in short RL:47:03

  :cycles(-3 +63) //RL:47:63
  lda #$19     //(2,RL:48:02) %0001:1001
  sta $D011    //(4,RL:48:06) Move Bad Line condition to the line below

  :cycles(63 -6) //RL:48:63
  lda #$1A    //(2,RL:49:02) %0001:1010
  sta $D011   //(4,RL:49:06) Move Bad Line condition to the line below

  :cycles(63 -6) //RL:49:63
  lda #$1B  //(2,RL:50:02) %0001:1011 (we are back to the default value)
  sta $D011 //(4,RL:50:06) Move Bad Line condition to the line below

//  :cycles(63 -6)//RL50:63

exiting_irq1:
  asl vic2_interrupt_status_register
  :set_raster(RASTER_LINE)
  :mov16 #irq1 : $fffe
  rti