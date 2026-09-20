// divider - Non-restoring unsigned clocked divider
//
// Algorithm:
//   1. Load: M <- divisor, D <- dividend, R <- 0, HOT <- 1
//   2. Shift {R, D} left 1 bit, then R <- R - M   (initial subtract)
//   3. Repeat for N-1 cycles, based on the sign of R from the previous op
//      rotate HOT (the counter)
//   4. Correction with a full adder at the end (combinational)
//   5. Quotient and remainder as above.
//
// Depends: common/lib (cas_row, lookahead_adder, mux, dff_sc, piso_reg,
// piso_msb_reg, or_n, and2, buf1)

module divider #(
    parameter int N = 4,   // operand width (M and D)
    parameter int DG = 2,  // gate delay, in `timescale units
    parameter int DD = 1   // register (clock-to-q) delay, in `timescale units
) (
    input  wire         clk,
    input  wire         clear,  // synchronous reset
    input  wire         start,  // pulse high to begin a division
    input  wire [N-1:0] dividend,
    input  wire [N-1:0] divisor,
    output wire [N-1:0] quotient,
    output wire [  N:0] remainder,
    output wire         done
);
  wire [N-1:0] M;  // divisor register
  wire [N-1:0] D;  // dividend -> quotient register
  wire [  N:0] R;  // partial remainder (bit N = sign)

  // Control: one-hot cycle sequencer
  //   hot[0] marks the last iterate
  //   load = idle & start : load M/D, clear R, seed the hot register
  //   done : one clock after the last iterate
  wire [N-1:0] hot;  // one-hot cycle sequencer
  wire busy, idle, load;

  or_n #(
      .N(1),
      .I(N),
      .D(DG)
  ) busy_or (
      .d(hot),
      .y(busy)
  );

  not #(DG) (idle, busy);
  and #(DG) (load, idle, start);

  piso_reg #(
      .N (N),
      .D (DG),
      .DD(DD)
  ) hot_reg (
      .clk  (clk),
      .clear(clear),
      .load (load),
      .d_in ({1'b1, {(N - 1) {1'b0}}}),
      .q    (hot)
  );

  dff_sc #(
      .N(1),
      .D(DD)
  ) done_reg (
      .clk  (clk),
      .clear(clear),
      .d    (hot[0]),
      .q    (done)
  );

  // The one shared add/subtract CAS row
  wire q_bit;  // quotient bit = sign of the previous result
  wire [N:0] pr;
  wire [N-1:0] cas_sum;
  wire q_row;  // row result non-negative
  wire q_row_n;  // row result sign (the new R[N])

  not #(DG) (q_bit, R[N]);

  buf1 #(N + 1) pr_buf (
      .a({R[N-1:0], D[N-1]}),
      .y(pr)
  );

  cas_row #(
      .N(N),
      .D(DG)
  ) row (
      .pr     (pr),
      .divisor(M),
      .op     (q_bit),
      .sum    (cas_sum),
      .q      (q_row)
  );

  not #(DG) (q_row_n, q_row);

  // M: divisor register (load on start, otherwise hold)
  wire [N-1:0] M_next;

  mux #(
      .N(N),
      .S(1),
      .D(DG)
  ) mux_M (
      .d  ({divisor, M}),
      .sel(load),
      .y  (M_next)
  );

  dff_sc #(
      .N(N),
      .D(DD)
  ) dff_M (
      .clk  (clk),
      .clear(clear),
      .d    (M_next),
      .q    (M)
  );

  // R: partial remainder
  //   load -> 0;  busy -> row result {sign, sum};  otherwise hold
  wire [N:0] R_next;

  mux #(
      .N(N + 1),
      .S(2),
      .D(DG)
  ) mux_R (
      .d  ({ {(N + 1) {1'b0}}, {(N + 1) {1'b0}}, {q_row_n, cas_sum}, R }),
      .sel({load, busy}),
      .y  (R_next)
  );

  dff_sc #(
      .N(N + 1),
      .D(DD)
  ) dff_R (
      .clk  (clk),
      .clear(clear),
      .d    (R_next),
      .q    (R)
  );

  // D: dividend in, quotient out
  //    q[N-1] streams MSB dividend bits to the row
  //    start cycle -> parallel-load dividend;  busy -> shift left, quotient
  //    bit in at the LSB (sin);  otherwise parallel-load itself (hold)
  wire [N-1:0] D_in;

  mux #(
      .N(N),
      .S(1),
      .D(DG)
  ) mux_D (
      .d  ({dividend, D}),
      .sel(load),
      .y  (D_in)
  );

  piso_msb_reg #(
      .N (N),
      .D (DG),
      .DD(DD)
  ) reg_D (
      .clk  (clk),
      .clear(clear),
      .load (idle),
      .sin  (q_bit),
      .d_in (D_in),
      .q    (D)
  );

  // Combinational correction at the outputs:
  //   remainder = R + (M when R < 0 else 0);  quotient = {D[N-2:0], ~R[N]}
  wire [N-1:0] cor_m;  // divisor, masked by R's sign

  and2 #(
      .N(N),
      .D(DG)
  ) cor_mask (
      .a(M),
      .b({N{R[N]}}),
      .y(cor_m)
  );

  // the restored remainder is non-negative and fits in N+1 bits, so the
  // carry-out is unused
  lookahead_adder #(
      .N(N + 1),
      .D(DG)
  ) cor_add (
      .cin   (1'b0),
      .addend(R),
      .augend({1'b0, cor_m}),
      .result(remainder),
      .cout  ()
  );

  buf1 #(
	.N(N)
   ) buf1 (
	{D[N-2:0], q_bit},
	quotient
  );

endmodule
