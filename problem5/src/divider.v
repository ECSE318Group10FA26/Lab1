// ==========================================================================
// divider.v
//
// Non-restoring unsigned divider (Lab 1, Fig 5.1)
//
//   M   : divisor register
//   D   : dividend in, quotient out
//   R   : partial remainder (N+1 bits, extra sign bit)
//   CNT : cycle counter (not shown in Fig 5.1)
//
// Algorithm (per lab handout):
//   1. Load: M <- divisor, D <- dividend, R <- 0, CNT <- N
//   2. Shift {R, D} left 1 bit, then R <- R - M   (initial subtract)
//   3. Repeat for N-1 cycles, based on the sign of R from the previous op:
//        R >= 0 : D[0] <- 1, shift {R,D} left 1 bit, R <- R - M
//        R <  0 : D[0] <- 0, shift {R,D} left 1 bit, R <- R + M
//      Decrement CNT each cycle.
//   4. Correction cycle (fixes last quotient bit):
//        R <  0 : D[0] <- 0, R <- R + M  (restore remainder)
//        R >= 0 : D[0] <- 1
//   5. Quotient is in D, remainder is in R.
//
// Design goals: minimize clock count and minimize per-cycle delay.
// ==========================================================================

module divider #(
    parameter int N = 4  // operand width (M and D)
) (
    input  wire         clk,
    input  wire         rst,        // synchronous reset
    input  wire         start,      // pulse high to begin a division
    input  wire [N-1:0] dividend,
    input  wire [N-1:0] divisor,
    output wire [N-1:0] quotient,
    output wire [  N:0] remainder,
    output reg          done
);

  // ------------------------------------------------------------------
  // Registers
  // ------------------------------------------------------------------
  reg [N-1:0] M;  // divisor
  reg [  N:0] R;  // partial remainder (extra sign bit)
  reg [N-1:0] D;  // dividend -> quotient
  reg [  3:0] cnt;  // cycle counter (enough for N <= 15)

  // ------------------------------------------------------------------
  // Control FSM
  // ------------------------------------------------------------------
  // TODO: state encoding, e.g.
  //   localparam IDLE = 2'd0, RUN = 2'd1, CORRECT = 2'd2, FINISH = 2'd3;
  //   reg [1:0] state;

  assign quotient  = D;
  assign remainder = R;

  // ------------------------------------------------------------------
  // Datapath + control
  // ------------------------------------------------------------------
  // TODO:
  //   - IDLE:    on start, load M, D; clear R; load CNT
  //   - RUN:     shift {R,D} left 1 bit; add/sub M based on sign of R;
  //              shift quotient bit into D[0]; decrement CNT
  //   - CORRECT: fix last quotient bit / restore remainder if R < 0
  //   - FINISH:  assert done, return to IDLE
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst) begin
      // TODO: reset registers, done <= 0
      done <= 1'b0;
    end else begin
      // TODO: FSM + datapath
    end
  end

endmodule
