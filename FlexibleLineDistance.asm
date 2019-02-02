#import "helpers.asm"
#import "wait_functions.asm"

.label border = $d020
.label background = $d021

.label cia1_interrupt_control_register = $dc0d
.label cia2_interrupt_control_register = $dd0d

// Note: the '-2' is required because stabilize_irq() takes 2 raster
// lines to synchronize the raster. More precisely, it _always_ ends
// after completing the 3rd cycle of raster line number RASTER_LINE.
.const RASTER_LINE = 48-2

:BasicUpstart2(main)
main:
  sei
    lda #WHITE
    sta border

    lda #50  // Initial raster line to start FLD'ing
    sta $FE
    lda #$FF // Go downward (0 means go upward)
    sta $FF

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
  // Reset $D011 to use the default $1B value with YSCROLL = 3
  lda #$1B
  sta $D011
  :stabilize_irq() //RasterLine 49, after cycle 3, in short RL:49:3
  :cycles(-3 +18)  //RL:49:18

loopy:
  :cycles(-18 +59)  //RL:49:59
  ldx $D012 //(4) Get current line, and..RL:49:63
  dex       //(2)..decrement it, so not to trigger a Bad Line condition
  txa       //(2)
  and #$07  //(2) Use lower 3 bits
  ora #$10  //(2) Screen on + Use textmode
  sta $D011 //(4) Avoid Bad Line condition (RL:48 -> YSCROLL=0) RL:50:12

  cpx $FE   //(3) Keep FLD'ing until raster line $FE..RL:50:15
  bne loopy//(2+)..has been reached RL:50:17+

  // Below this line it is not important to be cycle exact
  // (cycles are provided only for reference)

  lda $ff
  cmp #$ff // Going downward?
  bne upward // No? Then we are currently going upward
downward:
  inc $FE          //(5)
  lda $D012        //(4)
  cmp #240         //(2)
  bne exiting_irq1//(2+)
  lda #0
  sta $FF
  jmp exiting_irq1
upward:
  dec $FE          //(5)
  lda $D012        //(4)
  cmp #50         //(2) Stop at this raster line (RL:51:28)
  bne exiting_irq1//(2+)
  lda #$FF
  sta $FF

exiting_irq1:
  asl vic2_interrupt_status_register
  :set_raster(RASTER_LINE)
  :mov16 #irq1 : $fffe
  rti