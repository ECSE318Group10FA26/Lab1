// n-bit operand register with parallel load, shifting toward the MSB
//
// load = 1 : parallel load d_in
// load = 0 : shift one position toward the MSB (sin enters at the LSB),
//            so q[N-1] presents the stored word serially, MSB first
//
// Mirror of piso_reg - this shifts toward MSB instead of LSB
//
// Depends: mux, dff_sc

module piso_msb_reg #(
    // data width of register, in bits
    parameter int N = 2,
    // gate delay, in `timescale units
    parameter int D = 0,
    parameter int DD = 0
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         load,
    input  wire         sin,
    input  wire [N-1:0] d_in,
    output wire [N-1:0] q
);
  wire [N-1:0] d_next;  // next state of the register

  // d_next = load ? d_in : q shifted toward the MSB (sin enters at the LSB).
  // Mux input packing: input 0 in the low N bits, input 1 above it.
  mux #(
      .N(N),
      .S(1),
      .D(D)
  ) m (
      .d  ({d_in, {q[N-2:0], sin}}),
      .sel(load),
      .y  (d_next)
  );

  dff_sc #(
      .N(N),
      .D(DD)
  ) ff (
      .clk  (clk),
      .clear(clear),
      .d    (d_next),
      .q    (q)
  );
endmodule
